import Foundation
import SQLite3

struct MedicalCandidate {
    let reading: String
    let word: String
}

final class DictionaryStore {
    private var database: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private(set) var error: String?

    init() {
        guard let url = Bundle.main.url(forResource: "medical", withExtension: "sqlite") else {
            error = "辞書ファイルが見つかりません"; return
        }
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            error = "辞書を開けません"; return
        }
        sqlite3_exec(database, "PRAGMA cache_size=-512; PRAGMA mmap_size=0;", nil, nil, nil)
    }

    deinit { sqlite3_close(database) }

    func candidates(for raw: String, includePractical: Bool, limit: Int = 30) -> [MedicalCandidate] {
        guard database != nil else { return [] }
        let reading = raw.precomposedStringWithCanonicalMapping
        guard !reading.isEmpty else { return [] }
        var results: [MedicalCandidate] = []
        var seen = Set<String>()
        let flag = includePractical ? "1" : "0"
        // Exact reading matches come first. Prefix lookups use the same indexed range as the build checks.
        let queries = [
            ("SELECT reading,word FROM entries WHERE reading=? AND practical<=\(flag) ORDER BY priority,word LIMIT \(limit)", [reading]),
            ("SELECT reading,word FROM entries WHERE reading>? AND reading<? AND practical<=\(flag) ORDER BY priority,length(reading),reading,word LIMIT \(limit)", [reading, reading + "\u{10FFFF}"])
        ]
        for (sql, values) in queries {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { continue }
            for (index, value) in values.enumerated() {
                value.withCString { pointer in
                    _ = sqlite3_bind_text(statement, Int32(index + 1), pointer, -1, transient)
                }
            }
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let r = sqlite3_column_text(statement, 0), let w = sqlite3_column_text(statement, 1) else { continue }
                let word = String(cString: w)
                if seen.insert(word).inserted {
                    results.append(MedicalCandidate(reading: String(cString: r), word: word))
                    if results.count >= limit { break }
                }
            }
            sqlite3_finalize(statement)
            if results.count >= limit { break }
        }
        return results
    }
}
