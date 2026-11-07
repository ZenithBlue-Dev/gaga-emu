#include "ShaderTypes.h"

// The Community section of the filter picker: public-domain shaders from
// https://github.com/libretro/slang-shaders, converted to MSL by hand ahead of time. Each one's
// licence statement is quoted above it, and docs/05 section 5 records them. A shader goes here only
// when its own file says it may ship: that repository has no overall licence, and much of it is GPL.

// MARK: - Lottes CRT (crt/shaders/crt-lottes.slang)
// "PUBLIC DOMAIN CRT STYLED SCAN-LINE SHADER by Timothy Lottes"
// Parameters fixed at the file's defaults, except the sliders mapped below.

static inline float lottes_to_linear(float c) { return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4); }
static inline float3 lottes_to_linear(float3 c) { return float3(lottes_to_linear(c.r), lottes_to_linear(c.g), lottes_to_linear(c.b)); }
static inline float lottes_to_srgb(float c) { return c < 0.0031308 ? c * 12.92 : 1.055 * pow(c, 0.41666) - 0.055; }
static inline float3 lottes_to_srgb(float3 c) { return float3(lottes_to_srgb(c.r), lottes_to_srgb(c.g), lottes_to_srgb(c.b)); }
static inline float lottes_gaus(float pos, float scale) { return pow(2.0, scale * pos * pos); }

struct LottesInput {
    texture2d<float> tex;
    sampler s;
    float2 size;
    float2 pos;
    float2 dist;
};

static inline float3 lottes_fetch(LottesInput in, float2 off) {
    float2 pos = (floor(in.pos * in.size + off) + 0.5) / in.size;
    return lottes_to_linear(in.tex.sample(in.s, pos).rgb);
}

static inline float3 lottes_horizontal(LottesInput in, float off, int radius, float scale) {
    float3 sum = float3(0.0);
    float total = 0.0;
    for (int x = -radius; x <= radius; ++x) {
        float weight = lottes_gaus(in.dist.x + float(x), scale);
        sum += lottes_fetch(in, float2(float(x), off)) * weight;
        total += weight;
    }
    return sum / total;
}

fragment float4 lottes_crt_fragment(VertexOut in [[stage_in]],
                                    texture2d<float> tex [[texture(0)]],
                                    sampler s [[sampler(0)]],
                                    constant ShaderParameters& params [[buffer(0)]]) {
    const float hard_pix = -3.0, hard_bloom_pix = -1.5, hard_bloom_scan = -2.0;
    const float mask_dark = 0.5, mask_light = 1.5;
    // Upstream's hardScan -8.0 sits at the slider's 0.5; its bloomAmount 0.15 sits at the glow default.
    float hard_scan = -16.0 * clamp(params.scanline_weight, 0.02, 1.0);
    float bloom_amount = params.phosphor_glow * 0.6;

    float warp = params.curvature * 0.155;
    float2 p = in.uv * 2.0 - 1.0;
    p *= float2(1.0 + p.y * p.y * warp, 1.0 + p.x * p.x * warp * 1.32);
    float2 pos = p * 0.5 + 0.5;
    if (pos.x < 0.0 || pos.x > 1.0 || pos.y < 0.0 || pos.y > 1.0) return float4(0.0, 0.0, 0.0, 1.0);

    float2 size = source_size(params);
    float2 scaled = pos * size;
    LottesInput input = { tex, s, size, pos, -((scaled - floor(scaled)) - 0.5) };

    float3 color = float3(0.0);
    for (int line = -1; line <= 1; ++line) {
        color += lottes_horizontal(input, float(line), line == 0 ? 2 : 1, hard_pix)
               * lottes_gaus(input.dist.y + float(line), hard_scan);
    }
    float3 bloom = float3(0.0);
    for (int line = -2; line <= 2; ++line) {
        bloom += lottes_horizontal(input, float(line), abs(line) == 2 ? 2 : 3, hard_bloom_pix)
               * lottes_gaus(input.dist.y + float(line), hard_bloom_scan);
    }
    color += bloom * bloom_amount;

    // Stretched VGA style shadow mask, upstream's default.
    float2 screen = in.position.xy;
    float column = fract((screen.x + screen.y * 3.0) * 0.166666666);
    float3 mask = float3(mask_dark);
    if (column < 0.333) mask.r = mask_light;
    else if (column < 0.666) mask.g = mask_light;
    else mask.b = mask_light;

    return float4(apply_color_temp(lottes_to_srgb(max(color * mask, float3(0.0))), params.color_temp), 1.0);
}

// MARK: - LCD3x (handheld/shaders/lcd3x.slang)
// "Author: Gigaherz, License: Public domain"

fragment float4 lcd3x_fragment(VertexOut in [[stage_in]],
                               texture2d<float> tex [[texture(0)]],
                               sampler s [[sampler(0)]],
                               constant ShaderParameters& params [[buffer(0)]]) {
    const float brighten_scanlines = 16.0, brighten_lcd = 4.0;
    const float3 offsets = M_PI_F * float3(1.0 / 2.0, 1.0 / 2.0 - 2.0 / 3.0, 1.0 / 2.0 - 4.0 / 3.0);
    float2 angle = in.uv * 2.0 * M_PI_F * source_size(params);
    float y_factor = (brighten_scanlines + sin(angle.y)) / (brighten_scanlines + 1.0);
    float3 x_factors = (brighten_lcd + sin(angle.x + offsets)) / (brighten_lcd + 1.0);
    float3 color = y_factor * x_factors * tex.sample(s, in.uv).rgb;
    return float4(apply_color_temp(color, params.color_temp), 1.0);
}

// MARK: - Sharp Bilinear (pixel-art-scaling/shaders/sharp-bilinear.slang)
// "Author: Themaister, License: Public domain"

fragment float4 sharp_bilinear_fragment(VertexOut in [[stage_in]],
                                        texture2d<float> tex [[texture(0)]],
                                        constant ShaderParameters& params [[buffer(0)]]) {
    constexpr sampler linear_clamp(filter::linear, address::clamp_to_edge);
    float2 size = source_size(params);
    float2 texel = in.uv * size;
    float scale = max(floor(float(params.viewport_h) / size.y + 0.01), 1.0);
    float region_range = 0.5 - 0.5 / scale;
    float2 center_dist = fract(texel) - 0.5;
    float2 f = (center_dist - clamp(center_dist, -region_range, region_range)) * scale + 0.5;
    float3 color = tex.sample(linear_clamp, (floor(texel) + f) / size).rgb;
    return float4(apply_color_temp(color, params.color_temp), 1.0);
}
