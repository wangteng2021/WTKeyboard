import Foundation

enum AppGroupBootstrapper {
    private static let fileManager = FileManager.default

    static func installSharedLexiconIfNeeded() {
        defer {
            do {
                try ensureUserPhraseContainer()
            } catch {
                print("[AppGroupBootstrapper] Failed to prepare user phrase store: \(error)")
            }
        }
        syncResource(resourceName: "rime_lexicon", fileExtension: "json", destination: AppGroup.Resource.lexicon)
        syncResource(resourceName: "rime_lexicon", fileExtension: "sqlite", destination: AppGroup.Resource.sqliteLexicon)
    }

    private static func syncResource(resourceName: String, fileExtension: String, destination: String) {
        guard let source = Bundle.main.url(forResource: resourceName, withExtension: fileExtension),
              let destinationURL = AppGroup.fileURL(appending: destination) else {
            #if DEBUG
            print("[AppGroupBootstrapper] Missing source or destination URL for \(resourceName).\(fileExtension)")
            #endif
            return
        }

        do {
            if try needsCopy(from: source, to: destinationURL) {
                try copyLexicon(from: source, to: destinationURL)
            }
        } catch {
            print("[AppGroupBootstrapper] Failed to sync \(resourceName).\(fileExtension): \(error)")
        }
    }

    private static func needsCopy(from source: URL, to destination: URL) throws -> Bool {
        guard fileManager.fileExists(atPath: destination.path) else {
            return true
        }

        let sourceValues = try source.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let destinationValues = try destination.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])

        if let sSize = sourceValues.fileSize, let dSize = destinationValues.fileSize, sSize != dSize {
            return true
        }
        if let sDate = sourceValues.contentModificationDate, let dDate = destinationValues.contentModificationDate, sDate > dDate {
            return true
        }
        return false
    }

    private static func copyLexicon(from source: URL, to destination: URL) throws {
        let destinationDirectory = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destinationDirectory.path) {
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private static func ensureUserPhraseContainer() throws {
        guard let url = AppGroup.fileURL(appending: AppGroup.Resource.userPhrases) else { return }
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: url.path) {
            let data = try JSONEncoder().encode([String: [String]]())
            try data.write(to: url, options: .atomic)
        }
    }
}
