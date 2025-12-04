import Foundation

final class UserPhraseStore {
    private typealias Storage = [String: [String]]

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.ddm.similar.userphrasestore", qos: .utility)
    private var storage: Storage = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init?() {
        guard let url = AppGroup.fileURL(appending: AppGroup.Resource.userPhrases) else {
            return nil
        }
        fileURL = url
        queue.sync {
            storage = (try? Self.load(from: fileURL, decoder: decoder)) ?? [:]
        }
    }

    func snapshot() -> Storage {
        queue.sync { storage }
    }

    func addCandidate(_ candidate: String, for syllable: String) {
        queue.async {
            var bucket = self.storage[syllable] ?? []
            if let existingIndex = bucket.firstIndex(of: candidate) {
                bucket.remove(at: existingIndex)
            }
            bucket.insert(candidate, at: 0)
            self.storage[syllable] = bucket
            self.persistLocked()
        }
    }

    private static func load(from url: URL, decoder: JSONDecoder) throws -> Storage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(Storage.self, from: data)
    }

    private func persistLocked() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = try encoder.encode(storage)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[UserPhraseStore] Failed to persist: \(error)")
            #endif
        }
    }
}
