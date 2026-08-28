import AppKit
import AVFoundation
import SwiftUI
import OuviKit

// MARK: - Citation-aware text

/// Renders LLM output whose citation markers — ((mm:ss)) or ((sessionid:mm:ss)) —
/// become inline mono chips. Clicks arrive via the `ouvi-cite:` URL scheme and
/// are handled with `.onOpenCitation { sessionRef, ms in … }`.
struct CitationText: View {
    let text: String

    var body: some View {
        Text(Self.attributed(from: text))
            .font(DS.reading)
            .lineSpacing(4)
            .textSelection(.enabled)
            .tint(DS.accentHover)
    }

    static let pattern = #/\(\(([^()]*?)(\d{1,2}:\d{2}(?::\d{2})?)\)\)/#

    static func attributed(from raw: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(raw)
        while let match = rest.firstMatch(of: pattern) {
            result += AttributedString(String(rest[rest.startIndex..<match.range.lowerBound]))
            let context = String(match.output.1).trimmingCharacters(in: CharacterSet(charactersIn: " :—-"))
            let time = String(match.output.2)
            var chip = AttributedString(" \(time)")
            chip.font = DS.monoXS
            chip.foregroundColor = DS.textFaint
            var target = "ouvi-cite://seek/\(time)"
            if !context.isEmpty {
                target = "ouvi-cite://seek/\(time)?s=\(context.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
            chip.link = URL(string: target)
            result += chip
            rest = rest[match.range.upperBound...]
        }
        result += AttributedString(String(rest))
        return result
    }

    static func parse(link url: URL) -> (sessionRef: String?, ms: Int)? {
        guard url.scheme == "ouvi-cite" else { return nil }
        let time = url.lastPathComponent
        let parts = time.split(separator: ":").compactMap { Int($0) }
        let ms: Int
        switch parts.count {
        case 3: ms = ((parts[0] * 60 + parts[1]) * 60 + parts[2]) * 1000
        case 2: ms = (parts[0] * 60 + parts[1]) * 1000
        default: return nil
        }
        let ref = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "s" })?.value
        return (ref, ms)
    }
}

extension View {
    /// Intercepts citation-chip clicks from any CitationText below this view.
    func onOpenCitation(_ handler: @escaping (String?, Int) -> Void) -> some View {
        environment(\.openURL, OpenURLAction { url in
            if let (ref, ms) = CitationText.parse(link: url) {
                handler(ref, ms)
                return .handled
            }
            return .systemAction
        })
    }
}

// MARK: - Privacy badge

struct PrivacyBadge: View {
    enum Mode { case local, cloud }
    let mode: Mode
    var detail: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mode == .local ? "checkmark.shield" : "cloud")
                .font(.system(size: 10, weight: .medium))
            Text(mode == .local ? "LOCAL" : "NUVEM")
                .font(DS.mono(10, .bold))
                .tracking(0.8)
            if let detail {
                Text(detail)
                    .font(DS.caption)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(mode == .local ? DS.accentSoftText : DS.caution)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(mode == .local ? DS.accentSoft : DS.cautionSoft, in: Capsule())
    }
}

// MARK: - Tag (entity chip)

struct TagView: View {
    let icon: String
    let label: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(DS.caption)
            }
            .foregroundStyle(DS.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(DS.bgInset, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(DS.borderHairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Waveform (driven by real amplitude, never faked when idle)

struct WaveformView: View {
    let level: Float
    var bars: Int = 14
    var height: CGFloat = 18
    var color: Color = DS.live

    @State private var history: [Float] = []

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<bars, id: \.self) { index in
                let value = index < history.count ? history[history.count - 1 - index] : 0
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.opacity(value > 0.001 ? 0.9 : 0.25))
                    .frame(width: 2.5, height: max(3, CGFloat(min(1, value * 14)) * height))
            }
        }
        .frame(height: height)
        .onChange(of: level) { _, new in
            history.append(new)
            if history.count > bars { history.removeFirst(history.count - bars) }
        }
    }
}

// MARK: - Buttons in the kit's language

struct PrimaryButton: View {
    let title: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11)) }
                Text(title).font(DS.bodyMedium)
            }
            .foregroundStyle(DS.textOnAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.radiusControl))
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11)) }
                Text(title).font(DS.body)
            }
            .foregroundStyle(DS.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared audio playback (rail player + citation seeks)

/// Plays a session the way the user heard it: both channels — mic ("você") and
/// system ("eles") — as two synchronized players started on the same device
/// clock. Missing files surface as a visible error, never a silent no-op.
@MainActor
final class AudioPlayerController: ObservableObject {
    @Published private(set) var playingSessionID: String?
    @Published var progress: Double = 0
    @Published private(set) var durationMs: Int = 0
    @Published private(set) var isPlaying = false
    @Published var playbackError: String?

    private var players: [AVAudioPlayer] = []
    private var timer: Timer?

    private var primary: AVAudioPlayer? {
        players.max(by: { $0.duration < $1.duration })
    }

    func toggle(session: Session) {
        if playingSessionID == session.id, !players.isEmpty {
            isPlaying ? pause() : play(session: session, atMs: currentMs)
            return
        }
        play(session: session, atMs: 0)
    }

    func play(session: Session, atMs ms: Int) {
        if playingSessionID != session.id {
            stop()
            let paths = [session.micAudioPath, session.systemAudioPath]
                .compactMap { $0 }
                .filter { FileManager.default.fileExists(atPath: $0) }
            players = paths.compactMap { try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: $0)) }
            guard !players.isEmpty else {
                playbackError = "O áudio dessa reunião não está mais no disco (\(session.micAudioPath ?? "sem arquivo"))."
                return
            }
            playingSessionID = session.id
            durationMs = Int((players.map(\.duration).max() ?? 0) * 1000)
            for player in players { player.prepareToPlay() }
        }
        let seconds = Double(ms) / 1000
        // Start every channel at the same output-device time so they stay in sync.
        let startAt = (players.first?.deviceCurrentTime ?? 0) + 0.06
        for player in players {
            player.currentTime = min(seconds, max(0, player.duration - 0.05))
            player.play(atTime: startAt)
        }
        isPlaying = true
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let primary = self.primary else { return }
                self.progress = primary.duration > 0 ? primary.currentTime / primary.duration : 0
                if !primary.isPlaying, self.isPlaying {
                    self.isPlaying = false
                    self.timer?.invalidate()
                }
            }
        }
    }

    func pause() {
        for player in players { player.pause() }
        isPlaying = false
        timer?.invalidate()
    }

    func stop() {
        for player in players { player.stop() }
        players = []
        playingSessionID = nil
        isPlaying = false
        progress = 0
        timer?.invalidate()
    }

    var currentMs: Int {
        Int((primary?.currentTime ?? 0) * 1000)
    }
}
