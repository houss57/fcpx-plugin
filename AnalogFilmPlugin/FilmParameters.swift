import Foundation
import FxPlug

// MARK: - Parameter IDs
enum ParameterID {
    // Film Stock Parameters
    static let filmStock: UInt32 = 1000
    static let filmFormat: UInt32 = 1001
    static let processType: UInt32 = 1002
    
    // Grain Parameters
    static let grainAmount: UInt32 = 2000
    static let grainSize: UInt32 = 2001
    static let grainShadows: UInt32 = 2002
    static let grainHighlights: UInt32 = 2003
    static let grainChroma: UInt32 = 2004
    
    // Halation Parameters
    static let halationAmount: UInt32 = 3000
    static let halationThreshold: UInt32 = 3001
    static let halationRadius: UInt32 = 3002
    static let halationBackgroundGain: UInt32 = 3003
    
    // Bloom Parameters
    static let bloomAmount: UInt32 = 4000
    static let bloomThreshold: UInt32 = 4001
    static let bloomRadius: UInt32 = 4002
    
    // Artifact Parameters
    static let gateWeave: UInt32 = 5000
    static let filmBreath: UInt32 = 5001
    static let projectorFlicker: UInt32 = 5002
    static let flickerFrequency: UInt32 = 5003
    
    // Color Parameters
    static let colorTemperature: UInt32 = 6000
    static let contrast: UInt32 = 6001
    static let saturation: UInt32 = 6002
    
    // Output Parameters
    static let inputColorSpace: UInt32 = 7000
    static let outputColorSpace: UInt32 = 7001
    static let exportLUT: UInt32 = 7002
}

// MARK: - Film Stock Types
enum FilmStockType: Int, CaseIterable {
    case kodakVision350D = 0
    case kodakVision350T = 1
    case kodakVision500T = 2
    case kodakPortra160 = 3
    case kodakPortra400 = 4
    case kodakPortra800 = 5
    case fujiEterna250D = 6
    case fujiEterna500T = 7
    case agfaVista200 = 8
    case agfaVista400 = 9
    case ilfordHP5 = 10
    case ilfordFP4 = 11
    case kodakTrix400 = 12
    case kodakTMax400 = 13
    
    var displayName: String {
        switch self {
        case .kodakVision350D: return "Kodak Vision3 50D"
        case .kodakVision350T: return "Kodak Vision3 200T"
        case .kodakVision500T: return "Kodak Vision3 500T"
        case .kodakPortra160: return "Kodak Portra 160"
        case .kodakPortra400: return "Kodak Portra 400"
        case .kodakPortra800: return "Kodak Portra 800"
        case .fujiEterna250D: return "Fuji Eterna 250D"
        case .fujiEterna500T: return "Fuji Eterna 500T"
        case .agfaVista200: return "Agfa Vista 200"
        case .agfaVista400: return "Agfa Vista 400"
        case .ilfordHP5: return "Ilford HP5 Plus"
        case .ilfordFP4: return "Ilford FP4 Plus"
        case .kodakTrix400: return "Kodak Tri-X 400"
        case .kodakTMax400: return "Kodak T-Max 400"
        }
    }
    
    var isBlackAndWhite: Bool {
        switch self {
        case .ilfordHP5, .ilfordFP4, .kodakTrix400, .kodakTMax400:
            return true
        default:
            return false
        }
    }
    
    var isoSpeed: Int {
        switch self {
        case .kodakVision350D: return 50
        case .kodakVision350T: return 200
        case .kodakVision500T: return 500
        case .kodakPortra160: return 160
        case .kodakPortra400: return 400
        case .kodakPortra800: return 800
        case .fujiEterna250D: return 250
        case .fujiEterna500T: return 500
        case .agfaVista200: return 200
        case .agfaVista400: return 400
        case .ilfordHP5: return 400
        case .ilfordFP4: return 125
        case .kodakTrix400: return 400
        case .kodakTMax400: return 400
        }
    }
}

