import SwiftUI

struct ItemEditor: View {
    @EnvironmentObject private var store: NotebookStore
    @Environment(\.dismiss) private var dismiss
    let itemID: String
    @State private var deleting = false
    private var item: JSONObject { store.workspace.item(itemID) ?? [:] }
    private var data: JSONObject { item["data"]?.object ?? [:] }
    private var type: String { item.text("type") }
    private func field(_ key: String) -> Binding<String> {
        Binding(get: { data.text(key) }, set: { store.field(itemID, key: key, value: $0) })
    }
    var body: some View {
        NavigationStack {
            Form {
                if let message = store.message {
                    Section { Text(message).foregroundStyle(.primary) }
                }
                Section {
                    if type == "board" {
                        TextField("Board title", text: Binding(get: {
                            store.workspace.canvas(data.text("childCanvasId"))?.text("title") ?? ""
                        }, set: { value in store.edit { $0.renameCanvas(data.text("childCanvasId"), title: value) } }))
                    } else if type == "image" || type == "file" {
                        TextField("Name", text: field("name"))
                    } else {
                        TextField("Title", text: field("title"))
                    }
                    if type == "note" || type == "comment" {
                        TextField("Write something…", text: field("body"), axis: .vertical).lineLimit(8...30)
                    }
                    if type == "link" {
                        TextField("https://", text: field("url"), axis: .vertical).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        if let url = URL(string: data.text("url")), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                            Link("Open link", destination: url).frame(minHeight: 44)
                        }
                    }
                }
                if type == "todo" {
                    Section("Tasks") {
                        let tasks = data["tasks"]?.array ?? []
                        ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                            HStack(alignment: .top) {
                                Button {
                                    taskField(index, key: "done", value: .bool(!(task.object["done"]?.bool ?? false)))
                                } label: {
                                    Image(systemName: task.object["done"]?.bool == true ? "checkmark.circle.fill" : "circle").frame(width: 44, height: 44)
                                }.buttonStyle(.borderless).accessibilityLabel(task.object["done"]?.bool == true ? "Mark incomplete" : "Mark complete")
                                TextField("Task", text: Binding(get: { (data["tasks"]?.array ?? []).indices.contains(index) ? data["tasks"]!.array[index].object.text("text") : "" }, set: {
                                    taskField(index, key: "text", value: .string($0))
                                }), axis: .vertical).frame(minHeight: 44).strikethrough(task.object["done"]?.bool == true)
                            }
                        }.onDelete { offsets in
                            store.edit { notebook in
                                notebook.editData(itemID) { data in
                                    var tasks = data["tasks"]?.array ?? []
                                    for i in offsets.sorted(by: >) { if tasks.indices.contains(i) { tasks.remove(at: i) } }
                                    data["tasks"] = .array(tasks)
                                }
                            }
                        }
                        Button("Add task", systemImage: "plus") {
                            store.edit { notebook in
                                notebook.editData(itemID) { data in
                                    var tasks = data["tasks"]?.array ?? []
                                    tasks.append(.object(["id": .string(UUID().uuidString), "text": .string(""), "done": .bool(false)]))
                                    data["tasks"] = .array(tasks)
                                }
                            }
                        }.frame(minHeight: 44)
                    }
                }
                Section {
                    Text(store.busy ? "Syncing. Editing will resume shortly." : "Edits save on this iPhone as you write.").font(.footnote).foregroundStyle(.secondary)
                    Button("Delete", role: .destructive) { deleting = true }
                }
            }
            .disabled(!store.canEdit)
            .navigationTitle(type == "board" ? "Board" : type == "todo" ? "Tasks" : type == "link" ? "Link" : type == "column" ? "Group" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete this \(type == "board" ? "board and everything inside it" : "item")?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { if store.edit({ $0.deleteItem(itemID) }) { dismiss() } }
            }
        }
    }
    private func taskField(_ index: Int, key: String, value: JSONValue) {
        store.edit { notebook in
            notebook.editData(itemID) { data in
                var tasks = data["tasks"]?.array ?? []
                guard tasks.indices.contains(index) else { return }
                var task = tasks[index].object
                task[key] = value
                tasks[index] = .object(task)
                data["tasks"] = .array(tasks)
            }
        }
    }
}
