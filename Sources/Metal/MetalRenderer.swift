import Metal
import MetalKit

public enum ShaderPreset: String, CaseIterable, Identifiable {
    case original = "original"
    case cartoon = "cartoon"
    case crtV1 = "crt-v1"
    case crtV2 = "crt-v2"
    case geomCrt = "geom-crt"
    case geomCrtBorder = "geom-crt-border"
    case film = "film"
    case crtDeluxe = "crt-deluxe"
    case anime4k = "anime4k"
    case lottesCrt = "lottes-crt"
    case lcd3x = "lcd3x"
    case sharpBilinear = "sharp-bilinear"
    // The in-house catalogue (ShaderLibrary). A test checks these and its entries match.
    case catCrtAperture = "cat-crt-aperture", catCrtSlot = "cat-crt-slot", catCrtShadow = "cat-crt-shadow", catCrtPvm = "cat-crt-pvm"
    case catCrtConsumer = "cat-crt-consumer", catCrtArcade = "cat-crt-arcade", catCrtVga = "cat-crt-vga", catCrtComposite = "cat-crt-composite"
    case catCrtAged = "cat-crt-aged", catCrtTrinitron = "cat-crt-trinitron"
    case catLcdGrid = "cat-lcd-grid", catLcdDmg = "cat-lcd-dmg", catLcdPocket = "cat-lcd-pocket", catLcdLight = "cat-lcd-light"
    case catLcdGba = "cat-lcd-gba", catLcdNds = "cat-lcd-nds", catLcdSubpixel = "cat-lcd-subpixel", catLcdVfd = "cat-lcd-vfd"
    case catScanClassic = "cat-scan-classic", catScanSoft = "cat-scan-soft", catScanThick = "cat-scan-thick"
    case catScanInterlace = "cat-scan-interlace", catScanDouble = "cat-scan-double", catScanDynamic = "cat-scan-dynamic"
    case catScale2x = "cat-scale2x", catScale3x = "cat-scale3x", catEagle = "cat-eagle", catXbr = "cat-xbr", catXbrShallow = "cat-xbr-shallow"
    case catXbrz = "cat-xbrz", catScalefx = "cat-scalefx", catSai = "cat-sai", catHq = "cat-hq", catLanczos2 = "cat-lanczos2"
    case catCatmull = "cat-catmull", catMitchell = "cat-mitchell", catSmoothstep = "cat-smoothstep", catPixellate = "cat-pixellate"
    case catGaussian = "cat-gaussian", catBilateral = "cat-bilateral", catKuwahara = "cat-kuwahara", catFxaa = "cat-fxaa", catGlow = "cat-glow"
    case catNtsc = "cat-ntsc", catSvideo = "cat-svideo", catPal = "cat-pal", catSepia = "cat-sepia", catGrey = "cat-grey"
    case catVibrance = "cat-vibrance", catGamma = "cat-gamma", catNight = "cat-night", catDaltonize = "cat-daltonize"
    case catPalGb = "cat-pal-gb", catPalCga = "cat-pal-cga", catPalEga = "cat-pal-ega", catPalC64 = "cat-pal-c64"
    case catUnsharp = "cat-unsharp", catCas = "cat-cas", catLumaSharpen = "cat-luma-sharpen", catEdgeInk = "cat-edge-ink"
    case catVhs = "cat-vhs", catPosterize = "cat-posterize", catDitherMono = "cat-dither-mono", catDitherColour = "cat-dither-colour"
    case catHalftone = "cat-halftone", catCrossStitch = "cat-cross-stitch", catMosaic = "cat-mosaic", catThermal = "cat-thermal"
    case catScope = "cat-scope", catAmber = "cat-amber", catBlueprint = "cat-blueprint", catGbcamera = "cat-gbcamera", catCinema = "cat-cinema"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original: return "Original"
        case .cartoon: return "Cartoon"
        case .crtV1: return "CRT v1"
        case .crtV2: return "CRT v2"
        case .geomCrt: return "Geom CRT"
        case .geomCrtBorder: return "Geom CRT Border"
        case .film: return "Film"
        case .crtDeluxe: return "CRT Deluxe"
        case .anime4k: return "Anime4K"
        case .lottesCrt: return "Lottes CRT"
        case .lcd3x: return "LCD3x"
        case .sharpBilinear: return "Sharp Bilinear"
        default: return ShaderLibrary.entry(rawValue)?.name ?? rawValue
        }
    }

    /// A slider's title, which the catalogue names per filter.
    public func title(for kind: ShaderParameterKind) -> String { ShaderLibrary.entry(rawValue)?.sliders[kind] ?? kind.title }

    public static func from(id: String) -> ShaderPreset {
        if let preset = ShaderPreset(rawValue: id) { return preset }
        switch id {
        case "crt_v1": return .crtV1
        case "crt_v2": return .crtV2
        case "geom_crt": return .geomCrt
        case "geom_crt_border": return .geomCrtBorder
        default: return .original
        }
    }

    /// The passes this preset runs, in order. The last one draws to the screen.
    public var passes: [ShaderPass] {
        switch self {
        case .original: return [.final("original_fragment")]
        case .cartoon: return [.final("cartoon_fragment")]
        case .crtV1: return [.final("crt_v1_fragment")]
        case .crtV2: return [.final("crt_v2_fragment")]
        case .geomCrt: return [.final("geom_crt_fragment")]
        case .geomCrtBorder: return [.final("geom_crt_border_fragment")]
        case .film: return [.final("film_fragment")]
        case .crtDeluxe:
            return [.init(fragment: "crt_deluxe_beam_fragment", size: .source(1), format: .rgba16Float, sampling: .nearest),
                    .init(fragment: "crt_deluxe_scan_fragment", size: .output, format: .rgba16Float, sampling: .linear),
                    .final("crt_deluxe_mask_fragment", sampling: .linear)]
        case .anime4k:
            return (0..<4).map {
                .init(fragment: "anime4k_conv\($0)_fragment", size: .source(1), format: .rgba16Float, sampling: .nearest)
            } + [.init(fragment: "anime4k_output_fragment", size: .source(2), format: .bgra8Unorm, sampling: .nearest),
                 .final("original_fragment", sampling: .linear)]
        case .lottesCrt: return [.final("lottes_crt_fragment", sampling: .nearest)]
        case .lcd3x: return [.final("lcd3x_fragment")]
        case .sharpBilinear: return [.final("sharp_bilinear_fragment", sampling: .linear)]
        default: return [.final(ShaderLibrary.fragment(rawValue))]
        }
    }

    /// Presets that scale for themselves take no upscaling pass.
    public var usesUpscaler: Bool {
        switch self {
        case .crtDeluxe, .anime4k, .lottesCrt, .sharpBilinear: return false
        default: return ShaderLibrary.entry(rawValue)?.usesUpscaler ?? true
        }
    }

    /// The sliders that change anything for this preset.
    public var parameters: [ShaderParameterKind] {
        switch self {
        case .original, .cartoon, .film, .anime4k, .lcd3x, .sharpBilinear: return [.colorTemp]
        case .crtV1: return [.scanlines, .colorTemp]
        case .crtV2: return [.scanlines, .glow, .colorTemp]
        case .geomCrtBorder: return [.curvature, .scanlines, .colorTemp]
        case .geomCrt, .crtDeluxe, .lottesCrt: return [.curvature, .scanlines, .glow, .colorTemp]
        default:
            let sliders = ShaderLibrary.entry(rawValue)?.sliders ?? [:]
            return ShaderParameterKind.allCases.filter { sliders[$0] != nil }
        }
    }
}

