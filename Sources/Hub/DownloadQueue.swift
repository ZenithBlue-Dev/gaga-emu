import SwiftUI

/// Files the user picked from their own WebDAV or RomM server, copied in one at a time. It keeps going after the
/// sheet closes. Nothing else may add to it: there is no add-by-link.
// shortcut: a row shows a spinner and no percentage, because URLSession's async download reports no bytes. Upgrade with a delegate-based download task.
@MainActor final class DownloadQueue: ObservableObject {
    static let shared = DownloadQueue()

    enum Status: Equatable { case waiting, active, failed(String) }

    struct Job: Identifiable {
        let id = UUID()
        let key: String
        let name: String
        var status = Status.waiting
        let client: WebDAVClient?
        let run: @Sendable () async throws -> URL
        let finish: @MainActor (URL) async -> String?
    }

    @Published private(set) var jobs: [Job] = []
    /// The newest result, such as "Imported game.gba".
    @Published private(set) var note: String?
    private var running: Task<Void, Never>?
    private var released: [WebDAVClient] = []

    /// `key` is one file on one server: asking for a file already queued does nothing.
    func add(key: String, name: String, client: WebDAVClient?, run: @escaping @Sendable () async throws -> URL,
             finish: @escaping @MainActor (URL) async -> String?) {
        if let index = jobs.firstIndex(where: { $0.key == key }) {
            guard case .failed = jobs[index].status else { return }
            jobs.remove(at: index)
        }
        jobs.append(Job(key: key, name: name, client: client, run: run, finish: finish))
        pump()
    }

    func status(of key: String) -> Status? { jobs.first { $0.key == key }?.status }

    func cancel(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        if jobs[index].status == .active { running?.cancel() } else { jobs.remove(at: index); sweep() }
    }

    /// A sheet is done with its client: closed now, or once its last download ends.
    func release(_ client: WebDAVClient) {
        released.append(client)
        sweep()
    }

    private func sweep() {
        released.removeAll { client in
            let inUse = jobs.contains { job in
                if case .failed = job.status { return false }
                return job.client === client
            }
            if !inUse { client.close() }
            return !inUse
        }
    }

    private func pump() {
        guard running == nil, let index = jobs.firstIndex(where: { $0.status == .waiting }) else { return }
        jobs[index].status = .active
        let job = jobs[index]
        running = Task { [weak self] in
            var failure: String?
            do {
                let file = try await job.run()
                let text = await job.finish(file)
                self?.note = text ?? "Imported \(file.lastPathComponent)"
            } catch where !Task.isCancelled {
                failure = error.localizedDescription
            } catch {}
            guard let self else { return }
            if let failure, let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index].status = .failed(failure)
            } else {
                jobs.removeAll { $0.id == job.id }
            }
            running = nil
            sweep()
            pump()
        }
    }

    #if DEBUG
    /// `-GagaSeedDownloads YES`: rows that never finish and fetch nothing, for the walk's screenshots.
    func seedForWalk() {
        guard UserDefaults.standard.bool(forKey: "GagaSeedDownloads"), jobs.isEmpty else { return }
        for name in ["Sample One.gba", "Sample Two.gba"] {
            add(key: name, name: name, client: nil, run: {
                try await Task.sleep(for: .seconds(3600))
                throw CancellationError()
            }, finish: { _ in nil })
        }
    }
    #endif
}

/// The downloads in progress, waiting or failed, each with a way out.
struct DownloadRows: View {
    @ObservedObject private var queue = DownloadQueue.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !queue.jobs.isEmpty {
                Text("Downloads").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            }
            ForEach(queue.jobs) { job in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: job.name).font(.footnote).lineLimit(1).truncationMode(.middle)
                        Text(detail(job)).font(.meta).foregroundStyle(AppTheme.muted)
                    }
                    Spacer(minLength: 0)
                    if job.status == .active { ProgressView() }
                    Button(isFailed(job) ? "Remove" : "Cancel") { queue.cancel(job.id) }
                        .font(.footnote)
                        .frame(minHeight: 44)
                        .accessibilityLabel("\(isFailed(job) ? "Remove" : "Cancel") \(job.name)")
                }
                .accessibilityElement(children: .contain)
            }
            if let note = queue.note {
                Text(verbatim: note).font(.footnote).foregroundStyle(AppTheme.muted).accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    private func isFailed(_ job: DownloadQueue.Job) -> Bool {
        if case .failed = job.status { return true }
        return false
    }

    private func detail(_ job: DownloadQueue.Job) -> String {
        switch job.status {
        case .waiting: return "Waiting"
        case .active: return "Downloading"
        case .failed(let message): return message
        }
    }
}
