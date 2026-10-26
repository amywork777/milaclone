import Foundation

@main struct ModelChecks {
    static func main() throws {
        var notebook = Notebook.empty
        let root = notebook.rootID
        let id = notebook.add("todo", canvasID: root, data: ["title": .string("Packing"), "unknown": .object(["future": .bool(true)]), "tasks": .array([.object(["id": .string("t1"), "text": .string("Camera"), "done": .bool(false), "priority": .number(7), "future": .array([.null, .string("preserve")])])])])
        var rawItems = notebook.items
        rawItems[0]["x"] = .number(-137)
        rawItems[0]["w"] = .number(415)
        rawItems[0]["locked"] = .bool(true)
        notebook.items = rawItems
        notebook.raw["futureWorkspace"] = .string("preserve")
        let before = notebook.item(id)!
        notebook.editData(id) { data in
            var tasks = data["tasks"]!.array
            var task = tasks[0].object
            task["done"] = .bool(true)
            tasks[0] = .object(task)
            data["tasks"] = .array(tasks)
        }
        let edited = notebook.item(id)!
        for key in before.keys where key != "data" { precondition(before[key] == edited[key], "Layout/metadata changed: \(key)") }
        let task = edited["data"]!.object["tasks"]!.array[0].object
        precondition(task["priority"] == .number(7) && task["future"] != nil && task["done"] == .bool(true))
        precondition(edited["data"]!.object["unknown"] != nil)
        let encoded = try JSONEncoder().encode(notebook)
        let decoded = try JSONDecoder().decode(Notebook.self, from: encoded)
        precondition(decoded == notebook)
        precondition(decoded.item(id)?["h"] == .null && decoded.canvases[0]["parentCanvasId"] == .null)
        print("PASS: complete round trip preserves unknown fields, nulls, layout, task metadata")

        let bytes = Data([0, 255, 1, 2, 3, 4])
        notebook.files["/uploads/phone_test.bin"] = .string(bytes.base64EncodedString())
        let fileID = notebook.add("file", canvasID: root, data: ["src": .string("/uploads/phone_test.bin"), "name": .string("test.bin"), "mime": .string("application/octet-stream")])
        try notebook.validate()
        for canvas in notebook.canvases { precondition(canvas.number("createdAt").rounded() == canvas.number("createdAt")) }
        for item in notebook.items { precondition(item.number("createdAt").rounded() == item.number("createdAt")) }
        print("PASS: phone-created timestamps are integer milliseconds")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let disk = DiskStore(url: folder.appendingPathComponent("notebook.json"))
        let pending = LocalState(workspace: notebook, revision: "r1", dirty: true, recoveryRevision: "r2")
        try disk.write(pending)
        let reloaded = try disk.read()
        precondition(reloaded == pending)
        precondition(Data(base64Encoded: reloaded.workspace.files["/uploads/phone_test.bin"]!.string) == bytes)
        print("PASS: restart restores attachment bytes, dirty edits, revision and conflict together")
        let acknowledged = LocalState(workspace: notebook, revision: "r3", dirty: false)
        try disk.write(acknowledged)
        let acknowledgedRead = try disk.read()
        precondition(acknowledgedRead == acknowledged)
        print("PASS: atomic acknowledgement replaces workspace and revision together")

        let invalid = Data("{broken".utf8)
        try invalid.write(to: disk.url)
        do { _ = try disk.read(); preconditionFailure("Corruption silently overwritten") } catch { }
        precondition((try? Data(contentsOf: disk.url)) == invalid)
        print("PASS: corrupt saved notebook remains untouched and load throws")
        let blocked = DiskStore(url: disk.url.appendingPathComponent("cannot-write.json"))
        do { try blocked.write(pending); preconditionFailure("Expected persistence error") } catch { }
        precondition((try? Data(contentsOf: disk.url)) == invalid)
        print("PASS: failed persistence does not replace previous bytes")

        let board = notebook.add("board", canvasID: root)
        let childID = notebook.item(board)!["data"]!.object.text("childCanvasId")
        let column = notebook.add("column", canvasID: childID)
        let note = notebook.add("note", canvasID: childID, parent: column, data: ["body": .string("Inside")])
        let count = notebook.items.count
        precondition(notebook.add("column", canvasID: childID, parent: column).isEmpty)
        precondition(notebook.items.count == count)
        print("PASS: nested column creation is refused")
        precondition(notebook.children(childID, parent: column).first?.text("id") == note)
        notebook.deleteItem(board)
        precondition(notebook.canvas(childID) == nil && notebook.item(note) == nil && notebook.item(column) == nil && notebook.item(id) != nil)
        print("PASS: nested board/group deletion removes descendants and retains siblings")
        notebook.deleteItem(fileID)
        precondition(notebook.files.isEmpty)
        print("PASS: deletion prunes now-unreferenced attachment bytes")
        if CommandLine.arguments.count > 1 {
            notebook.files["/uploads/phone_fixture.bin"] = .string(bytes.base64EncodedString())
            notebook.add("file", canvasID: root, data: ["src": .string("/uploads/phone_fixture.bin"), "name": .string("fixture.bin"), "mime": .string("application/octet-stream")])
            try JSONEncoder().encode(notebook).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
    }
}
