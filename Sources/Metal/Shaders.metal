#include <metal_stdlib>
using namespace metal;

// MARK: - Uniform Parameters

struct ShaderParameters {
    float curvature;       // 0.0 (flat) to 1.0 (deep barrel)
    float scanline_weight; // 0.0 (off) to 1.0 (heavy)
    float phosphor_glow;   // Bloom intensity
    float color_temp;      // Warm (e.g. 0.0) to Cool (e.g. 1.0), neutral around 0.5
    float time;            // Frame timer for dynamic animation / grain
    uint  viewport_w;      // Output viewport width in pixels
    uint  viewport_h;      // Output viewport height in pixels
};

// MARK: - Vertex Input / Output

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Fullscreen Quad Vertex Shader

vertex VertexOut vertex_main(uint vertex_id [[vertex_id]]) {
    // Generates a 6-vertex fullscreen quad (2 triangles) covering NDC [-1, 1]
    const float2 positions[6] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0)
    };

    const float2 uvs[6] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0, 0.0)
    };

    VertexOut out;
    out.position = float4(positions[vertex_id], 0.0, 1.0);
    out.uv = uvs[vertex_id];
    return out;
}

// MARK: - Helper Functions

// Relative luminance based on Rec.709
static inline float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// Color temperature tint adjustment
static inline float3 apply_color_temp(float3 color, float temp) {
    // temp: 0.0 = warm (amber tint), 0.5 = neutral, 1.0 = cool (cyan-blue tint)
    float3 warm = float3(1.10, 0.96, 0.85);
    float3 cool = float3(0.88, 0.98, 1.12);
    float3 tint = mix(warm, cool, clamp(temp, 0.0, 1.0));
    return clamp(color * tint, 0.0, 1.0);
}

// Pseudo-random 2D noise generator
static inline float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Tube barrel curvature mapping
static inline float2 curve_coordinates(float2 uv, float k) {
    // Map uv to [-1, 1]
    float2 p = uv * 2.0 - 1.0;
    // Barrel distortion: p_distorted = p * (1.0 + k * dot(p, p))
    p = p * (1.0 + k * dot(p, p));
    // Remap back to [0, 1]
    return p * 0.5 + 0.5;
}

// Vignette factor
static inline float vignette(float2 uv, float strength) {
    float2 p = uv * 2.0 - 1.0;
    float d = dot(p, p);
    return clamp(1.0 - d * strength, 0.0, 1.0);
}

// MARK: - 1. Original (Pass-Through)

fragment float4 original_fragment(VertexOut in [[stage_in]],
                                  texture2d<float> core_texture [[texture(0)]],
                                  sampler tex_sampler [[sampler(0)]],
                                  constant ShaderParameters& params [[buffer(0)]]) {
    float4 color = core_texture.sample(tex_sampler, in.uv);
    color.rgb = apply_color_temp(color.rgb, params.color_temp);
    return color;
}

// MARK: - 2. Cartoon (Sobel Edge + Palette Quantize)

fragment float4 cartoon_fragment(VertexOut in [[stage_in]],
                                 texture2d<float> core_texture [[texture(0)]],
                                 sampler tex_sampler [[sampler(0)]],
                                 constant ShaderParameters& params [[buffer(0)]]) {
    float2 tex_size = float2(core_texture.get_width(), core_texture.get_height());
    float2 pixel_step = 1.0 / max(tex_size, float2(1.0, 1.0));

    // 3x3 Sobel kernel taps for luminance
    float lum[3][3];
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            float2 offset = float2(float(x), float(y)) * pixel_step;
            float4 sample = core_texture.sample(tex_sampler, in.uv + offset);
            lum[y + 1][x + 1] = luminance(sample.rgb);
        }
    }

    // Sobel Gx and Gy
    float gx = -lum[0][0] - 2.0 * lum[1][0] - lum[2][0] +
                lum[0][2] + 2.0 * lum[1][2] + lum[2][2];
    float gy = -lum[0][0] - 2.0 * lum[0][1] - lum[0][2] +
                lum[2][0] + 2.0 * lum[2][1] + lum[2][2];
    float edge = sqrt(gx * gx + gy * gy);

    // Sample center color and quantize into 16 discrete levels
    float4 center = core_texture.sample(tex_sampler, in.uv);
    const float levels = 16.0;
    float3 quantized = floor(center.rgb * levels + 0.5) / levels;

    // Darken edges
    float edge_factor = smoothstep(0.15, 0.35, edge);
    float3 final_rgb = mix(quantized, float3(0.05, 0.05, 0.08), edge_factor);
    final_rgb = apply_color_temp(final_rgb, params.color_temp);

    return float4(final_rgb, 1.0);
}

// MARK: - 3. CRT v1 (Lightweight Sine Scanlines)

