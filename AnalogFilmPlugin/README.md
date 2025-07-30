# Analog Film Emulation Plugin for Final Cut Pro

A native macOS FxPlug4 plugin that provides comprehensive analog film emulation effects for Final Cut Pro 11.1.1 and Motion 6.1.

## Features

### Film Stock Emulation
- **14 Authentic Film Stocks**: Including Kodak Vision3, Portra series, Fuji Eterna, Agfa Vista, and classic black & white films (Ilford HP5, Kodak Tri-X)
- **Film Format Support**: 8mm, 16mm, 35mm, and 65mm with format-specific characteristics
- **Process Types**: Negative, Print, and Reversal processing with accurate color response

### Advanced Grain System
- **Physically-based 3D Grain**: Procedural grain generation based on emulsion physics
- **Luminance-dependent Distribution**: Stronger grain in shadows and highlights, matching real film behavior
- **Format-specific Scaling**: Grain size automatically adjusts for film format (8mm has larger grain than 65mm)
- **Color Grain Support**: Separate chroma grain with adjustable intensity

### Film-Optical Effects
- **Halation**: Red-orange halos around bright lights with realistic falloff and background sensitivity
- **Bloom**: Lens glow effects with customizable threshold and radius
- **Gate Weave**: Frame-to-frame geometric jitter simulating mechanical film transport
- **Film Breath**: Subtle exposure fluctuation over time
- **Projector Flicker**: Periodic brightness modulation at adjustable frequencies

### Professional Color Pipeline
- **Multiple Log Format Support**: ARRI LogC, Sony S-Log3, Panasonic V-Log, Blackmagic Film, RED LogFilm
- **Wide Gamut Processing**: Internal processing in linear space to preserve color fidelity
- **Output Color Spaces**: Rec.709, Rec.2020, P3-D65, ACES
- **3D LUT Export**: Generate .cube files capturing the complete film pipeline

## Technical Specifications

### Requirements
- macOS 11.0 or later (Sonoma 14.7.6 recommended)
- Apple Silicon (M1/M2/M3) - ARM64 only
- Final Cut Pro 11.1.1 or Motion 6.1
- Metal-compatible GPU

### Performance
- **Metal-optimized**: All processing uses Metal compute shaders for GPU acceleration
- **Real-time Playback**: Optimized for 4K ProRes timelines on Apple Silicon
- **Metal Performance Shaders**: Efficient blur operations using MPS
- **16-bit Float Processing**: Maintains filmic subtlety and prevents banding

### Architecture
- **FxPlug4 Framework**: Native integration with Final Cut Pro's effect pipeline
- **Metal Shading Language**: GPU compute kernels for all image processing
- **Swift 5.0**: Modern, type-safe implementation
- **Modular Design**: Separate components for parameters, rendering, and color management

## Installation

1. **Build Requirements**:
   - Xcode 15.3 or later
   - macOS SDK 11.0+
   - Apple Developer account (for code signing)

2. **Build Process**:
   ```bash
   xcodebuild -project AnalogFilmPlugin.xcodeproj -target AnalogFilmPlugin -configuration Release ARCHS=arm64
   ```

3. **Installation**:
   - Copy `AnalogFilmPlugin.bundle` to `~/Library/Plug-Ins/FxPlug/`
   - Restart Final Cut Pro
   - The plugin appears under Effects > Color > Film Emulation

## Usage

### Basic Workflow
1. Apply "Analog Film Emulation" effect to your clip in Final Cut Pro
2. Choose a film stock from the dropdown menu
3. Adjust grain amount and size to taste
4. Fine-tune halation and bloom for the desired optical characteristics
5. Export 3D LUT if you want to apply the look in other applications

### Parameter Groups

#### Film Stock
- **Film Stock**: Choose from 14 authentic film emulations
- **Film Format**: Select 8mm, 16mm, 35mm, or 65mm (affects grain size and artifacts)
- **Process Type**: Negative, Print, or Reversal processing

#### Grain Controls
- **Grain Amount**: Overall grain intensity (0.0-2.0)
- **Grain Size**: Particle size multiplier (0.1-5.0)
- **Shadows Grain**: Grain intensity in shadow areas (0.0-2.0)
- **Highlights Grain**: Grain intensity in highlight areas (0.0-2.0)
- **Grain Chroma**: Color grain intensity (0.0-1.0)

