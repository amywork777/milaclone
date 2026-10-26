import Foundation
import Combine
import Network

@MainActor final class NotebookStore: ObservableObject {
    @Published private(set) var state: LocalState
    @Published private(set) var busy = false
    @Published private(set) var paired = false
    @Published private(set) var storageBlocked = false
    @Published var message: String?
    @Published private(set) var lastSync: Date?
    let disk: DiskStore
    private let monitor = NWPathMonitor()
    private var wasReachable = false
    var workspace: Notebook { state.workspace }
    var canEdit: Bool { !busy && !storageBlocked }
    var hasConflict: Bool { state.recoveryRevision != nil }
    var status: String {
        if storageBlocked { return "Storage needs attention" }
        if busy { return "Syncing with Mac…" }
        if hasConflict { return "Both copies have changes" }
        if state.dirty { return paired ? "Saved on iPhone · waiting to sync" : "Saved on iPhone" }
        return paired ? "Saved on iPhone and Mac" : "Saved on iPhone"
    }
    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pinboard", isDirectory: true)
        disk = DiskStore(url: dir.appendingPathComponent("notebook.json"))
        do { state = try disk.read() }
        catch { state = .empty; storageBlocked = true; message = "Your saved notebook could not be opened. It has been kept on this iPhone. \(error.localizedDescription)" }
        do { paired = try PairingVault.read() != nil }
        catch { message = error.localizedDescription }
        monitor.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let reconnected = reachable && !self.wasReachable
                self.wasReachable = reachable
                if reconnected { await self.sync(automatic: true) }
            }
        }
        monitor.start(queue: DispatchQueue(label: "Pinboard.connectivity"))
    }
    deinit { monitor.cancel() }
    @discardableResult private func persist(_ next: LocalState) -> Bool {
        do { try disk.write(next); state = next; return true }
        catch { message = "This edit could not be saved. Free some space and try again. \(error.localizedDescription)"; return false }
    }
    @discardableResult func edit(_ change: (inout Notebook) -> Void) -> Bool {
        guard canEdit else { return false }
        var next = state
        change(&next.workspace)
        next.dirty = true
        return persist(next)
    }
    func field(_ id: String, key: String, value: String) {
        edit { $0.editData(id) { $0[key] = .string(value) } }
    }
    @discardableResult func add(_ type: String, canvasID: String, parent: String? = nil, data: JSONObject = [:]) -> String? {
        guard workspace.canvas(canvasID) != nil else { message = "This board is no longer in the notebook."; return nil }
        guard type != "column" || parent == nil else { message = "Groups belong directly on a board."; return nil }
        var id: String?
        if !edit({ id = $0.add(type, canvasID: canvasID, parent: parent, data: data) }) { return nil }
        return id
    }
    func addAttachment(bytes: Data, name: String, mime: String, canvasID: String, parent: String? = nil) {
        guard canEdit else { message = "Wait for sync to finish, then add the attachment again."; return }
        guard workspace.canvas(canvasID) != nil else { message = "This board is no longer in the notebook."; return }
        do {
            guard bytes.count <= 25 * 1024 * 1024 else { throw NotebookError.attachmentTooLarge }
            let ext = URL(fileURLWithPath: name).pathExtension.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
            let path = "/uploads/phone_\(UUID().uuidString).\(ext.isEmpty ? "bin" : ext)"
            var next = state
            next.workspace.files[path] = .string(bytes.base64EncodedString())
            next.workspace.add(mime.hasPrefix("image/") ? "image" : "file", canvasID: canvasID, parent: parent,
                               data: ["src": .string(path), "name": .string(name), "mime": .string(mime)])
            try next.workspace.validate()
            next.dirty = true
            _ = persist(next)
        } catch { message = error.localizedDescription }
    }
    func pair(json: String) async -> Bool {
        guard canEdit else { return false }
        do {
            let pairing = try JSONDecoder().decode(Pairing.self, from: Data(json.utf8))
            try pairing.validate()
            // Clear acknowledgement before replacing credentials: no revision from another Mac can be reused.
            var next = state
            next.revision = nil
            next.recoveryRevision = nil
            next.dirty = state.dirty || !workspace.items.isEmpty || workspace.canvases.count > 1
            guard persist(next) else { return false }
            try PairingVault.save(pairing)
            paired = true
            await sync()
            return true
        } catch { message = error.localizedDescription; return false }
    }
    func sync(keepBoth: Bool = false, automatic: Bool = false) async {
        guard !busy, !storageBlocked, paired else { return }
        if hasConflict && !keepBoth { return }
        busy = true
        defer { busy = false }
        do {
            guard let pairing = try PairingVault.read() else { throw NotebookError.unpaired }
            let client = SyncClient(pairing: pairing)
            // Snapshot+revision+dirty are already durably saved, and editing remains disabled until acknowledgement.
            let envelope: SyncEnvelope
            if keepBoth, let revision = state.recoveryRevision {
                envelope = try await client.exchange(path: "/v1/recover", body: SyncWrite(baseRevision: revision, workspace: workspace))
            } else if state.dirty {
                if let revision = state.revision {
                    envelope = try await client.exchange(body: SyncWrite(baseRevision: revision, workspace: workspace))
                } else {
                    let remote = try await client.exchange()
                    var next = state
                    next.recoveryRevision = remote.revision
                    _ = persist(next)
                    return
                }
            } else { envelope = try await client.exchange() }
            if persist(LocalState(workspace: envelope.workspace, revision: envelope.revision, dirty: false)) {
                lastSync = Date()
                if !automatic { message = nil }
            }
        } catch let conflict as SyncConflict {
            var next = state
            next.recoveryRevision = conflict.envelope.revision
            _ = persist(next)
            if keepBoth { message = "The Mac changed again. Your phone copy is safe. Tap Keep both to try again." }
        } catch {
            if !automatic { message = "Could not reach your Mac. Your phone copy is safe. \(error.localizedDescription)" }
        }
    }
}
