import Foundation
import OuviKit

// ouvi-cli — headless utilities:
//   ouvi-cli transcribe <audio-file> [--lang pt|en] [--json]
//   ouvi-cli diarize <audio-file>
//   ouvi-cli doctor

func eprint(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    eprint("usage: ouvi-cli <transcribe|diarize|doctor> [args]")
    exit(64)
}

let command = arguments[1]

switch command {
case "transcribe":
    guard arguments.count >= 3 else {
        eprint("usage: ouvi-cli transcribe <audio-file> [--lang pt|en] [--json]")
        exit(64)
    }
    let url = URL(fileURLWithPath: arguments[2])
    var lang: String? = nil
    if let idx = arguments.firstIndex(of: "--lang"), idx + 1 < arguments.count {
        lang = arguments[idx + 1]
    }
    let asJSON = arguments.contains("--json")

    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            let started = Date()
            let transcript = try await TranscriptionService.shared.transcribe(url: url, languageHint: lang)
            let elapsed = Date().timeIntervalSince(started)
            if asJSON {
                let payload: [String: Any] = [
                    "text": transcript.text,
                    "utterances": transcript.utterances.map {
                        ["start_ms": $0.startMs, "end_ms": $0.endMs, "text": $0.text]
                    },
                    "elapsed_s": elapsed,
                ]
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
                print(String(data: data, encoding: .utf8)!)
            } else {
                for utterance in transcript.utterances {
                    let t = String(format: "%02d:%02d", utterance.startMs / 60000, (utterance.startMs / 1000) % 60)
                    print("[\(t)] \(utterance.text)")
                }
                eprint("— \(transcript.words.count) words in \(String(format: "%.1f", elapsed))s")
            }
            exit(0)
        } catch {
            eprint("transcribe failed: \(error)")
            exit(1)
        }
    }
    semaphore.wait()

case "diarize":
    guard arguments.count >= 3 else {
        eprint("usage: ouvi-cli diarize <audio-file>")
        exit(64)
    }
    let url = URL(fileURLWithPath: arguments[2])
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            let turns = try await DiarizationService.shared.diarize(url: url)
            for turn in turns {
                let t = String(format: "%02d:%02d", turn.startMs / 60000, (turn.startMs / 1000) % 60)
                print("[\(t)] \(turn.clusterID) (\((turn.endMs - turn.startMs) / 1000)s)")
            }
            exit(0)
        } catch {
            eprint("diarize failed: \(error)")
            exit(1)
        }
    }
    semaphore.wait()

case "import":
    guard arguments.count >= 3 else {
        eprint("usage: ouvi-cli import <audio-file> [--lang pt|en]")
        exit(64)
    }
    let url = URL(fileURLWithPath: arguments[2])
    var lang: String? = nil
    if let idx = arguments.firstIndex(of: "--lang"), idx + 1 < arguments.count {
        lang = arguments[idx + 1]
    }
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            let db = try OuviDatabase.openDefault()
            let service = ImportService(database: db)
            let sessionID = try await service.importFile(at: url, languageHint: lang) { progress in
                eprint("… \(progress.stage.rawValue)")
            }
            let segments = try db.segments(sessionID: sessionID)
            print("imported as session \(sessionID) — \(segments.count) segments")
            for segment in segments.prefix(8) {
                let t = String(format: "%02d:%02d", segment.startMs / 60000, (segment.startMs / 1000) % 60)
                print("[\(t)] \(segment.text)")
            }
            exit(0)
        } catch {
            eprint("import failed: \(error)")
            exit(1)
        }
    }
    semaphore.wait()

case "export":
    guard arguments.count >= 4, let format = ExportService.Format(rawValue: arguments[3]) else {
        eprint("usage: ouvi-cli export <session-id> <md|srt|vtt|json>")
        exit(64)
    }
    do {
        let db = try OuviDatabase.openDefault()
        print(try ExportService.export(sessionID: arguments[2], format: format, database: db))
        exit(0)
    } catch {
        eprint("export failed: \(error)")
        exit(1)
    }

case "reindex":
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            let db = try OuviDatabase.openDefault()
            await ChunkIndexer(database: db).reindexAll()
            let writer = VaultWriter(database: db)
            for session in (try? db.recentSessions(limit: 100_000)) ?? [] where session.state == .ready {
                _ = try? writer.writeNote(sessionID: session.id, userNotes: nil, enhancedNotes: nil)
            }
            try? writer.writePersonPages()
            print("reindex complete")
            exit(0)
        } catch {
            eprint("reindex failed: \(error)")
            exit(1)
        }
    }
    semaphore.wait()

case "tapcheck":
    // Exercises the system-audio tap for a few seconds and reports what the
    // IOProc actually delivered. Play some audio while it runs.
    let seconds = arguments.count >= 3 ? (Double(arguments[2]) ?? 4) : 4
    let recorder = SystemAudioTapRecorder()
    let out = FileManager.default.temporaryDirectory
        .appendingPathComponent("ouvi-tapcheck-\(UUID().uuidString).wav")
    do {
        try recorder.start(writingTo: out)
        eprint("tap started; capturing \(Int(seconds))s — play some audio now…")
        Thread.sleep(forTimeInterval: seconds)
        recorder.stop()
        let size = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
        print("tapcheck: \(recorder.diagnostics) fileBytes=\(size ?? 0)")
        try? FileManager.default.removeItem(at: out)
        exit(recorder.observedSignal ? 0 : 2)
    } catch {
        eprint("tapcheck failed to start: \(error)")
        exit(1)
    }

case "doctor":
    // Same self-check as `ouvi-mcp --doctor`.
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        .deletingLastPathComponent().appendingPathComponent("ouvi-mcp")
    process.arguments = ["--doctor"]
    try? process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)

default:
    eprint("unknown command: \(command)")
    exit(64)
}
