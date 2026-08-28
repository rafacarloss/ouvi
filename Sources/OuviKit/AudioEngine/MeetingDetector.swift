import Foundation
import CoreAudio
import OSLog

/// Detects that a meeting app started using the microphone, by polling the
/// per-process Core Audio objects (macOS 14+). Property listeners for these
/// are documented as flaky, so we poll on a timer instead.
public final class MeetingDetector {
    public struct MicUser: Equatable {
        public let bundleID: String
        public let displayName: String
    }

    /// Known conferencing apps (bundle id prefixes) worth prompting for.
    /// Browsers are included: Meet/Teams-in-browser open the mic through them.
    public static let meetingBundlePrefixes: [String: String] = [
        "us.zoom.xos": "Zoom",
        "com.microsoft.teams": "Microsoft Teams",
        "com.tinyspeck.slackmacgap": "Slack",
        "com.hnc.Discord": "Discord",
        "com.cisco.webexmeetingsapp": "Webex",
        "com.google.Chrome": "Chrome",
        "com.apple.Safari": "Safari",
        "company.thebrowser.Browser": "Arc",
        "com.brave.Browser": "Brave",
        "org.mozilla.firefox": "Firefox",
        "com.apple.FaceTime": "FaceTime",
    ]

    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "MeetingDetector")
    private var timer: Timer?
    private var lastActive: Set<String> = []

    /// Called on the main thread when a meeting-like app starts using the mic.
    public var onMeetingMicStarted: ((MicUser) -> Void)?
    /// Called when all previously active meeting apps released the mic.
    public var onMeetingMicStopped: (() -> Void)?

    public init() {}

    public func start(interval: TimeInterval = 2.0) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let users = Self.activeMicUsers()
        let active = Set(users.map(\.bundleID))
        for user in users where !lastActive.contains(user.bundleID) {
            log.info("mic in use by \(user.bundleID)")
            onMeetingMicStarted?(user)
        }
        if lastActive.isEmpty == false && active.isEmpty {
            onMeetingMicStopped?()
        }
        lastActive = active
    }

    /// All known meeting apps currently running audio input.
    public static func activeMicUsers() -> [MicUser] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard status == noErr, size > 0 else { return [] }

        var objects = [AudioObjectID](
            repeating: AudioObjectID(kAudioObjectUnknown),
            count: Int(size) / MemoryLayout<AudioObjectID>.size)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objects)
        guard status == noErr else { return [] }

        var result: [MicUser] = []
        for object in objects {
            var runningInput: UInt32 = 0
            var boolSize = UInt32(MemoryLayout<UInt32>.size)
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunningInput,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(object, &inputAddress, 0, nil, &boolSize, &runningInput) == noErr,
                  runningInput != 0
            else { continue }

            var bundleID: CFString = "" as CFString
            var strSize = UInt32(MemoryLayout<CFString>.size)
            var bundleAddress = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyBundleID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            let ok = withUnsafeMutablePointer(to: &bundleID) { ptr in
                AudioObjectGetPropertyData(object, &bundleAddress, 0, nil, &strSize, ptr)
            }
            guard ok == noErr else { continue }
            let id = bundleID as String
            for (prefix, name) in Self.meetingBundlePrefixes where id.hasPrefix(prefix) {
                result.append(MicUser(bundleID: id, displayName: name))
                break
            }
        }
        return result
    }
}
