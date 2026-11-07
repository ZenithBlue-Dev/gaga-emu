// Replaces upstream's src/libretro/net/net.cpp, which always links the libslirp Wi-Fi driver and so the
// host's sockets. This build has no network: emulated Wi-Fi has no driver, sends nothing and receives
// nothing, as upstream's own None mode does. Upstream's net.hpp needs AdapterData even without
// networking, so core.env force-includes include/gaga_nonet.h (no pcap code is compiled).
#include "net/net.hpp"

MelonDsDs::NetState::NetState() = default;

MelonDsDs::NetState::~NetState() noexcept = default;

int MelonDsDs::NetState::SendPacket(std::span<std::byte> data) noexcept {
    (void)data;
    return 0;
}

int MelonDsDs::NetState::RecvPacket(melonDS::u8* data) noexcept {
    (void)data;
    return 0;
}

std::vector<melonDS::AdapterData> MelonDsDs::NetState::GetAdapters() const noexcept { return {}; }

void MelonDsDs::NetState::Apply(const CoreConfig& config) noexcept { (void)config; }

MelonDsDs::NetworkMode MelonDsDs::NetState::GetNetworkMode() const noexcept { return NetworkMode::None; }