/// One step of the chain. Texture 0 is the previous pass's output, or the core frame for the first
/// pass, and texture 1 is always the core frame. A nil `size` means the drawable.
public struct ShaderPass: Equatable {
    public enum Size: Equatable { case source(Int), output }
    public enum Sampling: Equatable { case nearest, linear, chosen }

    public let fragment: String
    public var size: Size?
    public var format: MTLPixelFormat = .bgra8Unorm
    public var sampling: Sampling = .chosen

    static func final(_ fragment: String, sampling: Sampling = .chosen) -> ShaderPass {
        ShaderPass(fragment: fragment, size: nil, sampling: sampling)
    }
}

/// The first pass of the chain (docs/05 section 3.4). Nearest and Bilinear need no pass of their own.
public enum Upscaler: String, CaseIterable, Identifiable {
    case nearest, bilinear, bicubic, edgeSmooth = "edge-smooth"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .nearest: return "Nearest"
        case .bilinear: return "Bilinear"
        case .bicubic: return "Bicubic"
        case .edgeSmooth: return "Edge Smooth"
        }
    }

    var pass: ShaderPass? {
        switch self {
        case .nearest, .bilinear: return nil
        case .bicubic: return ShaderPass(fragment: "bicubic_fragment", size: .output, sampling: .nearest)
        case .edgeSmooth: return ShaderPass(fragment: "edge_smooth_fragment", size: .output, sampling: .nearest)
        }
    }
}

