import Foundation
import Metal
import simd
import OSLog

// MARK: - Color Management System

extension AnalogFilmEffect {
    
    func applyColorSpaceConversion(
        input: MTLTexture,
        output: MTLTexture,
        inputSpace: InputColorSpace? = nil,
        outputSpace: OutputColorSpace? = nil,
        commandBuffer: MTLCommandBuffer
    ) throws {
        
        guard let device = device else {
            throw FilmEffectError.metalSetupFailed
        }
        
        // Determine conversion type
        var conversionMatrix = matrix_float3x3(1.0) // Identity matrix
        var needsConversion = false
        
        if let inputSpace = inputSpace {
            conversionMatrix = getInputConversionMatrix(for: inputSpace)
            needsConversion = true
        }
        
        if let outputSpace = outputSpace {
            let outputMatrix = getOutputConversionMatrix(for: outputSpace)
            conversionMatrix = outputMatrix * conversionMatrix
            needsConversion = true
        }
        
        if !needsConversion {
            // No conversion needed, just copy
            try copyTexture(input: input, output: output, commandBuffer: commandBuffer)
            return
        }
        
        // Create color conversion compute kernel
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "colorSpaceConversion"),
              let pipelineState = try? device.makeComputePipelineState(function: function) else {
            throw FilmEffectError.pipelineStateNotFound
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw FilmEffectError.encoderCreationFailed
        }
        
        var matrix = conversionMatrix
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)
        computeEncoder.setBytes(&matrix, length: MemoryLayout<matrix_float3x3>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    // MARK: - Input Color Space Conversion Matrices
    
    private func getInputConversionMatrix(for inputSpace: InputColorSpace) -> matrix_float3x3 {
        switch inputSpace {
        case .rec709:
            // Already in Rec.709, no conversion needed
            return matrix_float3x3(1.0)
            
        case .arriLogC:
            // ARRI LogC to Linear Rec.709
            // This is handled in the Metal shader with log-to-linear conversion
            return matrix_float3x3(1.0)
            
        case .sonyS_Log3:
            // Sony S-Log3 to Linear
            return getSonyS_Log3Matrix()
            
        case .panasonicV_Log:
            // Panasonic V-Log to Linear
            return getPanasonicV_LogMatrix()
            
        case .blackmagicFilm:
            // Blackmagic Film to Linear
            return getBlackmagicFilmMatrix()
            
        case .redLogFilm:
            // RED LogFilm to Linear
            return getREDLogFilmMatrix()
        }
    }
    
    // MARK: - Output Color Space Conversion Matrices
    
    private func getOutputConversionMatrix(for outputSpace: OutputColorSpace) -> matrix_float3x3 {
        switch outputSpace {
        case .rec709:
            // Linear to Rec.709 (no matrix needed, handled by gamma)
            return matrix_float3x3(1.0)
            
        case .rec2020:
            // Rec.709 to Rec.2020
            return matrix_float3x3(columns: (
                simd_float3(0.6274, 0.3293, 0.0433),
                simd_float3(0.0691, 0.9195, 0.0114),
                simd_float3(0.0164, 0.0880, 0.8956)
            ))
            
        case .p3D65:
            // Rec.709 to P3-D65
            return matrix_float3x3(columns: (
                simd_float3(0.8225, 0.1774, 0.0001),
                simd_float3(0.0331, 0.9669, 0.0000),
                simd_float3(0.0171, 0.0724, 0.9105)
            ))
            
        case .aces:
            // Rec.709 to ACEScg
            return matrix_float3x3(columns: (
                simd_float3(0.6131, 0.3395, 0.0474),
                simd_float3(0.0702, 0.9164, 0.0134),
                simd_float3(0.0206, 0.1096, 0.8698)
            ))
        }
    }
    
    // MARK: - Specific Log Format Matrices
    
    private func getSonyS_Log3Matrix() -> matrix_float3x3 {
        // Sony S-Log3 to Rec.709 matrix
        return matrix_float3x3(columns: (
            simd_float3(1.0, 0.0, 0.0),
            simd_float3(0.0, 1.0, 0.0),
            simd_float3(0.0, 0.0, 1.0)
        ))
    }
    
    private func getPanasonicV_LogMatrix() -> matrix_float3x3 {
        // Panasonic V-Log to Rec.709 matrix
        return matrix_float3x3(columns: (
            simd_float3(1.0, 0.0, 0.0),
            simd_float3(0.0, 1.0, 0.0),
            simd_float3(0.0, 0.0, 1.0)
        ))
    }
    
    private func getBlackmagicFilmMatrix() -> matrix_float3x3 {
        // Blackmagic Film to Rec.709 matrix
        return matrix_float3x3(columns: (
            simd_float3(1.0, 0.0, 0.0),
            simd_float3(0.0, 1.0, 0.0),
            simd_float3(0.0, 0.0, 1.0)
        ))
    }
    
    private func getREDLogFilmMatrix() -> matrix_float3x3 {
        // RED LogFilm to Rec.709 matrix
        return matrix_float3x3(columns: (
            simd_float3(1.0, 0.0, 0.0),
            simd_float3(0.0, 1.0, 0.0),
            simd_float3(0.0, 0.0, 1.0)
        ))
    }
}

