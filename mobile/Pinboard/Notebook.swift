import Foundation

// Keep whole JSON objects so newer Mac fields and task metadata survive phone edits.
indirect enum JSONValue: Codable, Equatable, Hashable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var object: [String: JSONValue] { if case .object(let v) = self { return v }; return [:] }
    var array: [JSONValue] { if case .array(let v) = self { return v }; return [] }
    var string: String { if case .string(let v) = self { return v }; return "" }
    var number: Double { if case .number(let v) = self { return v }; return 0 }
    var bool: Bool { if case .bool(let v) = self { return v }; return false }
}
typealias JSONObject = [String: JSONValue]
extension Dictionary where Key == String, Value == JSONValue {
    func text(_ key: String) -> String { self[key]?.string ?? "" }
    func number(_ key: String) -> Double { self[key]?.number ?? 0 }
}

struct Notebook: Codable, Equatable {
    var raw: JSONObject
    init(raw: JSONObject) { self.raw = raw }
    init(from decoder: Decoder) throws { raw = try JSONObject(from: decoder) }
    func encode(to encoder: Encoder) throws { try raw.encode(to: encoder) }
    var rootID: String { raw.text("rootCanvasId") }
    var canvases: [JSONObject] {
        get { raw["canvases"]?.array.map(\.object) ?? [] }
        set { raw["canvases"] = .array(newValue.map(JSONValue.object)) }
    }
    var items: [JSONObject] {
        get { raw["items"]?.array.map(\.object) ?? [] }
        set { raw["items"] = .array(newValue.map(JSONValue.object)) }
    }
    var files: JSONObject {
        get { raw["files"]?.object ?? [:] }
        set { raw["files"] = .object(newValue) }
    }
    func canvas(_ id: String) -> JSONObject? { canvases.first { $0.text("id") == id } }
    func item(_ id: String) -> JSONObject? { items.first { $0.text("id") == id } }
    func children(_ canvasID: String, parent: String? = nil) -> [JSONObject] {
        items.filter { $0.text("canvasId") == canvasID && $0.text("parentItemId") == (parent ?? "") }
            .sorted { a, b in
                if a.number("y") != b.number("y") { return a.number("y") < b.number("y") }
                if a.number("x") != b.number("x") { return a.number("x") < b.number("x") }
                return a.text("id") < b.text("id")
            }
    }
    mutating func editData(_ id: String, _ change: (inout JSONObject) -> Void) {
        var all = items
        guard let i = all.firstIndex(where: { $0.text("id") == id }) else { return }
        var data = all[i]["data"]?.object ?? [:]
        change(&data)
        all[i]["data"] = .object(data)
        items = all
    }
    mutating func renameCanvas(_ id: String, title: String) {
        var all = canvases
        guard let i = all.firstIndex(where: { $0.text("id") == id }) else { return }
        all[i]["title"] = .string(title)
        canvases = all
    }
    @discardableResult mutating func add(_ type: String, canvasID: String, parent: String? = nil, data: JSONObject = [:]) -> String {
        guard type != "column" || parent == nil else { return "" }
        let id = "i_phone_" + UUID().uuidString
        let y = children(canvasID, parent: parent).map { $0.number("y") + max($0.number("h"), 180) }.max() ?? 35
        var content = data
        if type == "board" {
            let childID = "c_phone_" + UUID().uuidString
            canvases.append(Self.makeCanvas(id: childID, title: data.text("title").isEmpty ? "New board" : data.text("title"), parent: canvasID))
            content = ["childCanvasId": .string(childID)]
        }
        items.append(["id": .string(id), "canvasId": .string(canvasID), "parentItemId": parent.map(JSONValue.string) ?? .null,
                      "type": .string(type), "x": .number(60), "y": .number(y + 25), "w": .number(280), "h": .null,
                      "z": .number((items.map { $0.number("z") }.max() ?? 0) + 1), "color": .null,
                      "data": .object(content), "createdAt": .number((Date().timeIntervalSince1970 * 1000).rounded())])
        return id
    }
    mutating func deleteItem(_ id: String) {
        guard let target = item(id) else { return }
        for child in items.filter({ $0.text("parentItemId") == id }) { deleteItem(child.text("id")) }
        if target.text("type") == "board", let child = target["data"]?.object["childCanvasId"]?.string {
            for item in items.filter({ $0.text("canvasId") == child }) { deleteItem(item.text("id")) }
            canvases.removeAll { $0.text("id") == child }
        }
        items.removeAll { $0.text("id") == id }
        // The protocol carries only attachments referenced by item data.src.
        let referenced = Set(items.compactMap { $0["data"]?.object["src"]?.string })
        files = files.filter { referenced.contains($0.key) }
    }
    func validate() throws {
        guard !rootID.isEmpty, canvas(rootID) != nil,
              Set(canvases.map { $0.text("id") }).count == canvases.count,
              Set(items.map { $0.text("id") }).count == items.count else { throw NotebookError.invalidNotebook }
        var total = 0
        for value in files.values {
            guard let bytes = Data(base64Encoded: value.string), bytes.count <= 25 * 1024 * 1024 else { throw NotebookError.attachmentTooLarge }
            total += bytes.count
            guard total <= 100 * 1024 * 1024 else { throw NotebookError.attachmentTooLarge }
        }
    }
    static func makeCanvas(id: String, title: String, parent: String?) -> JSONObject {
        ["id": .string(id), "title": .string(title), "parentCanvasId": parent.map(JSONValue.string) ?? .null,
         "color": .null, "icon": .null, "createdAt": .number((Date().timeIntervalSince1970 * 1000).rounded())]
    }
    static var empty: Notebook {
        let id = "c_phone_" + UUID().uuidString
        return Notebook(raw: ["rootCanvasId": .string(id), "canvases": .array([.object(makeCanvas(id: id, title: "My notebook", parent: nil))]), "items": .array([]), "files": .object([:])])
    }
}

enum NotebookError: LocalizedError {
    case invalidNotebook, attachmentTooLarge, invalidPairing, keychain(Int32), http(Int), unpaired
    var errorDescription: String? {
        switch self {
        case .invalidNotebook: "This notebook could not be read. Your saved copy is unchanged."
        case .attachmentTooLarge: "Keep each attachment under 25 MB and the notebook's attachments under 100 MB."
        case .invalidPairing: "Paste the complete pairing JSON from your Mac. It must include an HTTPS address, token, and certificate fingerprint."
        case .keychain: "The pairing credential could not be saved securely. Please try again."
        case .http(let status): "The Mac returned an error (\(status)). Your phone changes are still saved."
        case .unpaired: "Connect your Mac in Sync settings first."
        }
    }
}

struct LocalState: Codable, Equatable {
    var workspace: Notebook
    var revision: String?
    var dirty: Bool
    var recoveryRevision: String?
    static var empty: LocalState { LocalState(workspace: .empty, dirty: false) }
}
struct DiskStore {
    let url: URL
    func read() throws -> LocalState {
        guard FileManager.default.fileExists(atPath: url.path) else { return .empty }
        let state = try JSONDecoder().decode(LocalState.self, from: Data(contentsOf: url))
        try state.workspace.validate()
        return state
    }
    func write(_ state: LocalState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
