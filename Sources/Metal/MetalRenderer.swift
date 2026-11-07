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
        }
    }

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
        }
    }

    /// Presets that scale for themselves take no upscaling pass.
    public var usesUpscaler: Bool {
        switch self {
        case .crtDeluxe, .anime4k, .lottesCrt, .sharpBilinear: return false
        default: return true
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
    /// One target per chain position, kept across frames.
    private var intermediates: [MTLTexture?] = []

    public var uniforms = ShaderUniforms()
    public var activePreset: ShaderPreset = .original
    public var upscaler: Upscaler = .nearest

    /// An imported filter (docs/05 section 4). It replaces the preset's last pass.
    public private(set) var importedPipeline: MTLRenderPipelineState?
    /// Called on the main thread if the GPU rejected a frame from the imported filter, after it is dropped.
    public var onImportedFailure: (() -> Void)?

    public weak var textureRing: MetalTextureRing?
    public var customTexture: MTLTexture?

    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private let lock = NSLock()

    /// Light-mode ink in both appearances: the picture needs a dark surround.
    static let letterboxColor = MTLClearColor(red: Double(Palette.ink.light >> 16 & 0xFF) / 255,
                                              green: Double(Palette.ink.light >> 8 & 0xFF) / 255,
                                              blue: Double(Palette.ink.light & 0xFF) / 255, alpha: 1)

    /// Aspect fit, centred. The clear colour shows in the rest.
    /// shortcut: treats core pixels as square, add a display aspect to the frame descriptor when a core needs it (SNES 8:7).
    static func fittedViewport(contentWidth: Int, contentHeight: Int, drawable: CGSize) -> MTLViewport {
        guard contentWidth > 0, contentHeight > 0, drawable.width > 0, drawable.height > 0 else {
            return MTLViewport(originX: 0, originY: 0, width: Double(drawable.width), height: Double(drawable.height), znear: 0, zfar: 1)
        }
        let scale = min(drawable.width / CGFloat(contentWidth), drawable.height / CGFloat(contentHeight))
        let width = (CGFloat(contentWidth) * scale).rounded()
        let height = (CGFloat(contentHeight) * scale).rounded()
        return MTLViewport(originX: Double((drawable.width - width) / 2), originY: Double((drawable.height - height) / 2),
                           width: Double(width), height: Double(height), znear: 0, zfar: 1)
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

    /// The last frame's size, for placing a finger on the picture.
    public var contentSize: CGSize? {
        lock.lock()
        defer { lock.unlock() }
        return customTexture.map { CGSize(width: $0.width, height: $0.height) }
    }

    /// Sliders and the upscaler. Saved values pass through a clamp, because state.json is a file.
    public func apply(_ values: ShaderParameterValues) {
        uniforms.curvature = min(max(values.curvature, 0), 1)
        uniforms.scanlineWeight = min(max(values.scanlineWeight, 0), 1)
        uniforms.phosphorGlow = min(max(values.phosphorGlow, 0), 1)
        uniforms.colorTemp = min(max(values.colorTemp, 0), 1)
        upscaler = values.resolvedUpscaler
    }

    public func setImported(_ pipeline: MTLRenderPipelineState?) {
        importedPipeline = pipeline
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

    /// Reuses this chain position's target while its size and format still fit.
    private func intermediate(at index: Int, width: Int, height: Int, format: MTLPixelFormat) -> MTLTexture? {
        if intermediates.count <= index { intermediates += Array(repeating: nil, count: index + 1 - intermediates.count) }
        if let current = intermediates[index], current.width == width, current.height == height, current.pixelFormat == format {
            return current
        }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        let texture = device.makeTexture(descriptor: desc)
        intermediates[index] = texture
        return texture
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

        let viewport = Self.fittedViewport(contentWidth: source.width, contentHeight: source.height, drawable: size)
        var values = uniforms
        values.time = Float(CACurrentMediaTime() - startTime)
        values.viewportW = UInt32(viewport.width)
        values.viewportH = UInt32(viewport.height)
        values.sourceW = UInt32(source.width)
        values.sourceH = UInt32(source.height)

        let chain = Self.chain(preset: activePreset, upscaler: upscaler)
        let imported = importedPipeline
        if imported != nil { watchImported(cmdBuffer) }
        var input = source

        for (index, pass) in chain.enumerated() {
            let isLast = index == chain.count - 1
            let state = isLast ? imported ?? pipeline(fragment: pass.fragment, format: pass.format)
                               : pipeline(fragment: pass.fragment, format: pass.format)
            let passDescriptor: MTLRenderPassDescriptor
            var output: MTLTexture?
            if let passSize = pass.size {
                let pixels = Self.pixelSize(passSize, source: source, viewport: viewport)
                guard let texture = intermediate(at: index, width: pixels.width, height: pixels.height, format: pass.format) else { continue }
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
                guard let self, self.importedPipeline != nil else { return }
                self.importedPipeline = nil
                self.onImportedFailure?()
            }
        }
    }
}
