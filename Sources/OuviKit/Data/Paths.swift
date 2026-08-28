import Foundation

/// Central registry of on-disk locations. Everything Ouvi stores lives either in
/// Application Support (index, audio, models) or in the user-chosen Markdown vault.
public enum OuviPaths {
    public static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Ouvi", isDirectory: true)
    }

    public static var databaseURL: URL { appSupport.appendingPathComponent("index.sqlite") }
    public static var audioDirectory: URL { appSupport.appendingPathComponent("audio", isDirectory: true) }
    public static var recordingsScratch: URL { appSupport.appendingPathComponent("scratch", isDirectory: true) }

    /// The user's Markdown vault. Defaults to ~/Documents/Ouvi until chosen in onboarding.
    public static var defaultVault: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ouvi", isDirectory: true)
    }

    public static func ensureDirectoriesExist() throws {
        for dir in [appSupport, audioDirectory, recordingsScratch] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
