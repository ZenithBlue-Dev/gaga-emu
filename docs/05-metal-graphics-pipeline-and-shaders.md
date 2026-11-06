# 05 — Metal Graphics Pipeline & Shader Subsystem

Gaga-Emu standardizes on Apple Metal 3 and Metal 4 for all visual output. It completely bypasses legacy OpenGL ES wrappers and maximizes throughput on Apple Silicon Unified Memory Architecture (UMA) using direct Metal Shading Language (MSL) pipelines.

---

## 1. Graphics Subsystem Architecture

```
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                         Emulator Frame Producer                             │
 ├──────────────────────────────────────┬──────────────────────────────────────┤
 │  2D Software Cores                   │  3D Hardware Accelerated Cores       │
 │  (GB, GBA, NES, SNES, Genesis, etc.) │  (PS1, PSP, 3DS, DC, PS2, PS3, PS4)  │
 │  Direct CPU Shared Pixel Buffer      │  Direct Metal Command Buffers        │
 │  [MTLStorageModeShared]              │  [MTLRenderCommandEncoder]           │
 └───────────────────┬──────────────────┴───────────────────┬──────────────────┘
                     │                                      │
                     ▼                                      ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                         Gaga-Emu Metal Post-Processor                       │
 │                                                                             │
 │  ┌───────────────────────────────────────────────────────────────────────┐  │
 │  │ MTKView / CAMetalLayer Surface (Native Display Resolution)            │  │
 │  └───────────────────────────────────┬───────────────────────────────────┘  │
 │                                      │                                      │
 │  ┌───────────────────────────────────┴───────────────────────────────────┐  │
 │  │ Multi-Pass Shader Engine (MSL Render Pipelines)                       │  │
 │  │ • Pass 0: Core Frame Upscaling / Filtering (Bilinear / Bicubic / xBRZ)│  │
 │  │ • Pass 1: CRT Simulation (Curvature, Scanlines, Phosphors, Shadowmask)│  │
 │  │ • Pass 2: Color Space Correction / Bloom / Bezel Compositing          │  │
 │  └───────────────────────────────────────────────────────────────────────┘  │
 └─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Zero-Copy Framebuffer Ingestion via Apple Silicon UMA

On traditional discrete GPUs, transferring CPU-rendered framebuffers requires a costly copy over the PCIe bus. On iOS devices powered by Apple Silicon, the CPU and GPU share a single, unified memory pool.

> **Critical Implementation Note**: Calling `MTLTexture.replace(region:...)` performs a synchronous CPU-to-GPU memory copy, which defeats UMA. True zero-copy requires allocating a shared `MTLBuffer` (`.storageModeShared`) whose raw CPU pointer is written directly by the core interpreter, and binding it as a texture via `device.makeTexture(descriptor:offset:bytesPerRow:)`.

### 2.1 Triple-Buffered Shared Memory Texture Ring
To achieve zero-copy streaming without frame stuttering, thread contention, or CPU stalling:
1. Gaga-Emu allocates three persistent `MTLBuffer` instances with `.storageModeShared` and 256-byte row alignment.
2. The CPU core interpreter writes directly to `buffer.contents()`.
3. An `MTLTexture` overlay is wrapped around the buffer with zero copying.
4. An inflight semaphore synchronizes frames, signaled inside the Metal command buffer's completion handler.

```swift
import Metal
import MetalKit

final class MetalTextureRing {
    private let device: MTLDevice
    private let bufferCount = 3
    private var buffers: [MTLBuffer] = []
    private var textures: [MTLTexture] = []
    private var writeIndex: Int = 0
    private let inflightSemaphore: DispatchSemaphore
    private let bytesPerRow: Int
    private let bufferSize: Int

    init(device: MTLDevice, width: Int, height: Int, pixelFormat: MTLPixelFormat) {
        self.device = device
        self.inflightSemaphore = DispatchSemaphore(value: bufferCount)

        // Metal requires 256-byte row alignment for buffer-backed textures
        let bytesPerPixel = (pixelFormat == .bgra8Unorm || pixelFormat == .rgba8Unorm) ? 4 : 2
        let rawBytesPerRow = width * bytesPerPixel
        self.bytesPerRow = (rawBytesPerRow + 255) & ~255
        self.bufferSize = self.bytesPerRow * height

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead]

