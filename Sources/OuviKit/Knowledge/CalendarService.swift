import EventKit
import Foundation
import OSLog

/// Calendar-driven zero-friction start: today's meetings in the sidebar and a
/// prompt when an event with a meeting link begins. One local EventKit grant
/// covers every account already in Calendar.app (iCloud, Google, Exchange) —
/// no OAuth, no server.
public final class CalendarService: ObservableObject {
    public struct Meeting: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let start: Date
        public let end: Date
        public let meetingURL: URL?

        public var isNow: Bool {
            let now = Date()
            return now >= start.addingTimeInterval(-120) && now <= end
        }
    }

    @Published public private(set) var todaysMeetings: [Meeting] = []
    @Published public private(set) var accessGranted = false

    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Calendar")
    private let store = EKEventStore()
    private var timer: Timer?

    /// Regex patterns for meeting links (MeetingBar-style, common services).
    private static let linkPatterns: [String] = [
        #"https?://[\w.-]*zoom\.us/j/[^\s<>"']+"#,
        #"https?://meet\.google\.com/[^\s<>"']+"#,
        #"https?://teams\.microsoft\.com/l/meetup-join/[^\s<>"']+"#,
        #"https?://[\w.-]*webex\.com/[^\s<>"']+"#,
        #"https?://meet\.around\.co/[^\s<>"']+"#,
        #"https?://[\w.-]*whereby\.com/[^\s<>"']+"#,
    ]

    public init() {}

    @MainActor
    public func requestAccessAndStart() async {
        do {
            accessGranted = try await store.requestFullAccessToEvents()
        } catch {
            log.error("calendar access failed: \(error.localizedDescription)")
            accessGranted = false
        }
        guard accessGranted else { return }
        refresh()
        timer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @MainActor
    public func refresh() {
        guard accessGranted else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        todaysMeetings = events
            .filter { !$0.isAllDay }
            .map { event in
                Meeting(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Reunião",
                    start: event.startDate,
                    end: event.endDate,
                    meetingURL: Self.meetingLink(in: event))
            }
            .sorted { $0.start < $1.start }
    }

    /// The meeting happening right now (if any) — used to prefill the session title.
    public var currentMeeting: Meeting? {
        todaysMeetings.first { $0.isNow }
    }

    static func meetingLink(in event: EKEvent) -> URL? {
        var haystack = [event.location, event.notes, event.url?.absoluteString]
            .compactMap { $0 }
            .joined(separator: "\n")
        if haystack.isEmpty { haystack = "" }
        for pattern in linkPatterns {
            if let range = haystack.range(of: pattern, options: .regularExpression) {
                return URL(string: String(haystack[range]))
            }
        }
        return nil
    }
}
