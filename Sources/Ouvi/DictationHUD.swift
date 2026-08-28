import AppKit
import SwiftUI
import OuviKit

/// The floating dictation pill: a non-activating NSPanel at the bottom-center
/// of the screen. Never steals focus — the paste must land in the target app.
@MainActor
final class DictationHUD {
    static let shared = DictationHUD()

    private var panel: NSPanel?
    private weak var controller: DictationController?

    func attach(to controller: DictationController) {
        self.controller = controller
        controller.onStateChange = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .idle: self?.hide()
                case .recording, .processing: self?.show()
                }
            }
        }
    }

    private func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false)
            panel.level = .statusBar
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            if let controller {
                panel.contentView = NSHostingView(rootView: DictationPillView(controller: controller))
            }
            self.panel = panel
        }
        position()
        panel?.orderFrontRegardless()
    }

    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 24))
    }

    private func hide() {
        panel?.orderOut(nil)
    }
}

struct DictationPillView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        HStack(spacing: 10) {
            if controller.state == .processing {
                ProgressView()
                    .controlSize(.small)
                Text("Transcrevendo…")
                    .font(DS.body)
                    .foregroundStyle(DS.textMuted)
            } else {
                Circle().fill(DS.live).frame(width: 8, height: 8)
                    .shadow(color: DS.liveGlow, radius: 5)
                LevelBars(level: controller.level)
                Text("Fale.")
                    .font(DS.bodyMedium)
                    .foregroundStyle(DS.textBody)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(DS.borderHairline, lineWidth: 0.5))
        .frame(width: 220, height: 44)
    }
}

struct LevelBars: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(DS.live.opacity(barActive(i) ? 0.9 : 0.25))
                    .frame(width: 3, height: barActive(i) ? 16 : 8)
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
    }

    private func barActive(_ index: Int) -> Bool {
        level * 40 > Float(index)
    }
}
