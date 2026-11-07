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
        }
    }

    public static func from(id: String) -> ShaderPreset {
        switch id {
        case "cartoon": return .cartoon
        case "crt-v1", "crt_v1": return .crtV1
        case "crt-v2", "crt_v2": return .crtV2
        case "geom-crt", "geom_crt": return .geomCrt
        case "geom-crt-border", "geom_crt_border": return .geomCrtBorder
        case "film": return .film
        default: return .original
        }
    }

    public var fragmentFunctionName: String {
        switch self {
        case .original: return "original_fragment"
        case .cartoon: return "cartoon_fragment"
        case .crtV1: return "crt_v1_fragment"
        case .crtV2: return "crt_v2_fragment"
        case .geomCrt: return "geom_crt_fragment"
        case .geomCrtBorder: return "geom_crt_border_fragment"
        case .film: return "film_fragment"
        }
    }
}

public struct ShaderUniforms {
    public var curvature: Float = 0.0
    public var scanlineWeight: Float = 0.5
    public var phosphorGlow: Float = 0.2
    public var colorTemp: Float = 0.5
    public var time: Float = 0.0
    public var viewportW: UInt32 = 0
    public var viewportH: UInt32 = 0

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
/// Layer-path cores gate on this when they arrive (milestone 5.1).
public enum GPUFloor {
    public static let layerPathMessage = "This system's 3D renderer needs an A14 chip or newer. 2D systems still work on this device."

    public static func supportsLayerPathCores(_ device: MTLDevice) -> Bool {
        device.supportsFamily(.apple7)
    }
}

public final class MetalRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    private var defaultLibrary: MTLLibrary?
    private var pipelineStates: [ShaderPreset: MTLRenderPipelineState] = [:]
    private var nearestSampler: MTLSamplerState?
    private var linearSampler: MTLSamplerState?

    private var uniformBuffer: MTLBuffer?
    public var uniforms = ShaderUniforms()
    public var activePreset: ShaderPreset = .original
    public var useLinearFilter: Bool = false

    public weak var textureRing: MetalTextureRing?
    public var customTexture: MTLTexture?

    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private let lock = NSLock()

    public init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        super.init()

