import SwiftUI

/// The small lock on an option GagaEmu Pro unlocks. VoiceOver hears the option's `proLocked` hint instead.
struct ProLockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppTheme.onAccent)
            .padding(4)
            .background(AppTheme.accentFill, in: Circle())
            .accessibilityHidden(true)
    }
}

extension View {
    /// A lock badge in the corner and "Requires GagaEmu Pro" for VoiceOver, while `locked`.
    func proLocked(_ locked: Bool, alignment: Alignment = .topTrailing) -> some View {
        overlay(alignment: alignment) { if locked { ProLockBadge().padding(4) } }
            .accessibilityHint(locked ? Text("Requires GagaEmu Pro") : Text(verbatim: ""))
    }

    /// The paywall over everything. A sideload build has none, and nothing is locked there.
    func proPaywall(isPresented: Binding<Bool>) -> some View {
        #if GAGA_SIDELOAD
        return self
        #else
        return fullScreenCover(isPresented: isPresented) { GagaPlusView() }
        #endif
    }
}
