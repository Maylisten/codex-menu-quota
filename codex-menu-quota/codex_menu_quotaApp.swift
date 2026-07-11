import SwiftUI

@main
struct codex_menu_quotaApp: App {
    @State private var preferences: AppPreferences
    @State private var store: QuotaStore

    init() {
        let preferences = AppPreferences()
        _preferences = State(initialValue: preferences)
        _store = State(initialValue: QuotaStore(preferences: preferences))
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store, preferences: preferences)
        } label: {
            MenuBarLabel(store: store, preferences: preferences)
        }
        .menuBarExtraStyle(.window)
    }
}
