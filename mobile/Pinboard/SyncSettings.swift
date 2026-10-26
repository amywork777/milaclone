import SwiftUI

struct SyncSettings: View {
    @EnvironmentObject private var store: NotebookStore
    @Environment(\.dismiss) private var dismiss
    @State private var pairingJSON = ""
    @State private var showingPairing = false
    @State private var confirmPair = false
    var body: some View {
        NavigationStack {
            Form {
                if let message = store.message {
                    Section { Text(message).foregroundStyle(.primary) }
                }
                Section {
                    Label(store.status, systemImage: store.busy ? "arrow.triangle.2.circlepath" : "iphone")
                    if let date = store.lastSync { Text("Last synced \(date.formatted(date: .abbreviated, time: .shortened))").font(.footnote).foregroundStyle(.secondary) }
                    if store.paired {
                        Button("Sync now") { Task { await store.sync() } }.disabled(store.busy || store.hasConflict)
                    }
                } footer: {
                    Text("Your notebook stays on your iPhone and Mac. Keep the Mac sync service running and both devices on the same network.")
                }
                if store.hasConflict {
                    Section("Keep your changes") {
                        Text("The Mac and iPhone have different copies. Keep both preserves the Mac notebook and puts this phone copy in a new board.")
                        Button("Keep both") { Task { await store.sync(keepBoth: true) } }.disabled(store.busy)
                    }
                }
                if !store.paired || showingPairing {
                    Section("Connect your Mac") {
                        Text("Paste the pairing JSON shown by Pinboard on your Mac. It contains the private key to this connection.").font(.subheadline).foregroundStyle(.secondary)
                        TextField("Pairing JSON", text: $pairingJSON, axis: .vertical).lineLimit(4...10).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                        Button("Connect") { confirmPair = true }.disabled(pairingJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.canEdit)
                    }
                } else {
                    Section { Button("Pair again") { showingPairing = true }.disabled(!store.canEdit) }
                }
            }
            .navigationTitle("Sync with Mac").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Connect to this Mac?", isPresented: $confirmPair, titleVisibility: .visible) {
                Button("Connect") {
                    Task {
                        if await store.pair(json: pairingJSON) { pairingJSON = ""; showingPairing = false }
                    }
                }
            } message: { Text("Use pairing details you copied from your own Mac. Any existing phone notes will be kept for the Keep both step.") }
        }
    }
}
