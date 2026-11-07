// Written by deps/glslang's CMake (build_info.h.tmpl) for glslang 15.3.0, the version deps/glslang's CHANGES.md
// names at the pinned commit. Committed because glslang's CMake is not run.
#ifndef GLSLANG_BUILD_INFO
#define GLSLANG_BUILD_INFO

#define GLSLANG_VERSION_MAJOR 15
#define GLSLANG_VERSION_MINOR 3
#define GLSLANG_VERSION_PATCH 0
#define GLSLANG_VERSION_FLAVOR ""

#define GLSLANG_VERSION_GREATER_THAN(major, minor, patch) \
    ((GLSLANG_VERSION_MAJOR) > (major) || ((major) == GLSLANG_VERSION_MAJOR && \
    ((GLSLANG_VERSION_MINOR) > (minor) || ((minor) == GLSLANG_VERSION_MINOR && \
     (GLSLANG_VERSION_PATCH) > (patch)))))

#define GLSLANG_VERSION_GREATER_OR_EQUAL_TO(major, minor, patch) \
    ((GLSLANG_VERSION_MAJOR) > (major) || ((major) == GLSLANG_VERSION_MAJOR && \
    ((GLSLANG_VERSION_MINOR) > (minor) || ((minor) == GLSLANG_VERSION_MINOR && \
     (GLSLANG_VERSION_PATCH >= (patch))))))

#define GLSLANG_VERSION_LESS_THAN(major, minor, patch) \
    ((GLSLANG_VERSION_MAJOR) < (major) || ((major) == GLSLANG_VERSION_MAJOR && \
    ((GLSLANG_VERSION_MINOR) < (minor) || ((minor) == GLSLANG_VERSION_MINOR && \
     (GLSLANG_VERSION_PATCH) < (patch)))))

#define GLSLANG_VERSION_LESS_OR_EQUAL_TO(major, minor, patch) \
    ((GLSLANG_VERSION_MAJOR) < (major) || ((major) == GLSLANG_VERSION_MAJOR && \
    ((GLSLANG_VERSION_MINOR) < (minor) || ((minor) == GLSLANG_VERSION_MINOR && \
     (GLSLANG_VERSION_PATCH <= (patch))))))

#endif // GLSLANG_BUILD_INFO
