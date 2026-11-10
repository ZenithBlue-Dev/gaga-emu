import SwiftUI

/// Add > RomM Server: sign in to the user's own RomM, pick a system, and queue games to copy in.
struct RomMSheet: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var queue = DownloadQueue.shared
    @AppStorage("GagaRomMAddress") private var address = ""
    @AppStorage("GagaRomMAllowHTTP") private var allowHTTP = false
    @State private var username = ""
    @State private var password = ""
    @State private var client: RomMClient?
    @State private var platforms: [RomMClient.Platform] = []
    @State private var platform: RomMClient.Platform?
    @State private var roms: [RomMClient.Rom] = []
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        PaperSheet(title: "RomM Server", subtitle: client?.base.host) {
            VStack(alignment: .leading, spacing: 0) {
                if client == nil {
                    ServerSignInForm(placeholder: "https://romm.local", address: $address, username: $username, password: $password,
                                     allowHTTP: $allowHTTP, busy: busy, canForget: WebDAVCredentials.load(account: RomMClient.keychainAccount) != nil,
                                     connect: connect, forget: forget)
                } else {
                    browser
                }
                if busy { ProgressView().padding(.top, 12) }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(AppTheme.accent).padding(.top, 8)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                DownloadRows().padding(.top, 12)
                Text("Use your own server and only games you have the right to use. GagaEmu lists no servers and fetches a file only when you choose it.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 12)
            }
        }
        .onAppear {
            if let saved = WebDAVCredentials.load(account: RomMClient.keychainAccount) {
                username = saved.username
                password = saved.password
            }
        }
        .onDisappear { if let client { queue.release(client) } }
    }

    private func forget() {
        WebDAVCredentials.delete(account: RomMClient.keychainAccount)
        address = ""
        username = ""
        password = ""
        allowHTTP = false
    }

    private var browser: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button(platform == nil ? "Sign Out" : "Up", action: back).buttonStyle(QuietButtonStyle())
                Text(verbatim: platform?.name ?? "Systems").font(.subheadline.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            Rule()
            if let platform {
                if roms.isEmpty && !busy {
                    Text("No game files GagaEmu can read for \(platform.name).").font(.footnote).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
                }
                ForEach(roms) { rom in
                    romRow(rom)
                    Rule()
                }
            } else {
                if platforms.isEmpty && !busy {
                    Text("This server has no systems yet.").font(.footnote).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
                }
                ForEach(platforms) { item in
                    Button { open(item) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder").frame(minWidth: 24).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                            Text(verbatim: item.name).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows this system's games")
                    Rule()
                }
            }
        }
    }

    private func romRow(_ rom: RomMClient.Rom) -> some View {
        let key = "romm:\(client?.base.absoluteString ?? ""):\(rom.id)"
        let status = queue.status(of: key)
        return Button { download(rom, key: key) } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle").frame(minWidth: 24).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: rom.title).multilineTextAlignment(.leading)
                    if let size = rom.size {
                        Text(size.formatted(.byteCount(style: .file))).font(.meta).foregroundStyle(AppTheme.muted)
                    }
                }
                Spacer(minLength: 0)
                if status == .active { ProgressView() }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(status == nil ? "" : "Queued")
        .accessibilityHint("Copies this file into your Library")
    }

    private func back() {
        if platform != nil {
            platform = nil
            roms = []
        } else {
            if let client { queue.release(client) }
            client = nil
            platforms = []
        }
    }

    private func connect() {
        message = nil
        let credentials = username.isEmpty ? nil : WebDAVCredentials(username: username, password: password)
        do {
            let next = try RomMClient(address: address, allowPlainHTTP: allowHTTP, credentials: credentials)
            busy = true
            Task {
                defer { busy = false }
                do {
                    platforms = try await next.platforms()
                    client = next
                    if let credentials, !credentials.save(account: RomMClient.keychainAccount) {
                        message = "Connected, but the sign-in could not be saved."
                    }
                } catch {
                    next.close()
                    message = error.localizedDescription
                }
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func open(_ item: RomMClient.Platform) {
        guard let client else { return }
        platform = item
        busy = true
        message = nil
        Task {
            defer { busy = false }
            do { roms = try await client.roms(platform: item.id) } catch { message = error.localizedDescription }
        }
    }

    private func download(_ rom: RomMClient.Rom, key: String) {
        guard let client else { return }
        let romDirectory = state.romDirectory, library = state
        queue.add(key: key, name: rom.fileName, client: client,
                  run: { try await client.download(rom.path, into: romDirectory) },
                  finish: { await library.importChosen($0) })
    }
}
