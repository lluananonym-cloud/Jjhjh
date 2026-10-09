import SwiftUI

@main
struct ServerMonitorApp: App {
    @StateObject private var store = ServerStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}
