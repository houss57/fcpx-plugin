# Development Guide - Analog Film Plugin

This guide covers the development process, architecture decisions, and technical implementation details of the Analog Film Plugin for Final Cut Pro.

## Architecture Overview

### FxPlug4 Integration
The plugin is built using Apple's FxPlug4 framework, which provides:
- Native integration with Final Cut Pro's effects pipeline
- Parameter UI automatically generated in the Inspector
- Real-time preview support with hardware acceleration
- Proper color management and frame handling

### Metal Compute Pipeline
All image processing is performed on the GPU using Metal:
- **Compute Shaders**: All effects implemented as Metal compute kernels
- **Metal Performance Shaders**: Used for optimized Gaussian blur operations
- **Parallel Processing**: Thread groups optimized for Apple Silicon GPUs
- **Memory Management**: Efficient texture creation and reuse

### Modular Design
The codebase is organized into focused modules:

```
AnalogFilmPlugin.swift      # Main plugin class, FxPlug integration
FilmParameters.swift        # Parameter definitions and UI setup
FilmStockProfiles.swift     # Film stock color science database
RenderPipeline.swift        # Metal rendering pipeline orchestration
ColorManagement.swift       # Color space conversions and LUT export
FilmEffects.metal          # GPU compute shaders
```

## Core Components

### 1. Film Stock Emulation (`FilmStockProfiles.swift`)

#### Color Response Modeling
Each film stock is characterized by:
- **Spectral Response Curves**: Simulating the sensitivity of different emulsion layers
- **Color Matrices**: 3x3 transforms representing dye layer interactions
- **Tone Curves**: Characteristic curves defining contrast and gamma response
- **Grain Profiles**: Physical grain characteristics (size, density, distribution)

```swift
struct FilmColorResponse {
    let redResponse: [Float]      // Spectral response for red layer
    let greenResponse: [Float]    // Spectral response for green layer  
    let blueResponse: [Float]     // Spectral response for blue layer
    let colorMatrix: matrix_float3x3  // Color transformation matrix
    let contrastCurve: ToneCurve     // Characteristic curve
    let grainCharacteristics: GrainProfile
}
```

#### Tone Curve Implementation
Film characteristic curves are implemented using a physically-based model:
- **Shadow Lift**: Simulates base fog and development lift
- **Highlight Rolloff**: Models highlight compression in emulsion
- **Gamma Response**: Non-linear response curve
- **Contrast**: Overall contrast multiplication

### 2. Procedural Grain System (`FilmEffects.metal`)

#### 3D Grain Generation
The grain system uses 3D Perlin noise to simulate realistic film grain:

```metal
float grain3D(float3 pos, float time) {
    float3 p = pos + float3(time * 0.1);
    float n1 = fbm(p.xy, 4);
    float n2 = fbm(p.yz + 100.0, 4);
    float n3 = fbm(p.xz + 200.0, 4);
    return (n1 + n2 + n3) / 3.0;
}
```

#### Luminance-Dependent Distribution
Grain intensity varies based on image luminance:
- **Shadows**: Higher grain due to underexposure amplification
- **Midtones**: Baseline grain level
- **Highlights**: Increased grain from overexposure effects

#### Format-Specific Scaling
Grain size automatically scales with film format:
- **8mm**: Large grain (2.5x multiplier)
- **16mm**: Medium-large grain (1.8x multiplier)
- **35mm**: Standard grain (1.0x baseline)
- **65mm**: Fine grain (0.6x multiplier)

### 3. Halation Effect (`halationEffect` kernel)

#### Physical Basis
Halation simulates light scattering through film base:
- Bright lights cause red-orange halos in adjacent dark areas
- Effect is strongest on dark backgrounds
- Primary affects red channel due to anti-halation layer properties

#### Implementation
1. **Threshold Detection**: Identify bright pixels above halation threshold
2. **Background Sensitivity**: Scale effect based on surrounding darkness
3. **Red Channel Diffusion**: Apply Gaussian blur to red channel of bright areas
4. **Color Mixing**: Blend halation (red-orange) with original image

### 4. Color Management (`ColorManagement.swift`)

#### Input Log Formats
Support for professional camera log formats:
- **ARRI LogC**: `(pow(10.0, (logc - 0.385537) / 0.247190) - 0.052272) / 5.555556`
- **Sony S-Log3**: Piecewise function with linear and log sections
- **Panasonic V-Log**: Similar piecewise implementation
- **RED LogFilm**: RED's proprietary log curve

#### Working Color Space
All processing occurs in linear RGB within a wide gamut space to:
- Preserve color fidelity during mathematical operations
- Avoid clipping in saturated color regions
- Maintain accuracy through multiple processing stages

#### Output Color Spaces
Support for modern delivery formats:
- **Rec.709**: Standard HD/SDR delivery
- **Rec.2020**: HDR and wide gamut delivery
- **P3-D65**: DCI and display P3 for theatrical/streaming
- **ACES**: Academy Color Encoding System for high-end workflows

### 5. Performance Optimizations

#### GPU Memory Management
- **Texture Reuse**: Intermediate textures are efficiently managed
- **Optimal Formats**: Use 16-bit float for processing, optimized for Apple Silicon
- **Memory Bandwidth**: Minimize texture reads/writes through careful pipeline design

#### Compute Shader Optimization
- **Thread Group Size**: 16x16 threads optimized for Apple GPU architecture
- **Memory Coalescing**: Ensure adjacent threads access adjacent memory
- **Branch Minimization**: Reduce conditional logic in inner loops

#### Metal Performance Shaders
Leverage MPS for computationally expensive operations:
- **Gaussian Blur**: `MPSImageGaussianBlur` for halation and bloom
- **Convolution**: Potential future use for specialized kernels

## Development Workflow

