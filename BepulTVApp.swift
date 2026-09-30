import SwiftUI

@main
struct BepulTVApp: App {
    @StateObject private var store = PlaylistStore.shared
    @StateObject private var player = PlayerManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(player)
        }
    }
}