#### Halation
- **Halation Amount**: Red halo intensity around bright lights (0.0-1.0)
- **Halation Threshold**: Brightness threshold for halation effect (0.0-1.0)
- **Halation Radius**: Spread of the halation effect (1.0-100.0)
- **Background Gain**: Halation intensity on dark backgrounds (0.0-1.0)

#### Bloom
- **Bloom Amount**: Lens glow intensity (0.0-1.0)
- **Bloom Threshold**: Brightness threshold for bloom (0.0-1.0)
- **Bloom Radius**: Size of the bloom effect (1.0-50.0)

#### Artifacts
- **Gate Weave**: Frame jitter intensity (0.0-10.0)
- **Film Breath**: Exposure fluctuation amount (0.0-0.1)
- **Projector Flicker**: Brightness flicker intensity (0.0-0.1)
- **Flicker Frequency**: Flicker rate in Hz (24.0-120.0)

#### Color Grading
- **Color Temperature**: Warm/cool adjustment (-1.0 to 1.0)
- **Contrast**: Contrast multiplier (0.1-3.0)
- **Saturation**: Color saturation (0.0-2.0)

#### Output
- **Input Color Space**: Source format conversion
- **Output Color Space**: Target color space
- **Export 3D LUT**: Generate .cube file

## Film Stock Profiles

### Color Negative Films
- **Kodak Vision3 50D**: Fine grain daylight stock with neutral color balance
- **Kodak Vision3 200T**: Versatile tungsten stock with excellent shadow detail
- **Kodak Vision3 500T**: High-speed tungsten stock with characteristic grain structure

### Portrait Films
- **Kodak Portra 160/400/800**: Renowned for skin tone reproduction and gentle contrast
- **Fuji Eterna 250D/500T**: Distinctive color science with lifted shadows

### Consumer Films
- **Agfa Vista 200/400**: Saturated colors with punchy contrast

### Black & White Films
- **Ilford HP5 Plus**: Classic high-speed B&W with pronounced grain
- **Ilford FP4 Plus**: Fine-grain portrait film
- **Kodak Tri-X 400**: Legendary street photography film
- **Kodak T-Max 400**: Modern tabular grain technology

## Code Signing

For production deployment, the plugin bundle must be code signed:

```bash
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" AnalogFilmPlugin.bundle
```

For distribution outside the Mac App Store, notarization is recommended:

```bash
xcrun notarytool submit AnalogFilmPlugin.bundle --keychain-profile "YourProfile" --wait
```

## Performance Optimization

### GPU Memory Management
- Intermediate textures are efficiently managed and reused
- Metal command buffers are properly synchronized
- Texture formats optimized for Apple Silicon GPUs

### Algorithm Optimization
- Grain generation uses efficient 3D noise functions
- Blur operations leverage Metal Performance Shaders
- Color space conversions use optimized matrix operations

### Quality Settings
For maximum performance during editing:
- Reduce grain amount on complex compositions
- Lower halation radius for faster preview
- Disable expensive effects during rough cuts

## Development Notes

### Project Structure
```
AnalogFilmPlugin/
├── AnalogFilmPlugin.swift      # Main plugin class and FxPlug integration
├── FilmParameters.swift        # Parameter definitions and UI
├── FilmStockProfiles.swift     # Film stock color science data
├── RenderPipeline.swift        # Metal rendering pipeline
├── ColorManagement.swift       # Color space conversions
├── FilmEffects.metal          # GPU compute shaders
├── Info.plist                 # Plugin registration
└── README.md                  # This file
```

### Metal Shaders
All image processing is performed in Metal compute shaders:
- `analogGrain`: 3D procedural grain generation
- `halationEffect`: Red halo simulation
- `bloomEffect`: Lens glow processing
- `filmStockResponse`: Color response and tone curves
- `colorGrading`: Final color adjustments
- `gateWeave`: Geometric frame jitter

### Extensibility
The plugin is designed for easy extension:
- New film stocks can be added to `FilmStockProfiles.swift`
- Additional effects can be implemented as Metal compute kernels
- Parameter groups can be extended in `FilmParameters.swift`

## License

This plugin is provided as reference implementation. The film stock profiles are based on published technical specifications and do not contain proprietary algorithms from film manufacturers.

## Support

For technical support or feature requests, please refer to the plugin documentation or contact the development team.

---

**Note**: This plugin requires Apple Silicon Macs (M1/M2/M3) and cannot run on Intel-based systems. The Metal compute shaders are optimized for Apple's GPU architecture and will not compile for other platforms.