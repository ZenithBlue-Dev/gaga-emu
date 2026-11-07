# 05 — Metal Graphics Pipeline & Shader Subsystem

This document specifies how frames reach the screen and how shaders are applied. `docs/03` is canonical for the core list and each core's renderer, `docs/06` for the bridge API and for which shaders are premium, and `docs/07` for phases and status. MoltenVK counts as Metal for this project (owner decision, 2026-11-07).

No performance number in this document is a measurement. The 60 frames per second in `ShaderManager.swift` is a requested rate (`preferredFramesPerSecond`), not a result.

---

## Status

The app presents frames from the mock core through the copy path. No real core is integrated.

| Item | Status | Where |
|---|---|---|
| Texture ring: three shared `MTLBuffer` slots, memcpy through `writeFrame` | built | `Sources/Metal/MetalTextureRing.swift` |
| Multi-pass renderer and nine built-in presets, checked on mGBA frames in the simulator | built | `Sources/Metal/MetalRenderer.swift`, `Shaders.metal`, `Anime4K.metal` |
| Shader preview canvas with a procedural texture | built | `Sources/Metal/ShaderManager.swift` |
| Filter picker: built-in, Community and Imported sections, upscaler and sliders saved per filter | built | `Sources/UI/Settings/FilterPickerView.swift` |
| Community presets, converted offline from public-domain files | built: three | `Sources/Metal/CommunityShaders.metal`, section 5 |
| Import `.metal` | built | `Sources/Metal/ImportedFilter.swift`, section 4.1 |
| Import `.slangp` and `.slang` | planned, deferred to after milestone 5.1: no tab or button until it exists | section 4 |
| Custom presets | planned: the per-filter sliders cover the common case | section 4 |
| Game view presenting a core frame | built, on the mock core | `Sources/UI/Game/GameView.swift` |
| Host-buffer path | planned | none |
| Core-owned layer path | built: MoltenVK v1.4.2 as one shared framework that each layer-path core links, the libretro Vulkan context, proved by the Vulkan test core | `Cores/shared/LibretroVulkan.c`, `Cores/vktest`, section 2.3 |
| Core-output texture path | planned | none |
| Multi-pass chain, Nearest, Bilinear, Bicubic and Edge Smooth upscalers | built | section 3.4 |
| `anime4k` (MIT port) and `crt-deluxe` (original) | built, premium | sections 3.1 and 5 |
| `crt-royale`, xBRZ | not shipped: both are GPL | section 5 |

---

## 1. Graphics Rules

