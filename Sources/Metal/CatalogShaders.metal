#include "ShaderTypes.h"

// The catalogue's single-pass filters, written in-house from published descriptions of each technique
// (docs/05 section 5.1 lists the basis of every one). No code here is taken from another shader.
// Sliders: scanline_weight is each filter's main strength, phosphor_glow its second control, curvature its third.

constexpr sampler cat_near(filter::nearest, address::clamp_to_edge);
constexpr sampler cat_linear(filter::linear, address::clamp_to_edge);

#define CAT(n) fragment float4 n##_fragment(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], \
    sampler s [[sampler(0)]], constant ShaderParameters& params [[buffer(0)]])
#define SIZE source_size(params)
#define PIX(x, y) cat_tap(tex, in.uv, SIZE, float2(x, y))

static inline float3 cat_tap(texture2d<float> t, float2 uv, float2 size, float2 off) {
    return t.sample(cat_near, (floor(uv * size) + 0.5 + off) / size).rgb;
}
static inline float cat_luma(float3 c) { return dot(c, float3(0.299, 0.587, 0.114)); }
static inline float4 cat_done(float3 c, constant ShaderParameters& p) { return float4(apply_color_temp(saturate(c), p.color_temp), 1.0); }
static inline float cat_rand(float2 p) { return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }

// Barrel distortion. Outside [0, 1] is off the tube.
static inline float2 cat_warp(float2 uv, float k) {
    float2 p = uv * 2.0 - 1.0;
    p *= 1.0 + float2(p.y * p.y, p.x * p.x) * k * 0.2;
    return p * 0.5 + 0.5;
}
static inline bool cat_off(float2 uv) { return uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0; }

// A gaussian beam across the scanline. Brighter pixels widen the beam, as on a tube.
static inline float cat_beam(float y, float luma, float hardness) {
    float d = fract(y) - 0.5;
    float width = mix(0.28, 0.55, luma);
    return exp(-d * d / (2.0 * width * width) * hardness);
}
static inline float3 cat_scan(float3 c, float y, float strength) {
    return c * mix(1.0, cat_beam(y, cat_luma(c), 1.0) * 1.35, strength);
}

// Phosphor layouts: three sub-pixels at screen scale.
static inline float3 cat_aperture(float2 p, float amount) {
    int x = int(fmod(p.x, 3.0));
    float3 m = float3(x == 0, x == 1, x == 2);
    return mix(float3(1.0), m * 2.4 + 0.2, amount);
}
static inline float3 cat_slot(float2 p, float amount) {
    float column = floor(p.x / 3.0);
    int x = int(fmod(p.x, 3.0));
    float y = fmod(p.y + fmod(column, 2.0) * 2.0, 4.0);
    float3 m = float3(x == 0, x == 1, x == 2) * (y < 3.0 ? 2.5 : 0.4) + 0.15;
    return mix(float3(1.0), m, amount);
}
static inline float3 cat_dots(float2 p, float amount) {
    float offset = fmod(floor(p.y / 2.0), 2.0) * 1.5;
    int x = int(fmod(p.x + offset, 3.0));
    float3 m = float3(x == 0, x == 1, x == 2) * 2.4 + 0.2;
    return mix(float3(1.0), m, amount);
}

// MARK: - CRT

// Sony-style vertical stripes with a soft beam.
CAT(cat_crt_aperture) {
    float2 uv = cat_warp(in.uv, params.curvature);
    if (cat_off(uv)) return float4(0, 0, 0, 1);
    float3 c = tex.sample(cat_linear, uv).rgb;
    c = cat_scan(c, uv.y * SIZE.y, params.scanline_weight);
    return cat_done(c * cat_aperture(in.position.xy, 0.4 + params.phosphor_glow * 0.6), params);
}

// Staggered slots, the common consumer-set mask.
CAT(cat_crt_slot) {
    float2 uv = cat_warp(in.uv, params.curvature);
    if (cat_off(uv)) return float4(0, 0, 0, 1);
    float3 c = tex.sample(cat_linear, uv).rgb;
    c = cat_scan(c, uv.y * SIZE.y, params.scanline_weight);
    return cat_done(c * cat_slot(in.position.xy, 0.4 + params.phosphor_glow * 0.6), params);
}

// Round phosphor triads in a staggered grid.
CAT(cat_crt_shadow) {
    float2 uv = cat_warp(in.uv, params.curvature);
    if (cat_off(uv)) return float4(0, 0, 0, 1);
    float3 c = tex.sample(cat_linear, uv).rgb;
    c = cat_scan(c, uv.y * SIZE.y, params.scanline_weight);
    return cat_done(c * cat_dots(in.position.xy, 0.4 + params.phosphor_glow * 0.6), params);
}

// Broadcast monitor: flat glass, hard pixels, fine dark lines, wider stripes.
CAT(cat_crt_pvm) {
    float2 size = SIZE;
    float3 c = PIX(0, 0);
    float d = fract(in.uv.y * size.y) - 0.5;
    float line = 1.0 - params.scanline_weight * smoothstep(0.30, 0.5, abs(d));
    return cat_done(c * line * cat_aperture(in.position.xy, 0.2 + params.phosphor_glow * 0.4), params);
}

// Living-room television: soft focus, bloom, a gentle bulge.
CAT(cat_crt_consumer) {
    float2 uv = cat_warp(in.uv, params.curvature + 0.15);
    if (cat_off(uv)) return float4(0, 0, 0, 1);
    float2 t = 1.0 / SIZE;
    float3 c = float3(0.0);
    for (int i = -2; i <= 2; ++i) c += tex.sample(cat_linear, uv + float2(float(i) * t.x * 0.8, 0.0)).rgb;
    c /= 5.0;
    c = cat_scan(c, uv.y * SIZE.y, params.scanline_weight * 0.7);
    return cat_done(c * (1.0 + params.phosphor_glow * 0.5) * cat_slot(in.position.xy, 0.25), params);
}

