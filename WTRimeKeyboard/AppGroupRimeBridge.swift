import Foundation

final class AppGroupRimeBridge: RimeNativeBridge {
    private let decoder = JSONDecoder()
    private let lexiconURL: URL
    private let userPhraseURL: URL?
    private var lexicon: [String: [String]] = [:]
    private var lastSignature: SignaturePair?
    private let queue = DispatchQueue(label: "com.ddm.similar.rime.bridge", qos: .userInitiated)

    init?(relativePath: String = AppGroup.Resource.lexicon, userPhrasePath: String = AppGroup.Resource.userPhrases) {
        guard let url = AppGroup.fileURL(appending: relativePath) else {
            return nil
        }
        lexiconURL = url
        userPhraseURL = AppGroup.fileURL(appending: userPhrasePath)
        queue.sync {
            reloadLexicon(force: true)
        }
    }

    func search(for input: String, limit: Int) -> [String] {
        guard !input.isEmpty else { return [] }
        return queue.sync {
            reloadLexicon(force: false)
            let normalized = normalize(input)
            let matches = lexicon[normalized] ?? []
            if matches.count <= limit {
                return matches
            }
            return Array(matches.prefix(limit))
        }
    }

    private func reloadLexicon(force: Bool) {
        guard force || needsReload() else { return }
        do {
            var table: [String: [String]] = [:]
            if FileManager.default.fileExists(atPath: lexiconURL.path) {
                let data = try Data(contentsOf: lexiconURL)
                let entries = try decoder.decode([LexiconEntry].self, from: data)
                table = Self.buildLexicon(from: entries)
            }
            if let userURL = userPhraseURL, FileManager.default.fileExists(atPath: userURL.path) {
                let data = try Data(contentsOf: userURL)
                let userLexicon = try decoder.decode([String: [String]].self, from: data)
                table.mergeSnapshot(userLexicon)
            }
            lexicon = table
            lastSignature = currentSignature()
        } catch {
            #if DEBUG
            print("[AppGroupRimeBridge] Failed to reload lexicon: \(error)")
            #endif
        }
    }

    private func needsReload() -> Bool {
        let current = currentSignature()
        guard let lastSignature else { return current.lexicon != nil || current.user != nil }
        return current != lastSignature
    }

    private func currentSignature() -> SignaturePair {
        SignaturePair(
            lexicon: signature(for: lexiconURL),
            user: signature(for: userPhraseURL)
        )
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
    }

    private static func buildLexicon(from entries: [LexiconEntry]) -> [String: [String]] {
        var table: [String: [String]] = [:]
        for entry in entries {
            let normalized = entry.syllable.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .replacingOccurrences(of: " ", with: "")
            let merged = (table[normalized] ?? []) + entry.candidates
            var seen = Set<String>()
            var deduped: [String] = []
            for candidate in merged where seen.insert(candidate).inserted {
                deduped.append(candidate)
            }
            table[normalized] = deduped
        }
        return table
    }
}

private struct FileSignature: Equatable {
    let size: UInt64
    let modifiedAt: Date
}

private struct SignaturePair: Equatable {
    let lexicon: FileSignature?
    let user: FileSignature?
}

private struct LexiconEntry: Decodable {
    let syllable: String
    let candidates: [String]
}

private func signature(for url: URL?) -> FileSignature? {
    guard let url else { return nil }
    do {
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        guard let date = values.contentModificationDate, let size = values.fileSize else {
            return nil
        }
        return FileSignature(size: UInt64(size), modifiedAt: date)
    } catch {
        return nil
    }
}

private extension Dictionary where Key == String, Value == [String] {
    mutating func mergeSnapshot(_ snapshot: [String: [String]]) {
        for (key, phrases) in snapshot {
            var bucket = self[key] ?? []
            for phrase in phrases.reversed() {
                if let index = bucket.firstIndex(of: phrase) {
                    bucket.remove(at: index)
                }
                bucket.insert(phrase, at: 0)
            }
            self[key] = bucket
        }
    }
}
