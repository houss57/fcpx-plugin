#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct FilmParameters {
    float grainAmount;
    float grainSize;
    float grainShadows;
    float grainHighlights;
    float grainChroma;
    
    float halationAmount;
    float halationThreshold;
    float halationRadius;
    float halationBackgroundGain;
    
    float bloomAmount;
    float bloomThreshold;
    float bloomRadius;
    
    float gateWeaveX;
    float gateWeaveY;
    float filmBreath;
    float projectorFlicker;
    
    float colorTemperature;
    float contrast;
    float saturation;
    
    float time;
    uint frameNumber;
};

struct FilmStockData {
    float3x3 colorMatrix;
    float shadowsLift;
    float highlightsRolloff;
    float gamma;
    float contrastMult;
    float grainBaseSize;
    float grainDensity;
};

// MARK: - Utility Functions

float3 rgb2xyz(float3 rgb) {
    float3x3 M = float3x3(
        float3(0.4124564, 0.3575761, 0.1804375),
        float3(0.2126729, 0.7151522, 0.0721750),
        float3(0.0193339, 0.1191920, 0.9503041)
    );
    return M * rgb;
}

float3 xyz2rgb(float3 xyz) {
    float3x3 M = float3x3(
        float3( 3.2404542, -1.5371385, -0.4985314),
        float3(-0.9692660,  1.8760108,  0.0415560),
        float3( 0.0556434, -0.2040259,  1.0572252)
    );
    return M * xyz;
}

float3 linearToSRGB(float3 linear) {
    return select(linear * 12.92, 1.055 * pow(linear, 1.0/2.4) - 0.055, linear > 0.0031308);
}

float3 sRGBToLinear(float3 srgb) {
    return select(srgb / 12.92, pow((srgb + 0.055) / 1.055, 2.4), srgb > 0.04045);
}

float3 logCToLinear(float3 logc) {
    // ARRI LogC to linear conversion
    float3 linear = (pow(10.0, (logc - 0.385537) / 0.247190) - 0.052272) / 5.555556;
    return max(linear, 0.0);
}

float3 linearToLogC(float3 linear) {
    // Linear to ARRI LogC conversion
    return 0.247190 * log10(5.555556 * linear + 0.052272) + 0.385537;
}

// Perlin noise for grain generation
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// 3D grain noise
float grain3D(float3 pos, float time) {
    float3 p = pos + float3(time * 0.1);
    float n1 = fbm(p.xy, 4);
    float n2 = fbm(p.yz + 100.0, 4);
    float n3 = fbm(p.xz + 200.0, 4);
    return (n1 + n2 + n3) / 3.0;
}

// MARK: - Film Stock Response Kernel