// Arcade monitor: heavy beams that bloom into dark gaps, very bright.
CAT(cat_crt_arcade) {
    float2 uv = cat_warp(in.uv, params.curvature);
    if (cat_off(uv)) return float4(0, 0, 0, 1);
    float3 c = tex.sample(cat_linear, uv).rgb;
    float beam = cat_beam(uv.y * SIZE.y, cat_luma(c), 2.0 + params.scanline_weight * 4.0);
    float3 bloom = tex.sample(cat_linear, uv, level(0)).rgb * params.phosphor_glow * 0.5;
    return cat_done(c * beam * 1.6 + bloom, params);
}

// A VGA monitor: line-doubled, no visible lines, a fine dot pitch.
CAT(cat_crt_vga) {
    float3 c = PIX(0, 0);
    return cat_done(c * mix(1.0, 0.75 + 0.25 * step(0.5, fract(in.uv.y * SIZE.y * 2.0)), params.scanline_weight)
                    * cat_dots(in.position.xy, 0.25 + params.phosphor_glow * 0.4), params);
}

// A cheap tube fed composite: chroma smeared wider than luma, then a mask.
CAT(cat_crt_composite) {
    float2 uv = cat_warp(in.uv, params.curvature);
    if (cat_off(uv)) return float4(0, 0, 0, 1);
    float2 t = float2(1.0 / SIZE.x, 0.0);
    float3 sharp = tex.sample(cat_linear, uv).rgb;
    float3 smear = (tex.sample(cat_linear, uv - t * 2.0).rgb + tex.sample(cat_linear, uv + t * 2.0).rgb + sharp) / 3.0;
    float l = cat_luma(sharp);
    float3 c = l + (smear - cat_luma(smear));
    c = cat_scan(c, uv.y * SIZE.y, params.scanline_weight * 0.8);
    return cat_done(c * cat_slot(in.position.xy, 0.2 + params.phosphor_glow * 0.4), params);
}

// Aged tube: rounded corners, darkening at the edges, a warm bias.
CAT(cat_crt_aged) {
    float2 uv = cat_warp(in.uv, params.curvature + 0.25);
    float2 e = abs(uv - 0.5) * 2.0;
    float corner = 1.0 - smoothstep(0.93, 1.0, pow(pow(e.x, 6.0) + pow(e.y, 6.0), 1.0 / 6.0));
    if (cat_off(uv)) return float4(0, 0, 0, 1);
    float3 c = tex.sample(cat_linear, uv).rgb * float3(1.03, 0.98, 0.88);
    c = cat_scan(c, uv.y * SIZE.y, params.scanline_weight);
    float vignette = 1.0 - dot(e, e) * 0.35 * (0.3 + params.phosphor_glow * 2.0);
    return cat_done(c * corner * vignette, params);
}

// Trinitron with its signature damper-wire shadow across the glass.
CAT(cat_crt_trinitron) {
    float3 c = PIX(0, 0);
    float d = fract(in.uv.y * SIZE.y) - 0.5;
    float line = 1.0 - params.scanline_weight * 0.8 * smoothstep(0.1, 0.5, abs(d));
    float wire = 1.0 - 0.18 * smoothstep(0.0015, 0.0, abs(in.uv.y - 0.33)) - 0.18 * smoothstep(0.0015, 0.0, abs(in.uv.y - 0.67));
    return cat_done(c * line * wire * cat_aperture(in.position.xy, 0.3 + params.phosphor_glow * 0.5), params);
}

// MARK: - LCD and handheld

// Pixel cell with a dark gap, the look of any passive-matrix handheld.
static inline float cat_cell(float2 uv, float2 size, float gap) {
    float2 f = abs(fract(uv * size) - 0.5);
    float edge = 0.5 - 0.4 * gap;
    return (1.0 - smoothstep(edge - 0.06, edge, f.x)) * (1.0 - smoothstep(edge - 0.06, edge, f.y));
}
static inline float3 cat_lcd(float3 tint, float3 ink, float l, float cell) { return mix(tint * 1.02, mix(tint, ink, 1.0 - l), cell); }

CAT(cat_lcd_grid) {
    float3 c = PIX(0, 0);
    return cat_done(mix(c * 0.25, c, cat_cell(in.uv, SIZE, params.scanline_weight)), params);
}

// DMG: four shades of pea green on a green screen.
CAT(cat_lcd_dmg) {
    float l = floor(cat_luma(PIX(0, 0)) * 3.0 + 0.5) / 3.0;
    return cat_done(cat_lcd(float3(0.61, 0.74, 0.06), float3(0.06, 0.22, 0.06), l, cat_cell(in.uv, SIZE, params.scanline_weight)), params);
}

// Pocket: grey-silver panel.
CAT(cat_lcd_pocket) {
    float l = floor(cat_luma(PIX(0, 0)) * 3.0 + 0.5) / 3.0;
    return cat_done(cat_lcd(float3(0.77, 0.81, 0.70), float3(0.12, 0.14, 0.11), l, cat_cell(in.uv, SIZE, params.scanline_weight)), params);
}

// Light: the backlit teal panel.
CAT(cat_lcd_light) {
    float l = floor(cat_luma(PIX(0, 0)) * 3.0 + 0.5) / 3.0;
    return cat_done(cat_lcd(float3(0.02, 0.84, 0.72), float3(0.0, 0.25, 0.25), l, cat_cell(in.uv, SIZE, params.scanline_weight)), params);
}

// GBA colour: its panel's darker, less saturated output, via a gamma and matrix fit to the panel.
CAT(cat_lcd_gba) {
    float3 c = pow(PIX(0, 0), float3(1.0 + params.phosphor_glow * 1.6));
    const float3x3 m = float3x3(float3(0.84, 0.09, 0.13), float3(0.18, 0.67, 0.28), float3(-0.02, 0.24, 0.59));
    float3 out = pow(saturate(m * c), float3(0.75));
    return cat_done(mix(out * 0.3, out, cat_cell(in.uv, SIZE, params.scanline_weight * 0.5)), params);
}

