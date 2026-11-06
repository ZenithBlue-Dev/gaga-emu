import Metal
import MetalKit
import Combine
import SwiftUI

public struct MetalPreviewCanvas: UIViewRepresentable {
    @ObservedObject var shaderManager: ShaderManager

    public init(shaderManager: ShaderManager = .shared) {
        self.shaderManager = shaderManager
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = shaderManager.device
        mtkView.delegate = shaderManager.previewRenderer
        mtkView.clearColor = MTLClearColor(red: 0.043, green: 0.047, blue: 0.063, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        // Uniforms and textures are updated dynamically via ShaderManager
    }
}

public final class ShaderManager: ObservableObject {
    public static let shared = ShaderManager()

    public let device: MTLDevice
    public let previewRenderer: MetalRenderer?

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

    @Published public var useLinearFilter: Bool = false {
        didSet {
            previewRenderer?.useLinearFilter = useLinearFilter
        }
    }

    public private(set) var previewTexture: MTLTexture?

    public init(device: MTLDevice? = nil) {
        guard let dev = device ?? MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = dev
        self.previewRenderer = MetalRenderer(device: dev)

        createPreviewTexture()
        if let tex = previewTexture {
            previewRenderer?.setTexture(tex)
        }
        syncUniforms()
    }

    public func syncUniforms() {
        let uniforms = ShaderUniforms(
            curvature: curvature,
            scanlineWeight: scanlineWeight,
            phosphorGlow: phosphorGlow,
            colorTemp: colorTemp,
            time: 0.0,
            viewportW: 256,
            viewportH: 224
        )
        previewRenderer?.uniforms = uniforms
    }

    public func select(shaderID: String) {
        selectedPreset = ShaderPreset.from(id: shaderID)
    }

    public func resetToDefaults() {
        curvature = 0.20
        scanlineWeight = 0.50
        phosphorGlow = 0.25
        colorTemp = 0.50
        useLinearFilter = false
        selectedPreset = .original
        syncUniforms()
    }

    // MARK: - Procedural 16-Bit Retro Scene Generator

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
