// Stands in for the headers upstream's embed-binaries step generates. MelonDSAssets.c holds the bytes and
// fails to assemble if a size here is not the file's size. The OpenGL shaders are not embedded.
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

extern const char embedded_melondsds_default_wfc_config[970]; // assets/wfc.cfg plus a NUL.
extern const unsigned char embedded_melondsds_graphic_error[2136];
extern const unsigned char embedded_melondsds_graphic_sorry[2121];
extern const unsigned char embedded_melondsds_error_title_font[131248];
extern const unsigned char embedded_melondsds_error_body_font[130528];

#ifdef __cplusplus
}
#endif
