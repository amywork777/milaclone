import SwiftUI

@main struct PinboardApp: App {
    @StateObject private var store = NotebookStore()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            NavigationStack { BoardView(canvasID: store.workspace.rootID) }
                .environmentObject(store)
                .tint(PinboardTheme.tint)
                .alert("Your notebook", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                    Button("OK") { store.message = nil }
                } message: { Text(store.message ?? "") }
        }
        .onChange(of: phase) { _, new in
            if new == .active { Task { await store.sync(automatic: true) } }
        }
    }
}

// Native adaptation of DESIGN.md's plum. System surfaces and text adapt to appearance.
enum PinboardTheme {
    static let tint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.788, green: 0.655, blue: 0.749, alpha: 1)
            : UIColor(red: 0.475, green: 0.341, blue: 0.431, alpha: 1)
    })
}
