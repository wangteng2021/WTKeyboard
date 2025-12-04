import Foundation

protocol InputEngine {
    func suggestions(for input: String, limit: Int) -> [String]
    func registerUserCandidate(_ candidate: String, for input: String)
    func clear()
}

final class RimeEngine: InputEngine {
    static let shared = RimeEngine()

    private var lexicon: [String: [String]] = [:]
    private var nativeBridge: RimeNativeBridge?
    private var cache: [String: [String]] = [:]
    private let queue = DispatchQueue(label: "com.wtkeyboard.rime", qos: .userInitiated)
    private let userPhraseStore = UserPhraseStore()

    private init() {
        loadBundledLexicon()
    }

    func registerNativeBridge(_ bridge: RimeNativeBridge) {
        nativeBridge = bridge
    }

    func suggestions(for rawInput: String, limit: Int = 8) -> [String] {
        let normalized = normalize(rawInput)
        guard !normalized.isEmpty else { return [] }

        if let cached = cache[normalized] {
            return Array(cached.prefix(limit))
        }

        if let bridge = nativeBridge {
            let candidates = bridge.search(for: normalized, limit: limit)
            cache[normalized] = candidates
            return candidates
        }

        let candidates = fallbackSuggestions(for: normalized, limit: limit)
        cache[normalized] = candidates
        return candidates
    }

    func registerUserCandidate(_ candidate: String, for rawInput: String) {
        let normalized = normalize(rawInput)
        guard !candidate.isEmpty, !normalized.isEmpty else { return }
        var bucket = lexicon[normalized] ?? []
        if let existingIndex = bucket.firstIndex(of: candidate) {
            bucket.remove(at: existingIndex)
        }
        bucket.insert(candidate, at: 0)
        lexicon[normalized] = bucket
        cache[normalized] = bucket
        userPhraseStore?.addCandidate(candidate, for: normalized)
    }

    func clear() {
        cache.removeAll()
    }

    func replaceLexicon(with url: URL) throws {
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([LexiconEntry].self, from: data)
        buildLexicon(from: entries)
        mergeUserPhrasesIntoLexicon()
        cache.removeAll()
    }

    private func loadBundledLexicon() {
        guard let url = Bundle.main.url(forResource: "rime_lexicon", withExtension: "json") else {
            mergeUserPhrasesIntoLexicon()
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([LexiconEntry].self, from: data)
            buildLexicon(from: entries)
        } catch {
            print("[RimeEngine] Failed to load bundled lexicon: \(error)")
        }
        mergeUserPhrasesIntoLexicon()
    }

    private func buildLexicon(from entries: [LexiconEntry]) {
        var table: [String: [String]] = [:]
        for entry in entries {
            let normalized = normalize(entry.syllable)
            let merged = (table[normalized] ?? []) + entry.candidates
            var seen = Set<String>()
            var deduped: [String] = []
            for word in merged where seen.insert(word).inserted {
                deduped.append(word)
            }
            table[normalized] = deduped
        }
        lexicon = table
    }

    private func fallbackSuggestions(for input: String, limit: Int) -> [String] {
        guard !input.isEmpty else { return [] }
        var matches: [String] = lexicon[input] ?? []
        if matches.count < limit {
            for (key, value) in lexicon where key.hasPrefix(input) && key != input {
                for candidate in value {
                    if matches.count >= limit { break }
                    if !matches.contains(candidate) {
                        matches.append(candidate)
                    }
                }
                if matches.count >= limit { break }
            }
        }
        return Array(matches.prefix(limit))
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
    }

    private func mergeUserPhrasesIntoLexicon() {
        guard let snapshot = userPhraseStore?.snapshot(), !snapshot.isEmpty else { return }
        lexicon.mergeSnapshot(snapshot)
    }
}

private struct LexiconEntry: Decodable {
    let syllable: String
    let candidates: [String]
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
