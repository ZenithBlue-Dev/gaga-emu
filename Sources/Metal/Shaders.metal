#include "ShaderTypes.h"

// Every preset samples texture(0), which is the core frame or the previous pass's output.
// Sizes that mean "one emulated pixel" come from params.source_w and source_h, because the
// texture may already be upscaled. Alpha is not read: an XRGB frame's X byte is undefined.

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
    return float4(apply_color_temp(color.rgb, params.color_temp), 1.0);
}

// MARK: - 2. Cartoon (Sobel Edge + Palette Quantize)

fragment float4 cartoon_fragment(VertexOut in [[stage_in]],
                                 texture2d<float> core_texture [[texture(0)]],
                                 sampler tex_sampler [[sampler(0)]],
                                 constant ShaderParameters& params [[buffer(0)]]) {
    float2 pixel_step = 1.0 / source_size(params);

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

    // Luminance modulation: 1.0 - intensity * sin(uv.y * lines * PI)^2
    float scanline = sin(in.uv.y * source_size(params).y * M_PI_F);
    float scanline_factor = 1.0 - (params.scanline_weight * 0.45) * (scanline * scanline);

    float3 final_rgb = color.rgb * scanline_factor;
    final_rgb = apply_color_temp(final_rgb, params.color_temp);
    return float4(final_rgb, 1.0);
}

// MARK: - 4. CRT v2 (Aperture Grille & Phosphors)

fragment float4 crt_v2_fragment(VertexOut in [[stage_in]],
                                texture2d<float> core_texture [[texture(0)]],
                                sampler tex_sampler [[sampler(0)]],
                                constant ShaderParameters& params [[buffer(0)]]) {
    float2 pixel_step = 1.0 / source_size(params);

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
    float scanline = sin(in.uv.y * source_size(params).y * M_PI_F);
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
    float scan = sin(curved_uv.y * source_size(params).y * M_PI_F);
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
    // Inner active CRT area is mapped inside [0.10, 0.90] x [0.10, 0.90]
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
    float scan = sin(curved_uv.y * source_size(params).y * M_PI_F);
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

    return float4(final_rgb, 1.0);
}

// MARK: - Upscalers (first pass of the chain, docs/05 section 3.4)

// Catmull-Rom weights for the four taps around a sample at fraction `t`.
static inline float4 catmull_rom(float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    return float4(-0.5 * t3 + t2 - 0.5 * t,
                  1.5 * t3 - 2.5 * t2 + 1.0,
                  -1.5 * t3 + 2.0 * t2 + 0.5 * t,
                  0.5 * t3 - 0.5 * t2);
}

fragment float4 bicubic_fragment(VertexOut in [[stage_in]],
                                 texture2d<float> tex [[texture(0)]],
                                 sampler s [[sampler(0)]],
                                 constant ShaderParameters& params [[buffer(0)]]) {
    float2 size = source_size(params);
    float2 pos = in.uv * size - 0.5;
    float2 base = floor(pos);
    float2 f = pos - base;
    float4 wx = catmull_rom(f.x);
    float4 wy = catmull_rom(f.y);
    float3 sum = float3(0.0);
    for (int y = 0; y < 4; ++y) {
        for (int x = 0; x < 4; ++x) {
            float2 texel = (base + float2(x - 1, y - 1) + 0.5) / size;
            sum += tex.sample(s, texel).rgb * wx[x] * wy[y];
        }
    }
    return float4(clamp(sum, 0.0, 1.0), 1.0);
}

// Edge Smooth: GagaEmu's own upscaler. Data-dependent triangulation (Yu, Morse and Sederberg, 2001):
// each cell between four texels splits along whichever diagonal crosses the smaller colour change,
// so interpolation follows edges instead of cutting across them. Not derived from xBRZ (GPL-3),
// Scale2x or the Eagle family. Fractions are sharpened, so flat areas keep their pixel shapes.
static inline float colour_distance(float3 a, float3 b) {
    return length(a - b);
}

