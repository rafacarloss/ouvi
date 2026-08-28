import Foundation
import AVFoundation

/// WAV → AAC .m4a archival transcode (~14 MB/h vs 115 MB/h for raw float WAV).
public enum AudioTranscoder {
    public static func transcodeToM4A(wav source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw OuviAudioError.osStatus("no audio track in \(source.lastPathComponent)", -1)
        }

        try? FileManager.default.removeItem(at: destination)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
        ])
        reader.add(output)

        let writer = try AVAssetWriter(outputURL: destination, fileType: .m4a)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 32_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 48_000,
        ])
        writer.add(input)

        guard reader.startReading() else { throw reader.error ?? OuviAudioError.osStatus("reader", -1) }
        guard writer.startWriting() else { throw writer.error ?? OuviAudioError.osStatus("writer", -1) }
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "ouvi.transcode")
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    if let sample = output.copyNextSampleBuffer() {
                        input.append(sample)
                    } else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
        await writer.finishWriting()
        if writer.status == .failed {
            throw writer.error ?? OuviAudioError.osStatus("finishWriting", -1)
        }
    }
}
