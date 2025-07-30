import Foundation
import simd

// MARK: - Film Stock Color Response
struct FilmColorResponse {
    let redResponse: [Float]      // Spectral response curve for red layer
    let greenResponse: [Float]    // Spectral response curve for green layer  
    let blueResponse: [Float]     // Spectral response curve for blue layer
    let colorMatrix: matrix_float3x3  // Color transformation matrix
    let contrastCurve: ToneCurve     // Characteristic curve
    let grainCharacteristics: GrainProfile
}

// MARK: - Tone Curve Definition
struct ToneCurve {
    let shadows: Float        // Shadow lift
    let highlights: Float     // Highlight rolloff
    let gamma: Float         // Mid-tone gamma
    let contrast: Float      // Overall contrast
    let blackPoint: Float    // Black point
    let whitePoint: Float    // White point
    
    func apply(to linearValue: Float) -> Float {
        // Apply film characteristic curve
        let lifted = max(0, linearValue + shadows * (1.0 - linearValue))
        let gammaCorrected = pow(lifted, 1.0 / gamma)
        let contrasted = pow(gammaCorrected, contrast)
        let rolled = contrasted / (contrasted + highlights)
        
        return mix(blackPoint, whitePoint, rolled)
    }
}

// MARK: - Grain Profile
struct GrainProfile {
    let baseSize: Float           // Base grain size
    let density: Float           // Grain density
    let distribution: Float      // Grain distribution pattern
    let shadowMultiplier: Float  // Grain intensity in shadows
    let highlightMultiplier: Float // Grain intensity in highlights
    let chromaIntensity: Float   // Color grain intensity
}

// MARK: - Film Stock Profiles Database
class FilmStockProfiles {
    
    private let profiles: [FilmStockType: FilmColorResponse]
    