kernel void filmStockResponse(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant FilmStockData& filmStock [[buffer(0)]],
    constant FilmParameters& params [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float3 linearColor = inputColor.rgb;
    
    // Apply film stock color matrix
    linearColor = filmStock.colorMatrix * linearColor;
    
    // Apply film characteristic curve
    float3 lifted = max(0.0, linearColor + filmStock.shadowsLift * (1.0 - linearColor));
    float3 gammaCorrected = pow(lifted, 1.0 / filmStock.gamma);
    float3 contrasted = pow(gammaCorrected, filmStock.contrastMult * params.contrast);
    float3 rolled = contrasted / (contrasted + filmStock.highlightsRolloff);
    
    // Apply additional color grading
    float3 finalColor = rolled;
    
    // Color temperature adjustment
    if (params.colorTemperature != 0.0) {
        float temp = params.colorTemperature;
        float3 tempAdjust = float3(1.0 + temp * 0.3, 1.0, 1.0 - temp * 0.2);
        finalColor *= tempAdjust;
    }
    
    // Saturation adjustment
    float luma = dot(finalColor, float3(0.299, 0.587, 0.114));
    finalColor = mix(float3(luma), finalColor, params.saturation);
    
    // Film breath (exposure fluctuation)
    if (params.filmBreath > 0.0) {
        float breathNoise = noise(float2(params.time * 0.1, 0.0)) * 2.0 - 1.0;
        float breathMult = 1.0 + breathNoise * params.filmBreath;
        finalColor *= breathMult;
    }
    
    // Projector flicker
    if (params.projectorFlicker > 0.0) {
        float flicker = sin(params.time * params.projectorFlicker * 6.28318) * 0.5 + 0.5;
        float flickerMult = 1.0 + flicker * params.projectorFlicker;
        finalColor *= flickerMult;
    }
    
    outputTexture.write(float4(finalColor, inputColor.a), gid);
}

// MARK: - Analog Grain Kernel

kernel void analogGrain(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant FilmParameters& params [[buffer(0)]],
    constant FilmStockData& filmStock [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    if (params.grainAmount <= 0.0) {
        float4 inputColor = inputTexture.read(gid);
        outputTexture.write(inputColor, gid);
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float3 color = inputColor.rgb;
    
    // Calculate grain position in 3D space
    float2 resolution = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = float2(gid) / resolution;
    
    float grainSize = params.grainSize * filmStock.grainBaseSize;
    float3 grainPos = float3(uv * resolution / grainSize, params.time * 0.1);
    
    // Generate 3D grain noise
    float grainNoise = grain3D(grainPos, params.time);
    grainNoise = grainNoise * 2.0 - 1.0; // Normalize to -1 to 1
    
    // Calculate luminance for grain distribution
    float luma = dot(color, float3(0.299, 0.587, 0.114));
    
    // Grain intensity based on luminance (stronger in shadows and highlights)
    float shadowWeight = smoothstep(0.0, 0.3, 1.0 - luma) * params.grainShadows;
    float highlightWeight = smoothstep(0.7, 1.0, luma) * params.grainHighlights;
    float grainIntensity = (shadowWeight + highlightWeight + 0.5) * params.grainAmount * filmStock.grainDensity;
    
    // Apply grain to luminance
    float grainedLuma = luma + grainNoise * grainIntensity * 0.1;
    
    // Generate color grain
    float3 colorGrain = float3(0.0);
    if (params.grainChroma > 0.0) {
        float3 chromaPos = grainPos + float3(100.0, 200.0, 300.0);
        colorGrain.r = grain3D(chromaPos, params.time) * 2.0 - 1.0;
        colorGrain.g = grain3D(chromaPos + float3(50.0, 0.0, 0.0), params.time) * 2.0 - 1.0;
        colorGrain.b = grain3D(chromaPos + float3(0.0, 50.0, 0.0), params.time) * 2.0 - 1.0;
        colorGrain *= params.grainChroma * grainIntensity * 0.05;
    }
    
    // Reconstruct color maintaining ratios
    float3 grainedColor = color;
    if (luma > 0.0) {
        grainedColor = color * (grainedLuma / luma);
    }
    
    // Add color grain
    grainedColor += colorGrain;
    
    // Clamp to valid range
    grainedColor = max(grainedColor, 0.0);
    
    outputTexture.write(float4(grainedColor, inputColor.a), gid);
}

// MARK: - Halation Effect Kernel

kernel void halationEffect(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> brightsTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant FilmParameters& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    if (params.halationAmount <= 0.0) {
        float4 inputColor = inputTexture.read(gid);
        outputTexture.write(inputColor, gid);
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float4 brightColor = brightsTexture.read(gid);
    
    // Halation affects primarily the red channel
    float halationRed = brightColor.r * params.halationAmount;
    
    // Background gain - halation is stronger on dark backgrounds
    float luma = dot(inputColor.rgb, float3(0.299, 0.587, 0.114));
    float backgroundMult = 1.0 + (1.0 - luma) * params.halationBackgroundGain;
    halationRed *= backgroundMult;
    
    // Apply halation as red-orange glow
    float3 halationColor = float3(halationRed, halationRed * 0.7, halationRed * 0.3);
    float3 finalColor = inputColor.rgb + halationColor;
    
    outputTexture.write(float4(finalColor, inputColor.a), gid);
}

// MARK: - Bloom Effect Kernel

kernel void bloomEffect(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> blurredTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant FilmParameters& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    if (params.bloomAmount <= 0.0) {
        float4 inputColor = inputTexture.read(gid);
        outputTexture.write(inputColor, gid);
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float4 blurredColor = blurredTexture.read(gid);
    
    // Add bloom with specified amount
    float3 bloomColor = blurredColor.rgb * params.bloomAmount;
    float3 finalColor = inputColor.rgb + bloomColor;
    
    outputTexture.write(float4(finalColor, inputColor.a), gid);
}

// MARK: - Gate Weave Kernel

kernel void gateWeave(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant FilmParameters& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    if (params.gateWeaveX == 0.0 && params.gateWeaveY == 0.0) {
        float4 inputColor = inputTexture.read(gid);
        outputTexture.write(inputColor, gid);
        return;
    }
    
    // Calculate offset based on frame number and random noise
    float2 frameOffset = float2(params.gateWeaveX, params.gateWeaveY);
    
    // Sample from offset position
    int2 samplePos = int2(gid) + int2(frameOffset);
    samplePos = clamp(samplePos, int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
    
    float4 sampledColor = inputTexture.read(uint2(samplePos));
    outputTexture.write(sampledColor, gid);
}

// MARK: - Brightness Threshold Kernel

kernel void brightnessThreshold(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& threshold [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float luma = dot(inputColor.rgb, float3(0.299, 0.587, 0.114));
    
    if (luma > threshold) {
        float excess = (luma - threshold) / (1.0 - threshold);
        float3 brightColor = inputColor.rgb * excess;
        outputTexture.write(float4(brightColor, inputColor.a), gid);
    } else {
        outputTexture.write(float4(0.0, 0.0, 0.0, inputColor.a), gid);
    }
}

// MARK: - Gaussian Blur Kernel (Horizontal)

kernel void gaussianBlurHorizontal(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& radius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float3 color = float3(0.0);
    float totalWeight = 0.0;
    
    int intRadius = int(ceil(radius));
    
    for (int x = -intRadius; x <= intRadius; x++) {
        int2 samplePos = int2(int(gid.x) + x, int(gid.y));
        samplePos.x = clamp(samplePos.x, 0, int(inputTexture.get_width()) - 1);
        
        float weight = exp(-0.5 * pow(float(x) / (radius * 0.333), 2.0));
        float4 sampleColor = inputTexture.read(uint2(samplePos));
        
        color += sampleColor.rgb * weight;
        totalWeight += weight;
    }
    
    color /= totalWeight;
    float alpha = inputTexture.read(gid).a;
    
    outputTexture.write(float4(color, alpha), gid);
}

// MARK: - Gaussian Blur Kernel (Vertical)

kernel void gaussianBlurVertical(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& radius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float3 color = float3(0.0);
    float totalWeight = 0.0;
    
    int intRadius = int(ceil(radius));
    
    for (int y = -intRadius; y <= intRadius; y++) {
        int2 samplePos = int2(int(gid.x), int(gid.y) + y);
        samplePos.y = clamp(samplePos.y, 0, int(inputTexture.get_height()) - 1);
        
        float weight = exp(-0.5 * pow(float(y) / (radius * 0.333), 2.0));
        float4 sampleColor = inputTexture.read(uint2(samplePos));
        
        color += sampleColor.rgb * weight;
        totalWeight += weight;
    }
    
    color /= totalWeight;
    float alpha = inputTexture.read(gid).a;
    
    outputTexture.write(float4(color, alpha), gid);
}

// MARK: - Color Grading Kernel

kernel void colorGrading(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant FilmParameters& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 inputColor = inputTexture.read(gid);
    float3 color = inputColor.rgb;
    
    // Apply final color adjustments
    // Contrast (applied as power function)
    color = pow(max(color, 0.0), params.contrast);
    
    // Saturation
    float luma = dot(color, float3(0.299, 0.587, 0.114));
    color = mix(float3(luma), color, params.saturation);
    
    // Color temperature fine adjustment
    if (params.colorTemperature != 0.0) {
        float temp = params.colorTemperature * 0.1; // Fine adjustment
        float3 tempMatrix = float3(1.0 + temp, 1.0, 1.0 - temp * 0.5);
        color *= tempMatrix;
    }
    
    // Clamp final output
    color = clamp(color, 0.0, 1.0);
    
    outputTexture.write(float4(color, inputColor.a), gid);
}