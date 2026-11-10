import Metal
import MetalKit
import Combine
import SwiftUI

public struct MetalPreviewCanvas: UIViewRepresentable {
    @ObservedObject var shaderManager: ShaderManager
    /// Draws the unfiltered picture, for the before and after comparison.
    var unfiltered = false

    public init(shaderManager: ShaderManager = .shared, unfiltered: Bool = false) {
        self.shaderManager = shaderManager
        self.unfiltered = unfiltered
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = shaderManager.device
        mtkView.delegate = unfiltered ? shaderManager.unfilteredRenderer : shaderManager.previewRenderer
        mtkView.clearColor = MTLClearColor(red: 0.043, green: 0.047, blue: 0.063, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 60
        // Reduce Motion and Low Power Mode get a still picture, redrawn only when a choice changes it.
        let still = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        mtkView.enableSetNeedsDisplay = still
        mtkView.isPaused = still
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        // Uniforms and textures are updated dynamically via ShaderManager; a still view draws once per change.
        if uiView.isPaused { uiView.setNeedsDisplay() }
    }
}

public final class ShaderManager: ObservableObject {
    public static let shared = ShaderManager()

    public let device: MTLDevice
    public let previewRenderer: MetalRenderer?
    /// Always Original, on the same picture.
    public let unfilteredRenderer: MetalRenderer?

    @Published public var selectedPreset: ShaderPreset = .original {
        didSet {
            previewRenderer?.activePreset = selectedPreset
            syncUniforms()
        }
    }

    @Published public var curvature: Float = 0.20 {
        didSet { syncUniforms() }
    }

    @Published public var scanlineWeight: Float = 0.50 {
        didSet { syncUniforms() }
    }

    @Published public var phosphorGlow: Float = 0.25 {
        didSet { syncUniforms() }
    }

    @Published public var colorTemp: Float = 0.50 {
        didSet { syncUniforms() }
    }

    @Published public var upscaler: Upscaler = .nearest {
        didSet {
            previewRenderer?.upscaler = upscaler
        }
    }

    public private(set) var previewTexture: MTLTexture?

    public init(device: MTLDevice? = nil) {
        guard let dev = device ?? MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = dev
        self.previewRenderer = MetalRenderer(device: dev)
        self.unfilteredRenderer = MetalRenderer(device: dev)

        createPreviewTexture()
        if let tex = previewTexture { show(tex) }
        syncUniforms()
    }

    private func show(_ texture: MTLTexture) {
        previewRenderer?.setTexture(texture)
        unfilteredRenderer?.setTexture(texture)
        objectWillChange.send()
    }

    /// The picture the preview and the catalogue's tiles are drawn from.
    public var previewSource: MTLTexture? { previewRenderer?.customTexture }

    public func syncUniforms() {
        let uniforms = ShaderUniforms(
            curvature: curvature,
            scanlineWeight: scanlineWeight,
            phosphorGlow: phosphorGlow,
            colorTemp: colorTemp
        )
        previewRenderer?.uniforms = uniforms
    }

    public func select(shaderID: String) {
        previewRenderer?.setImported(nil)
        previewRenderer?.setSlang(nil)
        selectedPreset = ShaderPreset.from(id: shaderID)
    }

    /// Runs an imported filter in the preview. It replaces the selected preset's last pass, so Original goes first.
    public func selectImported(_ pipeline: MTLRenderPipelineState) {
        selectedPreset = .original
        previewRenderer?.setSlang(nil)
        previewRenderer?.setImported(pipeline)
    }

    /// Runs an imported `.slangp` in the preview, in place of the whole chain.
    func selectSlang(_ chain: SlangChain) {
        selectedPreset = .original
        previewRenderer?.setImported(nil)
        previewRenderer?.setSlang(chain)
    }

    public func apply(_ values: ShaderParameterValues) {
        curvature = values.curvature
        scanlineWeight = values.scanlineWeight
        phosphorGlow = values.phosphorGlow
        colorTemp = values.colorTemp
        upscaler = values.resolvedUpscaler
        previewRenderer?.slangValues = values.slang ?? [:]
    }

    public func resetToDefaults() {
        curvature = 0.20
        scanlineWeight = 0.50
        phosphorGlow = 0.25
        colorTemp = 0.50
        upscaler = .nearest
        selectedPreset = .original
        syncUniforms()
    }

    // MARK: - Catalogue tiles

    private lazy var tileRenderer = MetalRenderer(device: device)
    /// Small tiles for rows and galleries. NSCache drops them under memory pressure, so a long scroll stays flat.
    private let tileCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 160
        return cache
    }()

