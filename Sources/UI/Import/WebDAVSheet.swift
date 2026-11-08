import SwiftUI

/// Add > WebDAV Server: sign in to the user's own server, browse it, and copy games in one at a time.
struct WebDAVSheet: View {
    @EnvironmentObject private var state: AppState
    @AppStorage("GagaWebDAVAddress") private var address = ""
    @AppStorage("GagaWebDAVAllowHTTP") private var allowHTTP = false
    @State private var username = ""
    @State private var password = ""
    @State private var client: WebDAVClient?
    @State private var folder: [String] = []
    @State private var entries: [WebDAVClient.Entry] = []
    @State private var busy = false
    @State private var importing: String?
    @State private var message: String?

    var body: some View {
        PaperSheet(title: "WebDAV Server", subtitle: client?.base.host) {
            VStack(alignment: .leading, spacing: 0) {
                if client == nil { signIn } else { browser }
                if busy { ProgressView().padding(.top, 12) }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(AppTheme.accent).padding(.top, 8)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                Text("Use your own server and only games you have the right to use. GagaEmu lists no servers and fetches a file only when you choose it.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 12)
            }
        }
        .onAppear {
            if let saved = WebDAVCredentials.load() {
                username = saved.username
                password = saved.password
            }
        }
        .onDisappear { client?.close() }
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            field("Server Address") {
                TextField("https://nas.local/games", text: $address)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Server address")
            }
            field("Username") {
                TextField("Optional", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Username")
            }
            field("Password") {
                SecureField("Optional", text: $password)
                    .textContentType(.password)
                    .accessibilityLabel("Password")
            }
            ToggleRow(title: "Allow Unencrypted HTTP",
                      note: "Off by default. With an http address your password and files cross the network unencrypted, so use it only on a network you trust.",
                      isOn: $allowHTTP)
            Rule()
            HStack(spacing: 12) {
                Button("Connect", action: connect)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy || address.isEmpty)
                if WebDAVCredentials.load() != nil {
                    Button("Forget Server", role: .destructive) {
                        WebDAVCredentials.delete()
                        address = ""
                        username = ""
                        password = ""
                        allowHTTP = false
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
            .padding(.top, 16)
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title)).font(.footnote).foregroundStyle(AppTheme.muted)
            content().frame(minHeight: 44)
            Rule()
        }
        .padding(.bottom, 8)
    }

    private var browser: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button(folder.isEmpty ? "Sign Out" : "Up") {
                    if folder.isEmpty {
                        client?.close()
                        client = nil
                        entries = []
                    } else {
                        folder.removeLast()
                        load()
                    }
                }
                .buttonStyle(QuietButtonStyle())
                Text(folder.last ?? "Top folder").font(.subheadline.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            Rule()
            if entries.isEmpty && !busy {
                Text("No folders or game files here.").font(.footnote).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
            }
            ForEach(entries) { entry in
                row(entry)
                Rule()
            }
        }
    }

    private func row(_ entry: WebDAVClient.Entry) -> some View {
        Button { entry.isFolder ? open(entry) : download(entry) } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.isFolder ? "folder" : "arrow.down.circle")
                    .frame(width: 24).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: entry.name).multilineTextAlignment(.leading)
                    if let size = entry.size {
                        Text(size.formatted(.byteCount(style: .file))).font(.meta).foregroundStyle(AppTheme.muted)
                    }
                }
                Spacer(minLength: 0)
                if importing == entry.name { ProgressView() }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy || importing != nil)
        .accessibilityHint(entry.isFolder ? "Opens this folder" : "Copies this file into your Library")
    }

    private func connect() {
        message = nil
        let credentials = username.isEmpty ? nil : WebDAVCredentials(username: username, password: password)
        do {
            let next = try WebDAVClient(address: address, allowPlainHTTP: allowHTTP, credentials: credentials)
            busy = true
            Task {
                defer { busy = false }
                do {
                    entries = try await next.list([])
                    folder = []
                    client = next
                    if let credentials, !credentials.save() { message = "Connected, but the sign-in could not be saved." }
                } catch {
                    next.close()
                    message = error.localizedDescription
                }
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func load() {
        guard let client else { return }
        busy = true
        message = nil
        Task {
            defer { busy = false }
            do { entries = try await client.list(folder) } catch { message = error.localizedDescription }
        }
    }

    private func open(_ entry: WebDAVClient.Entry) {
        folder.append(entry.name)
        load()
    }

    private func download(_ entry: WebDAVClient.Entry) {
        guard let client else { return }
        importing = entry.name
        message = nil
        let path = folder + [entry.name], romDirectory = state.romDirectory
        Task {
            defer { importing = nil }
            do {
                let dest = try await client.download(path, into: romDirectory)
                message = await state.importChosen(dest) ?? "Imported \(dest.lastPathComponent)"
            } catch {
                message = error.localizedDescription
            }
        }
    }
}
