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
