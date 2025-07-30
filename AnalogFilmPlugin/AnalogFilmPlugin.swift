import Foundation
import FxPlug
import Metal
import MetalPerformanceShaders
import CoreImage
import OSLog

@objc(AnalogFilmEffect)
class AnalogFilmEffect: NSObject, FxEffect2 {
    
    // MARK: - Properties
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var renderPipelineState: MTLRenderPipelineState?
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    private let logger = Logger(subsystem: "com.analogfilm.plugin", category: "AnalogFilmEffect")
    
    // Film stock profiles
    private let filmStockProfiles = FilmStockProfiles()
    
    // MARK: - FxPlug Required Methods
    
    required override init() {
        super.init()
        setupMetal()
    }
    
    func pluginVersion() -> UInt32 {
        return UInt32(kFxAPIVersion)
    }
    
    func displayName() -> String {
        return "Analog Film Emulation"
    }
    
    func versionDisplayName() -> String {
        return "1.0"
    }
    
    func groupDisplayName() -> String {
        return "Film Effects"
    }
    
    func supportedPixelFormats() -> [NSNumber] {
        return [
            NSNumber(value: kFxPixelFormat_BGRA8_Unorm.rawValue),
            NSNumber(value: kFxPixelFormat_RGBA16f.rawValue),
            NSNumber(value: kFxPixelFormat_RGBA32f.rawValue)
        ]
    }
    
    // MARK: - Parameter Setup
    
    func addParameters() throws {
        let paramAPI = parameterCreationAPI()
        
        try setupFilmStockParameters(paramAPI)
        try setupGrainParameters(paramAPI)
        try setupHalationParameters(paramAPI)
        try setupBloomParameters(paramAPI)
        try setupArtifactParameters(paramAPI)
        try setupColorParameters(paramAPI)
        try setupOutputParameters(paramAPI)
    }
    
    private func setupFilmStockParameters(_ paramAPI: FxParameterCreationAPI_v5) throws {
        // Film Stock Selection Group
        try paramAPI.addPopupMenu(withName: "Film Stock",
                                  parameterID: ParameterID.filmStock,
                                  defaultValue: 0,
                                  menuEntries: FilmStockType.allCases.map { $0.displayName },
                                  parameterFlags: 0)
        
        // Film Format (affects grain size and artifacts)
        try paramAPI.addPopupMenu(withName: "Film Format",
                                  parameterID: ParameterID.filmFormat,
                                  defaultValue: 2, // 35mm default
                                  menuEntries: ["8mm", "16mm", "35mm", "65mm"],
                                  parameterFlags: 0)
        
        // Process Type
        try paramAPI.addPopupMenu(withName: "Process Type",
                                  parameterID: ParameterID.processType,
                                  defaultValue: 0,
                                  menuEntries: ["Negative", "Print", "Reversal"],
                                  parameterFlags: 0)
    }
    
