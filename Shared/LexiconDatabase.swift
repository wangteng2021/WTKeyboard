import Foundation
import SQLite3

final class LexiconDatabase {
    private let db: OpaquePointer?

    private init(database: OpaquePointer?) {
        self.db = database
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    static func loadDefaultDatabase() -> LexiconDatabase? {
        let fileManager = FileManager.default

        if let sharedURL = AppGroup.fileURL(appending: AppGroup.Resource.sqliteLexicon),
           fileManager.fileExists(atPath: sharedURL.path),
           let database = LexiconDatabase.openDatabase(at: sharedURL) {
            return database
        }

        if let bundleURL = Bundle.main.url(forResource: "rime_lexicon", withExtension: "sqlite"),
           let database = LexiconDatabase.openDatabase(at: bundleURL) {
            return database
        }

        return nil
    }

    private static func openDatabase(at url: URL) -> LexiconDatabase? {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK {
            return LexiconDatabase(database: handle)
        } else if let handle {
            sqlite3_close(handle)
        }
        return nil
    }

    func lookup(code: String, limit: Int) -> [String] {
        guard let db, !code.isEmpty else { return [] }

        var results: [String] = []
        var seen = Set<String>()

        fetch(sql: "SELECT word FROM entries WHERE code_norm = ? ORDER BY weight DESC LIMIT ?;", code: code, limit: limit) { word in
            if !seen.contains(word) {
                seen.insert(word)
                results.append(word)
            }
        }

        if results.count < limit {
            fetch(sql: "SELECT word FROM entries WHERE code_norm LIKE ? || '%' ORDER BY weight DESC LIMIT ?;", code: code, limit: limit) { word in
                if !seen.contains(word) {
                    seen.insert(word)
                    results.append(word)
                }
            }
        }

        if results.count < limit {
            fetch(sql: "SELECT word FROM entries WHERE code_norm GLOB ? || '*' ORDER BY LENGTH(code_norm), weight DESC LIMIT ?;", code: code, limit: limit) { word in
                if !seen.contains(word) {
                    seen.insert(word)
                    results.append(word)
                }
            }
        }

        return Array(results.prefix(limit))
    }

    private func fetch(sql: String, code: String, limit: Int, consumer: (String) -> Void) {
        guard let db else { return }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        while sqlite3_step(statement) == SQLITE_ROW {
            if let pointer = sqlite3_column_text(statement, 0) {
                let word = String(cString: pointer)
                consumer(word)
            }
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