// NDS colour: milder than the GBA's, with its blue-leaning white.
CAT(cat_lcd_nds) {
    float3 c = pow(PIX(0, 0), float3(1.0 + params.phosphor_glow));
    const float3x3 m = float3x3(float3(0.90, 0.07, 0.08), float3(0.14, 0.77, 0.15), float3(-0.04, 0.16, 0.77));
    float3 out = pow(saturate(m * c), float3(0.85));
    return cat_done(mix(out * 0.4, out, cat_cell(in.uv, SIZE, params.scanline_weight * 0.4)), params);
}

// RGB sub-pixel columns at emulated-pixel scale.
CAT(cat_lcd_subpixel) {
    float3 c = PIX(0, 0);
    float x = fract(in.uv.x * SIZE.x) * 3.0;
    float3 m = float3(x < 1.0, x >= 1.0 && x < 2.0, x >= 2.0);
    return cat_done(c * mix(float3(1.0), m * 2.6 + 0.12, params.scanline_weight) * (1.0 + params.phosphor_glow * 0.4), params);
}

// Segment-style vacuum-fluorescent glow on black.
CAT(cat_lcd_vfd) {
    float l = cat_luma(PIX(0, 0));
    float on = step(0.35, l) * cat_cell(in.uv, SIZE, params.scanline_weight);
    float halo = l * (1.0 - cat_cell(in.uv, SIZE, 0.6)) * params.phosphor_glow;
    return cat_done(float3(0.18, 0.95, 0.85) * (on + halo), params);
}

// MARK: - Scanlines

CAT(cat_scan_classic) {
    float d = fract(in.uv.y * SIZE.y);
    return cat_done(PIX(0, 0) * (d < 0.5 ? 1.0 : 1.0 - params.scanline_weight), params);
}

CAT(cat_scan_soft) {
    float wave = 0.5 + 0.5 * cos(2.0 * M_PI_F * in.uv.y * SIZE.y);
    return cat_done(PIX(0, 0) * (1.0 - params.scanline_weight * wave * 0.7), params);
}

CAT(cat_scan_thick) {
    float d = abs(fract(in.uv.y * SIZE.y) - 0.5);
    return cat_done(PIX(0, 0) * (1.0 - params.scanline_weight * smoothstep(0.08, 0.2, d)), params);
}

// One field lit per frame.
CAT(cat_scan_interlace) {
    float field = floor(fmod(params.time * 60.0, 2.0));
    float line = fmod(floor(in.uv.y * SIZE.y) + field, 2.0);
    return cat_done(PIX(0, 0) * (1.0 - params.scanline_weight * line), params);
}

// Two scanlines per emulated row, so bright rows stay bright.
CAT(cat_scan_double) {
    float wave = abs(sin(2.0 * M_PI_F * in.uv.y * SIZE.y));
    return cat_done(PIX(0, 0) * (1.0 - params.scanline_weight * (1.0 - wave)), params);
}

// Beam width follows brightness, so highlights fill the gap.
CAT(cat_scan_dynamic) {
    float3 c = PIX(0, 0);
    return cat_done(cat_scan(c, in.uv.y * SIZE.y, params.scanline_weight), params);
}

// MARK: - Upscaling

// Scale2x (AdvMAME2x), Andrea Mazzoleni's published rule.
static inline float3 cat_scale2x(float3 e, float3 b, float3 d, float3 f, float3 h, float2 frac) {
    float3 result = e;
    if (any(b != h) && any(d != f)) {
        bool left = frac.x < 0.5, top = frac.y < 0.5;
        if (top && left && all(d == b)) result = d;
        if (top && !left && all(b == f)) result = f;
        if (!top && left && all(d == h)) result = d;
        if (!top && !left && all(h == f)) result = f;
    }
    return result;
}
CAT(cat_scale2x) {
    return cat_done(cat_scale2x(PIX(0, 0), PIX(0, -1), PIX(-1, 0), PIX(1, 0), PIX(0, 1), fract(in.uv * SIZE)), params);
}

// Scale3x: the same rule in nine cells.
CAT(cat_scale3x) {
    float3 a = PIX(-1, -1), b = PIX(0, -1), c = PIX(1, -1), d = PIX(-1, 0), e = PIX(0, 0), f = PIX(1, 0), g = PIX(-1, 1), h = PIX(0, 1), i = PIX(1, 1);
    float2 fr = floor(fract(in.uv * SIZE) * 3.0);
    float3 out = e;
    if (any(b != h) && any(d != f)) {
        int k = int(fr.y) * 3 + int(fr.x);
        bool db = all(d == b), bf = all(b == f), dh = all(d == h), hf = all(h == f);
        if (k == 0 && db) out = d;
        if (k == 1 && ((db && any(e != c)) || (bf && any(e != a)))) out = b;
        if (k == 2 && bf) out = f;
        if (k == 3 && ((db && any(e != g)) || (dh && any(e != a)))) out = d;
        if (k == 5 && ((bf && any(e != i)) || (hf && any(e != c)))) out = f;
        if (k == 6 && dh) out = d;
        if (k == 7 && ((dh && any(e != i)) || (hf && any(e != g)))) out = h;
        if (k == 8 && hf) out = f;
    }
    return cat_done(out, params);
}

// Eagle: a corner takes the colour its three outer neighbours agree on.
CAT(cat_eagle) {
    float2 fr = fract(in.uv * SIZE);
    float2 dir = float2(fr.x < 0.5 ? -1.0 : 1.0, fr.y < 0.5 ? -1.0 : 1.0);
    float3 e = PIX(0, 0), a = PIX(dir.x, 0), b = PIX(0, dir.y), c = PIX(dir.x, dir.y);
    return cat_done(all(a == b) && all(b == c) ? c : e, params);
}