    /// `tile(presetID:)` at row size, kept per preview picture.
    func cachedTile(presetID: String) -> UIImage? {
        let key = "\(presetID)|\(previewSource.map { ObjectIdentifier($0).hashValue } ?? 0)" as NSString
        if let hit = tileCache.object(forKey: key) { return hit }
        guard let image = tile(presetID: presetID, width: 160, height: 120) else { return nil }
        tileCache.setObject(image, forKey: key)
        return image
    }

    /// A small picture of one preset at its default sliders, on the current preview picture. Runs on the main
    /// thread, one tile at a time, as each tile scrolls in. Nil when the GPU has no room for it.
    func tile(presetID: String, width: Int = 240, height: Int = 180) -> UIImage? {
        guard let tileRenderer, let source = previewSource else { return nil }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        guard let target = device.makeTexture(descriptor: desc) else { return nil }
        tileRenderer.activePreset = ShaderPreset.from(id: presetID)
        tileRenderer.apply(ShaderParameterValues())
        tileRenderer.setTexture(source)
        tileRenderer.render(into: target)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        target.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info.rawValue),
              let image = context.makeImage() else { return nil }
        return UIImage(cgImage: image)
    }

    // MARK: - Procedural 16-Bit Retro Scene Generator

    /// Shows the user's picture in the filter preview, or the built-in scene for nil. For this run of the app only.
    /// False when the picture cannot be read.
    @discardableResult public func setPreviewImage(_ image: UIImage?) -> Bool {
        guard let image else {
            if let previewTexture { show(previewTexture) }
            return true
        }
        // Redrawn to apply its orientation and cap its size: a photo can be far larger than the preview needs.
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return false }
        let scale = min(1, 1024 / longest)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // 8-bit and opaque: Automatic can pick a wide-gamut format the texture loader refuses.
        format.preferredRange = .standard
        format.opaque = true
        let size = CGSize(width: max(1, (image.size.width * scale).rounded()), height: max(1, (image.size.height * scale).rounded()))
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let cgImage = drawn.cgImage,
              let texture = try? MTKTextureLoader(device: device).newTexture(cgImage: cgImage, options: [.SRGB: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue]) else { return false }
        show(texture)
        return true
    }

    private func createPreviewTexture() {
        let width = 256
        let height = 224

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: desc) else { return }

        // Generate vibrant 16-bit retro outdoor landscape (sky, sun, clouds, hills, checker ground)
        var pixels = [UInt32](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                var r: UInt8 = 0
                var g: UInt8 = 0
                var b: UInt8 = 0
                let a: UInt8 = 255

                if y < 130 {
                    // Sky gradient: cyan to deep blue
                    let t = Float(y) / 130.0
                    r = UInt8(15.0 + t * 40.0)
                    g = UInt8(120.0 + t * 80.0)
                    b = UInt8(220.0 - t * 30.0)

                    // Sun disc at (200, 40)
                    let dx = x - 195
                    let dy = y - 40
                    if dx * dx + dy * dy < 20 * 20 {
                        r = 255; g = 230; b = 80
                    }

                    // Pixel cloud at (60, 50)
                    let cdx = x - 60
                    let cdy = y - 50
                    if (cdx * cdx) / 36 + (cdy * cdy) / 9 < 16 {
                        r = 245; g = 250; b = 255
                    }
                } else if y < 160 {
                    // Distant green hills
                    let hillCurve = Int(sin(Double(x) * 0.04) * 8.0) + 140
                    if y >= hillCurve {
                        r = 34; g = 139; b = 34
                    } else {
                        r = 80; g = 180; b = 220
                    }
                } else {
                    // Retro checkerboard ground
                    let checkX = (x / 16) % 2
                    let checkY = (y / 16) % 2
                    if (checkX ^ checkY) == 0 {
                        r = 180; g = 110; b = 50 // Dirt/brick light
                    } else {
                        r = 140; g = 80; b = 30  // Dirt/brick dark
                    }
                }

                // Center 16x16 hero sprite character at (120, 150)
                if x >= 120 && x < 136 && y >= 150 && y < 166 {
                    let sx = x - 120
                    let sy = y - 150
                    if sy < 6 {
                        r = 240; g = 40; b = 40 // Red cap
                    } else if sy < 11 {
                        r = 255; g = 200; b = 150 // Face
                        if sx == 6 || sx == 10 { r = 0; g = 0; b = 0 } // Eyes
                    } else {
                        r = 30; g = 60; b = 200 // Blue overalls
                    }
                }

                // Little-endian RGBA
                pixels[y * width + x] = (UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(g) << 8) | UInt32(r)
            }
        }

        let region = MTLRegionMake2D(0, 0, width, height)
        pixels.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                texture.replace(region: region, mipmapLevel: 0, withBytes: base, bytesPerRow: width * 4)
            }
        }

        self.previewTexture = texture
    }
}