fragment float4 crt_v1_fragment(VertexOut in [[stage_in]],
                                texture2d<float> core_texture [[texture(0)]],
                                sampler tex_sampler [[sampler(0)]],
                                constant ShaderParameters& params [[buffer(0)]]) {
    float4 color = core_texture.sample(tex_sampler, in.uv);

    // Target retro scanlines (typically 224 or 240 lines)
    float target_lines = float(core_texture.get_height());
    if (target_lines <= 0.0) target_lines = 224.0;

    // Luminance modulation: 1.0 - intensity * sin(uv.y * lines * PI)^2
    float scanline = sin(in.uv.y * target_lines * M_PI_F);
    float scanline_factor = 1.0 - (params.scanline_weight * 0.45) * (scanline * scanline);

    float3 final_rgb = color.rgb * scanline_factor;
    final_rgb = apply_color_temp(final_rgb, params.color_temp);
    return float4(final_rgb, color.a);
}

// MARK: - 4. CRT v2 (Aperture Grille & Phosphors)

fragment float4 crt_v2_fragment(VertexOut in [[stage_in]],
                                texture2d<float> core_texture [[texture(0)]],
                                sampler tex_sampler [[sampler(0)]],
                                constant ShaderParameters& params [[buffer(0)]]) {
    float2 tex_size = float2(core_texture.get_width(), core_texture.get_height());
    float2 pixel_step = 1.0 / max(tex_size, float2(1.0, 1.0));

    // Multi-tap horizontal blur for subtle phosphor bloom
    float4 c_left  = core_texture.sample(tex_sampler, in.uv - float2(pixel_step.x * 0.5, 0.0));
    float4 c_mid   = core_texture.sample(tex_sampler, in.uv);
    float4 c_right = core_texture.sample(tex_sampler, in.uv + float2(pixel_step.x * 0.5, 0.0));
    float3 bloom   = (c_left.rgb * 0.25 + c_mid.rgb * 0.50 + c_right.rgb * 0.25);

    float3 base_color = mix(c_mid.rgb, bloom, clamp(params.phosphor_glow, 0.0, 1.0));

    // Aperture grille RGB phosphor triad based on screen-space X pixel column
    uint pixel_x = uint(in.position.x);
    uint mod3 = pixel_x % 3;

    float3 triad_mask;
    if (mod3 == 0) {
        triad_mask = float3(1.25, 0.70, 0.70); // Red stripe
    } else if (mod3 == 1) {
        triad_mask = float3(0.70, 1.25, 0.70); // Green stripe
    } else {
        triad_mask = float3(0.70, 0.70, 1.25); // Blue stripe
    }

    // Horizontal scanline modulation
    float target_lines = float(tex_size.y > 0.0 ? tex_size.y : 240.0);
    float scanline = sin(in.uv.y * target_lines * M_PI_F);
    float scan_attenuation = 1.0 - (params.scanline_weight * 0.35) * (scanline * scanline);

    float3 final_rgb = base_color * triad_mask * scan_attenuation;
    final_rgb = apply_color_temp(final_rgb, params.color_temp);

    return float4(clamp(final_rgb, 0.0, 1.0), 1.0);
}

// MARK: - 5. Geom CRT (Barrel Distortion + Vignette + Bloom)

fragment float4 geom_crt_fragment(VertexOut in [[stage_in]],
                                  texture2d<float> core_texture [[texture(0)]],
                                  sampler tex_sampler [[sampler(0)]],
                                  constant ShaderParameters& params [[buffer(0)]]) {
    // Curvature factor: scale params.curvature [0, 1] to reasonable barrel distortion [0, 0.35]
    float k = params.curvature * 0.30;
    float2 curved_uv = curve_coordinates(in.uv, k);

    // Black out out-of-bounds pixels
    if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    // Chromatic aberration at distorted edges
    float2 center_dist = curved_uv - float2(0.5);
    float dist_len = dot(center_dist, center_dist);
    float2 ca_offset = center_dist * dist_len * 0.035;

    float r = core_texture.sample(tex_sampler, curved_uv + ca_offset).r;
    float g = core_texture.sample(tex_sampler, curved_uv).g;
    float b = core_texture.sample(tex_sampler, curved_uv - ca_offset).b;
    float3 color = float3(r, g, b);

    // Scanlines
    float target_lines = float(core_texture.get_height() > 0 ? core_texture.get_height() : 240);
    float scan = sin(curved_uv.y * target_lines * M_PI_F);
    float scan_mod = 1.0 - (params.scanline_weight * 0.40) * (scan * scan);

    // Corner vignette
    float vig = vignette(curved_uv, 0.35);

    // Subtle phosphor glow
    float glow = params.phosphor_glow * 0.15;
    float3 final_rgb = (color * scan_mod + color * glow) * vig;
    final_rgb = apply_color_temp(final_rgb, params.color_temp);

    return float4(clamp(final_rgb, 0.0, 1.0), 1.0);
}

