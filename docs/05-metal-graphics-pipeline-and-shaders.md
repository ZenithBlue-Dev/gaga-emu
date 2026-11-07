# 05 — Metal Graphics Pipeline & Shader Subsystem

This document specifies how frames reach the screen and how shaders are applied. `docs/03` is canonical for the core list and each core's renderer, `docs/06` for the bridge API and for which shaders are premium, and `docs/07` for phases and status. MoltenVK counts as Metal for this project (owner decision, 2026-11-07).

No performance number in this document is a measurement. The 60 frames per second in `ShaderManager.swift` is a requested rate (`preferredFramesPerSecond`), not a result.

---

## Status

The app today is a shell plus a mock core. No core frame reaches the screen, because no game view exists and `AppState.launch` only records state.

| Item | Status | Where |
|---|---|---|
| Texture ring: three shared `MTLBuffer` slots, memcpy through `writeFrame` | built, no callers in `Sources` | `Sources/Metal/MetalTextureRing.swift` |
| Single-pass renderer and seven MSL presets | built, used only by the preview | `Sources/Metal/MetalRenderer.swift`, `Shaders.metal` |
| Shader preview canvas with a procedural texture | built | `Sources/Metal/ShaderManager.swift` |
| Shader picker, Default tab | built | `Sources/UI/Settings/ShadersSettingsView.swift` |
| Shader picker, RetroArch, Import and Custom tabs | stub: tabs exist, nothing can be added | same file |
| Game view presenting a core frame | planned | none |
| Host-buffer path | planned | none |
| Core-owned layer path | stub: `attach_metal_layer` is in the bridge, no core implements it, MoltenVK is not linked | `Sources/Bridge/GagaBridge.h:92` |
| Core-output texture path | planned | none |
| Multi-pass chain, Bicubic and xBRZ upscalers, parameter sliders | planned: slider properties exist, no `Slider` exists in `Sources` | none |
| `anime4k`, `crt-royale` | planned: neither is in the catalog, and a saved selection resets to Original | none |

---

## 1. Graphics Rules