static inline float cat_diff(float3 a, float3 b) {
    float3 d = abs(a - b);
    return dot(d, float3(0.48, 0.48, 0.20)) * 3.0;
}

// xBR-style corner blend: compare the two diagonal edge weights, then blend the corner along the winning edge.
static inline float3 cat_xbr(texture2d<float> tex, float2 uv, float2 size, float slope, float softness) {
    float2 fr = fract(uv * size) - 0.5;
    float2 dx = float2(fr.x < 0.0 ? -1.0 : 1.0, 0.0), dy = float2(0.0, fr.y < 0.0 ? -1.0 : 1.0);
    float3 e = cat_tap(tex, uv, size, float2(0)), f = cat_tap(tex, uv, size, dx), h = cat_tap(tex, uv, size, dy), i = cat_tap(tex, uv, size, dx + dy);
    float3 b = cat_tap(tex, uv, size, -dy), d = cat_tap(tex, uv, size, -dx), c = cat_tap(tex, uv, size, dx - dy), g = cat_tap(tex, uv, size, dy - dx);
    float3 f4 = cat_tap(tex, uv, size, dx * 2.0), h5 = cat_tap(tex, uv, size, dy * 2.0), i4 = cat_tap(tex, uv, size, dx * 2.0 + dy), i5 = cat_tap(tex, uv, size, dx + dy * 2.0);
    float edge1 = cat_diff(e, c) + cat_diff(e, g) + cat_diff(i, f4) + cat_diff(i, h5) + 4.0 * cat_diff(h, f);
    float edge2 = cat_diff(h, d) + cat_diff(h, i5) + cat_diff(f, i4) + cat_diff(f, b) + 4.0 * cat_diff(e, i);
    if (edge1 >= edge2) return e;
    float2 p = abs(fr);
    float along = (p.x + p.y * slope) / (1.0 + slope);
    float t = smoothstep(0.34 - softness, 0.34 + softness, along);
    return mix(e, cat_diff(e, f) <= cat_diff(e, h) ? f : h, t);
}
CAT(cat_xbr) { return cat_done(cat_xbr(tex, in.uv, SIZE, 1.0, 0.02 + params.phosphor_glow * 0.2), params); }
CAT(cat_xbr_shallow) { return cat_done(cat_xbr(tex, in.uv, SIZE, 0.5, 0.05 + params.phosphor_glow * 0.2), params); }

// xBRZ-style: a corner is rewritten only where one diagonal clearly dominates, and strokes stay intact.
CAT(cat_xbrz) {
    float2 size = SIZE;
    float2 fr = fract(in.uv * size) - 0.5;
    float2 dx = float2(fr.x < 0.0 ? -1.0 : 1.0, 0.0), dy = float2(0.0, fr.y < 0.0 ? -1.0 : 1.0);
    float3 e = PIX(0, 0), f = cat_tap(tex, in.uv, size, dx), h = cat_tap(tex, in.uv, size, dy), i = cat_tap(tex, in.uv, size, dx + dy);
    float3 b = cat_tap(tex, in.uv, size, -dy), d = cat_tap(tex, in.uv, size, -dx), c = cat_tap(tex, in.uv, size, dx - dy), g = cat_tap(tex, in.uv, size, dy - dx);
    float across = cat_diff(f, h) * 4.0 + cat_diff(e, c) + cat_diff(e, g);
    float along = cat_diff(e, i) * 4.0 + cat_diff(f, b) + cat_diff(h, d);
    float dominance = 1.5 + params.phosphor_glow * 2.0;
    if (across * dominance >= along || cat_diff(e, f) < 0.05 && cat_diff(e, h) < 0.05) return cat_done(e, params);
    float t = smoothstep(0.42, 0.58, abs(fr.x) + abs(fr.y));
    return cat_done(mix(e, cat_diff(e, f) <= cat_diff(e, h) ? f : h, t), params);
}

// ScaleFX-style: edges are confirmed by how far each corner pair continues in a 3x3 neighbourhood.
CAT(cat_scalefx) {
    float2 size = SIZE;
    float2 fr = fract(in.uv * size) - 0.5;
    float2 dx = float2(fr.x < 0.0 ? -1.0 : 1.0, 0.0), dy = float2(0.0, fr.y < 0.0 ? -1.0 : 1.0);
    float3 e = PIX(0, 0), f = cat_tap(tex, in.uv, size, dx), h = cat_tap(tex, in.uv, size, dy), i = cat_tap(tex, in.uv, size, dx + dy);
    float3 f2 = cat_tap(tex, in.uv, size, dx - dy), h2 = cat_tap(tex, in.uv, size, dy - dx);
    float thresh = 0.15 + params.phosphor_glow * 0.5;
    bool fh = cat_diff(f, h) < thresh;
    bool cont = cat_diff(f, f2) < thresh || cat_diff(h, h2) < thresh;
    if (!fh || !cont || cat_diff(e, i) < thresh) return cat_done(e, params);
    float t = smoothstep(0.40, 0.56, abs(fr.x) + abs(fr.y));
    return cat_done(mix(e, (f + h) * 0.5, t), params);
}

// 2xSaI-style: pairs of equal neighbours pick the sub-pixel, unequal ones average.
CAT(cat_sai) {
    float2 fr = fract(in.uv * SIZE);
    float3 a = PIX(0, 0), b = PIX(1, 0), c = PIX(0, 1), d = PIX(1, 1);
    float3 result = a;
    bool ad = all(a == d), bc = all(b == c);
    if (ad && !bc) result = a;
    else if (bc && !ad) result = b;
    else if (!ad && !bc) result = mix(mix(a, b, step(0.5, fr.x)), mix(c, d, step(0.5, fr.x)), step(0.5, fr.y));
    return cat_done(result, params);
}

