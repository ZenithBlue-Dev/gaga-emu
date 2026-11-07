import SwiftUI

/// Player slot assignment. Touch Control occupies Player 1 until a pad is bound there.
struct ControllersModalView: View {
    @EnvironmentObject private var controllers: ControllerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                    Text("Controllers").font(.system(size: 22, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(.white)
                slotRow(title: "Touch Control", symbol: "iphone", slot: controllers.touchOwnsPlayerOne ? 0 : nil, deviceID: nil)
                if controllers.devices.isEmpty {
                    Spacer()
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 120, height: 120)
                        .background(AppTheme.cardRaised, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
                    Text("No controllers connected")
                        .font(.system(size: 15)).foregroundStyle(AppTheme.textSecondary)
                    Text("Connect a DualSense, DualShock 4, Xbox, Joy-Con, or MFi pad.")
                        .font(.system(size: 13)).foregroundStyle(AppTheme.textTertiary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                    Spacer()
                } else {
                    ForEach(controllers.devices) { device in
                        slotRow(title: device.name, symbol: symbol(device.kind), slot: device.slot, deviceID: device.id)
                    }
                    Spacer()
                }
            }
            .padding(20)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34).background(AppTheme.cardRaised, in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Close")
                }
            }
        }
    }

    private func slotRow(title: String, symbol: String, slot: Int?, deviceID: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(.white)
            Text(title).foregroundStyle(.white).font(.system(size: 16, weight: .semibold))
            Spacer()
            Menu {
                ForEach(0..<ControllerManager.slotCount, id: \.self) { index in
                    Button("Player \(index + 1)") {
                        if let deviceID { controllers.assign(deviceID, to: index) }
                    }
                }
                if deviceID != nil {
                    Button("Unassign") { if let deviceID { controllers.assign(deviceID, to: nil) } }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(slot.map { "Player \($0 + 1)" } ?? "Unassigned")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(AppTheme.cardRaised, in: Capsule())
            }
            .disabled(deviceID == nil)
            .accessibilityLabel("\(title) slot")
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func symbol(_ kind: ControllerManager.Kind) -> String {
        switch kind {
        case .keyboard: return "keyboard"
        case .joyConLeft, .joyConRight, .joyConPair: return "gamecontroller"
        default: return "gamecontroller.fill"
        }
    }
}