### 1. Setup Development Environment
```bash
# Ensure Xcode 15.3+ is installed
xcode-select --install

# Clone or download the plugin source
# Open AnalogFilmPlugin.xcodeproj in Xcode
```

### 2. Building the Plugin
```bash
# Build for Apple Silicon only
xcodebuild -project AnalogFilmPlugin.xcodeproj \
           -target AnalogFilmPlugin \
           -configuration Release \
           ARCHS=arm64

# Or use the provided build script
./build.sh
```

### 3. Installation for Testing
```bash
# Install to Final Cut Pro
./install.sh

# Or manually copy
cp -R build/Release/AnalogFilmPlugin.bundle ~/Library/Plug-Ins/FxPlug/
```

### 4. Debugging

#### Metal Debugging
Enable Metal validation in Xcode:
- Edit Scheme > Run > Diagnostics > Metal API Validation

#### FxPlug Debugging
Use Console.app to view plugin logs:
```swift
import OSLog
private let logger = Logger(subsystem: "com.analogfilm.plugin", category: "AnalogFilmEffect")
logger.info("Debug message here")
```

#### Performance Profiling
Use Instruments.app:
- **GPU Report**: Analyze Metal performance
- **Time Profiler**: Find CPU bottlenecks
- **Memory Graph**: Check for memory leaks

## Testing Strategies

### 1. Unit Testing Metal Shaders
Create test textures and verify shader outputs:
```swift
// Test grain generation
let testTexture = createTestTexture(size: CGSize(width: 1920, height: 1080))
let result = processWithGrainShader(input: testTexture, parameters: testParams)
// Verify statistical properties of grain noise
```

### 2. Color Accuracy Testing
Use standard test images:
- **ColorChecker**: Verify color response accuracy
- **Grayscale Ramps**: Test tone curve linearity
- **Saturation Sweeps**: Check color gamut handling

### 3. Performance Testing
Test on target hardware:
- **4K ProRes Playback**: Ensure real-time performance
- **Memory Usage**: Monitor texture memory consumption
- **Thermal Testing**: Verify sustained performance

### 4. Integration Testing
Test with Final Cut Pro:
- **Parameter Changes**: Verify UI updates trigger re-renders
- **Timeline Scrubbing**: Test frame-accurate rendering
- **Export Testing**: Verify render queue processing

## Extending the Plugin

### Adding New Film Stocks

1. **Research Film Characteristics**:
   - Study published spectral sensitivity curves
   - Analyze characteristic curves from technical data sheets
   - Research grain structure and size information

2. **Create Profile Data**:
```swift
// Add to FilmStockProfiles.swift
profileDict[.newFilmStock] = FilmColorResponse(
    redResponse: createSpectralResponse(peak: 650, width: 90, sensitivity: 0.92),
    greenResponse: createSpectralResponse(peak: 550, width: 70, sensitivity: 1.0),
    blueResponse: createSpectralResponse(peak: 460, width: 80, sensitivity: 0.95),
    colorMatrix: matrix_float3x3(columns: (...)),
    contrastCurve: ToneCurve(...),
    grainCharacteristics: GrainProfile(...)
)
```

3. **Update Enumerations**:
   - Add new case to `FilmStockType` enum
   - Update `displayName` property
   - Test with various footage types

### Adding New Effects

1. **Create Metal Shader**:
```metal
kernel void newEffect(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant EffectParameters& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Implement effect logic
}
```

2. **Add Parameters**:
```swift
// In FilmParameters.swift
static let newEffectAmount: UInt32 = 8000
static let newEffectRadius: UInt32 = 8001
```

3. **Integrate into Pipeline**:
```swift
// In RenderPipeline.swift
if parameters.newEffectAmount > 0.0 {
    try applyNewEffect(input: currentInput, output: currentOutput, ...)
    swap(&currentInput, &currentOutput)
}
```

## Code Signing and Distribution

### Development Signing
For local testing, Xcode automatic signing is sufficient.

### Distribution Signing
For broader distribution:

```bash
# Sign with Developer ID
codesign --deep --force --verify --verbose \
         --sign "Developer ID Application: Your Name (TEAM_ID)" \
         AnalogFilmPlugin.bundle

# Notarize for Gatekeeper compatibility
xcrun notarytool submit AnalogFilmPlugin.bundle \
                 --keychain-profile "YourProfile" \
                 --wait

# Staple notarization ticket
xcrun stapler staple AnalogFilmPlugin.bundle
```

## Performance Benchmarks

### Target Performance
- **4K ProRes 422**: Real-time playback (24/30fps)
- **HD ProRes 422**: Real-time playback with full effects
- **Memory Usage**: <500MB texture memory for 4K processing

### Optimization Techniques
1. **Early Exit**: Skip processing when effect amounts are zero
2. **Resolution Scaling**: Process effects at appropriate resolutions
3. **Temporal Coherence**: Cache noise patterns between frames
4. **Metal Best Practices**: Follow Apple's Metal optimization guidelines

## Future Enhancements

### Planned Features
- **Additional Film Stocks**: Expand the film stock database
- **Print Film Simulation**: Simulate photochemical printing processes
- **Advanced Grain Models**: Implement tabular grain and other emulsion types
- **Lens Artifacts**: Add vignetting, chromatic aberration, distortion
- **Temporal Effects**: Frame-rate dependent artifacts and motion blur

### Research Areas
- **Spectroscopic Analysis**: More accurate color response modeling
- **Physical Grain Models**: Advanced emulsion physics simulation
- **Machine Learning**: AI-driven film characteristic extraction
- **HDR Processing**: Extended range tone mapping for HDR workflows

This development guide provides the foundation for understanding and extending the Analog Film Plugin. The modular architecture allows for incremental improvements while maintaining stability and performance.