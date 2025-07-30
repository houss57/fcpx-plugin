import Foundation
import Metal
import MetalPerformanceShaders
import FxPlug
import OSLog

// MARK: - Rendering Pipeline Extension

extension AnalogFilmEffect {
    
    func applyFilmEffects(
        input: MTLTexture,
        output: MTLTexture,
        parameters: FilmEffectParameters,
        commandBuffer: MTLCommandBuffer,
        renderInfo: FxRenderInfo
    ) throws {
        
        guard let device = device else {
            throw FilmEffectError.metalSetupFailed
        }
        
        let width = input.width
        let height = input.height
        
        // Create intermediate textures
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: input.pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let tempTexture1 = device.makeTexture(descriptor: textureDescriptor),
              let tempTexture2 = device.makeTexture(descriptor: textureDescriptor),
              let tempTexture3 = device.makeTexture(descriptor: textureDescriptor),
              let brightsTexture = device.makeTexture(descriptor: textureDescriptor),
              let blurredTexture = device.makeTexture(descriptor: textureDescriptor) else {
            throw FilmEffectError.textureCreationFailed
        }
        
        var currentInput = input
        var currentOutput = tempTexture1
        
        // Step 1: Color space conversion (if needed)
        if parameters.inputColorSpace != .rec709 {
            try applyColorSpaceConversion(
                input: currentInput,
                output: currentOutput,
                inputSpace: parameters.inputColorSpace,
                commandBuffer: commandBuffer
            )
            swap(&currentInput, &currentOutput)
        }
        
        // Step 2: Gate weave (geometric jitter)
        if parameters.gateWeave > 0.0 {
            try applyGateWeave(
                input: currentInput,
                output: currentOutput,
                parameters: parameters,
                renderInfo: renderInfo,
                commandBuffer: commandBuffer
            )
            swap(&currentInput, &currentOutput)
        }
        
        // Step 3: Film stock response
        try applyFilmStockResponse(
            input: currentInput,
            output: currentOutput,
            parameters: parameters,
            commandBuffer: commandBuffer
        )
        swap(&currentInput, &currentOutput)
        
        // Step 4: Analog grain
        if parameters.grainAmount > 0.0 {
            try applyAnalogGrain(
                input: currentInput,
                output: currentOutput,
                parameters: parameters,
                renderInfo: renderInfo,
                commandBuffer: commandBuffer
            )
            swap(&currentInput, &currentOutput)
        }
        
        // Step 5: Extract bright areas for halation and bloom
        if parameters.halationAmount > 0.0 || parameters.bloomAmount > 0.0 {
            let brightnessThreshold = min(parameters.halationThreshold, parameters.bloomThreshold)
            try extractBrightAreas(
                input: currentInput,
                output: brightsTexture,
                threshold: brightnessThreshold,
                commandBuffer: commandBuffer
            )
        }
        
        // Step 6: Halation effect
        if parameters.halationAmount > 0.0 {
            // Blur bright areas for halation
            try applyGaussianBlur(
                input: brightsTexture,
                output: blurredTexture,
                radius: parameters.halationRadius,
                commandBuffer: commandBuffer
            )
            
            try applyHalation(
                input: currentInput,
                brightsInput: blurredTexture,
                output: currentOutput,
                parameters: parameters,
                commandBuffer: commandBuffer
            )
            swap(&currentInput, &currentOutput)
        }
        
        // Step 7: Bloom effect
        if parameters.bloomAmount > 0.0 {
            // Use different blur radius for bloom
            try applyGaussianBlur(
                input: brightsTexture,
                output: blurredTexture,
                radius: parameters.bloomRadius,
                commandBuffer: commandBuffer
            )
            
            try applyBloom(
                input: currentInput,
                blurredInput: blurredTexture,
                output: currentOutput,
                parameters: parameters,
                commandBuffer: commandBuffer
            )
            swap(&currentInput, &currentOutput)
        }
        
        // Step 8: Final color grading
        try applyColorGrading(
            input: currentInput,
            output: currentOutput,
            parameters: parameters,
            commandBuffer: commandBuffer
        )
        swap(&currentInput, &currentOutput)
        
        // Step 9: Output color space conversion (if needed)
        if parameters.outputColorSpace != .rec709 {
            try applyColorSpaceConversion(
                input: currentInput,
                output: output,
                outputSpace: parameters.outputColorSpace,
                commandBuffer: commandBuffer
            )
        } else {
            // Copy final result to output
            try copyTexture(
                input: currentInput,
                output: output,
                commandBuffer: commandBuffer
            )
        }
    }
    
