import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import QuickLook
import ImageIO

struct EditTarget: Identifiable { let id: String }
struct BoardView: View {
    @EnvironmentObject private var store: NotebookStore
    let canvasID: String
    var parentID: String? = nil
    @State private var editing: EditTarget?
    @State private var settings = false
    @State private var importing = false
    @State private var photo: PhotosPickerItem?
    @State private var preview: URL?
    @State private var renaming = false
    @State private var deletingID: String?
    @State private var newTitle = ""
    var title: String {
        if let parentID { return store.workspace.item(parentID)?["data"]?.object.text("title") ?? "Group" }
        return store.workspace.canvas(canvasID)?.text("title") ?? "Board"
    }
    var body: some View {
        List {
            if parentID == nil && canvasID == store.workspace.rootID {
                Section {
                    Button { settings = true } label: {
                        HStack(spacing: 12) {
                            LoopMark().stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 28, height: 28).accessibilityHidden(true)
                            Text(store.status).font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            if store.busy { ProgressView() }
                        }.frame(minHeight: 44)
                    }
                }
            }
            if store.hasConflict {
                Section {
                    Text("Your Mac and iPhone both have changes. Keep both saves this phone copy in a new board on your Mac.").font(.subheadline)
                    Button("Keep both") { Task { await store.sync(keepBoth: true) } }.disabled(store.busy)
                }
            }
            let entries = store.workspace.children(canvasID, parent: parentID)
            if entries.isEmpty {
                ContentUnavailableView("Room for an idea", systemImage: "note.text", description: Text("Add a note, photo, link, task list, or another board."))
                    .listRowBackground(Color.clear)
            }
            ForEach(entries, id: \.self) { item in
                if item.text("type") == "column" {
                    Section {
                        let children = store.workspace.children(canvasID, parent: item.text("id"))
                        ForEach(children, id: \.self) { child in row(child) }
                        NavigationLink {
                            BoardView(canvasID: canvasID, parentID: item.text("id"))
                        } label: { Label("Open group", systemImage: "rectangle.3.group") }
                    } header: {
                        Button(item["data"]?.object.text("title").nonempty ?? "Group") { editing = EditTarget(id: item.text("id")) }
                            .textCase(nil).frame(minHeight: 44).disabled(!store.canEdit)
                    }
                } else { row(item) }
            }
        }
        .navigationTitle(title.isEmpty ? "Untitled" : title)
        .navigationBarTitleDisplayMode(parentID == nil && canvasID == store.workspace.rootID ? .large : .inline)
        .refreshable { await store.sync() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") { newTitle = title; renaming = true }.disabled(!store.canEdit)
                    Button("Sync settings", systemImage: "arrow.triangle.2.circlepath") { settings = true }
                    Button("Sync now", systemImage: "arrow.clockwise") { Task { await store.sync() } }.disabled(!store.paired || store.busy)
                } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Board options")
            }
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Button("Note", systemImage: "note.text") { add("note") }
                    PhotosPicker(selection: $photo, matching: .images) { Label("Photo", systemImage: "photo") }
                    Button("File", systemImage: "doc") { importing = true }
                    Button("Link", systemImage: "link") { add("link") }
                    Button("Task list", systemImage: "checklist") { add("todo") }
                    Button("Board", systemImage: "square.grid.2x2") { add("board") }
                    if parentID == nil { Button("Group", systemImage: "rectangle.3.group") { add("column") } }
                } label: { Label("Add", systemImage: "plus").frame(minWidth: 80, minHeight: 44) }
                    .disabled(!store.canEdit)
            }
        }
        .sheet(item: $editing) { ItemEditor(itemID: $0.id).environmentObject(store) }
        .sheet(isPresented: $settings) { SyncSettings().environmentObject(store) }
        .alert("Rename", isPresented: $renaming) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let parentID { store.field(parentID, key: "title", value: newTitle) }
                else { store.edit { $0.renameCanvas(canvasID, title: newTitle) } }
            }
        }
        .confirmationDialog("Delete this item and anything inside it?", isPresented: Binding(get: { deletingID != nil }, set: { if !$0 { deletingID = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deletingID { store.edit { $0.deleteItem(id) } }
                deletingID = nil
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 25 * 1024 * 1024 else { throw NotebookError.attachmentTooLarge }
                let bytes = try Data(contentsOf: url)
                store.addAttachment(bytes: bytes, name: url.lastPathComponent, mime: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", canvasID: canvasID, parent: parentID)
            } catch { store.message = error.localizedDescription }
        }
        .onChange(of: photo) { _, selected in
            Task { @MainActor in
                do {
                    guard let selected, let bytes = try await selected.loadTransferable(type: Data.self) else { return }
                    let type = selected.supportedContentTypes.first ?? .image
                    store.addAttachment(bytes: bytes, name: "Photo.\(type.preferredFilenameExtension ?? "jpg")", mime: type.preferredMIMEType ?? "image/jpeg", canvasID: canvasID, parent: parentID)
                    photo = nil
                } catch { store.message = error.localizedDescription }
            }
        }
        .quickLookPreview($preview)
    }
    @ViewBuilder private func row(_ item: JSONObject) -> some View {
        let data = item["data"]?.object ?? [:]
        let id = item.text("id")
        Group {
            if item.text("type") == "board" {
                NavigationLink { BoardView(canvasID: data.text("childCanvasId")) } label: {
                    Label(store.workspace.canvas(data.text("childCanvasId"))?.text("title").nonempty ?? "Board", systemImage: "square.grid.2x2")
                        .frame(minHeight: 44)
                }
            } else if item.text("type") == "column" {
                NavigationLink { BoardView(canvasID: canvasID, parentID: id) } label: { Label(data.text("title").nonempty ?? "Group", systemImage: "rectangle.3.group").frame(minHeight: 44) }
            } else if item.text("type") == "image" || item.text("type") == "file" {
                Button { openFile(data) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        if let image = ThumbnailCache.image(path: data.text("src"), base64: store.workspace.files[data.text("src")]?.string ?? "") {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 260).accessibilityLabel(data.text("name"))
                        }
                        Label(data.text("name").nonempty ?? "Attachment", systemImage: "paperclip").font(.body).foregroundStyle(.primary)
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain)
            } else {
                Button { editing = EditTarget(id: id) } label: { ItemSummary(item: item) }.buttonStyle(.plain).disabled(!store.canEdit)
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editing = EditTarget(id: id) }.disabled(!store.canEdit)
            Button("Delete", systemImage: "trash", role: .destructive) { deletingID = id }.disabled(!store.canEdit)
        }
    }
    private func add(_ type: String) {
        if let id = store.add(type, canvasID: canvasID, parent: parentID) { editing = EditTarget(id: id) }
    }
    private func openFile(_ data: JSONObject) {
        guard let bytes = Data(base64Encoded: store.workspace.files[data.text("src")]?.string ?? "") else {
            store.message = "This attachment is not stored in the notebook. Open it on your Mac."; return
        }
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Pinboard-preview", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = URL(fileURLWithPath: data.text("name")).lastPathComponent.nonempty ?? "Attachment"
            let url = dir.appendingPathComponent(UUID().uuidString + "-" + name)
            try bytes.write(to: url, options: .atomic)
            preview = url
        } catch { store.message = error.localizedDescription }
    }
}

