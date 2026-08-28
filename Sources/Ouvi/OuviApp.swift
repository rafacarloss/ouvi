import SwiftUI
import OuviKit

@main
struct OuviApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            Text("Ouvi")
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Ouvi launched")
    }
}
