//
//  Shaders.metal
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

#include <metal_stdlib>
using namespace metal;

// Common structures and vertex shader remain the same...
struct VertexIn {
    float3 position [[attribute(0)]];
    float2 textureCoordinate [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

struct Uniforms {
    float time;
    float intensity;
};

// Helper function for gaussian blur
float gaussian(float x, float sigma) {
    return (1.0 / (2.0 * M_PI_F * sigma * sigma)) * exp(-(x * x) / (2.0 * sigma * sigma));
}

// Color grading helper functions
float3 adjustContrast(float3 color, float contrast) {
    return mix(float3(0.5), color, contrast);
}

float3 adjustSaturation(float3 color, float saturation) {
    float luminance = dot(color, float3(0.3, 0.59, 0.11));
    return mix(float3(luminance), color, saturation);
}

float3 adjustBrightness(float3 color, float brightness) {
    return color * brightness;
}

float3 adjustHue(float3 color, float hue) {
    const float3 k = float3(0.57735, 0.57735, 0.57735);
    float cosAngle = cos(hue);
    return float3(color * cosAngle + cross(k, color) * sin(hue) + k * dot(k, color) * (1.0 - cosAngle));
}

float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}


vertex VertexOut vertex_shader(const device VertexIn* vertex_array [[ buffer(0) ]],
                             unsigned int vid [[ vertex_id ]]) {
    VertexIn vertexIn = vertex_array[vid];
    VertexOut vertexOut;
    vertexOut.position = float4(vertexIn.position, 1.0);
    vertexOut.textureCoordinate = vertexIn.textureCoordinate;
    return vertexOut;
}


// Beautify shader
fragment float4 wave_shader(VertexOut fragmentIn [[stage_in]],
                              texture2d<float> texture [[texture(0)]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = fragmentIn.textureCoordinate;
    
    // Wave distortion effect
    float2 offset = float2(
                           sin(uv.y * 10.0 + uniforms.time) * 0.01,
                           cos(uv.x * 10.0 + uniforms.time) * 0.01
                           ) * uniforms.intensity;
    
    uv += offset;
    
    // Keep UV coordinates in bounds
    uv = clamp(uv, 0.0, 1.0);
    
    float4 color = texture.sample(textureSampler, uv);
    return color;
}

// Dreamy shader
fragment float4 beautify_shader(VertexOut fragmentIn [[stage_in]],
                            texture2d<float> texture [[texture(0)]],
                            constant Uniforms &uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = fragmentIn.textureCoordinate;
    float2 textureSize = float2(texture.get_width(), texture.get_height());
    float aspect = textureSize.x / textureSize.y;
    
    // Parameters for beauty effect
    float glowRadius = 0.03 * uniforms.intensity;
    float softenRadius = 0.002 * uniforms.intensity;
    float brightness = 1.0 + (0.1 * uniforms.intensity);
    float warmth = 0.1 * uniforms.intensity;
    
    // Sample original color
    float4 originalColor = texture.sample(textureSampler, uv);
    
    // Soft blur for skin smoothing
    float4 blurredColor = float4(0.0);
    float totalWeight = 0.0;
    
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            float2 offset = float2(float(x) * softenRadius, float(y) * softenRadius);
            float weight = gaussian(length(offset), softenRadius);
            blurredColor += texture.sample(textureSampler, uv + offset) * weight;
            totalWeight += weight;
        }
    }
    blurredColor /= totalWeight;
    
    // Glow effect
    float4 glowColor = float4(0.0);
    totalWeight = 0.0;
    
    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            float2 offset = float2(float(x) * glowRadius, float(y) * glowRadius);
            float weight = gaussian(length(offset), glowRadius);
            glowColor += texture.sample(textureSampler, uv + offset) * weight;
            totalWeight += weight;
        }
    }
    glowColor /= totalWeight;
    
    // Blend original with blur and glow
    float4 finalColor = mix(originalColor, blurredColor, 0.4);
    finalColor = mix(finalColor, glowColor, 0.2);
    
    // Enhance brightness
    finalColor.rgb *= brightness;
    
    // Add slight warm tint
    float3 warmTint = float3(1.0 + warmth, 1.0 + warmth * 0.5, 1.0);
    finalColor.rgb *= warmTint;
    
    // Enhance skin tones
    float luminance = dot(finalColor.rgb, float3(0.299, 0.587, 0.114));
    float3 skinTone = float3(1.0 + 0.1 * uniforms.intensity,
                            1.0 + 0.05 * uniforms.intensity,
                            1.0);
    finalColor.rgb = mix(finalColor.rgb, finalColor.rgb * skinTone, luminance * 0.5);
    
    // Subtle pulsing glow
    float pulseIntensity = 0.03 * (sin(uniforms.time) * 0.5 + 0.5) * uniforms.intensity;
    finalColor.rgb += pulseIntensity;
    
    // Ensure we don't exceed maximum brightness
    finalColor = clamp(finalColor, 0.0, 1.0);
    
    return finalColor;
}