    private func setupGrainParameters(_ paramAPI: FxParameterCreationAPI_v5) throws {
        // Grain Amount
        try paramAPI.addFloat(slider: "Grain Amount",
                              parameterID: ParameterID.grainAmount,
                              defaultValue: 0.5,
                              parameterMin: 0.0,
                              parameterMax: 2.0,
                              sliderMin: 0.0,
                              sliderMax: 1.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Grain Size
        try paramAPI.addFloat(slider: "Grain Size",
                              parameterID: ParameterID.grainSize,
                              defaultValue: 1.0,
                              parameterMin: 0.1,
                              parameterMax: 5.0,
                              sliderMin: 0.1,
                              sliderMax: 3.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Grain Shadows/Highlights Distribution
        try paramAPI.addFloat(slider: "Shadows Grain",
                              parameterID: ParameterID.grainShadows,
                              defaultValue: 1.0,
                              parameterMin: 0.0,
                              parameterMax: 2.0,
                              sliderMin: 0.0,
                              sliderMax: 2.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        try paramAPI.addFloat(slider: "Highlights Grain",
                              parameterID: ParameterID.grainHighlights,
                              defaultValue: 1.2,
                              parameterMin: 0.0,
                              parameterMax: 2.0,
                              sliderMin: 0.0,
                              sliderMax: 2.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Grain Chroma
        try paramAPI.addFloat(slider: "Grain Chroma",
                              parameterID: ParameterID.grainChroma,
                              defaultValue: 0.3,
                              parameterMin: 0.0,
                              parameterMax: 1.0,
                              sliderMin: 0.0,
                              sliderMax: 1.0,
                              delta: 0.01,
                              parameterFlags: 0)
    }
    
    private func setupHalationParameters(_ paramAPI: FxParameterCreationAPI_v5) throws {
        // Halation Amount
        try paramAPI.addFloat(slider: "Halation Amount",
                              parameterID: ParameterID.halationAmount,
                              defaultValue: 0.3,
                              parameterMin: 0.0,
                              parameterMax: 1.0,
                              sliderMin: 0.0,
                              sliderMax: 1.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Halation Threshold
        try paramAPI.addFloat(slider: "Halation Threshold",
                              parameterID: ParameterID.halationThreshold,
                              defaultValue: 0.8,
                              parameterMin: 0.0,
                              parameterMax: 1.0,
                              sliderMin: 0.0,
                              sliderMax: 1.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Halation Radius
        try paramAPI.addFloat(slider: "Halation Radius",
                              parameterID: ParameterID.halationRadius,
                              defaultValue: 20.0,
                              parameterMin: 1.0,
                              parameterMax: 100.0,
                              sliderMin: 1.0,
                              sliderMax: 50.0,
                              delta: 0.1,
                              parameterFlags: 0)
        
        // Background Gain
        try paramAPI.addFloat(slider: "Background Gain",
                              parameterID: ParameterID.halationBackgroundGain,
                              defaultValue: 0.5,
                              parameterMin: 0.0,
                              parameterMax: 1.0,
                              sliderMin: 0.0,
                              sliderMax: 1.0,
                              delta: 0.01,
                              parameterFlags: 0)
    }
    
    private func setupBloomParameters(_ paramAPI: FxParameterCreationAPI_v5) throws {
        // Bloom Amount
        try paramAPI.addFloat(slider: "Bloom Amount",
                              parameterID: ParameterID.bloomAmount,
                              defaultValue: 0.2,
                              parameterMin: 0.0,
                              parameterMax: 1.0,
                              sliderMin: 0.0,
                              sliderMax: 1.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Bloom Threshold
        try paramAPI.addFloat(slider: "Bloom Threshold",
                              parameterID: ParameterID.bloomThreshold,
                              defaultValue: 0.7,
                              parameterMin: 0.0,
                              parameterMax: 1.0,
                              sliderMin: 0.0,
                              sliderMax: 1.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Bloom Radius
        try paramAPI.addFloat(slider: "Bloom Radius",
                              parameterID: ParameterID.bloomRadius,
                              defaultValue: 15.0,
                              parameterMin: 1.0,
                              parameterMax: 50.0,
                              sliderMin: 1.0,
                              sliderMax: 30.0,
                              delta: 0.1,
                              parameterFlags: 0)
    }
    
    private func setupArtifactParameters(_ paramAPI: FxParameterCreationAPI_v5) throws {
        // Gate Weave
        try paramAPI.addFloat(slider: "Gate Weave",
                              parameterID: ParameterID.gateWeave,
                              defaultValue: 0.0,
                              parameterMin: 0.0,
                              parameterMax: 10.0,
                              sliderMin: 0.0,
                              sliderMax: 5.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Film Breath
        try paramAPI.addFloat(slider: "Film Breath",
                              parameterID: ParameterID.filmBreath,
                              defaultValue: 0.0,
                              parameterMin: 0.0,
                              parameterMax: 0.1,
                              sliderMin: 0.0,
                              sliderMax: 0.05,
                              delta: 0.001,
                              parameterFlags: 0)
        
        // Projector Flicker
        try paramAPI.addFloat(slider: "Projector Flicker",
                              parameterID: ParameterID.projectorFlicker,
                              defaultValue: 0.0,
                              parameterMin: 0.0,
                              parameterMax: 0.1,
                              sliderMin: 0.0,
                              sliderMax: 0.05,
                              delta: 0.001,
                              parameterFlags: 0)
        
        // Flicker Frequency
        try paramAPI.addFloat(slider: "Flicker Frequency",
                              parameterID: ParameterID.flickerFrequency,
                              defaultValue: 48.0,
                              parameterMin: 24.0,
                              parameterMax: 120.0,
                              sliderMin: 24.0,
                              sliderMax: 60.0,
                              delta: 0.1,
                              parameterFlags: 0)
    }
    
    private func setupColorParameters(_ paramAPI: FxParameterCreationAPI_v5) throws {
        // Color Temperature Adjustment
        try paramAPI.addFloat(slider: "Color Temperature",
                              parameterID: ParameterID.colorTemperature,
                              defaultValue: 0.0,
                              parameterMin: -1.0,
                              parameterMax: 1.0,
                              sliderMin: -0.5,
                              sliderMax: 0.5,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Contrast
        try paramAPI.addFloat(slider: "Contrast",
                              parameterID: ParameterID.contrast,
                              defaultValue: 1.0,
                              parameterMin: 0.1,
                              parameterMax: 3.0,
                              sliderMin: 0.5,
                              sliderMax: 2.0,
                              delta: 0.01,
                              parameterFlags: 0)
        
        // Saturation
        try paramAPI.addFloat(slider: "Saturation",
                              parameterID: ParameterID.saturation,
                              defaultValue: 1.0,
                              parameterMin: 0.0,
                              parameterMax: 2.0,
                              sliderMin: 0.0,
                              sliderMax: 1.5,
                              delta: 0.01,
                              parameterFlags: 0)
    }
    
    private func setupOutputParameters(_ paramAPI: FxParameterCreationAPI_v5) throws {
        // Input Color Space
        try paramAPI.addPopupMenu(withName: "Input Color Space",
                                  parameterID: ParameterID.inputColorSpace,
                                  defaultValue: 0,
                                  menuEntries: ["Rec.709", "ARRI LogC", "Sony S-Log3", "Panasonic V-Log", "Blackmagic Film", "RED LogFilm"],
                                  parameterFlags: 0)
        
        // Output Color Space
        try paramAPI.addPopupMenu(withName: "Output Color Space",
                                  parameterID: ParameterID.outputColorSpace,
                                  defaultValue: 0,
                                  menuEntries: ["Rec.709", "Rec.2020", "P3-D65", "ACES"],
                                  parameterFlags: 0)
        
        // Export LUT Button
        try paramAPI.addButton(withName: "Export 3D LUT",
                               parameterID: ParameterID.exportLUT,
                               parameterFlags: 0)
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            logger.error("Failed to create Metal device")
            return
        }
        
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        // Load Metal library and create compute pipeline states
        guard let library = device.makeDefaultLibrary() else {
            logger.error("Failed to load Metal library")
            return
        }
        
        createComputePipelineStates(library: library)
    }
    
    private func createComputePipelineStates(library: MTLLibrary) {
        let shaderNames = [
            "analogGrain",
            "halationEffect",
            "bloomEffect",
            "filmStockResponse",
            "colorGrading",
            "gateWeave"
        ]
        
        for shaderName in shaderNames {
            guard let function = library.makeFunction(name: shaderName) else {
                logger.error("Failed to create function: \(shaderName)")
                continue
            }
            
            do {
                let pipelineState = try device?.makeComputePipelineState(function: function)
                computePipelineStates[shaderName] = pipelineState
            } catch {
                logger.error("Failed to create compute pipeline state for \(shaderName): \(error)")
            }
        }
    }
    
    // MARK: - Rendering
    
    func renderOutput(
        _ output: FxImageTile,
        withInput input: FxImageTile,
        withInfo renderInfo: FxRenderInfo,
        andParameterHelper paramHelper: FxParameterRetrievalAPI_v6
    ) -> FxPlugErrorCode {
        
        guard let device = device,
              let commandQueue = commandQueue else {
            return kFxError_InternalError
        }
        
        do {
            // Get parameter values
            let parameters = try getParameters(from: paramHelper, renderInfo: renderInfo)
            
            // Create command buffer
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                return kFxError_InternalError
            }
            
            // Convert input to Metal texture
            guard let inputTexture = input.ioSurface().metalTexture(device: device),
                  let outputTexture = output.ioSurface().metalTexture(device: device) else {
                return kFxError_InternalError
            }
            
            // Apply film effects pipeline
            try applyFilmEffects(
                input: inputTexture,
                output: outputTexture,
                parameters: parameters,
                commandBuffer: commandBuffer,
                renderInfo: renderInfo
            )
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            return kFxError_NoError
            
        } catch {
            logger.error("Rendering failed: \(error)")
            return kFxError_InternalError
        }
    }
}