// HQ-style: blend each neighbour in only when it is close in luma and chroma, no lookup table.
CAT(cat_hq) {
    float2 fr = fract(in.uv * SIZE) - 0.5;
    float3 e = PIX(0, 0), f = PIX(sign(fr.x), 0), h = PIX(0, sign(fr.y));
    float limit = 0.2 + params.phosphor_glow;
    float ax = cat_diff(e, f) < limit ? smoothstep(0.1, 0.5, abs(fr.x)) * 0.5 : 0.0;
    float ay = cat_diff(e, h) < limit ? smoothstep(0.1, 0.5, abs(fr.y)) * 0.5 : 0.0;
    return cat_done(mix(mix(e, f, ax), h, ay), params);
}

static inline float cat_lanczos(float x) {
    if (x == 0.0) return 1.0;
    if (abs(x) >= 2.0) return 0.0;
    float pix = M_PI_F * x;
    return 2.0 * sin(pix) * sin(pix * 0.5) / (pix * pix);
}
// Lanczos2, a two-lobe windowed sinc.
CAT(cat_lanczos2) {
    float2 size = SIZE, p = in.uv * size - 0.5, base = floor(p), f = p - base;
    float3 sum = float3(0); float total = 0.0;
    for (int y = -1; y <= 2; ++y) for (int x = -1; x <= 2; ++x) {
        float w = cat_lanczos(float(x) - f.x) * cat_lanczos(float(y) - f.y);
        sum += tex.sample(cat_near, (base + float2(x, y) + 0.5) / size).rgb * w;
        total += w;
    }
    return cat_done(sum / max(total, 0.001), params);
}

// Cubic convolution with the Catmull-Rom and Mitchell-Netravali parameters.
static inline float cat_bc(float x, float B, float C) {
    x = abs(x);
    if (x < 1.0) return ((12.0 - 9.0 * B - 6.0 * C) * x * x * x + (-18.0 + 12.0 * B + 6.0 * C) * x * x + (6.0 - 2.0 * B)) / 6.0;
    if (x < 2.0) return ((-B - 6.0 * C) * x * x * x + (6.0 * B + 30.0 * C) * x * x + (-12.0 * B - 48.0 * C) * x + (8.0 * B + 24.0 * C)) / 6.0;
    return 0.0;
}
static inline float3 cat_cubic(texture2d<float> tex, float2 uv, float2 size, float B, float C) {
    float2 p = uv * size - 0.5, base = floor(p), f = p - base;
    float3 sum = float3(0); float total = 0.0;
    for (int y = -1; y <= 2; ++y) for (int x = -1; x <= 2; ++x) {
        float w = cat_bc(float(x) - f.x, B, C) * cat_bc(float(y) - f.y, B, C);
        sum += tex.sample(cat_near, (base + float2(x, y) + 0.5) / size).rgb * w;
        total += w;
    }
    return sum / max(total, 0.001);
}
CAT(cat_catmull) { return cat_done(cat_cubic(tex, in.uv, SIZE, 0.0, 0.5), params); }
CAT(cat_mitchell) { return cat_done(cat_cubic(tex, in.uv, SIZE, 1.0 / 3.0, 1.0 / 3.0), params); }

// Iñigo Quilez's smoothstep-remapped bilinear for crisp soft pixels.
CAT(cat_smoothstep) {
    float2 size = SIZE, p = in.uv * size + 0.5, i = floor(p), f = p - i;
    f = mix(f, f * f * f * (f * (f * 6.0 - 15.0) + 10.0), 0.5 + params.scanline_weight * 0.5);
    return cat_done(tex.sample(cat_linear, (i + f - 0.5) / size).rgb, params);
}

// Area-weighted nearest: each screen pixel averages the source it covers.
CAT(cat_pixellate) {
    float2 size = SIZE, range = 0.5 * size / float2(params.viewport_w, params.viewport_h);
    float2 pos = in.uv * size;
    float2 lo = floor(pos - range), hi = floor(pos + range);
    float2 t = saturate((hi + 0.5 - pos + range) / max(2.0 * range, 0.001));
    float3 c = mix(mix(tex.sample(cat_near, (hi + 0.5) / size).rgb, tex.sample(cat_near, (float2(lo.x, hi.y) + 0.5) / size).rgb, t.x),
                   mix(tex.sample(cat_near, (float2(hi.x, lo.y) + 0.5) / size).rgb, tex.sample(cat_near, (lo + 0.5) / size).rgb, t.x), t.y);
    return cat_done(c, params);
}

// MARK: - Smoothing

static inline float3 cat_blur(texture2d<float> tex, float2 uv, float2 t) {
    float3 c = tex.sample(cat_linear, uv).rgb * 0.25;
    c += (tex.sample(cat_linear, uv + float2(t.x, 0)).rgb + tex.sample(cat_linear, uv - float2(t.x, 0)).rgb
        + tex.sample(cat_linear, uv + float2(0, t.y)).rgb + tex.sample(cat_linear, uv - float2(0, t.y)).rgb) * 0.125;
    c += (tex.sample(cat_linear, uv + t).rgb + tex.sample(cat_linear, uv - t).rgb
        + tex.sample(cat_linear, uv + float2(t.x, -t.y)).rgb + tex.sample(cat_linear, uv + float2(-t.x, t.y)).rgb) * 0.0625;
    return c;
}
CAT(cat_gaussian) { return cat_done(cat_blur(tex, in.uv, (0.5 + params.scanline_weight * 1.5) / SIZE), params); }