// Vintage shader
fragment float4 dreamy_shader(VertexOut fragmentIn [[stage_in]],
                             texture2d<float> texture [[texture(0)]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = fragmentIn.textureCoordinate;
    float2 center = float2(0.5, 0.5);
    
    // Create dreamy effect
    float vignetteStrength = 0.4 * uniforms.intensity;
    float glowStrength = 0.3 * uniforms.intensity;
    float aberrationStrength = 0.003 * uniforms.intensity;
    
    // Subtle pulsing movement
    float pulseTime = uniforms.time * 0.5;
    float2 pulseOffset = float2(
        sin(pulseTime) * 0.001 * uniforms.intensity,
        cos(pulseTime * 0.8) * 0.001 * uniforms.intensity
    );
    
    // Chromatic aberration
    float3 color;
    color.r = texture.sample(textureSampler, uv + aberrationStrength + pulseOffset).r;
    color.g = texture.sample(textureSampler, uv).g;
    color.b = texture.sample(textureSampler, uv - aberrationStrength + pulseOffset).b;
    
    // Dreamy bloom effect
    float3 bloom = float3(0.0);
    float bloomWeight = 0.0;
    float bloomSize = 0.03 * uniforms.intensity;
    
    for(int i = 0; i < 8; i++) {
        float angle = M_PI_F * 2.0 * float(i) / 8.0;
        float2 bloomOffset = float2(cos(angle), sin(angle)) * bloomSize;
        float weight = 1.0 / (1.0 + float(i));
        
        bloom += texture.sample(textureSampler, uv + bloomOffset).rgb * weight;
        bloomWeight += weight;
    }
    bloom /= bloomWeight;
    
    // Soft vignette
    float2 vignetteUV = uv - center;
    float vignette = 1.0 - length(vignetteUV) * vignetteStrength;
    vignette = smoothstep(0.0, 1.0, vignette);
    
    // Color grading
    float3 finalColor = mix(color, bloom, glowStrength);
    
    // Enhance colors
    float contrastBoost = 1.1 + (0.2 * uniforms.intensity);
    float saturationBoost = 1.2 + (0.3 * uniforms.intensity);
    float brightnessBoost = 1.1 + (0.1 * uniforms.intensity);
    
    finalColor = adjustContrast(finalColor, contrastBoost);
    finalColor = adjustSaturation(finalColor, saturationBoost);
    finalColor = adjustBrightness(finalColor, brightnessBoost);
    
    // Add warm highlights
    float3 warmHighlight = float3(1.1, 1.05, 1.0);
    float highlightIntensity = 0.3 * uniforms.intensity;
    float highlightStrength = pow(max(dot(finalColor, float3(0.299, 0.587, 0.114)), 0.0), 2.0);
    finalColor = mix(finalColor, finalColor * warmHighlight, highlightStrength * highlightIntensity);
    
    // Soft skin tones
    float3 skinTone = float3(1.1, 1.0, 0.9);
    float skinMask = pow(max(dot(finalColor, float3(0.3, 0.59, 0.11)), 0.0), 1.5);
    finalColor = mix(finalColor, finalColor * skinTone, skinMask * 0.3 * uniforms.intensity);
    
    // Apply vignette
    finalColor *= vignette;
    
    // Add subtle rainbow highlight
    float rainbowIntensity = 0.1 * uniforms.intensity;
    float3 rainbow = float3(
        sin(uv.y * 10.0 + uniforms.time),
        sin(uv.y * 10.0 + uniforms.time + 2.0),
        sin(uv.y * 10.0 + uniforms.time + 4.0)
    ) * 0.5 + 0.5;
    finalColor += rainbow * rainbowIntensity * highlightStrength;
    
    // Final adjustments
    finalColor = clamp(finalColor, 0.0, 1.0);
    
    return float4(finalColor, 1.0);
}


fragment float4 vintage_shader(VertexOut fragmentIn [[stage_in]],
                             texture2d<float> texture [[texture(0)]],
                               constant Uniforms &uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = fragmentIn.textureCoordinate;
    
    // Film grain
    float2 noiseUV = uv * float2(texture.get_width(), texture.get_height()) / 1000.0;
    float noise = random(noiseUV + uniforms.time) * 0.1 * uniforms.intensity;
    
    // Vintage color shift
    float2 r_offset = float2(0.009 * uniforms.intensity, 0.0);
    float2 g_offset = float2(0.0, 0.009 * uniforms.intensity);
    float2 b_offset = float2(-0.009 * uniforms.intensity, 0.0);
    
    float3 color;
    color.r = texture.sample(textureSampler, uv + r_offset).r;
    color.g = texture.sample(textureSampler, uv + g_offset).g;
    color.b = texture.sample(textureSampler, uv + b_offset).b;
    
    // Vignette
    float2 vignetteUV = uv - 0.5;
    float vignette = 1.0 - dot(vignetteUV, vignetteUV) * (1.0 + uniforms.intensity);
    vignette = pow(vignette, 1.5);
    
    // Color grading
    float3 shadows = float3(0.9, 0.7, 0.6);
    float3 midtones = float3(1.1, 1.0, 0.9);
    float3 highlights = float3(1.0, 0.9, 0.8);
    
    float luminance = dot(color, float3(0.299, 0.587, 0.114));
    float3 colorGraded = mix(
        mix(shadows, midtones, smoothstep(0.0, 0.5, luminance)),
        highlights,
        smoothstep(0.5, 1.0, luminance)
    );
    
    color *= colorGraded;
    
    // Add film scratches
    float scratchIntensity = 0.3 * uniforms.intensity;
    float scratch = random(float2(uniforms.time * 10.0, uv.y * 0.1));
    scratch = step(0.99, scratch) * scratchIntensity;
    color += scratch;
    
    // Light leak effect
    float3 leakColor = float3(1.2, 0.8, 0.6);
    float leak = sin(uv.x * 10.0 + uniforms.time) * 0.5 + 0.5;
    leak *= sin(uv.y * 8.0 - uniforms.time * 0.5) * 0.5 + 0.5;
    leak *= uniforms.intensity * 0.3;
    
    color = mix(color, leakColor, leak);
    
    // Apply vignette and grain
    color *= vignette;
    color += noise;
    
    // Final adjustments
    color = clamp(color, 0.0, 1.0);
    float fadeAmount = 0.1 * uniforms.intensity;
    color = mix(color, float3(0.9, 0.85, 0.8), fadeAmount);
    
    return float4(color, 1.0);
}