1. App UI, frame presentation and the host post-process chain use native Metal.
2. 2D and software-rendered cores send their frame through the host texture ring and the Metal shader chain.
3. 3D cores use Vulkan on statically linked MoltenVK, rendering to a `CAMetalLayer`. This is the pattern S3 and S4 use (`S3/ios/SambaS3/App/Game/GameView.swift:7`, `S3/docs/ios/moltenvk-rsx-feature-map.md:3`). A native Metal backend is allowed where upstream has one; PPSSPP has `Common/GPU/Metal`, excluded from its libretro build, and which release ships it is unverified (`docs/03`).
4. GLES-only and desktop-GL-only renderers are not an accepted path. Such a core needs a Vulkan, Metal or software renderer, or it is out. libretro has no Metal context type: its enum stops at OpenGL variants, Vulkan, Direct3D and RSX ([libretro.h](https://raw.githubusercontent.com/libretro/libretro-common/master/include/libretro.h)).
5. PS3 and PS4 are external sister projects (S3, S4). They are never catalog rows or frame producers here. S2 and PS2 are non-shipping research.

### GPU support

A14 required for layer-path 3D cores; 2D cores have no such floor. A14 (Apple7) is the lowest family with Metal 3 ([Metal Feature Set Tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf)). Metal 4 is optional and never baseline with iOS 17.0 as the minimum.

The app does not refuse older devices. iOS 17.0 also runs on A12 and A13, `Info.plist` requires only `arm64` and `metal`, and no code in `Sources` uses a Metal 3 API, so 2D cores run on any Metal device. `GPUFloor.supportsLayerPathCores` (`device.supportsFamily(.apple7)`, in `Sources/Metal/MetalRenderer.swift`) is the check future layer-path cores gate on, with `GPUFloor.layerPathMessage` as the user-facing text (milestone 5.1).

---

## 2. Frame Paths

```
 Software renderer ── GagaFrameDescriptor ── memcpy into ring slot ──┐
 Software renderer ── writes ring slot directly (planned) ───────────┤
 Vulkan or Metal renderer ── off-screen MTLTexture (planned) ────────┤
                                                                     ▼
                                       MetalRenderer: host shader chain
                                                                     │
                                                                     ▼
 Vulkan or Metal renderer, owns the layer ───────────────────► CAMetalLayer
 (host shader chain skipped)
```

### 2.1 Copy path: ring and memcpy

This is the default for software-rendered cores, including libretro cores. A core's video callback delivers a `GagaFrameDescriptor`, and the host copies it row by row into the next ring slot with `MetalTextureRing.writeFrame`. This path copies once per frame and is not zero copy.

Each slot is a `.storageModeShared` `MTLBuffer` with a texture created from it by `MTLBuffer.makeTexture(descriptor:offset:bytesPerRow:)`, a method on the buffer rather than the device ([Apple documentation](https://developer.apple.com/tutorials/data/documentation/metal/mtlbuffer/maketexture(descriptor:offset:bytesperrow:).json)). The texture shares storage with the buffer, so the GPU reads what the CPU wrote without a blit. The CPU copy out of the core's own buffer still happens.

Row alignment comes from the device and must not be hard-coded.

```swift
let alignment = device.minimumLinearTextureAlignment(for: pixelFormat)
let bytesPerRow = ((width * bytesPerPixel + alignment - 1) / alignment) * alignment
```

| `GagaPixelFormat` | `MTLPixelFormat` | Note |
|---|---|---|
| `GAGA_PIXEL_FORMAT_RGB565` | `.b5g6r5Unorm` | |
| `GAGA_PIXEL_FORMAT_XRGB8888` | `.bgra8Unorm` | The X byte is undefined, so presets must not depend on sampled alpha. |
| `GAGA_PIXEL_FORMAT_RGBA8888` | `.rgba8Unorm` | |

An inflight semaphore bounds the ring at three slots, and `acquireWritableBuffer` blocks the emulation thread when all three are in flight. Each acquire pairs with exactly one completion signal: `MetalRenderer.draw` calls `attachCompletion` on every draw with a texture, and it attaches nothing unless an acquire is waiting. The simulator cannot use buffer-backed linear textures, so the ring falls back to `texture.replace` there.

### 2.2 Host-buffer path (planned)

A core that can render into caller-supplied memory receives the current ring slot through `set_host_framebuffer` (`docs/06`, section 2.4) and writes to `buffer.contents()` directly. This is the only path that may be described as zero copy. The core must honour the host's `bytes_per_row` and pixel format.

libretro cores stay on the copy path unless a specific core is shown to use this API. libretro does define `RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER`, but it is marked experimental and a core may ignore it. An adapter could back it with a ring slot, and a per-core check must confirm the frames actually land there before the copy is dropped for that core.

### 2.3 Core-owned layer path

The host hands the core a `CAMetalLayer` through `attach_metal_layer`, and the core presents directly. The host shader chain does not run. S3 and S4 use this pattern (`SambaBridge.h:53-54`, `BachataBridge.h:271-274`), and both pass pixel size and support detach; GagaEmu's bridge needs the same additions (`docs/06`, section 2.4).

libretro Vulkan cores differ, because under libretro the frontend owns the Vulkan context (`RETRO_HW_CONTEXT_VULKAN`, [libretro_vulkan.h](https://raw.githubusercontent.com/libretro/libretro-common/master/include/libretro_vulkan.h)). A GagaEmu libretro adapter must create the instance and device on MoltenVK, accept the core's image, and present it to the layer. Seen from the bridge, the adapter is what owns the layer. This adapter does not exist yet.

### 2.4 Core-output texture path (planned)

A core renders off-screen and hands the host an `MTLTexture`, created on the same `MTLDevice`, which the host feeds to the shader chain. Native Metal backends can do this directly. For Vulkan on MoltenVK the route is `VK_EXT_metal_objects`, which the [MoltenVK user guide](https://raw.githubusercontent.com/KhronosGroup/MoltenVK/main/Docs/MoltenVK_Runtime_UserGuide.md) lists as supported; it is unverified in this project.

This path is an optional improvement. v1 ships without it, and section 2.5 is the rule until it exists.

### 2.5 Which cores skip host shaders

`docs/03` owns each core's renderer; this table states the consequence. A core on the layer path skips host shaders, and the Shaders row is disabled for its games with the reason shown. The Premium Filters entitlement does not cover those cores until the output-texture path exists (`docs/06` section 4.3).

| Path | Host shaders | Cores |
|---|---|---|
| Copy, or host buffer where proven | Run | Game Boy and GBC, GBA, NES, SNES, Genesis and Mega-CD, PS1 with PCSX-ReARMed or with Beetle PSX HW in software mode, DS, Saturn, Arcade, DOS and Win9x |
| Core-owned layer | Skipped until the output-texture path exists for that core | N64 with ParaLLEl-RDP, PS1 with Beetle PSX HW in Vulkan mode, PSP, Dreamcast, 3DS |
| Undetermined | Decided by the spike | Java ME (J2meJS) and Symbian (EKA2L1). Symbian's iOS path links OpenGLES.framework today, so it is out under rule 4 unless a Vulkan or software renderer is proven. |

Two entries carry conditions from `docs/03`. N64 fails the no-JIT gate as configured upstream until an interpreter RSP is proven usable, and ParaLLEl-RDP's Vulkan requirements on MoltenVK are unverified. The Dreamcast fork's renderer is unverified. Azahar can also fall back to its software renderer, which would move it to the copy path. `docs/07` tracks these spikes.

---

## 3. Shader Picker

Seen in screenshot `0BF2D032`: a sheet with an edit button and a close button, a search field, the tabs Default, RetroArch, Import and Custom, a preview card with an image button, and a list where each row has a preview (eye) control and a separate selection control.

Status in GagaEmu: search field, tabs, preview card and list are built. The edit button and image button are planned. The eye icon currently shows selection rather than acting as a separate preview control.

### 3.1 Built-in presets

These descriptions match `Sources/Metal/Shaders.metal`. Each preset also applies the colour temperature tint. Premium assignment is in `docs/06`.

| Preset ID | Label | Behaviour |
|---|---|---|
| `original` | Original | Samples the frame. Nearest or linear comes from `useLinearFilter`, which has no UI yet. |
| `cartoon` | Cartoon | Sobel luminance edges darken high-contrast pixels. Colour is quantized with `floor(c * 16 + 0.5) / 16`, which yields 17 values per channel. |
| `crt-v1` | CRT v1 | Sine-squared scanline modulation of luminance. |
| `crt-v2` | CRT v2 | Vertical R, G, B stripe mask plus scanlines. |
| `geom-crt-border` | Geom CRT Border | Procedural bezel around an active area of 0.12 to 0.88, with inner shadow, diagonal glare and scanlines. It uses no image asset. |
| `geom-crt` | Geom CRT | Barrel distortion scaled by `curvature`, edge chromatic aberration, scanlines, vignette and glow. |
| `film` | Film | Grain stepped at 24 Hz, warm colour grading, and occasional dust marks. |

### 3.2 Parameters

`ShaderParameters` in `Shaders.metal` and `ShaderUniforms` in `MetalRenderer.swift` carry the values below, in a shared buffer of at least 256 bytes. Values can change without rebuilding a pipeline state. No slider writes them yet.

```metal
struct ShaderParameters {
    float curvature;       // 0.0 (flat) to 1.0 (deep barrel)
    float scanline_weight; // 0.0 (off) to 1.0 (heavy)
    float phosphor_glow;   // Bloom intensity
    float color_temp;      // 0.0 warm, 0.5 neutral, 1.0 cool (a normalized tint, not Kelvin)
    float time;            // Frame timer for dynamic animation and grain
    uint  viewport_w;      // Output viewport width in pixels
    uint  viewport_h;      // Output viewport height in pixels
};
```

### 3.3 Preview card

`MetalPreviewCanvas` is an `MTKView` inside the sheet that runs the selected preset's real MSL pipeline over a procedural texture generated in `ShaderManager.swift:108-201`. No sample image is bundled. The pixel-art scene and image button are seen in screenshot `0BF2D032`; letting the user change the preview image is planned. A stale comment in `ShadersSettingsView.swift` still describes a stand-in preview and is tracked in `docs/07`.

### 3.4 Multi-pass chain (planned)

`MetalRenderer.draw` runs one fragment pass. The planned chain has an upscaling pass (Nearest, Bilinear, Bicubic or xBRZ), a CRT pass, and a colour or bezel compositing pass. `anime4k` and `crt-royale` belong here and stay off the premium list until implemented.

---

## 4. Runtime Shader Policy

The rule against generating CPU code is separate from GPU shaders. No shipped core may generate or execute CPU code at runtime (`docs/04`). GPU shader compilation is a different matter: MoltenVK and SPIRV-Cross translate GPU shaders at runtime in S3 and S4, and that is accepted here. Guideline 2.5.2 is not treated as a compiler ban.

| Source | Mechanism | Status |
|---|---|---|
| Built-in presets | Bundled metallib, with `makeLibrary(source:)` as fallback (`MetalRenderer.swift:121`) | built |
| Import tab, `.metal` | Runtime `makeLibrary(source:)` on a user-selected file. A compile failure shows the error and selects Original. | planned |
| Import tab, `.slangp` and `.slang` | Needs a translation path from Slang to MSL, for example glslang and SPIRV-Cross. The tools and where they run are undecided. | planned |
| RetroArch tab | Curated presets converted offline and bundled. Each preset's licence is recorded before it ships, since these are third-party works. | planned |
| Custom tab | User-edited parameter sets over existing presets. The exact scope is undecided. | planned |
