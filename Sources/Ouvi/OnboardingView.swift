import AVFoundation
import SwiftUI
import OuviKit

/// First-run walkthrough: what Ouvi is, the four permissions (with real checks
/// — TCC denials are silent), and the vault location.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var accessibilityGranted = CursorPaster.accessibilityGranted
    @State private var vaultPath = OuviSettings.vaultPath

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bem-vindo ao Ouvi")
                    .font(.largeTitle.weight(.bold))
                Text("Reuniões transcritas e ditado por voz — tudo processado no seu Mac, salvo em arquivos Markdown seus.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                OnboardingStep(
                    done: micGranted,
                    title: "Microfone",
                    detail: "Sua voz nas reuniões e no ditado.",
                    button: micGranted ? nil : "Autorizar"
                ) {
                    AVCaptureDevice.requestAccess(for: .audio) { ok in
                        Task { @MainActor in micGranted = ok }
                    }
                }
                OnboardingStep(
                    done: false,
                    neutral: true,
                    title: "Áudio do sistema",
                    detail: "O que você ouve na call (os outros participantes). O macOS pede essa permissão automaticamente na sua primeira gravação.",
                    button: nil, action: {})
                OnboardingStep(
                    done: accessibilityGranted,
                    title: "Acessibilidade",
                    detail: "Insere o texto ditado em qualquer app (segure Fn e fale).",
                    button: accessibilityGranted ? nil : "Autorizar"
                ) {
                    CursorPaster.requestAccessibility()
                    accessibilityGranted = CursorPaster.accessibilityGranted
                }
                OnboardingStep(
                    done: state.calendar.accessGranted,
                    title: "Calendário",
                    detail: "Sugere gravar quando uma reunião da sua agenda começa.",
                    button: state.calendar.accessGranted ? nil : "Autorizar"
                ) {
                    Task { await state.calendar.requestAccessAndStart() }
                }
                OnboardingStep(
                    done: true,
                    title: "Seu vault",
                    detail: vaultPath,
                    button: "Escolher pasta…"
                ) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        OuviSettings.vaultPath = url.path
                        vaultPath = url.path
                    }
                }
            }

            HStack {
                Text("Modelos de transcrição (~1 GB) baixam na primeira gravação.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Começar") {
                    UserDefaults.standard.set(true, forKey: "hasOnboarded")
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560)
    }
}

struct OnboardingStep: View {
    let done: Bool
    var neutral: Bool = false
    let title: String
    let detail: String
    let button: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: neutral ? "info.circle" : (done ? "checkmark.circle.fill" : "circle"))
                .foregroundStyle(neutral ? Color.secondary : (done ? .green : .secondary))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let button {
                Button(button, action: action)
            }
        }
    }
}
