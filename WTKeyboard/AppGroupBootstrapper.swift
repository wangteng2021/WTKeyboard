import Foundation

enum AppGroupBootstrapper {
    private static let fileManager = FileManager.default

    static func installSharedLexiconIfNeeded() {
        #if DEBUG
        print("[AppGroupBootstrapper] Starting lexicon installation...")
        print("[AppGroupBootstrapper] AppGroup identifier: \(AppGroup.identifier)")
        #endif
        
        // 检查 App Group 容器
        if let containerURL = AppGroup.containerURL() {
            #if DEBUG
            print("[AppGroupBootstrapper] ✅ AppGroup container accessible: \(containerURL.path)")
            #endif
        } else {
            #if DEBUG
            print("[AppGroupBootstrapper] ❌ Failed to access AppGroup container")
            print("[AppGroupBootstrapper] Please check:")
            print("  1. App Group identifier matches in entitlements: \(AppGroup.identifier)")
            print("  2. App Group capability is enabled in Xcode")
            print("  3. Provisioning profile includes App Group")
            #endif
        }
        
        defer {
            do {
                try ensureUserPhraseContainer()
            } catch {
                print("[AppGroupBootstrapper] Failed to prepare user phrase store: \(error)")
            }
        }
        
        syncResource(resourceName: "rime_lexicon", fileExtension: "json", destination: AppGroup.Resource.lexicon)
        syncResource(resourceName: "rime_lexicon", fileExtension: "sqlite", destination: AppGroup.Resource.sqliteLexicon)
        
        #if DEBUG
        print("[AppGroupBootstrapper] Lexicon installation completed")
        #endif
    }

    private static func syncResource(resourceName: String, fileExtension: String, destination: String) {
        #if DEBUG
        print("[AppGroupBootstrapper] Syncing \(resourceName).\(fileExtension)...")
        #endif
        
        guard let source = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            #if DEBUG
            print("[AppGroupBootstrapper] ❌ Source file not found in Bundle: \(resourceName).\(fileExtension)")
            print("[AppGroupBootstrapper] Bundle path: \(Bundle.main.bundlePath)")
            if let resourcePath = Bundle.main.resourcePath {
                print("[AppGroupBootstrapper] Resource path: \(resourcePath)")
            }
            #endif
            return
        }
        
        #if DEBUG
        print("[AppGroupBootstrapper] ✅ Source file found: \(source.path)")
        #endif
        
        guard let destinationURL = AppGroup.fileURL(appending: destination) else {
            #if DEBUG
            print("[AppGroupBootstrapper] ❌ Failed to construct destination URL for: \(destination)")
            if let containerURL = AppGroup.containerURL() {
                print("[AppGroupBootstrapper] Container URL exists: \(containerURL.path)")
            } else {
                print("[AppGroupBootstrapper] Container URL is nil - App Group not accessible")
            }
            #endif
            return
        }
        
        #if DEBUG
        print("[AppGroupBootstrapper] Destination: \(destinationURL.path)")
        #endif

        do {
            if try needsCopy(from: source, to: destinationURL) {
                #if DEBUG
                print("[AppGroupBootstrapper] Copying \(resourceName).\(fileExtension)...")
                #endif
                try copyLexicon(from: source, to: destinationURL)
                #if DEBUG
                print("[AppGroupBootstrapper] ✅ Successfully copied \(resourceName).\(fileExtension)")
                #endif
            } else {
                #if DEBUG
                print("[AppGroupBootstrapper] ⏭️  Skipping copy (file up to date): \(resourceName).\(fileExtension)")
                #endif
            }
        } catch {
            print("[AppGroupBootstrapper] ❌ Failed to sync \(resourceName).\(fileExtension): \(error)")
            #if DEBUG
            print("[AppGroupBootstrapper] Error details: \(error.localizedDescription)")
            #endif
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