// Bilateral: smooths within flat areas, stops at edges.
CAT(cat_bilateral) {
    float2 size = SIZE;
    float3 e = PIX(0, 0), sum = float3(0); float total = 0.0;
    float sigma = 0.02 + params.scanline_weight * 0.3;
    for (int y = -2; y <= 2; ++y) for (int x = -2; x <= 2; ++x) {
        float3 c = cat_tap(tex, in.uv, size, float2(x, y));
        float3 d = c - e;
        float w = exp(-dot(d, d) / sigma) * exp(-float(x * x + y * y) / 6.0);
        sum += c * w; total += w;
    }
    return cat_done(sum / total, params);
}

// Kuwahara: each pixel takes the mean of whichever quadrant around it varies least. Paint-like.
CAT(cat_kuwahara) {
    float2 size = SIZE;
    float3 best = float3(0); float least = 1e6;
    const int2 corners[4] = {int2(-2, -2), int2(0, -2), int2(-2, 0), int2(0, 0)};
    for (int q = 0; q < 4; ++q) {
        float3 sum = float3(0), squares = float3(0);
        for (int y = 0; y <= 2; ++y) for (int x = 0; x <= 2; ++x) {
            float3 c = cat_tap(tex, in.uv, size, float2(corners[q] + int2(x, y)));
            sum += c; squares += c * c;
        }
        float3 mean = sum / 9.0;
        float v = dot(squares / 9.0 - mean * mean, float3(1));
        if (v < least) { least = v; best = mean; }
    }
    return cat_done(best, params);
}

// FXAA in the spirit of Timothy Lottes's published console algorithm: blend along the local luma gradient.
CAT(cat_fxaa) {
    float2 t = 1.0 / SIZE;
    float3 rgbNW = tex.sample(cat_linear, in.uv + t * float2(-1, -1)).rgb, rgbNE = tex.sample(cat_linear, in.uv + t * float2(1, -1)).rgb;
    float3 rgbSW = tex.sample(cat_linear, in.uv + t * float2(-1, 1)).rgb, rgbSE = tex.sample(cat_linear, in.uv + t * float2(1, 1)).rgb;
    float3 rgbM = tex.sample(cat_linear, in.uv).rgb;
    float lNW = cat_luma(rgbNW), lNE = cat_luma(rgbNE), lSW = cat_luma(rgbSW), lSE = cat_luma(rgbSE), lM = cat_luma(rgbM);
    float lo = min(lM, min(min(lNW, lNE), min(lSW, lSE))), hi = max(lM, max(max(lNW, lNE), max(lSW, lSE)));
    float2 dir = float2(-((lNW + lNE) - (lSW + lSE)), (lNW + lSW) - (lNE + lSE));
    float reduce = max((lNW + lNE + lSW + lSE) * 0.03, 1.0 / 128.0);
    float rcp = 1.0 / (min(abs(dir.x), abs(dir.y)) + reduce);
    dir = clamp(dir * rcp, float2(-8), float2(8)) * t;
    float3 a = 0.5 * (tex.sample(cat_linear, in.uv + dir * (1.0 / 3.0 - 0.5)).rgb + tex.sample(cat_linear, in.uv + dir * (2.0 / 3.0 - 0.5)).rgb);
    float3 b = a * 0.5 + 0.25 * (tex.sample(cat_linear, in.uv - dir * 0.5).rgb + tex.sample(cat_linear, in.uv + dir * 0.5).rgb);
    float l = cat_luma(b);
    return cat_done(l < lo || l > hi ? a : b, params);
}

// Soft Glow: a screen blend of a wide blur.
CAT(cat_glow) {
    float3 c = PIX(0, 0);
    float3 b = cat_blur(tex, in.uv, 2.5 / SIZE);
    return cat_done(1.0 - (1.0 - c) * (1.0 - b * (0.3 + params.scanline_weight * 0.7)), params);
}

// MARK: - Colour

static inline float3 cat_yiq(float3 c) { return float3(dot(c, float3(0.299, 0.587, 0.114)), dot(c, float3(0.596, -0.274, -0.322)), dot(c, float3(0.211, -0.523, 0.312))); }
static inline float3 cat_rgb(float3 c) { return float3(c.x + 0.956 * c.y + 0.621 * c.z, c.x - 0.272 * c.y - 0.647 * c.z, c.x - 1.106 * c.y + 1.703 * c.z); }

// NTSC composite: chroma band-limited, luma dot-crawl from a subcarrier at 3.58 MHz of the line.
CAT(cat_ntsc) {
    float2 t = float2(1.0 / SIZE.x, 0.0);
    float3 yiq = float3(0.0);
    for (int i = -3; i <= 3; ++i) yiq += cat_yiq(tex.sample(cat_linear, in.uv + t * float(i) * (0.6 + params.scanline_weight)).rgb);
    yiq /= 7.0;
    float3 centre = cat_yiq(tex.sample(cat_linear, in.uv).rgb);
    float crawl = sin(in.uv.x * SIZE.x * 2.0 * M_PI_F * 0.5 + floor(in.uv.y * SIZE.y) * M_PI_F + params.time * 12.0) * params.phosphor_glow * 0.1;
    return cat_done(cat_rgb(float3(centre.x + crawl * centre.y, yiq.y, yiq.z)), params);
}

// S-Video: separate luma, so no crawl, chroma still soft.
CAT(cat_svideo) {
    float2 t = float2(1.0 / SIZE.x, 0.0);
    float3 yiq = float3(0.0);
    for (int i = -2; i <= 2; ++i) yiq += cat_yiq(tex.sample(cat_linear, in.uv + t * float(i) * (0.4 + params.scanline_weight * 0.6)).rgb);
    yiq /= 5.0;
    return cat_done(cat_rgb(float3(cat_yiq(tex.sample(cat_linear, in.uv).rgb).x, yiq.y, yiq.z)), params);
}

