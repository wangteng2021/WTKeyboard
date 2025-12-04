import Foundation

protocol InputEngine {
    func suggestions(for input: String, limit: Int) -> [String]
    func registerUserCandidate(_ candidate: String, for input: String)
    func clear()
}

final class RimeEngine: InputEngine {
    static let shared = RimeEngine()

    private let lexiconDatabase: LexiconDatabase?
    private var userLexicon: [String: [String]] = [:]
    private var nativeBridge: RimeNativeBridge?
    private var cache: [String: [String]] = [:]
    private let queue = DispatchQueue(label: "com.wtkeyboard.rime", qos: .userInitiated)
    private let userPhraseStore = UserPhraseStore()

    private init() {
        lexiconDatabase = LexiconDatabase.loadDefaultDatabase()
        userLexicon = userPhraseStore?.snapshot() ?? [:]
    }

    func registerNativeBridge(_ bridge: RimeNativeBridge) {
        queue.sync {
            nativeBridge = bridge
            cache.removeAll()
        }
    }

    func suggestions(for rawInput: String, limit: Int = 8) -> [String] {
        let normalized = normalize(rawInput)
        guard !normalized.isEmpty else { return [] }

        return queue.sync {
            if let cached = cache[normalized] {
                return Array(cached.prefix(limit))
            }

            var candidates: [String] = []
            if let bridge = nativeBridge {
                candidates = bridge.search(for: normalized, limit: limit)
            } else if let database = lexiconDatabase {
                candidates = database.lookup(code: normalized, limit: limit)
            }

            candidates = overlayUserCandidates(for: normalized, base: candidates, limit: limit)
            cache[normalized] = candidates
            return Array(candidates.prefix(limit))
        }
    }

    func registerUserCandidate(_ candidate: String, for rawInput: String) {
        let normalized = normalize(rawInput)
        guard !candidate.isEmpty, !normalized.isEmpty else { return }
        queue.sync {
            var bucket = userLexicon[normalized] ?? []
            if let existingIndex = bucket.firstIndex(of: candidate) {
                bucket.remove(at: existingIndex)
            }
            bucket.insert(candidate, at: 0)
            userLexicon[normalized] = bucket
            let existing = cache[normalized] ?? []
            let limit = max(existing.count, 8)
            cache[normalized] = overlayUserCandidates(for: normalized, base: existing, limit: limit)
            userPhraseStore?.addCandidate(candidate, for: normalized)
        }
    }

    func clear() {
        queue.sync {
            cache.removeAll()
        }
    }

    private func normalize(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return folded
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func overlayUserCandidates(for key: String, base: [String], limit: Int) -> [String] {
        guard let custom = userLexicon[key], !custom.isEmpty else {
            return base
        }
        var combined: [String] = custom
        for candidate in base where !combined.contains(candidate) {
            combined.append(candidate)
        }
        return Array(combined.prefix(limit))
    }
}