public enum ShaderParameterKind: String, CaseIterable, Identifiable {
    case curvature, scanlines, glow, colorTemp

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .curvature: return "Curvature"
        case .scanlines: return "Scanlines"
        case .glow: return "Glow"
        case .colorTemp: return "Colour"
        }
    }

    public var keyPath: WritableKeyPath<ShaderParameterValues, Float> {
        switch self {
        case .curvature: return \.curvature
        case .scanlines: return \.scanlineWeight
        case .glow: return \.phosphorGlow
        case .colorTemp: return \.colorTemp
        }
    }
}

/// What the picker saves per preset, in state.json. `upscaler` stays a string so a value from a later
/// build cannot fail the whole file's decode.
public struct ShaderParameterValues: Codable, Equatable {
    public var curvature: Float = 0.20
    public var scanlineWeight: Float = 0.50
    public var phosphorGlow: Float = 0.25
    public var colorTemp: Float = 0.50
    public var upscaler: String = Upscaler.nearest.rawValue
    /// An imported `.slangp`'s own parameters by name. Optional, so older files still decode.
    public var slang: [String: Float]?

    public init() {}

    public var resolvedUpscaler: Upscaler { Upscaler(rawValue: upscaler) ?? .nearest }
}

public struct ShaderUniforms {
    public var curvature: Float = 0.0
    public var scanlineWeight: Float = 0.5
    public var phosphorGlow: Float = 0.2
    public var colorTemp: Float = 0.5
    public var time: Float = 0.0
    public var viewportW: UInt32 = 0
    public var viewportH: UInt32 = 0
    public var sourceW: UInt32 = 0
    public var sourceH: UInt32 = 0

    public init(
        curvature: Float = 0.0,
        scanlineWeight: Float = 0.5,
        phosphorGlow: Float = 0.2,
        colorTemp: Float = 0.5,
        time: Float = 0.0,
        viewportW: UInt32 = 0,
        viewportH: UInt32 = 0
    ) {
        self.curvature = curvature
        self.scanlineWeight = scanlineWeight
        self.phosphorGlow = phosphorGlow
        self.colorTemp = colorTemp
        self.time = time
        self.viewportW = viewportW
        self.viewportH = viewportH
    }
}

/// A14 (Apple7) is required for layer-path 3D cores (docs/05 section 2.3); 2D cores have no such floor.
/// GameSession refuses a layer-path core below it with `layerPathMessage`.
public enum GPUFloor {
    public static let layerPathMessage = "This system's 3D renderer needs an A14 chip or newer. 2D systems still work on this device."

