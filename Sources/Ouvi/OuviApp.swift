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
            MenuBarPanel()
                .environmentObject(state)
        } label: {
            Image(systemName: state.isRecording ? "waveform.circle.fill" : "waveform.circle")
        }
        .menuBarExtraStyle(.window)

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

/// The kit's MenuBarPanel: "Agora" card with one-click record, rest of today's
/// agenda, dictation status, quick links.
struct MenuBarPanel: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(state.isRecording ? "Gravando" : "Agora")
                    .font(DS.bodyMedium)
                Spacer()
                PrivacyBadge(mode: .local, detail: nil)
            }

            if state.isRecording {
                HStack(spacing: 8) {
                    Circle().fill(DS.live).frame(width: 7, height: 7)
                    Text("AO VIVO · \(elapsed)")
                        .font(DS.mono(11, .bold))
                        .foregroundStyle(DS.accentSoftText)
                    Spacer()
                    Button("Parar") { state.stopRecording() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(10)
                .background(DS.bgInset, in: RoundedRectangle(cornerRadius: DS.radiusCard))
            } else if let meeting = state.calendar.currentMeeting {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meeting.title)
                            .font(DS.bodyMedium)
                            .lineLimit(1)
                        Text("\(meeting.start.formatted(date: .omitted, time: .shortened)) – \(meeting.end.formatted(date: .omitted, time: .shortened))")
                            .font(DS.monoXS)
                            .foregroundStyle(DS.textFaint)
                    }
                    Spacer()
                    Button("Gravar") { state.startRecording(title: meeting.title) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(10)
                .background(DS.bgInset, in: RoundedRectangle(cornerRadius: DS.radiusCard))
            } else {
                Button {
                    state.startRecording()
                } label: {
                    Label("Gravar reunião agora", systemImage: "circle.fill")
                        .font(DS.body)
                }
            }

            let upcoming = state.calendar.todaysMeetings.filter { $0.start > Date() }.prefix(3)
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("DEPOIS HOJE")
                        .font(DS.mono(10, .bold))
                        .tracking(1.0)
                        .foregroundStyle(DS.textFaint)
                    ForEach(Array(upcoming)) { meeting in
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.textFaint)
                            Text(meeting.title)
                                .font(DS.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(meeting.start.formatted(date: .omitted, time: .shortened))
                                .font(DS.monoXS)
                                .foregroundStyle(DS.textFaint)
                        }
                    }
                }
            }

            Divider().overlay(DS.borderHairline)
            HStack {
                Text("Ditado")
                    .font(DS.body)
                Spacer()
                Text("fn")
                    .font(DS.mono(11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.bgInset, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(DS.borderHairline, lineWidth: 0.5))
            }

            Divider().overlay(DS.borderHairline)
            HStack(spacing: 4) {
                GhostButton(title: "Abrir Ouvi", icon: "macwindow") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                GhostButton(title: "Vault", icon: "folder") {
                    NSWorkspace.shared.open(OuviSettings.vaultURL)
                }
                SettingsLink {
                    Text("Ajustes")
                        .font(DS.body)
                        .foregroundStyle(DS.textMuted)
                }
                Spacer()
                GhostButton(title: "Sair", icon: nil) { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private var elapsed: String {
        let s = Int(state.recordingElapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
