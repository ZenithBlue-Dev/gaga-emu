// Translates one RetroArch slang pass, Vulkan GLSL, to Metal Shading Language text (docs/05 section 4.2).
// glslang compiles each stage to SPIR-V and SPIRV-Cross writes MSL. Nothing here generates CPU code:
// the output is shader source that Metal compiles like an imported .metal file.
#ifndef GAGA_SLANG_H
#define GAGA_SLANG_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Returns a JSON object the caller frees with gaga_slang_free, or NULL with a reason in `error`:
//   {"vertex": MSL, "fragment": MSL, "ubo": {"size": n, "members": {name: offset}},
//    "push": {"size": n, "members": {name: offset}}, "textures": [name]}
// The uniform block is buffer(0) and the push constant block buffer(1) in both stages. Each texture is
// bound at its index in "textures", with a sampler at the same index. Vertex inputs are attributes 0
// (vec4 position) and 1 (vec2 texture coordinate). Both stages' entry points are named main0.
char *gaga_slang_translate(const char *vertex_glsl, const char *fragment_glsl, char *error, size_t error_capacity);
void gaga_slang_free(char *json);

#ifdef __cplusplus
}
#endif

#endif
