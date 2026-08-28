import AppKit
import Carbon.HIToolbox
import OSLog

/// Inserts text at the cursor of whatever app is frontmost.
/// Strategy (industry consensus): snapshot clipboard → write text marked
/// transient → simulated ⌘V via CGEvent → restore the clipboard shortly after,
/// guarded so a user copy that happens meanwhile is never clobbered.
public enum CursorPaster {
    private static let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Paster")
    /// Pasteboard marker so clipboard managers ignore our transient write.
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static let sessionType = NSPasteboard.PasteboardType("com.rafacarloss.ouvi.paste-session")

    public static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// True while a password field has secure input enabled — synthetic paste
    /// is blocked there; callers should surface "dictation unavailable".
    public static var secureInputActive: Bool {
        IsSecureEventInputEnabled()
    }

    public static func paste(_ text: String) {
        guard accessibilityGranted else {
            log.error("paste blocked: accessibility not granted")
            return
        }
        guard !secureInputActive else {
            log.warning("paste blocked: secure input active")
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)
        let sessionID = UUID().uuidString

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("", forType: transientType)
        pasteboard.setString(sessionID, forType: sessionType)

        // Give the pasteboard a beat to settle before the synthetic keystroke.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sendCommandV()
            // Restore after the target app has read the pasteboard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let current = NSPasteboard.general
                // Only restore if our transient write is still on top.
                if current.string(forType: sessionType) == sessionID {
                    restorePasteboard(current, from: snapshot)
                }
            }
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .privateState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        usleep(10_000)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: Clipboard snapshot/restore (all items, all types)

    private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        }
    }

    private static func restorePasteboard(
        _ pasteboard: NSPasteboard,
        from snapshot: [[NSPasteboard.PasteboardType: Data]]
    ) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items = snapshot.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}