// MARK: - 6. Geom CRT Border (Vintage TV Bezel Composite)

fragment float4 geom_crt_border_fragment(VertexOut in [[stage_in]],
                                         texture2d<float> core_texture [[texture(0)]],
                                         sampler tex_sampler [[sampler(0)]],
                                         constant ShaderParameters& params [[buffer(0)]]) {
    // Inner active CRT area is mapped inside [0.12, 0.88] x [0.12, 0.88]
    const float2 border_min = float2(0.10, 0.10);
    const float2 border_max = float2(0.90, 0.90);
    const float2 border_range = border_max - border_min;

    // Check if within bezel or screen
    if (in.uv.x < border_min.x || in.uv.x > border_max.x ||
        in.uv.y < border_min.y || in.uv.y > border_max.y) {
        // Outside screen: render vintage dark-gray / plastic bezel
        float2 p = in.uv * 2.0 - 1.0;
        float d = length(p);
        float bezel_shade = mix(0.18, 0.08, clamp(d * 0.7, 0.0, 1.0));

        // Subtle specular highlight on top bezel edge
        if (in.uv.y < 0.12 && in.uv.x > 0.15 && in.uv.x < 0.85) {
            bezel_shade += 0.08 * (1.0 - abs(in.uv.x - 0.5) * 2.0);
        }

        return float4(float3(bezel_shade), 1.0);
    }

    // Remap coordinates inside screen area
    float2 screen_uv = (in.uv - border_min) / border_range;
    float k = max(params.curvature * 0.25, 0.08);
    float2 curved_uv = curve_coordinates(screen_uv, k);

    if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
        // Inner bezel shadow border
        return float4(0.04, 0.04, 0.05, 1.0);
    }

    float4 sample = core_texture.sample(tex_sampler, curved_uv);

    // Inner shadow near screen edges
    float edge_dist = min(min(curved_uv.x, 1.0 - curved_uv.x), min(curved_uv.y, 1.0 - curved_uv.y));
    float inner_shadow = smoothstep(0.0, 0.06, edge_dist);

    // Subtle glass glare reflection (diagonal sweep)
    float glare = 0.04 * max(0.0, 1.0 - abs(curved_uv.x + curved_uv.y * 0.8 - 0.8) * 4.0);

    // Scanline pass
    float target_lines = float(core_texture.get_height() > 0 ? core_texture.get_height() : 240);
    float scan = sin(curved_uv.y * target_lines * M_PI_F);
    float scan_mod = 1.0 - (params.scanline_weight * 0.35) * (scan * scan);

    float3 final_rgb = (sample.rgb * scan_mod + glare) * inner_shadow;
    final_rgb = apply_color_temp(final_rgb, params.color_temp);

    return float4(clamp(final_rgb, 0.0, 1.0), 1.0);
}

// MARK: - 7. Film (Celluloid Film Stock + Animated Grain + Dust)

fragment float4 film_fragment(VertexOut in [[stage_in]],
                              texture2d<float> core_texture [[texture(0)]],
                              sampler tex_sampler [[sampler(0)]],
                              constant ShaderParameters& params [[buffer(0)]]) {
    float4 color = core_texture.sample(tex_sampler, in.uv);

    // Dynamic animated high-frequency film grain
    float2 grain_uv = in.uv * float2(params.viewport_w > 0 ? params.viewport_w : 800,
                                     params.viewport_h > 0 ? params.viewport_h : 600);
    float time_stepped = floor(params.time * 24.0); // 24 FPS film shutter cadence
    float noise = hash(grain_uv + float2(time_stepped * 17.13, time_stepped * 31.71));
    float grain = (noise - 0.5) * 0.16;

    // Vintage 1970s warm color grading (Technicolor / Kodachrome shift)
    float3 warm_graded;
    warm_graded.r = pow(color.r, 0.90) * 1.08;
    warm_graded.g = color.g * 0.98;
    warm_graded.b = pow(color.b, 1.15) * 0.88;

    // Intermittent dust / lint artifact (sparingly appears)
    float dust_chance = hash(float2(time_stepped * 7.7, 91.3));
    float dust = 0.0;
    if (dust_chance > 0.92) {
        float2 dust_pos = float2(hash(float2(time_stepped, 1.0)), hash(float2(time_stepped, 2.0)));
        float d = distance(in.uv, dust_pos);
        if (d < 0.006) {
            dust = 0.45; // Dark hair/dust particle
        }
    }

    float3 final_rgb = clamp(warm_graded + grain - dust, 0.0, 1.0);
    final_rgb = apply_color_temp(final_rgb, params.color_temp);

    return float4(final_rgb, color.a);
}
