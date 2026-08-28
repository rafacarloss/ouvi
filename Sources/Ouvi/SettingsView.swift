import AVFoundation
import SwiftUI
import OuviKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("Geral", systemImage: "gear") }
            AISettings()
                .tabItem { Label("Inteligência", systemImage: "sparkles") }
            DictionarySettings()
                .tabItem { Label("Dicionário", systemImage: "character.book.closed") }
            PermissionsSettings()
                .tabItem { Label("Permissões", systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 420)
    }
}

struct GeneralSettings: View {
    @State private var vaultPath = OuviSettings.vaultPath
    @State private var language = OuviSettings.languageHint
    @State private var keepAudio = OuviSettings.keepAudio

    var body: some View {
        Form {
            Section("Vault (arquivos Markdown)") {
                HStack {
                    Text(vaultPath)
                        .truncationMode(.middle)
                        .lineLimit(1)
                    Spacer()
                    Button("Escolher…") { pickVault() }
                }
                Text("Suas notas e transcrições viram arquivos Markdown nessa pasta — abra no Obsidian, versione com git, é tudo seu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Transcrição") {
                Picker("Idioma", selection: $language) {
                    Text("Detectar automaticamente").tag("auto")
                    Text("Português").tag("pt")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                }
                .onChange(of: language) { _, new in OuviSettings.languageHint = new }
                Toggle("Manter o áudio gravado (player + re-transcrição)", isOn: $keepAudio)
                    .onChange(of: keepAudio) { _, new in OuviSettings.keepAudio = new }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func pickVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Usar como vault"
        if panel.runModal() == .OK, let url = panel.url {
            OuviSettings.vaultPath = url.path
            vaultPath = url.path
        }
    }
}

struct AISettings: View {
    @State private var cloudEnabled = OuviSettings.cloudEnabled
    @State private var apiKey = KeychainService.get(KeychainService.claudeAPIKey) ?? ""
    @State private var claudeModel = OuviSettings.claudeModel
    @State private var localURL = OuviSettings.localLLMBaseURL
    @State private var localModel = OuviSettings.localLLMModel
    @State private var embeddingModel = OuviSettings.localEmbeddingModel

    var body: some View {
        Form {
            Section("Privacidade") {
                Toggle("Permitir IA na nuvem (Claude) para resumos e chat", isOn: $cloudEnabled)
                    .onChange(of: cloudEnabled) { _, new in OuviSettings.cloudEnabled = new }
                Text("O áudio e a transcrição NUNCA saem do seu Mac. Com a nuvem ligada, apenas o texto da reunião é enviado à Anthropic com a sua própria chave, e a reunião fica marcada com um selo de nuvem.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Claude") {
                SecureField("API key (sk-ant-…)", text: $apiKey)
                    .onChange(of: apiKey) { _, new in
                        try? KeychainService.set(new, for: KeychainService.claudeAPIKey)
                    }
                Picker("Modelo", selection: $claudeModel) {
                    Text("Claude Opus 5 (melhor)").tag("claude-opus-5")
                    Text("Claude Sonnet 5 (rápido)").tag("claude-sonnet-5")
                }
                .onChange(of: claudeModel) { _, new in OuviSettings.claudeModel = new }
            }
            Section("LLM local (Ollama / LM Studio)") {
                TextField("Endpoint", text: $localURL)
                    .onChange(of: localURL) { _, new in OuviSettings.localLLMBaseURL = new }
                TextField("Modelo de chat", text: $localModel)
                    .onChange(of: localModel) { _, new in OuviSettings.localLLMModel = new }
                TextField("Modelo de embeddings", text: $embeddingModel)
                    .onChange(of: embeddingModel) { _, new in OuviSettings.localEmbeddingModel = new }
                Text("Com a nuvem desligada, resumos e limpeza do ditado usam esse endpoint (ex.: `ollama pull qwen3:4b`). Sem endpoint, o ditado insere o texto bruto do ASR — que já sai pontuado.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PermissionsSettings: View {
    @State private var micGranted = false
    @State private var accessibilityGranted = CursorPaster.accessibilityGranted

    var body: some View {
        Form {
            PermissionRow(
                title: "Microfone",
                granted: micGranted,
                explain: "Necessário para gravar sua voz em reuniões e no ditado.",
                settingsAnchor: "Privacy_Microphone"
            ) {
                AVCaptureDevice.requestAccess(for: .audio) { ok in
                    Task { @MainActor in micGranted = ok }
                }
            }
            PermissionRow(
                title: "Gravação de áudio do sistema",
                granted: true,
                explain: "Captura o que você OUVE na call (os outros participantes). O macOS pergunta na primeira gravação. Se a transcrição vier vazia, autorize em Ajustes do Sistema → Privacidade → Gravação de Áudio do Sistema.",
                settingsAnchor: "Privacy_AudioCapture",
                requestLabel: "Abrir Ajustes"
            ) {
                openSettings(anchor: "Privacy_AudioCapture")
            }
            PermissionRow(
                title: "Acessibilidade",
                granted: accessibilityGranted,
                explain: "Permite inserir o texto ditado em qualquer app (⌘V simulado).",
                settingsAnchor: "Privacy_Accessibility"
            ) {
                CursorPaster.requestAccessibility()
                accessibilityGranted = CursorPaster.accessibilityGranted
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            accessibilityGranted = CursorPaster.accessibilityGranted
        }
    }

    private func openSettings(anchor: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        NSWorkspace.shared.open(url)
    }
}

struct PermissionRow: View {
    let title: String
    let granted: Bool
    let explain: String
    let settingsAnchor: String
    var requestLabel: String = "Autorizar"
    let action: () -> Void

    var body: some View {
        Section {
            HStack {
                Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(granted ? .green : .secondary)
                VStack(alignment: .leading) {
                    Text(title)
                    Text(explain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(requestLabel, action: action)
            }
        }
    }
}
