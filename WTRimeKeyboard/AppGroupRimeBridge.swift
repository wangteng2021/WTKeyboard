import Foundation

final class AppGroupRimeBridge: RimeNativeBridge {
    private let decoder = JSONDecoder()
    private let fileURL: URL
    private var lexicon: [String: [String]] = [:]
    private var lastSignature: FileSignature?
    private let queue = DispatchQueue(label: "com.ddm.similar.rime.bridge", qos: .userInitiated)

    init?(relativePath: String = AppGroup.Resource.lexicon) {
        guard let url = AppGroup.fileURL(appending: relativePath) else {
            return nil
        }
        fileURL = url
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
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            lexicon = [:]
            lastSignature = nil
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let entries = try decoder.decode([LexiconEntry].self, from: data)
            lexicon = Self.buildLexicon(from: entries)
            lastSignature = currentSignature()
        } catch {
            #if DEBUG
            print("[AppGroupRimeBridge] Failed to reload lexicon: \(error)")
            #endif
        }
    }

    private func needsReload() -> Bool {
        guard let current = currentSignature() else {
            return lastSignature != nil
        }
        guard let lastSignature else {
            return true
        }
        return current != lastSignature
    }

    private func currentSignature() -> FileSignature? {
        do {
            let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            guard let date = values.contentModificationDate, let size = values.fileSize else {
                return nil
            }
            return FileSignature(size: UInt64(size), modifiedAt: date)
        } catch {
            return nil
        }
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

private struct LexiconEntry: Decodable {
    let syllable: String
    let candidates: [String]
}
