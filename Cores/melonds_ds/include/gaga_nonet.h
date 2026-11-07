// Force-included into every C++ file (core.env). Upstream's net.hpp and format.cpp use these pcap types
// and flags even when networking is off; MelonDSNet.cpp says why. Only declarations: no pcap code is
// compiled or linked. The flags missing from melonDS's bundled pcap.h take libpcap 1.10's values, and
// only name flags in log text.
#pragma once

#include <Net_PCap.h>

#ifndef PCAP_IF_WIRELESS
#define PCAP_IF_WIRELESS 0x00000008
#endif
#ifndef PCAP_IF_CONNECTION_STATUS
#define PCAP_IF_CONNECTION_STATUS 0x00000030
#define PCAP_IF_CONNECTION_STATUS_UNKNOWN 0x00000000
#define PCAP_IF_CONNECTION_STATUS_CONNECTED 0x00000010
#define PCAP_IF_CONNECTION_STATUS_DISCONNECTED 0x00000020
#define PCAP_IF_CONNECTION_STATUS_NOT_APPLICABLE 0x00000030
#endif