// MARK: - Film Format Types
enum FilmFormat: Int, CaseIterable {
    case format8mm = 0
    case format16mm = 1
    case format35mm = 2
    case format65mm = 3
    
    var displayName: String {
        switch self {
        case .format8mm: return "8mm"
        case .format16mm: return "16mm"
        case .format35mm: return "35mm"
        case .format65mm: return "65mm"
        }
    }
    
    var grainSizeMultiplier: Float {
        switch self {
        case .format8mm: return 2.5
        case .format16mm: return 1.8
        case .format35mm: return 1.0
        case .format65mm: return 0.6
        }
    }
    
    var artifactIntensity: Float {
        switch self {
        case .format8mm: return 1.5
        case .format16mm: return 1.2
        case .format35mm: return 1.0
        case .format65mm: return 0.7
        }
    }
}

// MARK: - Process Types
enum ProcessType: Int, CaseIterable {
    case negative = 0
    case print = 1
    case reversal = 2
    
    var displayName: String {
        switch self {
        case .negative: return "Negative"
        case .print: return "Print"
        case .reversal: return "Reversal"
        }
    }
}

// MARK: - Color Space Types
enum InputColorSpace: Int, CaseIterable {
    case rec709 = 0
    case arriLogC = 1
    case sonyS_Log3 = 2
    case panasonicV_Log = 3
    case blackmagicFilm = 4
    case redLogFilm = 5
    
    var displayName: String {
        switch self {
        case .rec709: return "Rec.709"
        case .arriLogC: return "ARRI LogC"
        case .sonyS_Log3: return "Sony S-Log3"
        case .panasonicV_Log: return "Panasonic V-Log"
        case .blackmagicFilm: return "Blackmagic Film"
        case .redLogFilm: return "RED LogFilm"
        }
    }
}

enum OutputColorSpace: Int, CaseIterable {
    case rec709 = 0
    case rec2020 = 1
    case p3D65 = 2
    case aces = 3
    
    var displayName: String {
        switch self {
        case .rec709: return "Rec.709"
        case .rec2020: return "Rec.2020"
        case .p3D65: return "P3-D65"
        case .aces: return "ACES"
        }
    }
}

// MARK: - Parameter Retrieval
struct FilmEffectParameters {
    // Film Stock
    let filmStock: FilmStockType
    let filmFormat: FilmFormat
    let processType: ProcessType
    
    // Grain
    let grainAmount: Float
    let grainSize: Float
    let grainShadows: Float
    let grainHighlights: Float
    let grainChroma: Float
    
    // Halation
    let halationAmount: Float
    let halationThreshold: Float
    let halationRadius: Float
    let halationBackgroundGain: Float
    
    // Bloom
    let bloomAmount: Float
    let bloomThreshold: Float
    let bloomRadius: Float
    
    // Artifacts
    let gateWeave: Float
    let filmBreath: Float
    let projectorFlicker: Float
    let flickerFrequency: Float
    
    // Color
    let colorTemperature: Float
    let contrast: Float
    let saturation: Float
    
    // Output
    let inputColorSpace: InputColorSpace
    let outputColorSpace: OutputColorSpace
    
    // Computed properties based on film format and stock
    var effectiveGrainSize: Float {
        return grainSize * filmFormat.grainSizeMultiplier
    }
    
    var effectiveArtifactIntensity: Float {
        return filmFormat.artifactIntensity
    }
    
    var effectiveGrainAmount: Float {
        let isoMultiplier = Float(filmStock.isoSpeed) / 400.0 // 400 ISO as baseline
        return grainAmount * sqrt(isoMultiplier)
    }
}

