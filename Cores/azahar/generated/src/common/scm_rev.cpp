// Copyright 2014-2026 Citra Emulator Project / Azahar Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include "common/scm_rev.h"

#define GIT_REV      "219d743a1e698101fe1ab8bef43e6563126c3c27"
#define GIT_BRANCH   "HEAD"
#define GIT_DESC     "219d743a1"
#define BUILD_NAME   ""
#define BUILD_DATE   "2026-10-08T22:07:01Z"
#define BUILD_VERSION "2126.2"
#define BUILD_FULLNAME "2126.2"
#define BUILD_VARIANT ""
#define SHADER_CACHE_VERSION "60285fd00a6f029d76309816616d213c"

namespace Common {

const char g_scm_rev[]      = GIT_REV;
const char g_scm_branch[]   = GIT_BRANCH;
const char g_scm_desc[]     = GIT_DESC;
const char g_build_name[]   = BUILD_NAME;
const char g_build_date[]   = BUILD_DATE;
const char g_build_fullname[] = BUILD_FULLNAME;
const char g_build_version[]  = BUILD_VERSION;
const char g_build_variant[]  = BUILD_VARIANT;
const char g_shader_cache_version[] = SHADER_CACHE_VERSION;

} // namespace