// PAL: vertical chroma averaging across two lines, as a delay line does.
CAT(cat_pal) {
    float2 t = float2(0.0, 1.0 / SIZE.y);
    float3 here = cat_yiq(tex.sample(s, in.uv).rgb), up = cat_yiq(tex.sample(s, in.uv - t).rgb);
    return cat_done(cat_rgb(float3(here.x, mix(here.y, up.y, 0.5 * params.scanline_weight * 2.0), mix(here.z, up.z, 0.5 * params.scanline_weight * 2.0))), params);
}

CAT(cat_sepia) {
    float3 c = tex.sample(s, in.uv).rgb;
    float3 tone = float3(dot(c, float3(0.393, 0.769, 0.189)), dot(c, float3(0.349, 0.686, 0.168)), dot(c, float3(0.272, 0.534, 0.131)));
    return cat_done(mix(c, tone, params.scanline_weight * 2.0), params);
}

CAT(cat_grey) {
    float3 c = tex.sample(s, in.uv).rgb;
    return cat_done(mix(c, float3(cat_luma(c)), saturate(params.scanline_weight * 2.0)), params);
}

// Vibrance: lifts muted colours more than saturated ones.
CAT(cat_vibrance) {
    float3 c = tex.sample(s, in.uv).rgb;
    float l = cat_luma(c), sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    return cat_done(mix(float3(l), c, 1.0 + params.scanline_weight * 1.5 * (1.0 - sat)), params);
}

// Gamma lift for dim screens and dark games.
CAT(cat_gamma) {
    float3 c = tex.sample(s, in.uv).rgb;
    return cat_done(pow(c, float3(1.0 / (0.6 + params.scanline_weight * 1.6))), params);
}

// Night: strips blue, dims, for play in the dark.
CAT(cat_night) {
    float3 c = tex.sample(s, in.uv).rgb;
    return cat_done(float3(c.r, c.g * 0.7, c.b * 0.25) * (0.5 + params.scanline_weight), params);
}

// Daltonize for red-green colour blindness: moves lost contrast into blue (Fidaner et al.).
CAT(cat_daltonize) {
    float3 c = tex.sample(s, in.uv).rgb;
    float3 seen = float3(0.567 * c.r + 0.433 * c.g, 0.558 * c.r + 0.442 * c.g, 0.242 * c.g + 0.758 * c.b);
    float3 lost = c - seen;
    float3 shift = float3(0.0, lost.r * 0.7 + lost.g, lost.r * 0.7 + lost.b);
    return cat_done(c + shift * (0.5 + params.scanline_weight), params);
}

// Quantise to a fixed palette by nearest colour.
#define PALETTE_FRAGMENT(name, count, ...) CAT(name) { \
    const float3 pal[count] = { __VA_ARGS__ }; \
    float3 c = tex.sample(cat_near, in.uv).rgb, best = pal[0]; float least = 9.0; \
    for (int i = 0; i < count; ++i) { float3 d = c - pal[i]; float v = dot(d, d); if (v < least) { least = v; best = pal[i]; } } \
    return cat_done(mix(c, best, saturate(params.scanline_weight * 2.0)), params); }

PALETTE_FRAGMENT(cat_pal_gb, 4, float3(0.06, 0.22, 0.06), float3(0.19, 0.38, 0.19), float3(0.55, 0.67, 0.06), float3(0.61, 0.74, 0.06))
PALETTE_FRAGMENT(cat_pal_cga, 4, float3(0.0), float3(0.33, 1.0, 1.0), float3(1.0, 0.33, 1.0), float3(1.0))
PALETTE_FRAGMENT(cat_pal_ega, 8, float3(0.0), float3(0.0, 0.0, 0.67), float3(0.0, 0.67, 0.0), float3(0.67, 0.0, 0.0), float3(0.67, 0.67, 0.0), float3(0.67, 0.0, 0.67), float3(0.0, 0.67, 0.67), float3(1.0))
PALETTE_FRAGMENT(cat_pal_c64, 8, float3(0.0), float3(1.0), float3(0.53, 0.0, 0.0), float3(0.67, 1.0, 0.93), float3(0.8, 0.27, 0.8), float3(0.0, 0.8, 0.33), float3(0.0, 0.0, 0.67), float3(0.93, 0.93, 0.47))

// MARK: - Sharpen

CAT(cat_unsharp) {
    float3 c = PIX(0, 0);
    float3 b = cat_blur(tex, in.uv, 1.0 / SIZE);
    return cat_done(c + (c - b) * params.scanline_weight * 3.0, params);
}

// Contrast-adaptive sharpening, after AMD's published CAS description: the kernel weakens near clipping.
CAT(cat_cas) {
    float3 c = PIX(0, 0), n = PIX(0, -1), s2 = PIX(0, 1), w = PIX(-1, 0), e = PIX(1, 0);
    float3 lo = min(c, min(n, min(s2, min(w, e)))), hi = max(c, max(n, max(s2, max(w, e))));
    float3 amp = sqrt(saturate(min(lo, 1.0 - hi) / max(hi, float3(0.001))));
    float3 weight = -amp / mix(8.0, 5.0, params.scanline_weight);
    return cat_done((c + (n + s2 + w + e) * weight) / (1.0 + 4.0 * weight), params);
}

// Sharpen the luma only, so colour edges do not fringe.
CAT(cat_luma_sharpen) {
    float3 c = PIX(0, 0);
    float l = cat_luma(c), blur = cat_luma(cat_blur(tex, in.uv, 1.0 / SIZE));
    return cat_done(c + (l - blur) * params.scanline_weight * 3.0, params);
}

// Darken detected edges, like a pen line around sprites.
CAT(cat_edge_ink) {
    float3 c = PIX(0, 0);
    float e = cat_diff(c, PIX(1, 0)) + cat_diff(c, PIX(-1, 0)) + cat_diff(c, PIX(0, 1)) + cat_diff(c, PIX(0, -1));
    return cat_done(c * (1.0 - smoothstep(0.1, 1.0, e) * params.scanline_weight * 1.6), params);
}