extension AnalogFilmEffect {
    func getParameters(from paramHelper: FxParameterRetrievalAPI_v6, renderInfo: FxRenderInfo) throws -> FilmEffectParameters {
        
        let filmStockValue = try paramHelper.getIntValue(ParameterID.filmStock, atTime: renderInfo.renderTime)
        let filmFormatValue = try paramHelper.getIntValue(ParameterID.filmFormat, atTime: renderInfo.renderTime)
        let processTypeValue = try paramHelper.getIntValue(ParameterID.processType, atTime: renderInfo.renderTime)
        
        let grainAmount = try paramHelper.getFloatValue(ParameterID.grainAmount, atTime: renderInfo.renderTime)
        let grainSize = try paramHelper.getFloatValue(ParameterID.grainSize, atTime: renderInfo.renderTime)
        let grainShadows = try paramHelper.getFloatValue(ParameterID.grainShadows, atTime: renderInfo.renderTime)
        let grainHighlights = try paramHelper.getFloatValue(ParameterID.grainHighlights, atTime: renderInfo.renderTime)
        let grainChroma = try paramHelper.getFloatValue(ParameterID.grainChroma, atTime: renderInfo.renderTime)
        
        let halationAmount = try paramHelper.getFloatValue(ParameterID.halationAmount, atTime: renderInfo.renderTime)
        let halationThreshold = try paramHelper.getFloatValue(ParameterID.halationThreshold, atTime: renderInfo.renderTime)
        let halationRadius = try paramHelper.getFloatValue(ParameterID.halationRadius, atTime: renderInfo.renderTime)
        let halationBackgroundGain = try paramHelper.getFloatValue(ParameterID.halationBackgroundGain, atTime: renderInfo.renderTime)
        
        let bloomAmount = try paramHelper.getFloatValue(ParameterID.bloomAmount, atTime: renderInfo.renderTime)
        let bloomThreshold = try paramHelper.getFloatValue(ParameterID.bloomThreshold, atTime: renderInfo.renderTime)
        let bloomRadius = try paramHelper.getFloatValue(ParameterID.bloomRadius, atTime: renderInfo.renderTime)
        
        let gateWeave = try paramHelper.getFloatValue(ParameterID.gateWeave, atTime: renderInfo.renderTime)
        let filmBreath = try paramHelper.getFloatValue(ParameterID.filmBreath, atTime: renderInfo.renderTime)
        let projectorFlicker = try paramHelper.getFloatValue(ParameterID.projectorFlicker, atTime: renderInfo.renderTime)
        let flickerFrequency = try paramHelper.getFloatValue(ParameterID.flickerFrequency, atTime: renderInfo.renderTime)
        
        let colorTemperature = try paramHelper.getFloatValue(ParameterID.colorTemperature, atTime: renderInfo.renderTime)
        let contrast = try paramHelper.getFloatValue(ParameterID.contrast, atTime: renderInfo.renderTime)
        let saturation = try paramHelper.getFloatValue(ParameterID.saturation, atTime: renderInfo.renderTime)
        
        let inputColorSpaceValue = try paramHelper.getIntValue(ParameterID.inputColorSpace, atTime: renderInfo.renderTime)
        let outputColorSpaceValue = try paramHelper.getIntValue(ParameterID.outputColorSpace, atTime: renderInfo.renderTime)
        
        return FilmEffectParameters(
            filmStock: FilmStockType(rawValue: filmStockValue) ?? .kodakVision350T,
            filmFormat: FilmFormat(rawValue: filmFormatValue) ?? .format35mm,
            processType: ProcessType(rawValue: processTypeValue) ?? .negative,
            grainAmount: grainAmount,
            grainSize: grainSize,
            grainShadows: grainShadows,
            grainHighlights: grainHighlights,
            grainChroma: grainChroma,
            halationAmount: halationAmount,
            halationThreshold: halationThreshold,
            halationRadius: halationRadius,
            halationBackgroundGain: halationBackgroundGain,
            bloomAmount: bloomAmount,
            bloomThreshold: bloomThreshold,
            bloomRadius: bloomRadius,
            gateWeave: gateWeave,
            filmBreath: filmBreath,
            projectorFlicker: projectorFlicker,
            flickerFrequency: flickerFrequency,
            colorTemperature: colorTemperature,
            contrast: contrast,
            saturation: saturation,
            inputColorSpace: InputColorSpace(rawValue: inputColorSpaceValue) ?? .rec709,
            outputColorSpace: OutputColorSpace(rawValue: outputColorSpaceValue) ?? .rec709
        )
    }
}