    public static func supportsLayerPathCores(_ device: MTLDevice) -> Bool {
        device.supportsFamily(.apple7)
    }
}

public final class MetalRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    private let library: MTLLibrary
    private let vertexFunction: MTLFunction
    private struct PipelineKey: Hashable {
        let fragment: String
        let format: MTLPixelFormat
    }
    private var pipelineStates: [PipelineKey: MTLRenderPipelineState] = [:]
    private var nearestSampler: MTLSamplerState?
    private var linearSampler: MTLSamplerState?
    /// One target per screen and chain position, kept across frames.
    private var intermediates: [[MTLTexture?]] = []
    /// Each screen cut out of a two-screen frame, turned if asked (docs/05 section 2.6).
    private var cropTargets: [MTLTexture?] = []
    private lazy var cropPipeline: MTLRenderPipelineState? = {
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "screen_crop_vertex")
        desc.fragmentFunction = library.makeFunction(name: "screen_crop_fragment")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try? device.makeRenderPipelineState(descriptor: desc)
    }()
    /// How the picture is placed. The platform is empty when the core draws its own picture, so the core's
    /// frame is placed whole.
    private var screen = ScreenSettings()
    private var screenPlatform = ""

    public var uniforms = ShaderUniforms()
    public var activePreset: ShaderPreset = .original
    public var upscaler: Upscaler = .nearest

    /// An imported filter (docs/05 section 4). It replaces the preset's last pass.
    public private(set) var importedPipeline: MTLRenderPipelineState?
    /// Called on the main thread if the GPU rejected a frame from the imported filter, after it is dropped.
    public var onImportedFailure: (() -> Void)?
    /// An imported `.slangp` (docs/05 section 4.2). It replaces the whole chain, upscaler included.
    private(set) var slangChain: SlangChain?
    /// Its parameters by name, from the saved sliders. A missing one uses the preset's value.
    var slangValues: [String: Float] = [:]
    private var frameCount: UInt32 = 0

    public weak var textureRing: MetalTextureRing?
    public var customTexture: MTLTexture?

    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private let lock = NSLock()

    /// Light-mode ink in both appearances: the picture needs a dark surround.
    static let letterboxColor = MTLClearColor(red: Double(Palette.ink.light >> 16 & 0xFF) / 255,
                                              green: Double(Palette.ink.light >> 8 & 0xFF) / 255,
                                              blue: Double(Palette.ink.light & 0xFF) / 255, alpha: 1)

    /// What both picture paths hand the screen: 8-bit UNORM holding sRGB-encoded values, tagged sRGB, so
    /// nothing applies gamma a second time. MoltenVK sets the same on a layer-path core's layer from its
    /// `B8G8R8A8_UNORM` / `SRGB_NONLINEAR` swapchain (`LibretroVulkan.c`).
    static let outputPixelFormat: MTLPixelFormat = .bgra8Unorm
    static let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)

    static func configureOutput(_ layer: CAMetalLayer) {
        layer.pixelFormat = outputPixelFormat
        layer.colorspace = outputColorSpace
    }

    /// The whole chain for this selection, upscaling pass first.
    public static func chain(preset: ShaderPreset, upscaler: Upscaler) -> [ShaderPass] {
        let lead = preset.usesUpscaler ? upscaler.pass.map { [$0] } ?? [] : []
        return lead + preset.passes
    }

    public init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "vertex_main") else { return nil }
        self.commandQueue = queue
        self.library = library
        self.vertexFunction = vertex
        super.init()
        setupSamplers()
    }

    private func setupSamplers() {
        let nearestDesc = MTLSamplerDescriptor()
        nearestDesc.minFilter = .nearest
        nearestDesc.magFilter = .nearest
        nearestDesc.sAddressMode = .clampToEdge
        nearestDesc.tAddressMode = .clampToEdge
        nearestSampler = device.makeSamplerState(descriptor: nearestDesc)

        let linearDesc = MTLSamplerDescriptor()
        linearDesc.minFilter = .linear
        linearDesc.magFilter = .linear
        linearDesc.sAddressMode = .clampToEdge
        linearDesc.tAddressMode = .clampToEdge
        linearSampler = device.makeSamplerState(descriptor: linearDesc)
    }

    public func setTexture(_ texture: MTLTexture) {
        lock.lock()
        self.customTexture = texture
        lock.unlock()
    }

    /// A layer-path core's off-screen frame (docs/05 section 2.4), copied into `ring` once the core's copy is done,
    /// so the filter chain draws it as any ring frame. Signals the core's done event even for a dropped frame:
    /// the core writes the texture again only after it. Runs on this queue, so draws come after the copy.
    func receive(_ frame: GagaMetalTextureFrame, ring: MetalTextureRing) {
        guard let texture = frame.texture.map({ Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() }) as? MTLTexture,
              let ready = frame.ready_event.map({ Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() }) as? MTLSharedEvent,
              let done = frame.done_event.map({ Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() }) as? MTLSharedEvent,
              let cmdBuffer = commandQueue.makeCommandBuffer() else { return }
        cmdBuffer.enqueue() // Its place on the queue comes before any draw that sees the new slot.
        cmdBuffer.encodeWaitForEvent(ready, value: frame.ready_value)
        if let blit = cmdBuffer.makeBlitCommandEncoder() {
            if let slot = ring.copyFrame(texture, with: blit) { setTexture(slot) }
            blit.endEncoding()
        }
        cmdBuffer.encodeSignalEvent(done, value: frame.done_value)
        cmdBuffer.commit()
    }

    /// A layer-path core's last presented frame size, from its size-only frame descriptor.
    private var presentedSize: CGSize?

    public func setPresentedSize(width: Int, height: Int) {
        lock.lock()
        presentedSize = CGSize(width: width, height: height)
        lock.unlock()
    }

    /// The last frame's size, for placing a finger on the picture. A layer-path core fits its frame in the
    /// layer the same way (`LibretroVulkan.c`, `lr_vk_record_copy`), so its presented size serves too.
    public var contentSize: CGSize? {
        lock.lock()
        defer { lock.unlock() }
        return customTexture.map { CGSize(width: $0.width, height: $0.height) } ?? presentedSize
    }

    /// `platformID` empty places the frame whole, as one screen.
    func setScreen(_ settings: ScreenSettings, platformID: String) {
        lock.lock()
        screen = settings
        screenPlatform = platformID
        lock.unlock()
    }

    /// Where the last frame's screens are drawn in a canvas of `canvas` pixels, for placing a finger.
    func placements(canvas: CGSize) -> [ScreenPlacement] {
        guard let content = contentSize else { return [] }
        lock.lock()
        let (settings, platform) = (screen, screenPlatform)
        lock.unlock()
        return ScreenLayout.placements(frame: content, canvas: canvas, platformID: platform, settings: settings)
    }

    /// Sliders and the upscaler. Saved values pass through a clamp, because state.json is a file.
    public func apply(_ values: ShaderParameterValues) {
        uniforms.curvature = min(max(values.curvature, 0), 1)
        uniforms.scanlineWeight = min(max(values.scanlineWeight, 0), 1)
        uniforms.phosphorGlow = min(max(values.phosphorGlow, 0), 1)
        uniforms.colorTemp = min(max(values.colorTemp, 0), 1)
        upscaler = values.resolvedUpscaler
        slangValues = values.slang ?? [:]
    }

    public func setImported(_ pipeline: MTLRenderPipelineState?) {
        importedPipeline = pipeline
    }

    func setSlang(_ chain: SlangChain?) {
        slangChain = chain
    }

    private func pipeline(fragment: String, format: MTLPixelFormat) -> MTLRenderPipelineState? {
        let key = PipelineKey(fragment: fragment, format: format)
        if let cached = pipelineStates[key] { return cached }
        guard let function = library.makeFunction(name: fragment) else { return nil }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFunction
        desc.fragmentFunction = function
        desc.colorAttachments[0].pixelFormat = format
        let state = try? device.makeRenderPipelineState(descriptor: desc)
        pipelineStates[key] = state
        return state
    }

    /// Reuses this screen's chain-position target while its size and format still fit.
    private func intermediate(screen: Int, at index: Int, width: Int, height: Int, format: MTLPixelFormat) -> MTLTexture? {
        while intermediates.count <= screen { intermediates.append([]) }
        if intermediates[screen].count <= index {
            intermediates[screen] += Array(repeating: nil, count: index + 1 - intermediates[screen].count)
        }
        let texture = reuse(intermediates[screen][index], width: width, height: height, format: format)
        intermediates[screen][index] = texture
        return texture
    }

    private func reuse(_ current: MTLTexture?, width: Int, height: Int, format: MTLPixelFormat) -> MTLTexture? {
        if let current, current.width == width, current.height == height, current.pixelFormat == format { return current }
        // Zoom can ask for an output-sized pass past the GPU's limit.
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: min(max(width, 1), 8192),
                                                            height: min(max(height, 1), 8192), mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        return device.makeTexture(descriptor: desc)
    }

    /// The placement's part of the frame, turned, at the screen's own pixel size.
    private func cropped(_ source: MTLTexture, _ placement: ScreenPlacement, screen: Int, into cmdBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = cropPipeline else { return nil }
        let w = max(Int((CGFloat(source.width) * placement.source.width).rounded()), 1)
        let h = max(Int((CGFloat(source.height) * placement.source.height).rounded()), 1)
        let (width, height) = placement.rotation == .none ? (w, h) : (h, w)
        while cropTargets.count <= screen { cropTargets.append(nil) }
        guard let target = reuse(cropTargets[screen], width: width, height: height, format: .bgra8Unorm) else { return nil }
        cropTargets[screen] = target
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        var corners = ScreenLayout.cropCorners(placement)
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&corners, length: MemoryLayout<SIMD2<Float>>.stride * corners.count, index: 0)
        encoder.setFragmentTexture(source, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        return target
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmdBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        encode(into: cmdBuffer, target: rpd, size: view.drawableSize)
        cmdBuffer.present(drawable)
        cmdBuffer.commit()
    }

    /// Renders the current frame into `target`, so a test can read what the screen would get.
    func render(into target: MTLTexture) {
        guard let cmdBuffer = commandQueue.makeCommandBuffer() else { return }
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = target
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].storeAction = .store
        encode(into: cmdBuffer, target: rpd, size: CGSize(width: target.width, height: target.height))
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
    }

    private func encode(into cmdBuffer: MTLCommandBuffer, target rpd: MTLRenderPassDescriptor, size: CGSize) {
        lock.lock()
        let source = self.customTexture
        lock.unlock()

        rpd.colorAttachments[0].clearColor = Self.letterboxColor

        guard let source else {
            cmdBuffer.makeRenderCommandEncoder(descriptor: rpd)?.endEncoding()
            return
        }

        // Releases one acquired ring slot, if any is waiting. Attaches nothing on a repeat draw.
        textureRing?.attachCompletion(to: cmdBuffer)

        lock.lock()
        let (settings, platform) = (screen, screenPlatform)
        lock.unlock()
        let placements = ScreenLayout.placements(frame: CGSize(width: source.width, height: source.height), canvas: size,
                                                 platformID: platform, settings: settings)
        if slangChain != nil || importedPipeline != nil { watchImported(cmdBuffer) }
        // The filter chain runs once per screen, on that screen alone (docs/05 section 2.6). The first screen drawn
        // clears the target and the rest load it.
        var cleared = false
        for (index, placement) in placements.enumerated() {
            let bounds = CGRect(origin: .zero, size: size)
            let visible = placement.dest.intersection(bounds).integral.intersection(bounds)
            guard !visible.isNull, visible.width >= 1, visible.height >= 1,
                  let input = placement.isWholeFrame ? source : cropped(source, placement, screen: index, into: cmdBuffer) else { continue }
            let target: MTLRenderPassDescriptor
            if cleared {
                target = rpd.copy() as! MTLRenderPassDescriptor // swiftlint:disable:this force_cast
                target.colorAttachments[0].loadAction = .load
            } else {
                target = rpd
            }
            cleared = true
            let viewport = MTLViewport(originX: Double(placement.dest.minX), originY: Double(placement.dest.minY),
                                       width: Double(placement.dest.width), height: Double(placement.dest.height), znear: 0, zfar: 1)
            let scissor = MTLScissorRect(x: Int(visible.minX), y: Int(visible.minY), width: Int(visible.width), height: Int(visible.height))
            encodeScreen(input, screen: index, into: cmdBuffer, target: target, viewport: viewport, scissor: scissor)
        }
        if !cleared { cmdBuffer.makeRenderCommandEncoder(descriptor: rpd)?.endEncoding() }
    }

    /// One screen through the whole chain. The last pass draws into `viewport` of `target`, cut to `scissor`.
    private func encodeScreen(_ source: MTLTexture, screen: Int, into cmdBuffer: MTLCommandBuffer, target rpd: MTLRenderPassDescriptor,
                              viewport: MTLViewport, scissor: MTLScissorRect) {
        var values = uniforms
        values.time = Float(CACurrentMediaTime() - startTime)
        values.viewportW = UInt32(viewport.width)
        values.viewportH = UInt32(viewport.height)
        values.sourceW = UInt32(source.width)
        values.sourceH = UInt32(source.height)

        if let slang = slangChain {
            encodeSlang(slang, into: cmdBuffer, target: rpd, source: source, viewport: viewport, scissor: scissor, screen: screen)
            return
        }
        let chain = Self.chain(preset: activePreset, upscaler: upscaler)
        let imported = importedPipeline
        var input = source

        for (index, pass) in chain.enumerated() {
            let isLast = index == chain.count - 1
            let state = isLast ? imported ?? pipeline(fragment: pass.fragment, format: pass.format)
                               : pipeline(fragment: pass.fragment, format: pass.format)
            let passDescriptor: MTLRenderPassDescriptor
            var output: MTLTexture?
            if let passSize = pass.size {
                let pixels = Self.pixelSize(passSize, source: source, viewport: viewport)
                guard let texture = intermediate(screen: screen, at: index, width: pixels.width, height: pixels.height, format: pass.format) else { continue }
                output = texture
                passDescriptor = MTLRenderPassDescriptor()
                passDescriptor.colorAttachments[0].texture = texture
                passDescriptor.colorAttachments[0].loadAction = .dontCare
                passDescriptor.colorAttachments[0].storeAction = .store
            } else {
                passDescriptor = rpd
            }
            guard let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
            if let state {
                encoder.setRenderPipelineState(state)
                if let output {
                    encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(output.width), height: Double(output.height), znear: 0, zfar: 1))
                } else {
                    encoder.setViewport(viewport)
                    encoder.setScissorRect(scissor)
                }
                encoder.setFragmentBytes(&values, length: MemoryLayout<ShaderUniforms>.size, index: 0)
                encoder.setFragmentTexture(input, index: 0)
                encoder.setFragmentTexture(source, index: 1)
                encoder.setFragmentSamplerState(sampler(pass.sampling), index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            }
            encoder.endEncoding()
            if let output { input = output }
        }
    }

    /// Each pass draws a quad into its own target, sized by its scale type; the last draws into the picture.
    /// shortcut: a scale on the last pass is ignored (it always fills the picture), add a final blit if a preset needs it.
    private func encodeSlang(_ chain: SlangChain, into cmdBuffer: MTLCommandBuffer, target rpd: MTLRenderPassDescriptor,
                             source: MTLTexture, viewport: MTLViewport, scissor: MTLScissorRect, screen: Int) {
        frameCount &+= 1
        let view = (width: max(Int(viewport.width), 1), height: max(Int(viewport.height), 1))
        var parameters: [String: Float] = [:]
        for parameter in chain.filter.parameters {
            parameters[parameter.name] = min(max(slangValues[parameter.name] ?? parameter.initial, parameter.minimum), parameter.maximum)
        }
        var input = source
        for (index, pass) in chain.passes.enumerated() {
            let output: MTLTexture?
            let size: (width: Int, height: Int)
            let descriptor: MTLRenderPassDescriptor
            if index == chain.passes.count - 1 {
                output = nil
                size = view
                descriptor = rpd
            } else {
                size = SlangChain.outputSize(pass.spec, input: (input.width, input.height), viewport: view)
                guard let texture = intermediate(screen: screen, at: index, width: size.width, height: size.height, format: pass.format) else { return }
                output = texture
                descriptor = MTLRenderPassDescriptor()
                descriptor.colorAttachments[0].texture = texture
                descriptor.colorAttachments[0].loadAction = .dontCare
                descriptor.colorAttachments[0].storeAction = .store
            }
            guard let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
            encoder.setRenderPipelineState(pass.pipeline)
            encoder.setViewport(output.map { MTLViewport(originX: 0, originY: 0, width: Double($0.width), height: Double($0.height), znear: 0, zfar: 1) } ?? viewport)
            if output == nil { encoder.setScissorRect(scissor) }
            let mod = UInt32(max(pass.spec.frameCountMod, 0))
            let frame = SlangChain.Frame(source: (input.width, input.height), original: (source.width, source.height), output: size,
                                         viewport: view, frameCount: mod > 0 ? frameCount % mod : frameCount, parameters: parameters)
            for (block, slot) in [(pass.spec.ubo, 0), (pass.spec.push, 1)] where block.size > 0 {
                SlangChain.blockBytes(block, frame: frame).withUnsafeBytes {
                    encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: slot)
                    encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: slot)
                }
            }
            SlangChain.quad.withUnsafeBytes {
                encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: SlangChain.vertexBufferIndex)
            }
            for (slot, name) in pass.spec.textures.enumerated() {
                let texture = name == "Original" ? source : input
                encoder.setVertexTexture(texture, index: slot)
                encoder.setFragmentTexture(texture, index: slot)
                encoder.setVertexSamplerState(pass.sampler, index: slot)
                encoder.setFragmentSamplerState(pass.sampler, index: slot)
            }
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            if let output { input = output }
        }
    }

    private static func pixelSize(_ size: ShaderPass.Size, source: MTLTexture, viewport: MTLViewport) -> (width: Int, height: Int) {
        switch size {
        case .source(let scale): return (source.width * scale, source.height * scale)
        case .output: return (max(Int(viewport.width), 1), max(Int(viewport.height), 1))
        }
    }

    private func sampler(_ sampling: ShaderPass.Sampling) -> MTLSamplerState? {
        switch sampling {
        case .nearest: return nearestSampler
        case .linear: return linearSampler
        // After an upscaling pass the texture is already output sized, and curved presets still resample it.
        case .chosen: return upscaler == .nearest ? nearestSampler : linearSampler
        }
    }

    /// A shader that hangs the GPU fails its command buffers. Stop using it instead of failing every frame.
    private func watchImported(_ cmdBuffer: MTLCommandBuffer) {
        cmdBuffer.addCompletedHandler { [weak self] buffer in
            guard buffer.status == .error else { return }
            DispatchQueue.main.async {
                guard let self, self.importedPipeline != nil || self.slangChain != nil else { return }
                self.importedPipeline = nil
                self.slangChain = nil
                self.onImportedFailure?()
            }
        }
    }
}