// MARK: - Retro looks

// Video tape: chroma bleed, tracking wobble and a noise band.
CAT(cat_vhs) {
    float band = fmod(params.time * 0.2, 1.3) - 0.15;
    float wobble = sin(in.uv.y * 90.0 + params.time * 3.0) * 0.0015 * (1.0 + params.scanline_weight * 3.0);
    float2 uv = in.uv + float2(wobble + smoothstep(0.04, 0.0, abs(in.uv.y - band)) * 0.02, 0.0);
    float3 c = tex.sample(cat_linear, uv).rgb;
    float3 bleed = tex.sample(cat_linear, uv - float2(4.0 / SIZE.x, 0.0)).rgb;
    float3 yiq = float3(cat_yiq(c).x, cat_yiq(bleed).y, cat_yiq(bleed).z);
    float noise = (cat_rand(floor(in.position.xy * 0.5) + params.time) - 0.5) * (0.04 + params.phosphor_glow * 0.25);
    return cat_done(cat_rgb(yiq) + noise, params);
}

CAT(cat_posterize) {
    float levels = 2.0 + floor((1.0 - params.scanline_weight) * 12.0);
    return cat_done(floor(tex.sample(s, in.uv).rgb * levels + 0.5) / levels, params);
}

static inline float cat_bayer(float2 p) {
    const int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
    int2 i = int2(fmod(floor(p), 4.0));
    return (float(m[i.y * 4 + i.x]) + 0.5) / 16.0 - 0.5;
}
CAT(cat_dither_mono) {
    float2 p = in.position.xy / max(1.0, floor(params.viewport_h / SIZE.y));
    float v = cat_luma(tex.sample(cat_near, in.uv).rgb) + cat_bayer(p) * (0.5 + params.scanline_weight);
    return cat_done(float3(v > 0.5), params);
}
CAT(cat_dither_colour) {
    float2 p = in.position.xy / max(1.0, floor(params.viewport_h / SIZE.y));
    float levels = 3.0;
    float3 v = tex.sample(cat_near, in.uv).rgb + cat_bayer(p) * (0.1 + params.scanline_weight * 0.5);
    return cat_done(floor(v * levels + 0.5) / levels, params);
}

// Newsprint: dots grow with darkness on a rotated grid.
CAT(cat_halftone) {
    float scale = 4.0 + (1.0 - params.scanline_weight) * 12.0;
    float2x2 r = float2x2(float2(0.707, 0.707), float2(-0.707, 0.707));
    float2 p = (r * in.position.xy) / scale;
    float l = cat_luma(tex.sample(s, in.uv).rgb);
    float dot2 = length(fract(p) - 0.5);
    return cat_done(float3(smoothstep(0.02, -0.02, dot2 - sqrt(1.0 - l) * 0.65) < 0.5), params);
}

// Stitches: a pixel becomes an X on cloth.
CAT(cat_cross_stitch) {
    float2 f = fract(in.uv * SIZE) - 0.5;
    float3 c = PIX(0, 0);
    float d = min(abs(f.x + f.y), abs(f.x - f.y));
    return cat_done(mix(float3(0.92, 0.88, 0.8), c, 1.0 - smoothstep(0.08, 0.18, d)), params);
}

// Chunky mosaic.
CAT(cat_mosaic) {
    float2 size = SIZE / (2.0 + floor(params.scanline_weight * 14.0));
    return cat_done(tex.sample(cat_near, (floor(in.uv * size) + 0.5) / size).rgb, params);
}

// False-colour heat map of brightness.
CAT(cat_thermal) {
    float l = cat_luma(tex.sample(s, in.uv).rgb);
    float3 c = saturate(float3(l * 3.0 - 1.0, l * 3.0 - 0.1 - abs(l * 3.0 - 1.5), 1.2 - l * 3.0));
    return cat_done(c, params);
}

// Green phosphor oscilloscope.
CAT(cat_scope) {
    float l = cat_luma(PIX(0, 0));
    float beam = cat_beam(in.uv.y * SIZE.y, l, 2.0 + params.scanline_weight * 3.0);
    return cat_done(float3(0.1, 1.0, 0.25) * l * beam + float3(0.0, 0.12, 0.03) * params.phosphor_glow, params);
}

// Amber phosphor terminal.
CAT(cat_amber) {
    float l = cat_luma(PIX(0, 0));
    return cat_done(float3(1.0, 0.65, 0.1) * cat_scan(float3(l), in.uv.y * SIZE.y, params.scanline_weight), params);
}

// Blueprint: inverted edges on blue paper.
CAT(cat_blueprint) {
    float3 c = PIX(0, 0);
    float e = cat_diff(c, PIX(1, 0)) + cat_diff(c, PIX(0, 1));
    return cat_done(mix(float3(0.07, 0.2, 0.45), float3(0.9), smoothstep(0.05, 0.3 + params.scanline_weight, e)), params);
}

// Gameboy Camera: 1-bit Bayer pattern in four shades of grey.
CAT(cat_gbcamera) {
    float2 p = in.position.xy / max(1.0, floor(params.viewport_h / SIZE.y));
    float v = cat_luma(tex.sample(cat_near, in.uv).rgb) + cat_bayer(p) * (0.2 + params.scanline_weight * 0.6);
    return cat_done(float3(floor(saturate(v) * 3.0 + 0.5) / 3.0), params);
}

// Cinema bars and grain over a lifted, warm grade.
CAT(cat_cinema) {
    float bar = step(0.1, in.uv.y) * step(in.uv.y, 0.9);
    float3 c = tex.sample(s, in.uv).rgb * float3(1.05, 1.0, 0.92);
    float grain = (cat_rand(floor(in.position.xy) + params.time) - 0.5) * (0.02 + params.scanline_weight * 0.12);
    return cat_done((pow(c, float3(0.92)) + grain) * bar, params);
}
