#!/usr/bin/env swift

import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct Entry {
    let word: String
    let codeRaw: String
    let codeNormalized: String
    let weight: Int
}

enum ConverterError: Error {
    case invalidArguments
    case failedToReadInput(URL)
    case failedToOpenDatabase(String)
    case failedToPrepareStatement(String)
}

@discardableResult
func main() throws -> Int32 {
    let arguments = CommandLine.arguments
    guard arguments.count >= 3 else {
        print("Usage: convert_rime_dict <path/to/dict.yaml> <path/to/output.sqlite>")
        throw ConverterError.invalidArguments
    }

    let inputURL = URL(fileURLWithPath: arguments[1])
    let outputURL = URL(fileURLWithPath: arguments[2])

    let entries = try parseEntries(from: inputURL)
    try export(entries: entries, to: outputURL)
    print("Converted \(entries.count) entries into \(outputURL.path)")
    return EXIT_SUCCESS
}

func parseEntries(from url: URL) throws -> [Entry] {
    let data = try Data(contentsOf: url)
    guard let contents = String(data: data, encoding: .utf8) else {
        throw ConverterError.failedToReadInput(url)
    }

    var entries: [Entry] = []
    var reachedPayload = false

    contents.enumerateLines { rawLine, _ in
        if !reachedPayload {
            if rawLine.trimmingCharacters(in: .whitespaces) == "..." {
                reachedPayload = true
            }
            return
        }

        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, !line.hasPrefix("#") else { return }

        let parts = line.split(separator: "\t").map { String($0) }
        let tokens: [String]
        if parts.count >= 2 {
            tokens = parts
        } else {
            tokens = line.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        }

        guard tokens.count >= 2 else { return }
        let phrase = tokens[0]
        let codeRaw = tokens[1]
        let weight = tokens.count >= 3 ? Int(tokens[2]) ?? 0 : 0
        let normalized = normalize(codeRaw)

        entries.append(Entry(word: phrase, codeRaw: codeRaw, codeNormalized: normalized, weight: weight))
    }

    return entries
}

func export(entries: [Entry], to url: URL) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
        try fileManager.removeItem(at: url)
    }
    let parent = url.deletingLastPathComponent()
    if !fileManager.fileExists(atPath: parent.path) {
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
    }

    var db: OpaquePointer?
    guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
        throw ConverterError.failedToOpenDatabase(url.path)
    }
    defer { sqlite3_close(db) }

    try exec(db: db, sql: "PRAGMA journal_mode=OFF;")
    try exec(db: db, sql: "PRAGMA synchronous=OFF;")
    try exec(db: db, sql: """
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code_raw TEXT NOT NULL,
            code_norm TEXT NOT NULL,
            word TEXT NOT NULL,
            weight INTEGER DEFAULT 0
        );
        """)
    try exec(db: db, sql: "CREATE INDEX idx_entries_code_norm ON entries(code_norm);")

    let insertSQL = "INSERT INTO entries (code_raw, code_norm, word, weight) VALUES (?, ?, ?, ?);"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
        throw ConverterError.failedToPrepareStatement(String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(statement) }

    for entry in entries {
        sqlite3_bind_text(statement, 1, entry.codeRaw, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, entry.codeNormalized, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, entry.word, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 4, Int32(entry.weight))

        if sqlite3_step(statement) != SQLITE_DONE {
            let message = String(cString: sqlite3_errmsg(db))
            print("Failed to insert entry \(entry.word): \(message)")
        }
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }
}

func exec(db: OpaquePointer?, sql: String) throws {
    if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
        throw ConverterError.failedToPrepareStatement(String(cString: sqlite3_errmsg(db)))
    }
}

func normalize(_ code: String) -> String {
    let trimmed = code.lowercased().replacingOccurrences(of: "'", with: "")
    return trimmed.replacingOccurrences(of: " ", with: "")
}

do {
    _ = try main()
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
