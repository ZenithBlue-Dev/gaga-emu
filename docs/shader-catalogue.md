# Shader catalogue

Every filter in `Sources/Metal/CatalogShaders.metal` is original Metal Shading Language written in-house from the
published description of the technique named below. None is ported from another shader, so none needs a notice in
`Licences/notices.json`; the licence is the project's own. Upscalers marked "Style" follow the published idea and are
not exact reproductions. Three older filters are ports with their own licences, recorded in docs/05 section 5.

| Id | Name | Category | Basis (published description) | Licence |
|---|---|---|---|---|
| cat-crt-aperture | Aperture Grille | CRT | Trinitron-style stripe phosphor layout; gaussian beam scanlines | In-house |
| cat-crt-slot | Slot Mask | CRT | Staggered slot-mask phosphor pattern | In-house |
| cat-crt-shadow | Shadow Mask | CRT | Round phosphor triad in a staggered grid | In-house |
| cat-crt-pvm | Broadcast Monitor | CRT | Sharp pixels, fine scanlines of a studio monitor | In-house |
| cat-crt-consumer | Living Room TV | CRT | Horizontal beam spread, bloom, barrel distortion | In-house |
| cat-crt-arcade | Arcade Cabinet | CRT | Luma-dependent beam width | In-house |
| cat-crt-vga | VGA Monitor | CRT | Double-scan line doubling, dot pitch | In-house |
| cat-crt-composite | Composite TV | CRT | Luma/chroma separation at a band limit | In-house |
| cat-crt-aged | Aged Tube | CRT | Rounded-corner vignette, superellipse edge | In-house |
| cat-crt-trinitron | Damper Wire Tube | CRT | Trinitron damper-wire shadows | In-house |
| cat-lcd-grid | Pixel Grid | LCD and Handheld | Passive-matrix pixel gap | In-house |
| cat-lcd-dmg | Game Boy Green | LCD and Handheld | DMG four-shade panel tint | In-house |
| cat-lcd-pocket | Pocket Grey | LCD and Handheld | Game Boy Pocket panel tint | In-house |
| cat-lcd-light | Backlit Teal | LCD and Handheld | Game Boy Light backlit tint | In-house |
| cat-lcd-gba | GBA Panel Colour | LCD and Handheld | Display gamma with a fitted colour matrix | In-house |
| cat-lcd-nds | DS Panel Colour | LCD and Handheld | Display gamma with a fitted colour matrix | In-house |
| cat-lcd-subpixel | RGB Subpixels | LCD and Handheld | Column RGB subpixel layout | In-house |
| cat-lcd-vfd | Fluorescent Display | LCD and Handheld | Vacuum-fluorescent segment glow | In-house |
| cat-scan-classic | Hard Scanlines | Scanlines | Alternating dark line | In-house |
| cat-scan-soft | Soft Scanlines | Scanlines | Cosine brightness modulation | In-house |
| cat-scan-thick | Thick Scanlines | Scanlines | Thin beam, wide gap | In-house |
| cat-scan-interlace | Interlaced | Scanlines | Alternate field per frame | In-house |
| cat-scan-double | Double Lines | Scanlines | Two lines per row | In-house |
| cat-scan-dynamic | Dynamic Beam | Scanlines | Luma-dependent beam width | In-house |
| cat-scale2x | Scale2x | Upscaling | AdvMAME2x / Scale2x rule, A. Mazzoleni | In-house |
| cat-scale3x | Scale3x | Upscaling | Scale3x rule, A. Mazzoleni | In-house |
| cat-eagle | Eagle | Upscaling | Eagle corner rule | In-house |
| cat-xbr | xBR Style | Upscaling | xBR edge weighting as Hyllian described it | In-house |
| cat-xbr-shallow | xBR Shallow Style | Upscaling | Same, with a shallow slope | In-house |
| cat-xbrz | xBRZ Style | Upscaling | Dominant-gradient corner rule, in the manner of xBRZ | In-house |
| cat-scalefx | ScaleFX Style | Upscaling | Edge continuation in a 3x3 neighbourhood | In-house |
| cat-sai | 2xSaI Style | Upscaling | Pair-equality rule of 2xSaI | In-house |
| cat-hq | HQ Style | Upscaling | Threshold neighbour blending, no lookup table | In-house |
| cat-lanczos2 | Lanczos2 | Upscaling | Lanczos 2-lobe sinc | In-house |
| cat-catmull | Catmull-Rom | Upscaling | Cubic convolution, B=0 C=0.5 | In-house |
| cat-mitchell | Mitchell | Upscaling | Mitchell-Netravali, B=C=1/3 | In-house |
| cat-smoothstep | Soft Pixels | Upscaling | Smootherstep-remapped bilinear, per I. Quilez | In-house |
| cat-pixellate | Clean Pixels | Upscaling | Area sampling | In-house |
| cat-gaussian | Gaussian Blur | Smoothing | Binomial 3x3 kernel | In-house |
| cat-bilateral | Edge-Keeping Blur | Smoothing | Bilateral filter, Tomasi and Manduchi | In-house |
| cat-kuwahara | Kuwahara Paint | Smoothing | Kuwahara filter | In-house |
| cat-fxaa | FXAA | Smoothing | FXAA described by T. Lottes | In-house |
| cat-glow | Soft Glow | Smoothing | Screen blend of a blur | In-house |
| cat-ntsc | NTSC Composite | Colour | YIQ band limiting, subcarrier crawl | In-house |
| cat-svideo | S-Video | Colour | YIQ chroma band limit only | In-house |
| cat-pal | PAL Tint | Colour | PAL chroma delay-line averaging | In-house |
| cat-sepia | Sepia | Colour | Standard sepia matrix | In-house |
| cat-grey | Greyscale | Colour | Rec.601 luma | In-house |
| cat-vibrance | Vibrance | Colour | Saturation weighted by inverse saturation | In-house |
| cat-gamma | Brighten | Colour | Power-law gamma | In-house |
| cat-night | Night Mode | Colour | Blue reduction | In-house |
| cat-daltonize | Red-Green Assist | Colour | Daltonize, Fidaner et al. | In-house |
| cat-pal-gb | Game Boy Palette | Colour | Nearest of the DMG palette | In-house |
| cat-pal-cga | CGA Palette | Colour | Nearest of a CGA palette | In-house |
| cat-pal-ega | EGA Colours | Colour | Nearest of eight EGA colours | In-house |
| cat-pal-c64 | C64 Colours | Colour | Nearest of eight C64 colours | In-house |
| cat-unsharp | Unsharp Mask | Sharpen | Unsharp masking | In-house |
| cat-cas | Adaptive Sharpen | Sharpen | Contrast Adaptive Sharpening as AMD describes it | In-house |
| cat-luma-sharpen | Luma Sharpen | Sharpen | Unsharp mask on luma only | In-house |
| cat-edge-ink | Ink Edges | Sharpen | Local-difference edge detect | In-house |
| cat-vhs | VHS Tape | Retro Looks | Chroma bleed, tracking wobble | In-house |
| cat-posterize | Posterize | Retro Looks | Per-channel quantisation | In-house |
| cat-dither-mono | 1-Bit Dither | Retro Looks | 4x4 Bayer ordered dither | In-house |
| cat-dither-colour | Colour Dither | Retro Looks | 4x4 Bayer colour dither | In-house |
| cat-halftone | Newsprint | Retro Looks | Rotated halftone grid | In-house |
| cat-cross-stitch | Cross Stitch | Retro Looks | Per-pixel X mask | In-house |
| cat-mosaic | Mosaic | Retro Looks | Block quantisation | In-house |
| cat-thermal | Thermal | Retro Looks | False-colour map | In-house |
| cat-scope | Oscilloscope | Retro Looks | Green phosphor beam | In-house |
| cat-amber | Amber Terminal | Retro Looks | Amber phosphor monochrome | In-house |
| cat-blueprint | Blueprint | Retro Looks | Edges on blue | In-house |
| cat-gbcamera | Game Boy Camera | Retro Looks | Ordered dither to four greys | In-house |
| cat-cinema | Cinema Bars | Retro Looks | Letterbox and grain | In-house |

