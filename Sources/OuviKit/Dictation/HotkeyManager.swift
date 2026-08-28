import AppKit
import Carbon.HIToolbox
import OSLog

/// Global push-to-talk. Two mechanisms:
/// - A Carbon hotkey (default ⌥Space) — permission-free, toggle style.
/// - A "hold Fn/Globe" monitor via NSEvent flagsChanged — needs Accessibility.
public final class HotkeyManager {
    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Hotkey")

    public var onPushToTalkDown: (() -> Void)?
    public var onPushToTalkUp: (() -> Void)?
    public var onToggle: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var flagsMonitor: Any?
    private var fnIsDown = false

    public init() {}

    deinit { stop() }

    /// Registers ⌥Space as the toggle hotkey and Fn-hold as push-to-talk.
    public func start(holdFn: Bool = true) {
        registerCarbonHotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
        if holdFn {
            startFnMonitor()
        }
    }

    public func stop() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        flagsMonitor = nil
    }

    // MARK: Carbon toggle hotkey

    private func registerCarbonHotkey(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.onToggle?() }
                _ = event
                return noErr
            },
            1, &eventType, selfPointer, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4F55_5649) /* 'OUVI' */, id: 1)
        RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef)
        log.info("toggle hotkey registered (⌥Space)")
    }

    // MARK: Fn hold monitor

    private func startFnMonitor() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let fnDown = event.modifierFlags.contains(.function)
            // Ignore Fn+arrow style combos: react only to the bare Fn key itself.
            guard event.keyCode == 63 else { return }
            if fnDown && !self.fnIsDown {
                self.fnIsDown = true
                self.onPushToTalkDown?()
            } else if !fnDown && self.fnIsDown {
                self.fnIsDown = false
                self.onPushToTalkUp?()
            }
        }
        log.info("Fn push-to-talk monitor active")
    }
}
