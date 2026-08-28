import SwiftUI
import OuviKit

@main
struct OuviApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        WindowGroup("Ouvi", id: "main") {
            MainWindow()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 560)
                .tint(DS.accent)
                .font(DS.body)
        }

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(state)
        } label: {
            Image(systemName: state.isRecording ? "waveform.circle.fill" : "waveform.circle")
        }

        Settings {
            SettingsView()
                .environmentObject(state)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        DS.registerFonts()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DictationHUD.shared.attach(to: AppState.shared.dictation)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if state.isRecording {
            Button("Parar gravação (\(Int(state.recordingElapsed / 60)) min)") {
                state.stopRecording()
            }
        } else {
            Button("Gravar reunião agora") {
                state.startRecording()
            }
        }
        Divider()
        Button("Abrir Ouvi") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink {
            Text("Ajustes…")
        }
        Divider()
        Button("Sair") {
            NSApp.terminate(nil)
        }
    }
}