fragment float4 edge_smooth_fragment(VertexOut in [[stage_in]],
                                     texture2d<float> tex [[texture(0)]],
                                     sampler s [[sampler(0)]],
                                     constant ShaderParameters& params [[buffer(0)]]) {
    float2 size = source_size(params);
    float2 pos = in.uv * size - 0.5;
    float2 base = floor(pos);
    float3 t[4][4];
    for (int y = 0; y < 4; ++y) {
        for (int x = 0; x < 4; ++x) {
            t[y][x] = tex.sample(s, (base + float2(x - 1, y - 1) + 0.5) / size).rgb;
        }
    }
    float3 a = t[1][1], b = t[1][2], c = t[2][1], d = t[2][2];

    // Summed colour change along each diagonal direction, over the cell and its neighbours.
    float falling = colour_distance(a, d) + colour_distance(t[0][0], a) + colour_distance(d, t[3][3])
                  + colour_distance(t[0][1], b) + colour_distance(c, t[3][2])
                  + colour_distance(t[1][0], c) + colour_distance(b, t[2][3]);
    float rising = colour_distance(b, c) + colour_distance(t[0][3], b) + colour_distance(c, t[3][0])
                 + colour_distance(t[0][2], a) + colour_distance(d, t[3][1])
                 + colour_distance(t[1][3], d) + colour_distance(a, t[2][0]);

    float2 f = smoothstep(0.2, 0.8, pos - base);
    float3 result;
    if (falling < rising) {
        // Split along a to d.
        result = f.x >= f.y ? a + f.x * (b - a) + f.y * (d - b) : a + f.y * (c - a) + f.x * (d - c);
    } else if (rising < falling) {
        // Split along b to c.
        result = f.x + f.y <= 1.0 ? a + f.x * (b - a) + f.y * (c - a)
                                  : d + (1.0 - f.x) * (c - d) + (1.0 - f.y) * (b - d);
    } else {
        result = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }
    return float4(clamp(result, 0.0, 1.0), 1.0);
}

// MARK: - CRT Deluxe (three passes, written for GagaEmu; not derived from crt-royale)

// Pass 1, source size: gamma to linear light, with the beam's horizontal spread.
fragment float4 crt_deluxe_beam_fragment(VertexOut in [[stage_in]],
                                         texture2d<float> tex [[texture(0)]],
                                         sampler s [[sampler(0)]],
                                         constant ShaderParameters& params [[buffer(0)]]) {
    float texel = 1.0 / source_size(params).x;
    float spread = 0.15 + clamp(params.phosphor_glow, 0.0, 1.0) * 0.35;
    float3 sum = float3(0.0);
    float total = 0.0;
    for (int x = -2; x <= 2; ++x) {
        float weight = exp(-float(x * x) / (2.0 * spread * spread + 0.0001));
        float3 c = tex.sample(s, in.uv + float2(float(x) * texel, 0.0)).rgb;
        sum += pow(c, float3(2.4)) * weight;
        total += weight;
    }
    return float4(sum / total, 1.0);
}

// Pass 2, output size: tube curvature, and a beam whose height grows with brightness.
fragment float4 crt_deluxe_scan_fragment(VertexOut in [[stage_in]],
                                         texture2d<float> tex [[texture(0)]],
                                         sampler s [[sampler(0)]],
                                         constant ShaderParameters& params [[buffer(0)]]) {
    float2 uv = curve_coordinates(in.uv, params.curvature * 0.20);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return float4(0.0, 0.0, 0.0, 1.0);
    float lines = source_size(params).y;
    float row = uv.y * lines - 0.5;
    float base = floor(row);
    float tightness = mix(1.3, 0.55, clamp(params.scanline_weight, 0.0, 1.0));
    float3 sum = float3(0.0);
    for (int i = -1; i <= 2; ++i) {
        float line = base + float(i);
        float3 c = tex.sample(s, float2(uv.x, (line + 0.5) / lines)).rgb;
        float sigma = (0.28 + 0.27 * sqrt(max(max(c.r, c.g), c.b))) * tightness;
        float distance = row - line;
        sum += c * exp(-(distance * distance) / (2.0 * sigma * sigma)) / (sigma * 2.5066);
    }
    return float4(sum, 1.0);
}

// Pass 3, drawable: halation, a slot mask in screen pixels, vignette, then back to gamma.
fragment float4 crt_deluxe_mask_fragment(VertexOut in [[stage_in]],
                                         texture2d<float> tex [[texture(0)]],
                                         sampler s [[sampler(0)]],
                                         constant ShaderParameters& params [[buffer(0)]]) {
    float2 texel = 1.0 / float2(tex.get_width(), tex.get_height());
    float3 c = tex.sample(s, in.uv).rgb;
    float3 halo = float3(0.0);
    for (int i = 0; i < 8; ++i) {
        float angle = float(i) * M_PI_F / 4.0;
        halo += tex.sample(s, in.uv + float2(cos(angle), sin(angle)) * texel * 5.0).rgb;
    }
    c += halo * 0.125 * clamp(params.phosphor_glow, 0.0, 1.0) * 0.35;

    uint column = uint(in.position.x);
    uint slot = column / 3;
    bool gap = (uint(in.position.y) + slot * 2) % 4 == 0;
    uint triad = column % 3;
    float3 mask = triad == 0 ? float3(1.22, 0.78, 0.78) : (triad == 1 ? float3(0.78, 1.22, 0.78) : float3(0.78, 0.78, 1.22));
    c *= mask * (gap ? 0.85 : 1.0);

    c *= mix(1.0, vignette(in.uv, 0.30), params.curvature > 0.0 ? 1.0 : 0.5);
    c = pow(max(c * 1.15, float3(0.0)), float3(1.0 / 2.2));
    return float4(apply_color_temp(c, params.color_temp), 1.0);
}
