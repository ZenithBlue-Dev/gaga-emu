// Forced into every Flycast file by core.env (-include flags.h). Only macros, so it reaches the system
// headers before they declare anything.
#pragma once

// No network (docs/04 section 8). Flycast's modem, broadband adapter, DCNet, UPnP and Naomi network code
// stays compiled, but every route out starts at one of these calls. Renaming them in every file, the
// system headers included, sends each call to a stand-in in FlycastSupport.cpp that refuses it, so the
// framework never imports the socket or name lookup API. Uniform renaming keeps std::bind and the
// members of the same names working.
#define socket gaga_flycast_no_socket
#define connect gaga_flycast_no_connect
#define bind gaga_flycast_no_bind
#define listen gaga_flycast_no_listen
#define accept gaga_flycast_no_accept
#define getaddrinfo gaga_flycast_no_getaddrinfo
#define gethostbyname gaga_flycast_no_gethostbyname

// Flycast's retro_run (C++) gets another name. FlycastCore.c defines retro_run, which the adapter calls:
// it checks video memory for writes, then runs Flycast's (FlycastSupport.cpp says why).
#ifdef __cplusplus
#define retro_run gaga_flycast_upstream_retro_run
#endif