struct ItemSummary: View {
    let item: JSONObject
    var body: some View {
        let data = item["data"]?.object ?? [:]
        VStack(alignment: .leading, spacing: 8) {
            Text(data.text("title").nonempty ?? (item.text("type") == "todo" ? "Tasks" : item.text("type") == "link" ? "Link" : "Note")).font(.headline)
            if item.text("type") == "todo" {
                let tasks = data["tasks"]?.array ?? []
                ForEach(Array(tasks.prefix(5).enumerated()), id: \.offset) { _, task in
                    Label(task.object.text("text"), systemImage: task.object["done"]?.bool == true ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(.secondary)
                }
                if tasks.count > 5 { Text("\(tasks.count - 5) more tasks").foregroundStyle(.secondary) }
            } else if item.text("type") == "link" {
                Text(data.text("url")).foregroundStyle(.secondary).lineLimit(2)
            } else if !data.text("body").isEmpty {
                Text(data.text("body")).foregroundStyle(.secondary).lineLimit(5)
            }
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 8).contentShape(Rectangle())
    }
}
extension String { var nonempty: String? { isEmpty ? nil : self } }

// One quiet, hand-drawn loop, adapted from the notebook's existing identity.
struct LoopMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.2, y: rect.height * 0.65))
        p.addCurve(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.3), control1: CGPoint(x: -rect.width * 0.05, y: -rect.height * 0.1), control2: CGPoint(x: rect.width * 1.1, y: rect.height * 0.05))
        p.addCurve(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.8), control1: CGPoint(x: rect.width * 0.1, y: rect.height * 1.2), control2: CGPoint(x: rect.width * 0.95, y: rect.height * 1.05))
        return p
    }
}

// Bound thumbnail decode cost independently of the original offline attachment.
@MainActor private enum ThumbnailCache {
    static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()
    static func image(path: String, base64: String) -> UIImage? {
        let key = (path + ":" + String(base64.count)) as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let bytes = Data(base64Encoded: base64), let source = CGImageSourceCreateWithData(bytes as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 780, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
