#ifndef SHADER_TYPES_H
#define SHADER_TYPES_H

#include <metal_stdlib>
using namespace metal;

// Must match ShaderUniforms in MetalRenderer.swift. Imported filters declare the same layout (docs/05 section 4).
struct ShaderParameters {
    float curvature;       // 0.0 (flat) to 1.0 (deep barrel)
    float scanline_weight; // 0.0 (off) to 1.0 (heavy)
    float phosphor_glow;   // Bloom intensity
    float color_temp;      // 0.0 warm, 0.5 neutral, 1.0 cool
    float time;            // Frame timer for dynamic animation and grain
    uint  viewport_w;      // Output viewport width in pixels
    uint  viewport_h;      // Output viewport height in pixels
    uint  source_w;        // Core frame width, whatever size earlier passes wrote
    uint  source_h;        // Core frame height
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Colour temperature tint. 0.5 is exactly neutral, so Original at its default changes nothing.
static inline float3 apply_color_temp(float3 color, float temp) {
    const float3 warm = float3(1.10, 0.96, 0.85);
    const float3 cool = float3(0.88, 0.98, 1.12);
    float t = clamp(temp, 0.0, 1.0);
    float3 tint = t < 0.5 ? mix(warm, float3(1.0), t * 2.0) : mix(float3(1.0), cool, (t - 0.5) * 2.0);
    return clamp(color * tint, 0.0, 1.0);
}

static inline float2 source_size(constant ShaderParameters& params) {
    return max(float2(params.source_w, params.source_h), float2(1.0));
}

#endif