    // MARK: - Individual Effect Applications
    
    private func applyFilmStockResponse(
        input: MTLTexture,
        output: MTLTexture,
        parameters: FilmEffectParameters,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates["filmStockResponse"] else {
            throw FilmEffectError.pipelineStateNotFound
        }
        
        // Get film stock profile
        let filmProfile = filmStockProfiles.getProfile(for: parameters.filmStock)
        
        // Create film stock data buffer
        var filmStockData = FilmStockData(
            colorMatrix: filmProfile.colorMatrix,
            shadowsLift: filmProfile.contrastCurve.shadows,
            highlightsRolloff: filmProfile.contrastCurve.highlights,
            gamma: filmProfile.contrastCurve.gamma,
            contrastMult: filmProfile.contrastCurve.contrast,
            grainBaseSize: filmProfile.grainCharacteristics.baseSize,
            grainDensity: filmProfile.grainCharacteristics.density
        )
        
        // Create parameter buffer
        var filmParams = createFilmParameters(from: parameters)
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)
        computeEncoder.setBytes(&filmStockData, length: MemoryLayout<FilmStockData>.size, index: 0)
        computeEncoder.setBytes(&filmParams, length: MemoryLayout<FilmParameters>.size, index: 1)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    private func applyAnalogGrain(
        input: MTLTexture,
        output: MTLTexture,
        parameters: FilmEffectParameters,
        renderInfo: FxRenderInfo,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates["analogGrain"] else {
            throw FilmEffectError.pipelineStateNotFound
        }
        
        let filmProfile = filmStockProfiles.getProfile(for: parameters.filmStock)
        
        var filmStockData = FilmStockData(
            colorMatrix: filmProfile.colorMatrix,
            shadowsLift: filmProfile.contrastCurve.shadows,
            highlightsRolloff: filmProfile.contrastCurve.highlights,
            gamma: filmProfile.contrastCurve.gamma,
            contrastMult: filmProfile.contrastCurve.contrast,
            grainBaseSize: filmProfile.grainCharacteristics.baseSize,
            grainDensity: filmProfile.grainCharacteristics.density
        )
        
        var filmParams = createFilmParameters(from: parameters, renderInfo: renderInfo)
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)
        computeEncoder.setBytes(&filmParams, length: MemoryLayout<FilmParameters>.size, index: 0)
        computeEncoder.setBytes(&filmStockData, length: MemoryLayout<FilmStockData>.size, index: 1)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    private func applyHalation(
        input: MTLTexture,
        brightsInput: MTLTexture,
        output: MTLTexture,
        parameters: FilmEffectParameters,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates["halationEffect"] else {
            throw FilmEffectError.pipelineStateNotFound
        }
        
        var filmParams = createFilmParameters(from: parameters)
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(brightsInput, index: 1)
        computeEncoder.setTexture(output, index: 2)
        computeEncoder.setBytes(&filmParams, length: MemoryLayout<FilmParameters>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    private func applyBloom(
        input: MTLTexture,
        blurredInput: MTLTexture,
        output: MTLTexture,
        parameters: FilmEffectParameters,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates["bloomEffect"] else {
            throw FilmEffectError.pipelineStateNotFound
        }
        
        var filmParams = createFilmParameters(from: parameters)
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(blurredInput, index: 1)
        computeEncoder.setTexture(output, index: 2)
        computeEncoder.setBytes(&filmParams, length: MemoryLayout<FilmParameters>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    private func applyGateWeave(
        input: MTLTexture,
        output: MTLTexture,
        parameters: FilmEffectParameters,
        renderInfo: FxRenderInfo,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates["gateWeave"] else {
            throw FilmEffectError.pipelineStateNotFound
        }
        
        // Generate random weave offset based on frame
        let frameNumber = UInt32(renderInfo.renderTime.value)
        let randomSeed = Float(frameNumber.hashValue) / Float(Int32.max)
        
        let maxWeave = parameters.gateWeave * parameters.effectiveArtifactIntensity
        let weaveX = (randomSeed * 2.0 - 1.0) * maxWeave
        let weaveY = (randomSeed * 2.0 - 1.0) * maxWeave * 0.7 // Slightly less vertical movement
        
        var filmParams = createFilmParameters(from: parameters, renderInfo: renderInfo)
        filmParams.gateWeaveX = weaveX
        filmParams.gateWeaveY = weaveY
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)
        computeEncoder.setBytes(&filmParams, length: MemoryLayout<FilmParameters>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    private func applyColorGrading(
        input: MTLTexture,
        output: MTLTexture,
        parameters: FilmEffectParameters,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates["colorGrading"] else {
            throw FilmEffectError.pipelineStateNotFound
        }
        
        var filmParams = createFilmParameters(from: parameters)
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)
        computeEncoder.setBytes(&filmParams, length: MemoryLayout<FilmParameters>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    // MARK: - Utility Functions
    
    private func extractBrightAreas(
        input: MTLTexture,
        output: MTLTexture,
        threshold: Float,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates["brightnessThreshold"] else {
            throw FilmEffectError.pipelineStateNotFound
        }
        
        var thresholdValue = threshold
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)
        computeEncoder.setBytes(&thresholdValue, length: MemoryLayout<Float>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    private func applyGaussianBlur(
        input: MTLTexture,
        output: MTLTexture,
        radius: Float,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let device = device else {
            throw FilmEffectError.metalSetupFailed
        }
        
        // Use Metal Performance Shaders for efficient Gaussian blur
        let blur = MPSImageGaussianBlur(device: device, sigma: radius / 3.0)
        blur.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
    }
    
    private func copyTexture(
        input: MTLTexture,
        output: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw FilmEffectError.encoderCreationFailed
        }
        
        blitEncoder.copy(
            from: input,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: input.width, height: input.height, depth: 1),
            to: output,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        
        blitEncoder.endEncoding()
    }
    
    private func createFilmParameters(from parameters: FilmEffectParameters, renderInfo: FxRenderInfo? = nil) -> FilmParameters {
        let time = renderInfo?.renderTime.seconds ?? 0.0
        let frameNumber = renderInfo?.renderTime.value ?? 0
        
        return FilmParameters(
            grainAmount: parameters.effectiveGrainAmount,
            grainSize: parameters.effectiveGrainSize,
            grainShadows: parameters.grainShadows,
            grainHighlights: parameters.grainHighlights,
            grainChroma: parameters.grainChroma,
            halationAmount: parameters.halationAmount,
            halationThreshold: parameters.halationThreshold,
            halationRadius: parameters.halationRadius,
            halationBackgroundGain: parameters.halationBackgroundGain,
            bloomAmount: parameters.bloomAmount,
            bloomThreshold: parameters.bloomThreshold,
            bloomRadius: parameters.bloomRadius,
            gateWeaveX: 0.0, // Will be set by gateWeave function
            gateWeaveY: 0.0, // Will be set by gateWeave function
            filmBreath: parameters.filmBreath,
            projectorFlicker: parameters.projectorFlicker,
            colorTemperature: parameters.colorTemperature,
            contrast: parameters.contrast,
            saturation: parameters.saturation,
            time: Float(time),
            frameNumber: UInt32(frameNumber)
        )
    }
}

// MARK: - Supporting Types

struct FilmParameters {
    let grainAmount: Float
    let grainSize: Float
    let grainShadows: Float
    let grainHighlights: Float
    let grainChroma: Float
    
    let halationAmount: Float
    let halationThreshold: Float
    let halationRadius: Float
    let halationBackgroundGain: Float
    
    let bloomAmount: Float
    let bloomThreshold: Float
    let bloomRadius: Float
    
    var gateWeaveX: Float
    var gateWeaveY: Float
    let filmBreath: Float
    let projectorFlicker: Float
    
    let colorTemperature: Float
    let contrast: Float
    let saturation: Float
    
    let time: Float
    let frameNumber: UInt32
}

struct FilmStockData {
    let colorMatrix: matrix_float3x3
    let shadowsLift: Float
    let highlightsRolloff: Float
    let gamma: Float
    let contrastMult: Float
    let grainBaseSize: Float
    let grainDensity: Float
}

// MARK: - Error Types

enum FilmEffectError: Error {
    case metalSetupFailed
    case textureCreationFailed
    case pipelineStateNotFound
    case encoderCreationFailed
}