1. App UI, frame presentation and the host post-process chain use native Metal.
2. 2D and software-rendered cores send their frame through the host texture ring and the Metal shader chain.
3. 3D cores use Vulkan on one embedded MoltenVK framework that every such core links, rendering to a `CAMetalLayer`. This is the pattern S3 and S4 use (`S3/ios/SambaS3/App/Game/GameView.swift:7`, `S3/docs/ios/moltenvk-rsx-feature-map.md:3`). A native Metal backend is allowed where upstream has one; PPSSPP has `Common/GPU/Metal`, excluded from its libretro build, and which release ships it is unverified (`docs/03`).
4. GLES-only and desktop-GL-only renderers are not an accepted path. Such a core needs a Vulkan, Metal or software renderer, or it is out. libretro has no Metal context type: its enum stops at OpenGL variants, Vulkan, Direct3D and RSX ([libretro.h](https://raw.githubusercontent.com/libretro/libretro-common/master/include/libretro.h)).
5. PS3 and PS4 are external sister projects (S3, S4). They are never catalog rows or frame producers here. S2 and PS2 are non-shipping research.

### GPU support

A14 required for layer-path 3D cores; 2D cores have no such floor. A14 (Apple7) is the lowest family with Metal 3 ([Metal Feature Set Tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf)). Metal 4 is optional and never baseline with iOS 17.0 as the minimum.

The app does not refuse older devices. iOS 17.0 also runs on A12 and A13, `Info.plist` requires only `arm64` and `metal`, and no code in `Sources` uses a Metal 3 API, so 2D cores run on any Metal device. `GPUFloor.supportsLayerPathCores` (`device.supportsFamily(.apple7)`, in `Sources/Metal/MetalRenderer.swift`) is the check layer-path cores gate on: `GameSession` refuses one below Apple7 with `GPUFloor.layerPathMessage` as the user-facing text (milestone 5.1).

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

An inflight semaphore bounds the ring at three slots. `acquireWritableBuffer` does not block: when all three are in flight it returns nil and the frame is dropped and counted. Blocking would deadlock, because a pause or teardown waits for the frame in flight on the main thread, which is the thread whose draws release slots. Each acquire pairs with exactly one completion signal: `MetalRenderer.draw` calls `attachCompletion` on every draw with a texture, and it attaches nothing unless an acquire is waiting.

The ring changes size and format whenever a frame's descriptor does. The renderer sets an aspect-fit viewport and clears to the ink letterbox colour, in both appearances. `shortcut:` it assumes square pixels, so a core with a non-square display aspect looks stretched until the bridge reports the aspect.

The simulator cannot use buffer-backed linear textures, so the ring falls back to `texture.replace` there. Its GPU also has no 16-bit formats, so RGB565 frames are expanded to BGRA there. The real `.b5g6r5Unorm` path runs only on a device.

### 2.2 Host-buffer path (planned)

A core that can render into caller-supplied memory receives the current ring slot through `set_host_framebuffer` (`docs/06`, section 2.4) and writes to `buffer.contents()` directly. This is the only path that may be described as zero copy. The core must honour the host's `bytes_per_row` and pixel format.

libretro cores stay on the copy path unless a specific core is shown to use this API. libretro does define `RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER`, but it is marked experimental and a core may ignore it. An adapter could back it with a ring slot, and a per-core check must confirm the frames actually land there before the copy is dropped for that core.

### 2.3 Core-owned layer path

The host hands the core a `CAMetalLayer` through `attach_metal_layer`, with the drawable size in pixels and the scale, and the core presents directly. The host shader chain does not run. S3 and S4 use this pattern (`SambaBridge.h:53-54`, `BachataBridge.h:271-274`). `GAGA_CORE_CAP_METAL_LAYER` marks such a core (`docs/06` section 2.4).

**Host.** `GamePicture` puts a `MetalLayerView` (a `UIView` backed by `CAMetalLayer`, ink background) in place of the `MTKView`. It attaches on every pixel-size change and detaches when it leaves its window. A turn between landscape left and landscape right keeps the size, so it changes nothing. `GameSession` keeps the layer until the core exists, and detaches only the layer attached last. Pause waits for the GPU to go idle, which keeps GPU work out of the background. A layer-path core sends a size-only frame per present, so the ring stays empty: save-state thumbnails come from `read_layer_pixels`. Touch pointer mapping takes the content size from those size-only frames (`MetalRenderer.setPresentedSize`), so a finger maps over the same aspect fit the adapter blits. `MetalLayerView` and the `MTKView` both set BGRA8 UNORM tagged sRGB (`MetalRenderer.configureOutput`), and MoltenVK sets the same from the swapchain, so both paths show the same colours.

**libretro Vulkan.** Under libretro the frontend owns the Vulkan context (`RETRO_HW_CONTEXT_VULKAN`, [libretro_vulkan.h](https://raw.githubusercontent.com/libretro/libretro-common/master/include/libretro_vulkan.h)). `Cores/shared/LibretroVulkan.c` is that frontend, compiled into a core's framework with `GAGA_LIBRETRO_VULKAN` and kept apart from the software adapter:

- **Context.** It accepts `SET_HW_RENDER` for Vulkan only and answers `GET_PREFERRED_HW_RENDER`, `SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE` (version 1: `get_application_info`, `create_device`, `destroy_device`; version 2's `create_device2` is not used), `GET_HW_RENDER_INTERFACE` (`RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION` 5) and `SET_HW_SHARED_CONTEXT`. The instance enables `VK_KHR_surface`, `VK_EXT_metal_surface` and `VK_KHR_get_physical_device_properties2`. MoltenVK is linked directly, with no Vulkan loader, so no portability enumeration is needed; the device adds `VK_KHR_swapchain` and, where offered, `VK_KHR_portability_subset`. With a negotiation interface the core makes the device; without one the adapter makes a device with one graphics and compute queue and no optional features. The context is made after `retro_load_game` and before the first frame, then `context_reset` runs. Teardown runs `context_destroy`, `retro_unload_game`, the core's `destroy_device`, then the device and instance.
- **Frame.** The core calls `set_image` (an image with `TRANSFER_SRC` usage), optionally `set_command_buffers`, and `video_refresh(RETRO_HW_FRAME_BUFFER_VALID, ...)`. The adapter waits for the frame slot, acquires a swapchain image, clears it to the ink letterbox, blits the core image aspect-fit with linear filtering, and presents. FIFO, `B8G8R8A8_UNORM`, two frames in flight. It waits on the core's semaphores, signals its `signal_semaphore`, and honours queue-family ownership transfer. The queue lock is a mutex. With no layer attached, frames still render and their semaphores still clear, but nothing is shown. A failed submit raises FATAL "The 3D renderer stopped working."
- **Swapchain.** On iOS, MoltenVK sets the layer's `drawableSize`, `maximumDrawableCount` and `framebufferOnly` from the swapchain, and does not dispatch to the main thread when given a `CAMetalLayer`, so the core's queue can build it. A size change rebuilds it with `oldSwapchain`. Out of date on acquire rebuilds and retries once.
- **Shortcuts.** Square pixels, as on the copy path. The blit copies UNORM to a UNORM swapchain, so an sRGB core image is shown without conversion. Fast-forward runs no faster than the display, because FIFO presents every frame.

**MoltenVK.** v1.4.2, built from source by `scripts/build-moltenvk.sh` into a static `MoltenVK.xcframework` with the iOS device and Simulator slices. MoltenVK's `fetchDependencies` pins its dependencies to the commits the tag records (`docs/03` section 5 has the pins and licences). Nothing built is committed. It translates SPIR-V to MSL with SPIRV-Cross and compiles an `MTLLibrary` at run time. That is GPU code: no CPU code is generated, and the no-JIT gate passes on both slices.

### 2.4 Core-output texture path (planned)

A core renders off-screen and hands the host an `MTLTexture`, created on the same `MTLDevice`, which the host feeds to the shader chain. Native Metal backends can do this directly. For Vulkan on MoltenVK the route is `VK_EXT_metal_objects`, which the [MoltenVK user guide](https://raw.githubusercontent.com/KhronosGroup/MoltenVK/main/Docs/MoltenVK_Runtime_UserGuide.md) lists as supported; it is unverified in this project.

This path is an optional improvement. v1 ships without it, and section 2.5 is the rule until it exists.

### 2.5 Which cores skip host shaders

`docs/03` owns each core's renderer; this table states the consequence. A core on the layer path skips host shaders. The filter picker disables its rows for such a game and says why, and the Gaga Plus line names this build's layer-path cores. The Premium Filters entitlement does not cover those cores until the output-texture path exists (`docs/06` section 4.3).

| Path | Host shaders | Cores |
|---|---|---|
| Copy, or host buffer where proven | Run | Game Boy and GBC, GBA, NES, SNES, Genesis and Mega-CD, PS1 with PCSX-ReARMed or with Beetle PSX HW in software mode, DS, Saturn, Arcade, DOS and Win9x |
| Core-owned layer | Skipped until the output-texture path exists for that core | N64 with ParaLLEl-RDP, PS1 with Beetle PSX HW in Vulkan mode, PSP, Dreamcast, 3DS |
| Undetermined | Decided by the spike | Java ME (J2meJS) and Symbian (EKA2L1). Symbian's iOS path links OpenGLES.framework today, so it is out under rule 4 unless a Vulkan or software renderer is proven. |

Two entries carry conditions from `docs/03`. N64 passes the no-JIT gate as GagaEmu builds it (cxd4 interpreter RSP), and MoltenVK reports ParaLLEl-RDP's required 8-bit and 16-bit storage and int8/int16 features; both still wait on the device run in `docs/07` 5.2. PSP runs PPSSPP's own Vulkan renderer through upstream's libretro Vulkan context, which renders into the frontend's images; it asserts a surface at device creation, so `Cores/ppsspp/LibretroVulkanContextGaga.cpp` makes one from an unshown `CAMetalLayer` of its own (`docs/03` section 5). Dreamcast is Flycast's own Vulkan renderer on MoltenVK v1.4.2 through the layer path (`Cores/flycast`, `GAGA_LIBRETRO_VULKAN_LAYER`), with per-triangle alpha sorting because the per-pixel renderer needs more than MoltenVK offers. Flycast's shaders are GLSL compiled to SPIR-V by its bundled glslang at run time, then to MSL by MoltenVK: GPU code only, no CPU code is generated. With no `mprotect`, VRAM texture writes are found by comparing a copy of each watched page before every frame, so a texture the game rewrites and draws in the same frame shows one frame late. It waits on the device run in `docs/07` 6.2. 3DS is Azahar's own Vulkan renderer on the shared MoltenVK framework through the same layer path (`Cores/azahar`, `GAGA_LIBRETRO_VULKAN_LAYER`, libretro Vulkan negotiation v1). Azahar loads the game in `context_reset`, after the frontend's Vulkan device exists. Both screens are drawn into one picture, side by side by default (`citra_layout_option`), landscape only; the bottom screen takes touch through the libretro pointer. Its fragment shaders are SPIR-V from sirit and its vertex and geometry shaders GLSL compiled by glslang at run time; with `use_hw_shader` on, PICA200 shader programs run on the GPU. GPU code only: the shader JIT is not compiled, so no CPU code is generated. It waits on the device run in `docs/07` 6.3. Azahar's software renderer is compiled too, but needs a picture path from the adapter for `citra_graphics_api` = Software, which is not wired; it would move 3DS to the copy path. `docs/07` tracks these spikes.

---

## 3. Shader Picker

Seen in screenshot `0BF2D032`: a sheet with an edit button and a close button, a search field, the tabs Default, RetroArch, Import and Custom, a preview card with an image button, and a list where each row has a preview (eye) control and a separate selection control.

Status in GagaEmu: the picker is an original split view, with the list on the left and a large preview and its controls on the right (`docs/06` section 3.4). There are no tabs, search field or eye icons. The list has three sections: the built-in presets, Community, and Imported with an `Import .metal File` button.

### 3.1 Built-in presets

These descriptions match `Sources/Metal/Shaders.metal` and `Anime4K.metal`. Each preset also applies the colour temperature tint, which is exactly neutral at 0.5, and writes alpha 1. Premium assignment is in `docs/06` section 4.3. All nine, and the three in section 3.5, were selected in a running mGBA session in the simulator and drew the core's frame (milestone 3.1).

| Preset ID | Label | Passes | Behaviour |
|---|---|---|---|
| `original` | Original | 1 | Samples the frame through the chosen upscaler. |
| `cartoon` | Cartoon | 1 | Sobel luminance edges darken high-contrast pixels. Colour is quantized with `floor(c * 16 + 0.5) / 16`, which yields 17 values per channel. |
| `crt-v1` | CRT v1 | 1 | Sine-squared scanline modulation of luminance. |
| `crt-v2` | CRT v2 | 1 | Vertical R, G, B stripe mask plus scanlines. |
| `geom-crt-border` | Geom CRT Border | 1 | Procedural bezel around an active area of 0.12 to 0.88, with inner shadow, diagonal glare and scanlines. It uses no image asset. |
| `geom-crt` | Geom CRT | 1 | Barrel distortion scaled by `curvature`, edge chromatic aberration, scanlines, vignette and glow. |
| `film` | Film | 1 | Grain stepped at 24 Hz, warm colour grading, and occasional dust marks. |
| `crt-deluxe` | CRT Deluxe | 3 | Written for GagaEmu, not derived from crt-royale. Beam pass at source size in linear light with horizontal spread; scan pass at output size with curvature and a beam whose height grows with brightness; mask pass with halation, a slot mask in screen pixels and vignette. |
| `anime4k` | Anime4K | 6 | Port of Anime4K's `Anime4K_Upscale_CNN_x2_S`: four convolution passes at source size, a depth-to-space pass at twice the source size, then a linear scale to the screen. |

Scanline counts and other "one emulated pixel" sizes come from `source_w` and `source_h`, not the texture size, because an earlier pass may have upscaled the texture.

### 3.2 Parameters

`ShaderParameters` in `Sources/Metal/ShaderTypes.h` and `ShaderUniforms` in `MetalRenderer.swift` carry the values below, 36 bytes, passed with `setFragmentBytes` at buffer(0). Values change without rebuilding a pipeline state.

```metal
struct ShaderParameters {
    float curvature;       // 0.0 (flat) to 1.0 (deep barrel)
    float scanline_weight; // 0.0 (off) to 1.0 (heavy)
    float phosphor_glow;   // Bloom intensity
    float color_temp;      // 0.0 warm, 0.5 neutral, 1.0 cool (a normalized tint, not Kelvin)
    float time;            // Frame timer for dynamic animation and grain
    uint  viewport_w;      // Output viewport width in pixels
    uint  viewport_h;      // Output viewport height in pixels
    uint  source_w;        // Core frame width, whatever size earlier passes wrote
    uint  source_h;        // Core frame height
};
```

The picker shows a slider for each value the selected preset reads (`ShaderPreset.parameters`): Curvature, Scanlines, Glow and Colour. An imported filter shows all four. `ShaderParameterValues` holds the four values and the upscaler, and `AppState.shaderParameters` saves one per filter ID in `state.json`, written when a drag ends. Values are clamped to 0 to 1 when applied, and an unknown upscaler name decodes and falls back to Nearest, so an edited file cannot fail to load. Reset returns a filter to its defaults. The same values apply to every game that uses the filter.

### 3.3 Preview card

`MetalPreviewCanvas` is an `MTKView` inside the picker that runs the selected filter's real chain over a procedural texture made by `ShaderManager.createPreviewTexture`. No sample image is bundled. Letting the user change the preview image is planned.

### 3.4 Multi-pass chain

`MetalRenderer.chain(preset:upscaler:)` returns the passes for a preset. Each `ShaderPass` names a fragment function, an output size (a multiple of the source, the output viewport, or the drawable for the last pass), a pixel format, and its sampling. Intermediate textures are cached per chain position and remade only when their size or format changes. Every pass gets the previous pass's output at texture(0), the core frame at texture(1), a sampler at sampler(0) and the parameters at buffer(0).

Presets that take an upscaler (Original, Cartoon, CRT v1, CRT v2, Geom CRT, Geom CRT Border, Film, LCD3x and imported filters) offer Nearest, Bilinear, Bicubic and Edge Smooth. Nearest and Bilinear only change the last pass's sampler. Bicubic and Edge Smooth add a first pass at output size:

| Upscaler | Pass | Method |
|---|---|---|
| Nearest | none | Nearest-neighbour sampling. The default. |
| Bilinear | none | Linear sampling. |
| Bicubic | `bicubic_fragment` | Catmull-Rom, 16 taps. |
| Edge Smooth | `edge_smooth_fragment` | GagaEmu's own edge-aware upscaler, by data-dependent triangulation (Yu, Morse and Sederberg, 2001): each cell between four texels splits along the diagonal with the smaller colour change, so interpolation follows edges. Fractions are sharpened, so flat areas keep their pixel shapes. It is not xBRZ, Scale2x or an Eagle variant. |

xBRZ was the planned upscaler. Its upstream licence is GPL-3.0, so it is not shipped and Edge Smooth replaces it (section 5).

CRT Deluxe, Anime4K, Lottes CRT and Sharp Bilinear fix their own sampling, so they show no upscaler choice.

The GPU cost of the longer chains is not measured on a device.

### 3.5 Community presets

Offline conversions to MSL of shaders from [libretro/slang-shaders](https://github.com/libretro/slang-shaders), in `Sources/Metal/CommunityShaders.metal`. That repository has no overall licence and much of it is GPL, so a shader is converted only when its own file places it in the public domain or under a compatible licence. Each row shows its author and licence.

| Preset ID | Label | Source file | Parameters |
|---|---|---|---|
| `lottes-crt` | Lottes CRT | `crt/shaders/crt-lottes.slang` | Curvature, Scanlines, Glow, Colour mapped onto the file's warp, hard scan and bloom amount |
| `lcd3x` | LCD3x | `handheld/shaders/lcd3x.slang` | Colour |
| `sharp-bilinear` | Sharp Bilinear | `pixel-art-scaling/shaders/sharp-bilinear.slang` | Colour |

This replaces the old RetroArch tab. That name is not used as a label.

---

## 4. Runtime Shader Policy

The rule against generating CPU code is separate from GPU shaders. No shipped core may generate or execute CPU code at runtime (`docs/04`). GPU shader compilation is a different matter: MoltenVK and SPIRV-Cross translate GPU shaders at runtime in S3 and S4, and that is accepted here. Guideline 2.5.2 is not treated as a compiler ban.

| Source | Mechanism | Status |
|---|---|---|
| Built-in presets | Bundled default metallib. There is no source fallback: the renderer fails to initialise if the library is missing. | built |
| Community presets | Converted offline and bundled in the same metallib (section 3.5). | built |
| Import, `.metal` | Runtime `makeLibrary(source:)` on a user-selected file (section 4.1). | built |
| Import, `.slangp` and `.slang` | Needs a translation path from Slang to MSL, such as glslang and SPIRV-Cross. It waits for MoltenVK (milestone 5.1), and no tab or button is shown until then. | planned, deferred to after 5.1 |
| Custom presets | User-edited parameter sets over existing presets. The per-filter sliders in section 3.2 cover the common case. | planned |

### 4.1 Imported `.metal` filters

`ImportedFilterStore` copies a picked file into Application Support and lists it in the Imported section with a delete button. `ImportedFilter.validate` checks, in order, and every failure is a `FilterImportError` whose plain-text message the picker shows in a sheet titled "Filter Not Imported" while Original is selected:

1. The extension is `.metal`, the file is not empty, and it is at most 256 KiB.
2. It is UTF-8 text with no NUL byte.
3. No `#include`, `#import` or `%:` line names anything except Metal's own headers.
4. `makeLibrary(source:)` compiles it. The compiler log is shown.
5. It has a fragment function named `gaga_fragment`, and a pipeline links with the app's vertex function. The link log is shown.
6. Reflection shows it binds only buffer(0), at most 36 bytes, texture(0) and texture(1) as `texture2d<float>`, and sampler(0).

Compilation runs off the main thread. A filter that passes runs as the last pass of the chain, after the chosen upscaler. If a command buffer that uses it ends in error, the renderer drops it, the session falls back to Original, and no crash follows. A hostile shader can still stall the GPU briefly before that happens. `Tests/Phase3Tests.swift` covers each rejection and a working filter.

---

## 5. Licences

Recorded before shipping, as section 4 requires for third-party shaders.

| Work | Upstream | Licence | Shipped |
|---|---|---|---|
| Anime4K `Anime4K_Upscale_CNN_x2_S.glsl` | [bloc97/Anime4K](https://github.com/bloc97/Anime4K), commit `28535a4aff3deb55707a36c2f2d05009e0cb7fb3` | MIT, "Copyright (c) 2019-2021 bloc97". The notice is kept in `Anime4K.metal` and must appear in About > Licences (`docs/07` milestone 7.5). | yes, as `anime4k` |
| crt-lottes | libretro/slang-shaders `crt/shaders/crt-lottes.slang`, commit `3685eda59ffd2ebe1b12cc4640581dc23552ce88` | Public domain, by the file's own header (Timothy Lottes) | yes |
| lcd3x | same repository, `handheld/shaders/lcd3x.slang` | Public domain, by the file's own header (Gigaherz) | yes |
| sharp-bilinear | same repository, `pixel-art-scaling/shaders/sharp-bilinear.slang` | Public domain, by the file's own header (Themaister) | yes |
| crt-royale | libretro/slang-shaders | GPL-2.0 or later, by its header | no: CRT Deluxe is an original replacement |
| xBRZ | [xbrz on SourceForge](https://sourceforge.net/projects/xbrz/) | GPL-3.0 | no: Edge Smooth is an original replacement |
| libretro/slang-shaders as a whole | GitHub | No repository licence; each file carries its own | only the three files above |

CRT Deluxe, Edge Smooth, Bicubic and the seven original presets are GagaEmu's own code.