        for _ in 0..<bufferCount {
            guard let buf = device.makeBuffer(length: bufferSize, options: .storageModeShared),
                  let tex = buf.makeTexture(descriptor: descriptor, offset: 0, bytesPerRow: bytesPerRow) else {
                fatalError("Failed to allocate zero-copy shared Metal buffer")
            }
            buffers.append(buf)
            textures.append(tex)
        }
    }

    /// Acquires direct raw CPU pointer for the core interpreter to write into
    func acquireWritableBuffer() -> (UnsafeMutableRawPointer, MTLTexture, Int) {
        inflightSemaphore.wait()
        let idx = writeIndex
        writeIndex = (writeIndex + 1) % bufferCount
        return (buffers[idx].contents(), textures[idx], idx)
    }

    /// Called by the Metal render submitter to register completion signaling
    func attachCompletion(to commandBuffer: MTLCommandBuffer) {
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }
    }
}
```

---

## 3. Shaders & Visual Processing Engine (Ref: `0BF2D032`)

As shown in Manic EMU reference image `0BF2D032`, the shader selector provides four distinct tabs: **Default**, **RetroArch**, **Import**, and **Custom**, paired with an interactive real-time preview canvas.

```
   ┌────────────────────────────────────────────────────────┐
   │ ░░░ Shaders                                    (✎) (✕) │
   ├────────────────────────────────────────────────────────┤
   │  [Search Shaders                            ]          │
   ├──────────────┬──────────────┬──────────────┬───────────┤
   │   Default    │  RetroArch   │    Import    │   Custom  │
   ├──────────────┴──────────────┴──────────────┴───────────┤
   │  ┌──────────────────────────────────────────────────┐  │
   │  │   Interactive Real-Time Preview Card             │  │
   │  │   [Live 16-bit Pixel Art Canvas with Active MSL] │  │
   │  └──────────────────────────────────────────────────┘  │
   │                                                        │
   │  ● Original           (Eye Icon)        [Selected]     │
   │  ○ Cartoon            (Eye Icon)                       │
   │  ○ CRT v1             (Eye Icon)                       │
   │  ○ CRT v2             (Eye Icon)                       │
   │  ○ Geom CRT Border    (Eye Icon)                       │
   │  ○ Geom CRT           (Eye Icon)                       │
   │  ○ Film               (Eye Icon)                       │
   └────────────────────────────────────────────────────────┘
```

### 3.1 Built-in MSL Shader Specifications

#### 1. `Original`
- Pure 1:1 pass-through.
- Selectable between Nearest-Neighbor (crisp pixels) and Bilinear filtering.

#### 2. `Cartoon`
- Cel-shaded visual effect.
- Computes Sobel luminance edge gradients in a fragment shader, darkening high-contrast edges and quantizing RGB color channels into 16 distinct palette bands.

#### 3. `CRT v1` (Lightweight Scanlines)
- Ultra-fast single-pass shader designed for minimal thermal impact on older iOS devices.
- Modulates horizontal line luminance using a sine wave function:
  $$\text{Luminance}(y) = 1.0 - \text{Intensity} \cdot \left(\sin\left(\frac{y}{\text{ScreenHeight}} \cdot \text{TargetLines} \cdot \pi\right)\right)^2$$

#### 4. `CRT v2` (Aperture Grille & Phosphors)
- Simulates Sony Trinitron aperture grilles with vertical RGB phosphor triads.
- Sub-pixel phosphor weighting: applies alternating 3-column color filters $(R, G, B)$ mapped to physical screen pixels, paired with subtle horizontal bloom.

#### 5. `Geom CRT Border`
- Composites an authentic vintage CRT television chassis / monitor border around the emulated screen area.
- Includes glass glare reflections and bezel inner shadows.

#### 6. `Geom CRT` (Mathematical Tube Geometry)
- Emulates cathode ray tube barrel distortion by transforming screen coordinates:
  $$p_{\text{distorted}} = p \cdot \left(1.0 + k \cdot (p \cdot p)\right)$$
- Features edge vignette darkening, multi-tap phosphor bleeding, and chromatic aberration.

#### 7. `Film`
- Simulates vintage celluloid film stock.
- Generates dynamic, animated film grain using high-speed pseudorandom noise, paired with 1970s color grading and intermittent dust artifacts.

---

## 4. Community Shader Architecture & Offline Precompilation

To support shaders from the Libretro ecosystem without violating Apple App Store Rule 2.5.2 (which strictly forbids downloading executable code or arbitrary compilers at runtime):
1. **Zero Runtime Compiler Overhead**: Gaga-Emu does **not** ship runtime compiler dependencies (`glslang`, `spirv-cross`) inside the production App Store app.
2. **Offline Toolchain**: The Libretro `.slangp` and `.slang` shader presets are converted offline during build time into precompiled Metal Shading Language (`.metallib`) binaries.
3. **Dynamic Uniform Parameter Updates**: Parameter adjustments (curvature radius, scanline depth, phosphor mask weight, bloom gain) are passed dynamically via a dedicated 256-byte `MTLBuffer` uniform struct:

```metal
// Uniform parameters updated per frame without pipeline recompilation
struct ShaderParameters {
    float curvature;     // 0.0 (flat) to 1.0 (deep barrel)
    float scanline_weight;// 0.0 (off) to 1.0 (heavy)
    float phosphor_glow; // Bloom intensity
    float color_temp;    // Warm (3200K) to Cool (9300K)
    float time;          // Frame timer for dynamic grain
    uint  viewport_w;
    uint  viewport_h;
};
```
Modifying slider values in the SwiftUI settings sheet immediately updates this uniform buffer in shared memory at 60 FPS without ever rebuilding the `MTLRenderPipelineState`.

---

## 5. Live Interactive Shader Preview Card

The preview card shown in screenshot `0BF2D032-B3DB-43DC-B6B2-F084D4B560C8.PNG` solves a classic emulator UX problem: users previously had to launch a game to verify how a shader looked.
- **Embedded `MTKView`**: A miniature Metal view (aspect ratio 4:3) rendered directly inside the SwiftUI Shaders sheet.
- **Dedicated Sample Texture**: Bundles a high-contrast 16-bit retro sprite scene (`shader_preview_sample.png`) featuring vibrant skies, clouds, pixel characters, and ground textures.
- **Instant Parameter Reflection**: As the user taps through presets or drags slider bars for curvature or scanline intensity, the preview `MTKView` updates the uniform buffer values in real-time at 60 FPS without hitching.