// MARK: - Additional Color Space Conversion Kernels

// This would be added to the FilmEffects.metal file:
/*
kernel void colorSpaceConversion(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float3x3& conversionMatrix [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float3 convertedColor = conversionMatrix * inputColor.rgb;
    
    outputTexture.write(float4(convertedColor, inputColor.a), gid);
}

// Log format conversions
kernel void arriLogCToLinear(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float3 logcColor = inputColor.rgb;
    
    // ARRI LogC to Linear conversion
    float3 linearColor = (pow(10.0, (logcColor - 0.385537) / 0.247190) - 0.052272) / 5.555556;
    linearColor = max(linearColor, 0.0);
    
    outputTexture.write(float4(linearColor, inputColor.a), gid);
}

kernel void sonyS_Log3ToLinear(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float3 slog3Color = inputColor.rgb;
    
    // Sony S-Log3 to Linear conversion
    float3 linearColor = select(
        (slog3Color - 0.092864) / 5.367655,
        (pow(10.0, (slog3Color - 0.420721) / 0.261266) - 0.037584) / 0.991461,
        slog3Color >= 0.159301
    );
    linearColor = max(linearColor, 0.0);
    
    outputTexture.write(float4(linearColor, inputColor.a), gid);
}

kernel void panasonicV_LogToLinear(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float3 vlogColor = inputColor.rgb;
    
    // Panasonic V-Log to Linear conversion
    float3 linearColor = select(
        (vlogColor - 0.125) / 5.6,
        pow(10.0, (vlogColor - 0.241514) / 0.14847) - 0.00873,
        vlogColor >= 0.181
    );
    linearColor = max(linearColor, 0.0);
    
    outputTexture.write(float4(linearColor, inputColor.a), gid);
}
*/

// MARK: - LUT Export Functionality

extension AnalogFilmEffect {
    
    func exportLUT(parameters: FilmEffectParameters, size: Int = 33) -> Data? {
        guard let device = device,
              let commandQueue = commandQueue else {
            logger.error("Metal not initialized for LUT export")
            return nil
        }
        
        let lutSize = size
        let lutData = generateIdentityLUT(size: lutSize)
        
        // Create textures for LUT processing
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: lutSize * lutSize,
            height: lutSize,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let inputTexture = device.makeTexture(descriptor: textureDescriptor),
              let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            logger.error("Failed to create LUT textures")
            return nil
        }
        
        // Upload identity LUT data
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: lutSize * lutSize, height: lutSize, depth: 1))
        
        inputTexture.replace(region: region,
                           mipmapLevel: 0,
                           withBytes: lutData,
                           bytesPerRow: lutSize * lutSize * 4 * MemoryLayout<Float>.size)
        
        // Process LUT through film pipeline
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            logger.error("Failed to create command buffer for LUT export")
            return nil
        }
        
        do {
            // Apply film effects to the identity LUT
            let renderInfo = FxRenderInfo() // Create dummy render info
            try applyFilmEffects(
                input: inputTexture,
                output: outputTexture,
                parameters: parameters,
                commandBuffer: commandBuffer,
                renderInfo: renderInfo
            )
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // Read back processed LUT data
            let processedData = UnsafeMutablePointer<Float>.allocate(capacity: lutSize * lutSize * lutSize * 4)
            defer { processedData.deallocate() }
            
            outputTexture.getBytes(processedData,
                                 bytesPerRow: lutSize * lutSize * 4 * MemoryLayout<Float>.size,
                                 from: region,
                                 mipmapLevel: 0)
            
            // Convert to .cube format
            return convertToCubeFormat(data: processedData, size: lutSize)
            
        } catch {
            logger.error("Failed to process LUT: \(error)")
            return nil
        }
    }
    
    private func generateIdentityLUT(size: Int) -> [Float] {
        var lutData: [Float] = []
        lutData.reserveCapacity(size * size * size * 4)
        
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let red = Float(r) / Float(size - 1)
                    let green = Float(g) / Float(size - 1)
                    let blue = Float(b) / Float(size - 1)
                    
                    lutData.append(red)
                    lutData.append(green)
                    lutData.append(blue)
                    lutData.append(1.0) // Alpha
                }
            }
        }
        
        return lutData
    }
    
    private func convertToCubeFormat(data: UnsafePointer<Float>, size: Int) -> Data {
        var cubeString = "# Analog Film LUT\n"
        cubeString += "# Generated by Analog Film Plugin\n"
        cubeString += "LUT_3D_SIZE \(size)\n"
        cubeString += "DOMAIN_MIN 0.0 0.0 0.0\n"
        cubeString += "DOMAIN_MAX 1.0 1.0 1.0\n\n"
        
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let index = (b * size * size + g * size + r) * 4
                    let red = data[index]
                    let green = data[index + 1]
                    let blue = data[index + 2]
                    
                    cubeString += String(format: "%.6f %.6f %.6f\n", red, green, blue)
                }
            }
        }
        
        return cubeString.data(using: .utf8) ?? Data()
    }
}