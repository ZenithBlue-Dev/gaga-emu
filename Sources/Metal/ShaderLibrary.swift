import Foundation

/// How the filter picker groups the catalogue.
public enum ShaderCategory: String, CaseIterable, Identifiable {
    case crt = "CRT"
    case lcd = "LCD and Handheld"
    case scanlines = "Scanlines"
    case upscaling = "Upscaling"
    case smoothing = "Smoothing"
    case colour = "Colour"
    case sharpen = "Sharpen"
    case retro = "Retro Looks"

    public var id: String { rawValue }
}

/// The in-house catalogue in `CatalogShaders.metal`. Each entry is one fragment function: id `cat-x-y` runs
/// `cat_x_y_fragment` (docs/05 section 5.1 records the basis of each).
public enum ShaderLibrary {
    public struct Entry {
        public let id: String
        public let name: String
        public let category: ShaderCategory
        /// The sliders that change anything, by kind, with this filter's own title for each.
        public let sliders: [ShaderParameterKind: String]
        /// True when the filter samples through the chosen upscaler, not its own taps.
        public var usesUpscaler = false
    }

    private static func make(_ id: String, _ name: String, _ category: ShaderCategory, _ strength: String? = nil, _ second: String? = nil,
                             _ third: String? = nil, upscaler: Bool = false) -> Entry {
        var sliders = [ShaderParameterKind.colorTemp: ShaderParameterKind.colorTemp.title]
        if let strength { sliders[.scanlines] = strength }
        if let second { sliders[.glow] = second }
        if let third { sliders[.curvature] = third }
        return Entry(id: id, name: name, category: category, sliders: sliders, usesUpscaler: upscaler)
    }