## Where filters do not apply

Every core in this build draws through `MetalRenderer`, either by the copy path or, for the Vulkan cores (azahar,
beetle_psx, flycast, mupen64plus_next, ppsspp), through the output texture (`LibretroVulkan.h` declares
`GAGA_CORE_CAP_OUTPUT_TEXTURE`). No core is excluded by capability. A Vulkan core whose `attachOutputTexture()` fails at
runtime falls back to presenting directly, and that one session has no filter.

## Frame cost

Measured on an A19 iPhone by `testFrameCostOfHeaviestFilters`: average milliseconds per frame over 60 frames, drawing
offscreen to 2622x1206. The budget at 60 fps is 16.67 ms. No game was running at the same time, so this is the filter's
own cost and not a measurement of a loaded N64 or PSP session.

| Filter | N64 640x480 | PSP 960x544 |
|---|---|---|
| original | 1.10 | 0.42 |
| crt-deluxe | 2.29 | 1.02 |
| anime4k | 2.10 | 1.35 |
| lottes-crt | 3.27 | 4.29 |
| cat-crt-arcade | 0.45 | 0.46 |
| cat-xbr | 0.83 | 0.95 |
| cat-kuwahara | 1.63 | 2.01 |
| cat-bilateral | 1.28 | 1.55 |
| cat-lanczos2 | 1.44 | 1.76 |
| cat-ntsc | 0.59 | 0.64 |

## xdelta

`Sources/Hub/Xdelta.swift` decodes VCDIFF from RFC 3284, with the code table, address caches and custom code tables.
Its djw and fgk decoders follow the format of xdelta3 (Apache-2.0, https://github.com/jmacd/xdelta), read as a
description of the bitstream; the code is our own. LZMA sections go to the system `Compression` framework.