        setupShaders()
        setupSamplers()
        setupUniformBuffer()
    }

    private func setupShaders() {
        // Attempt default bundle library, fallback to compiling embedded MSL source
        if let library = device.makeDefaultLibrary() {
            self.defaultLibrary = library
        } else if let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
                  let library = try? device.makeLibrary(URL: url) {
            self.defaultLibrary = library
        } else {
            // Compile from source if metallib not yet built
            let mslSource = MetalRenderer.embeddedShaderSource()
            if let library = try? device.makeLibrary(source: mslSource, options: nil) {
                self.defaultLibrary = library
            }
        }

        guard let library = defaultLibrary,
              let vertexFunc = library.makeFunction(name: "vertex_main") else {
            return
        }

        for preset in ShaderPreset.allCases {
            guard let fragFunc = library.makeFunction(name: preset.fragmentFunctionName) else {
                continue
            }

            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertexFunc
            desc.fragmentFunction = fragFunc
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm

            if let pso = try? device.makeRenderPipelineState(descriptor: desc) {
                pipelineStates[preset] = pso
            }
        }
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

    private func setupUniformBuffer() {
        let size = MemoryLayout<ShaderUniforms>.stride
        uniformBuffer = device.makeBuffer(length: max(size, 256), options: .storageModeShared)
    }

    public func setTexture(_ texture: MTLTexture) {
        lock.lock()
        self.customTexture = texture
        lock.unlock()
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        lock.lock()
        uniforms.viewportW = UInt32(size.width)
        uniforms.viewportH = UInt32(size.height)
        lock.unlock()
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmdBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        lock.lock()
        let currentTexture = self.customTexture
        let currentPreset = self.activePreset
        let filterLinear = self.useLinearFilter
        var currentUniforms = self.uniforms
        lock.unlock()

        guard let targetTexture = currentTexture else {
            // No texture to render, clear to dark OLED
            rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0.043, green: 0.047, blue: 0.063, alpha: 1.0)
            if let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: rpd) {
                encoder.endEncoding()
            }
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
            return
        }

        // Releases one acquired ring slot, if any is waiting. Attaches nothing on a repeat draw.
        textureRing?.attachCompletion(to: cmdBuffer)

        guard let pipelineState = pipelineStates[currentPreset] ?? pipelineStates[.original],
              let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: rpd) else {
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
            return
        }

        // Update uniforms
        let elapsed = Float(CACurrentMediaTime() - startTime)
        currentUniforms.time = elapsed
        if currentUniforms.viewportW == 0 {
            currentUniforms.viewportW = UInt32(view.drawableSize.width)
            currentUniforms.viewportH = UInt32(view.drawableSize.height)
        }

        if let uBuf = uniformBuffer {
            memcpy(uBuf.contents(), &currentUniforms, MemoryLayout<ShaderUniforms>.size)
            encoder.setFragmentBuffer(uBuf, offset: 0, index: 0)
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(targetTexture, index: 0)

        let sampler = filterLinear ? linearSampler : nearestSampler
        encoder.setFragmentSamplerState(sampler, index: 0)

        // Draw fullscreen quad (6 vertices)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        cmdBuffer.present(drawable)
        cmdBuffer.commit()
    }

    private static func embeddedShaderSource() -> String {
        return """
        #include <metal_stdlib>
        using namespace metal;

        struct ShaderParameters {
            float curvature;
            float scanline_weight;
            float phosphor_glow;
            float color_temp;
            float time;
            uint  viewport_w;
            uint  viewport_h;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };

        vertex VertexOut vertex_main(uint vertex_id [[vertex_id]]) {
            const float2 positions[6] = {
                float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0),
                float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)
            };
            const float2 uvs[6] = {
                float2(0.0, 1.0), float2(1.0, 1.0), float2(0.0, 0.0),
                float2(0.0, 0.0), float2(1.0, 1.0), float2(1.0, 0.0)
            };
            VertexOut out;
            out.position = float4(positions[vertex_id], 0.0, 1.0);
            out.uv = uvs[vertex_id];
            return out;
        }

        static inline float luminance(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
        static inline float3 apply_temp(float3 c, float t) {
            float3 w = float3(1.10, 0.96, 0.85);
            float3 cool = float3(0.88, 0.98, 1.12);
            return clamp(c * mix(w, cool, clamp(t, 0.0, 1.0)), 0.0, 1.0);
        }
        static inline float hash(float2 p) {
            float3 p3 = fract(float3(p.xyx) * 0.1031);
            p3 += dot(p3, p3.yzx + 33.33);
            return fract((p3.x + p3.y) * p3.z);
        }
        static inline float2 curve(float2 uv, float k) {
            float2 p = uv * 2.0 - 1.0;
            p = p * (1.0 + k * dot(p, p));
            return p * 0.5 + 0.5;
        }

        fragment float4 original_fragment(VertexOut in [[stage_in]],
                                          texture2d<float> tex [[texture(0)]],
                                          sampler s [[sampler(0)]],
                                          constant ShaderParameters& p [[buffer(0)]]) {
            float4 c = tex.sample(s, in.uv);
            return float4(apply_temp(c.rgb, p.color_temp), c.a);
        }

        fragment float4 cartoon_fragment(VertexOut in [[stage_in]],
                                         texture2d<float> tex [[texture(0)]],
                                         sampler s [[sampler(0)]],
                                         constant ShaderParameters& p [[buffer(0)]]) {
            float2 step = 1.0 / max(float2(tex.get_width(), tex.get_height()), float2(1.0));
            float lum[3][3];
            for (int y = -1; y <= 1; ++y) {
                for (int x = -1; x <= 1; ++x) {
                    lum[y+1][x+1] = luminance(tex.sample(s, in.uv + float2(x, y) * step).rgb);
                }
            }
            float gx = -lum[0][0] - 2.0*lum[1][0] - lum[2][0] + lum[0][2] + 2.0*lum[1][2] + lum[2][2];
            float gy = -lum[0][0] - 2.0*lum[0][1] - lum[0][2] + lum[2][0] + 2.0*lum[2][1] + lum[2][2];
            float edge = sqrt(gx*gx + gy*gy);
            float4 center = tex.sample(s, in.uv);
            float3 q = floor(center.rgb * 16.0 + 0.5) / 16.0;
            float3 res = mix(q, float3(0.05), smoothstep(0.15, 0.35, edge));
            return float4(apply_temp(res, p.color_temp), 1.0);
        }

        fragment float4 crt_v1_fragment(VertexOut in [[stage_in]],
                                        texture2d<float> tex [[texture(0)]],
                                        sampler s [[sampler(0)]],
                                        constant ShaderParameters& p [[buffer(0)]]) {
            float4 c = tex.sample(s, in.uv);
            float lines = float(tex.get_height() > 0 ? tex.get_height() : 224);
            float scan = sin(in.uv.y * lines * M_PI_F);
            float factor = 1.0 - (p.scanline_weight * 0.45) * (scan * scan);
            return float4(apply_temp(c.rgb * factor, p.color_temp), c.a);
        }

        fragment float4 crt_v2_fragment(VertexOut in [[stage_in]],
                                        texture2d<float> tex [[texture(0)]],
                                        sampler s [[sampler(0)]],
                                        constant ShaderParameters& p [[buffer(0)]]) {
            float2 step = 1.0 / max(float2(tex.get_width(), tex.get_height()), float2(1.0));
            float3 bloom = (tex.sample(s, in.uv - float2(step.x*0.5, 0.0)).rgb * 0.25 +
                            tex.sample(s, in.uv).rgb * 0.50 +
                            tex.sample(s, in.uv + float2(step.x*0.5, 0.0)).rgb * 0.25);
            float3 base = mix(tex.sample(s, in.uv).rgb, bloom, clamp(p.phosphor_glow, 0.0, 1.0));
            uint mod3 = uint(in.position.x) % 3;
            float3 mask = (mod3 == 0) ? float3(1.25, 0.70, 0.70) : ((mod3 == 1) ? float3(0.70, 1.25, 0.70) : float3(0.70, 0.70, 1.25));
            float lines = float(tex.get_height() > 0 ? tex.get_height() : 240);
            float scan = sin(in.uv.y * lines * M_PI_F);
            float factor = 1.0 - (p.scanline_weight * 0.35) * (scan * scan);
            return float4(apply_temp(clamp(base * mask * factor, 0.0, 1.0), p.color_temp), 1.0);
        }

        fragment float4 geom_crt_fragment(VertexOut in [[stage_in]],
                                          texture2d<float> tex [[texture(0)]],
                                          sampler s [[sampler(0)]],
                                          constant ShaderParameters& p [[buffer(0)]]) {
            float2 cuv = curve(in.uv, p.curvature * 0.30);
            if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) return float4(0.0, 0.0, 0.0, 1.0);
            float2 ca = (cuv - 0.5) * dot(cuv - 0.5, cuv - 0.5) * 0.035;
            float r = tex.sample(s, cuv + ca).r;
            float g = tex.sample(s, cuv).g;
            float b = tex.sample(s, cuv - ca).b;
            float scan = sin(cuv.y * 240.0 * M_PI_F);
            float sm = 1.0 - (p.scanline_weight * 0.40) * (scan * scan);
            float vig = clamp(1.0 - dot(cuv*2.0 - 1.0, cuv*2.0 - 1.0)*0.35, 0.0, 1.0);
            return float4(apply_temp(clamp((float3(r, g, b) * sm + float3(r, g, b) * (p.phosphor_glow * 0.15)) * vig, 0.0, 1.0), p.color_temp), 1.0);
        }

        fragment float4 geom_crt_border_fragment(VertexOut in [[stage_in]],
                                                 texture2d<float> tex [[texture(0)]],
                                                 sampler s [[sampler(0)]],
                                                 constant ShaderParameters& p [[buffer(0)]]) {
            if (in.uv.x < 0.10 || in.uv.x > 0.90 || in.uv.y < 0.10 || in.uv.y > 0.90) {
                return float4(mix(0.18, 0.08, clamp(length(in.uv * 2.0 - 1.0) * 0.7, 0.0, 1.0)));
            }
            float2 suv = (in.uv - 0.10) / 0.80;
            float2 cuv = curve(suv, max(p.curvature * 0.25, 0.08));
            if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) return float4(0.04, 0.04, 0.05, 1.0);
            float4 sample = tex.sample(s, cuv);
            float edge = min(min(cuv.x, 1.0 - cuv.x), min(cuv.y, 1.0 - cuv.y));
            float shadow = smoothstep(0.0, 0.06, edge);
            float glare = 0.04 * max(0.0, 1.0 - abs(cuv.x + cuv.y * 0.8 - 0.8) * 4.0);
            float scan = sin(cuv.y * 240.0 * M_PI_F);
            return float4(apply_temp(clamp((sample.rgb * (1.0 - p.scanline_weight * 0.35 * scan * scan) + glare) * shadow, 0.0, 1.0), p.color_temp), 1.0);
        }

        fragment float4 film_fragment(VertexOut in [[stage_in]],
                                      texture2d<float> tex [[texture(0)]],
                                      sampler s [[sampler(0)]],
                                      constant ShaderParameters& p [[buffer(0)]]) {
            float4 c = tex.sample(s, in.uv);
            float time_step = floor(p.time * 24.0);
            float noise = hash(in.uv * float2(p.viewport_w > 0 ? p.viewport_w : 800, p.viewport_h > 0 ? p.viewport_h : 600) + float2(time_step * 17.13, time_step * 31.71));
            float grain = (noise - 0.5) * 0.16;
            float3 warm = float3(pow(c.r, 0.90) * 1.08, c.g * 0.98, pow(c.b, 1.15) * 0.88);
            float dust = (hash(float2(time_step * 7.7, 91.3)) > 0.92 && distance(in.uv, float2(hash(float2(time_step, 1.0)), hash(float2(time_step, 2.0)))) < 0.006) ? 0.45 : 0.0;
            return float4(apply_temp(clamp(warm + grain - dust, 0.0, 1.0), p.color_temp), c.a);
        }
        """
    }
}