    public static let entries: [Entry] = [
        make("cat-crt-aperture", "Aperture Grille", .crt, "Scanlines", "Mask", "Curvature"),
        make("cat-crt-slot", "Slot Mask", .crt, "Scanlines", "Mask", "Curvature"),
        make("cat-crt-shadow", "Shadow Mask", .crt, "Scanlines", "Mask", "Curvature"),
        make("cat-crt-pvm", "Broadcast Monitor", .crt, "Scanlines", "Mask"),
        make("cat-crt-consumer", "Living Room TV", .crt, "Scanlines", "Glow", "Curvature"),
        make("cat-crt-arcade", "Arcade Cabinet", .crt, "Beam", "Bloom", "Curvature"),
        make("cat-crt-vga", "VGA Monitor", .crt, "Line Doubling", "Mask"),
        make("cat-crt-composite", "Composite TV", .crt, "Scanlines", "Mask", "Curvature"),
        make("cat-crt-aged", "Aged Tube", .crt, "Scanlines", "Vignette", "Curvature"),
        make("cat-crt-trinitron", "Damper Wire Tube", .crt, "Scanlines", "Mask"),

        make("cat-lcd-grid", "Pixel Grid", .lcd, "Grid"),
        make("cat-lcd-dmg", "Game Boy Green", .lcd, "Grid"),
        make("cat-lcd-pocket", "Pocket Grey", .lcd, "Grid"),
        make("cat-lcd-light", "Backlit Teal", .lcd, "Grid"),
        make("cat-lcd-gba", "GBA Panel Colour", .lcd, "Grid", "Depth"),
        make("cat-lcd-nds", "DS Panel Colour", .lcd, "Grid", "Depth"),
        make("cat-lcd-subpixel", "RGB Subpixels", .lcd, "Stripes", "Brightness"),
        make("cat-lcd-vfd", "Fluorescent Display", .lcd, "Segments", "Halo"),

        make("cat-scan-classic", "Hard Scanlines", .scanlines, "Darkness"),
        make("cat-scan-soft", "Soft Scanlines", .scanlines, "Darkness"),
        make("cat-scan-thick", "Thick Scanlines", .scanlines, "Darkness"),
        make("cat-scan-interlace", "Interlaced", .scanlines, "Darkness"),
        make("cat-scan-double", "Double Lines", .scanlines, "Darkness"),
        make("cat-scan-dynamic", "Dynamic Beam", .scanlines, "Darkness"),

        make("cat-scale2x", "Scale2x", .upscaling),
        make("cat-scale3x", "Scale3x", .upscaling),
        make("cat-eagle", "Eagle", .upscaling),
        make("cat-xbr", "xBR Style", .upscaling, nil, "Softness"),
        make("cat-xbr-shallow", "xBR Shallow Style", .upscaling, nil, "Softness"),
        make("cat-xbrz", "xBRZ Style", .upscaling, nil, "Dominance"),
        make("cat-scalefx", "ScaleFX Style", .upscaling, nil, "Tolerance"),
        make("cat-sai", "2xSaI Style", .upscaling),
        make("cat-hq", "HQ Style", .upscaling, nil, "Tolerance"),
        make("cat-lanczos2", "Lanczos2", .upscaling),
        make("cat-catmull", "Catmull-Rom", .upscaling),
        make("cat-mitchell", "Mitchell", .upscaling),
        make("cat-smoothstep", "Soft Pixels", .upscaling, "Sharpness"),
        make("cat-pixellate", "Clean Pixels", .upscaling),

        make("cat-gaussian", "Gaussian Blur", .smoothing, "Radius"),
        make("cat-bilateral", "Edge-Keeping Blur", .smoothing, "Smoothing"),
        make("cat-kuwahara", "Kuwahara Paint", .smoothing),
        make("cat-fxaa", "FXAA", .smoothing),
        make("cat-glow", "Soft Glow", .smoothing, "Amount"),

        make("cat-ntsc", "NTSC Composite", .colour, "Chroma Blur", "Dot Crawl"),
        make("cat-svideo", "S-Video", .colour, "Chroma Blur"),
        make("cat-pal", "PAL Tint", .colour, "Line Blend", upscaler: true),
        make("cat-sepia", "Sepia", .colour, "Amount", upscaler: true),
        make("cat-grey", "Greyscale", .colour, "Amount", upscaler: true),
        make("cat-vibrance", "Vibrance", .colour, "Amount", upscaler: true),
        make("cat-gamma", "Brighten", .colour, "Amount", upscaler: true),
        make("cat-night", "Night Mode", .colour, "Brightness", upscaler: true),
        make("cat-daltonize", "Red-Green Assist", .colour, "Amount", upscaler: true),
        make("cat-pal-gb", "Game Boy Palette", .colour, "Amount"),
        make("cat-pal-cga", "CGA Palette", .colour, "Amount"),
        make("cat-pal-ega", "EGA Colours", .colour, "Amount"),
        make("cat-pal-c64", "C64 Colours", .colour, "Amount"),

        make("cat-unsharp", "Unsharp Mask", .sharpen, "Amount"),
        make("cat-cas", "Adaptive Sharpen", .sharpen, "Amount"),
        make("cat-luma-sharpen", "Luma Sharpen", .sharpen, "Amount"),
        make("cat-edge-ink", "Ink Edges", .sharpen, "Amount"),

        make("cat-vhs", "VHS Tape", .retro, "Wobble", "Noise"),
        make("cat-posterize", "Posterize", .retro, "Amount", upscaler: true),
        make("cat-dither-mono", "1-Bit Dither", .retro, "Spread"),
        make("cat-dither-colour", "Colour Dither", .retro, "Spread"),
        make("cat-halftone", "Newsprint", .retro, "Dot Size", upscaler: true),
        make("cat-cross-stitch", "Cross Stitch", .retro),
        make("cat-mosaic", "Mosaic", .retro, "Block Size"),
        make("cat-thermal", "Thermal", .retro, upscaler: true),
        make("cat-scope", "Oscilloscope", .retro, "Beam", "Afterglow"),
        make("cat-amber", "Amber Terminal", .retro, "Scanlines"),
        make("cat-blueprint", "Blueprint", .retro, "Threshold"),
        make("cat-gbcamera", "Game Boy Camera", .retro, "Spread"),
        make("cat-cinema", "Cinema Bars", .retro, "Grain", upscaler: true)
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })

    public static func entry(_ id: String) -> Entry? { byID[id] }

    public static func fragment(_ id: String) -> String { id.replacingOccurrences(of: "-", with: "_") + "_fragment" }
}