    init() {
        var profileDict: [FilmStockType: FilmColorResponse] = [:]
        
        // Kodak Vision3 50D (5203/7203)
        profileDict[.kodakVision350D] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 640, width: 80, sensitivity: 0.85),
            greenResponse: createSpectralResponse(peak: 540, width: 60, sensitivity: 1.0),
            blueResponse: createSpectralResponse(peak: 450, width: 70, sensitivity: 0.9),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(1.05, -0.05, 0.0),
                simd_float3(-0.02, 1.08, -0.06),
                simd_float3(0.0, -0.08, 1.08)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.05,
                highlights: 0.15,
                gamma: 0.6,
                contrast: 1.1,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 0.8,
                density: 0.6,
                distribution: 0.85,
                shadowMultiplier: 1.2,
                highlightMultiplier: 0.9,
                chromaIntensity: 0.3
            )
        )
        
        // Kodak Vision3 200T (5213/7213)
        profileDict[.kodakVision350T] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 645, width: 85, sensitivity: 0.88),
            greenResponse: createSpectralResponse(peak: 545, width: 65, sensitivity: 1.0),
            blueResponse: createSpectralResponse(peak: 455, width: 75, sensitivity: 0.92),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(1.02, -0.02, 0.0),
                simd_float3(-0.01, 1.06, -0.05),
                simd_float3(0.0, -0.06, 1.06)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.06,
                highlights: 0.18,
                gamma: 0.58,
                contrast: 1.05,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 1.0,
                density: 0.75,
                distribution: 0.8,
                shadowMultiplier: 1.3,
                highlightMultiplier: 1.0,
                chromaIntensity: 0.35
            )
        )
        
        // Kodak Vision3 500T (5219/7219)
        profileDict[.kodakVision500T] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 650, width: 90, sensitivity: 0.92),
            greenResponse: createSpectralResponse(peak: 550, width: 70, sensitivity: 1.0),
            blueResponse: createSpectralResponse(peak: 460, width: 80, sensitivity: 0.95),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(0.98, 0.02, 0.0),
                simd_float3(0.01, 1.04, -0.05),
                simd_float3(0.0, -0.04, 1.04)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.08,
                highlights: 0.22,
                gamma: 0.55,
                contrast: 1.0,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 1.4,
                density: 1.0,
                distribution: 0.75,
                shadowMultiplier: 1.5,
                highlightMultiplier: 1.2,
                chromaIntensity: 0.4
            )
        )
        
        // Kodak Portra 160
        profileDict[.kodakPortra160] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 635, width: 75, sensitivity: 0.9),
            greenResponse: createSpectralResponse(peak: 535, width: 55, sensitivity: 1.0),
            blueResponse: createSpectralResponse(peak: 445, width: 65, sensitivity: 0.85),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(1.08, -0.08, 0.0),
                simd_float3(-0.03, 1.12, -0.09),
                simd_float3(0.02, -0.12, 1.1)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.04,
                highlights: 0.12,
                gamma: 0.65,
                contrast: 1.15,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 0.7,
                density: 0.5,
                distribution: 0.9,
                shadowMultiplier: 1.0,
                highlightMultiplier: 0.8,
                chromaIntensity: 0.25
            )
        )
        
        // Kodak Portra 400
        profileDict[.kodakPortra400] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 640, width: 80, sensitivity: 0.92),
            greenResponse: createSpectralResponse(peak: 540, width: 60, sensitivity: 1.0),
            blueResponse: createSpectralResponse(peak: 450, width: 70, sensitivity: 0.88),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(1.06, -0.06, 0.0),
                simd_float3(-0.02, 1.1, -0.08),
                simd_float3(0.01, -0.1, 1.09)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.05,
                highlights: 0.15,
                gamma: 0.62,
                contrast: 1.12,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 1.0,
                density: 0.7,
                distribution: 0.85,
                shadowMultiplier: 1.2,
                highlightMultiplier: 0.9,
                chromaIntensity: 0.3
            )
        )
        
        // Kodak Portra 800
        profileDict[.kodakPortra800] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 645, width: 85, sensitivity: 0.95),
            greenResponse: createSpectralResponse(peak: 545, width: 65, sensitivity: 1.0),
            blueResponse: createSpectralResponse(peak: 455, width: 75, sensitivity: 0.9),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(1.04, -0.04, 0.0),
                simd_float3(-0.01, 1.08, -0.07),
                simd_float3(0.0, -0.08, 1.08)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.06,
                highlights: 0.18,
                gamma: 0.6,
                contrast: 1.08,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 1.3,
                density: 0.9,
                distribution: 0.8,
                shadowMultiplier: 1.4,
                highlightMultiplier: 1.1,
                chromaIntensity: 0.35
            )
        )
        
        // Fuji Eterna 250D
        profileDict[.fujiEterna250D] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 630, width: 70, sensitivity: 0.85),
            greenResponse: createSpectralResponse(peak: 530, width: 50, sensitivity: 1.0),
            blueResponse: createSpectralResponse(peak: 440, width: 60, sensitivity: 0.95),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(0.95, 0.05, 0.0),
                simd_float3(0.02, 1.15, -0.17),
                simd_float3(0.05, -0.2, 1.15)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.03,
                highlights: 0.1,
                gamma: 0.68,
                contrast: 1.2,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 0.9,
                density: 0.65,
                distribution: 0.88,
                shadowMultiplier: 1.1,
                highlightMultiplier: 0.85,
                chromaIntensity: 0.28
            )
        )
        
        // Fuji Eterna 500T
        profileDict[.fujiEterna500T] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 635, width: 75, sensitivity: 0.88),
            greenResponse: createSpectralResponse(peak: 535, width: 55, sensitivity: 1.0),
            blueResponse: createSpectralResponse(peak: 445, width: 65, sensitivity: 0.98),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(0.93, 0.07, 0.0),
                simd_float3(0.03, 1.12, -0.15),
                simd_float3(0.06, -0.18, 1.12)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.04,
                highlights: 0.14,
                gamma: 0.65,
                contrast: 1.15,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 1.2,
                density: 0.8,
                distribution: 0.82,
                shadowMultiplier: 1.3,
                highlightMultiplier: 1.0,
                chromaIntensity: 0.32
            )
        )
        
        // Black and White Films
        
        // Ilford HP5 Plus
        profileDict[.ilfordHP5] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 550, width: 200, sensitivity: 0.9),
            greenResponse: createSpectralResponse(peak: 550, width: 200, sensitivity: 0.9),
            blueResponse: createSpectralResponse(peak: 550, width: 200, sensitivity: 0.9),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(0.299, 0.587, 0.114),
                simd_float3(0.299, 0.587, 0.114),
                simd_float3(0.299, 0.587, 0.114)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.08,
                highlights: 0.25,
                gamma: 0.52,
                contrast: 1.25,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 1.5,
                density: 1.1,
                distribution: 0.7,
                shadowMultiplier: 1.6,
                highlightMultiplier: 1.3,
                chromaIntensity: 0.0
            )
        )
        
        // Kodak Tri-X 400
        profileDict[.kodakTrix400] = FilmColorResponse(
            redResponse: createSpectralResponse(peak: 550, width: 200, sensitivity: 0.85),
            greenResponse: createSpectralResponse(peak: 550, width: 200, sensitivity: 0.85),
            blueResponse: createSpectralResponse(peak: 550, width: 200, sensitivity: 0.85),
            colorMatrix: matrix_float3x3(columns: (
                simd_float3(0.299, 0.587, 0.114),
                simd_float3(0.299, 0.587, 0.114),
                simd_float3(0.299, 0.587, 0.114)
            )),
            contrastCurve: ToneCurve(
                shadows: 0.1,
                highlights: 0.3,
                gamma: 0.48,
                contrast: 1.35,
                blackPoint: 0.0,
                whitePoint: 1.0
            ),
            grainCharacteristics: GrainProfile(
                baseSize: 1.8,
                density: 1.3,
                distribution: 0.65,
                shadowMultiplier: 1.8,
                highlightMultiplier: 1.5,
                chromaIntensity: 0.0
            )
        )
        
        self.profiles = profileDict
    }
    
    func getProfile(for filmStock: FilmStockType) -> FilmColorResponse {
        return profiles[filmStock] ?? profiles[.kodakVision350T]!
    }
    
    private func createSpectralResponse(peak: Float, width: Float, sensitivity: Float) -> [Float] {
        var response: [Float] = []
        for wavelength in stride(from: 380, through: 780, by: 10) {
            let distance = abs(Float(wavelength) - peak)
            let gaussian = exp(-pow(distance / (width * 0.5), 2))
            response.append(gaussian * sensitivity)
        }
        return response
    }
}

// Helper function for mixing values
private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    return a + (b - a) * t
}