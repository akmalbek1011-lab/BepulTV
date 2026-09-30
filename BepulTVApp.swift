import SwiftUI

@main
struct BepulTVApp: App {
    @StateObject private var store = PlaylistStore.shared
    @StateObject private var player = PlayerManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(player)
        }
    }
}
