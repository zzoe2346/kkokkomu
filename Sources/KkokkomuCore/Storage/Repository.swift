import Foundation
import SQLite3

public actor Repository {
    public let url: URL
    private var latestRevision: UInt64 = 0
    public init(url: URL) { self.url = url }
    private func connection<T>(
        at file: URL? = nil, readonly: Bool = false, _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        let target = file ?? url
        if !readonly {
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        var pointer: OpaquePointer?
        let flags = readonly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(target.path, &pointer, flags, nil) == SQLITE_OK, let db = pointer
        else {
            if let pointer { sqlite3_close(pointer) }
            throw KkokkomuError.storage("학습 보관함을 열 수 없습니다. 저장 위치와 권한을 확인하세요.")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5000)
        try execute(db, "PRAGMA foreign_keys=ON")
        return try body(db)
    }
    private func execute(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw KkokkomuError.storage("학습 기록 저장에 실패했습니다. 원본을 유지했습니다. (\(sqlite3_errcode(db)))")
        }
    }
    private func rows(_ db: OpaquePointer, _ sql: String) throws -> [[String]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw KkokkomuError.storage("보관함 형식을 읽을 수 없습니다.")
        }
        defer { sqlite3_finalize(stmt) }
        var result: [[String]] = []
        while true {
            let status = sqlite3_step(stmt)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw KkokkomuError.storage("보관함을 읽지 못했습니다.") }
            result.append(
                (0..<sqlite3_column_count(stmt)).map { i in
                    sqlite3_column_text(stmt, i).map { String(cString: $0) } ?? ""
                })
        }
    }
    private func schema(_ db: OpaquePointer) throws {
        let version = try rows(db, "PRAGMA user_version").first?.first
        guard version == "0" || version == "1" else {
            throw KkokkomuError.storage("더 새로운 버전의 보관함입니다. 앱을 업데이트하세요.")
        }
        if version == "0" {
            guard try rows(db, "SELECT name FROM sqlite_master WHERE type='table'").isEmpty else {
                throw KkokkomuError.storage("알 수 없는 데이터 파일입니다.")
            }
            try execute(
                db,
                """
                BEGIN IMMEDIATE;
                CREATE TABLE session(id TEXT PRIMARY KEY, payload TEXT NOT NULL);
                CREATE TABLE question(id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES session(id), parent_id TEXT REFERENCES question(id), payload TEXT NOT NULL);
                CREATE TABLE attempt(id TEXT PRIMARY KEY, question_id TEXT NOT NULL REFERENCES question(id), payload TEXT NOT NULL);
                CREATE TABLE review(id TEXT PRIMARY KEY REFERENCES question(id), payload TEXT NOT NULL);
                CREATE INDEX question_session ON question(session_id);
                CREATE INDEX attempt_question ON attempt(question_id);
                PRAGMA user_version=1;
                COMMIT;
                """)
        }
    }
    private func readLibrary(_ db: OpaquePointer) throws -> Library {
        guard try rows(db, "PRAGMA user_version").first?.first == "1",
            try rows(db, "PRAGMA quick_check").first?.first == "ok",
            try rows(db, "PRAGMA foreign_key_check").isEmpty
        else { throw KkokkomuError.storage("백업 형식이나 무결성을 확인하지 못했습니다.") }
        func decode<T: Decodable>(_ table: String, _: T.Type) throws -> [T] {
            try rows(db, "SELECT payload FROM \(table) ORDER BY rowid").map {
                try JSONDecoder().decode(T.self, from: Data($0[0].utf8))
            }
        }
        var lib = Library()
        lib.sessions = try decode("session", Session.self)
        lib.questions = try decode("question", Question.self)
        lib.attempts = try decode("attempt", Attempt.self)
        lib.reviews = try decode("review", ReviewItem.self)
        try lib.validate()
        // Validate payload identifiers against indexed relations as well as against other payloads.
        let sessions = try rows(db, "SELECT id FROM session").map { $0[0] }
        guard Set(sessions) == Set(lib.sessions.map { $0.id.uuidString }) else {
            throw KkokkomuError.invalid("보관함 식별자가 일치하지 않습니다.")
        }
        for r in try rows(db, "SELECT id, session_id, COALESCE(parent_id,'') FROM question") {
            guard
                lib.questions.contains(where: {
                    $0.id.uuidString == r[0] && $0.sessionID.uuidString == r[1]
                        && ($0.parentID?.uuidString ?? "") == r[2]
                })
            else { throw KkokkomuError.invalid("질문의 연결이 올바르지 않습니다.") }
        }
        for r in try rows(db, "SELECT id, question_id FROM attempt") {
            guard
                lib.attempts.contains(where: {
                    $0.id.uuidString == r[0] && $0.questionID.uuidString == r[1]
                })
            else { throw KkokkomuError.invalid("답변의 연결이 올바르지 않습니다.") }
        }
        guard
            Set(try rows(db, "SELECT id FROM review").map { $0[0] })
                == Set(lib.reviews.map { $0.questionID.uuidString })
        else { throw KkokkomuError.invalid("복습 연결이 올바르지 않습니다.") }
        return lib
    }
    public func load() throws -> Library {
        try connection { db in
            try schema(db)
            return try readLibrary(db)
        }
    }
    public func save(_ lib: Library, revision: UInt64) throws {
        guard revision >= latestRevision else { return }
        try lib.validate()
        try connection { db in
            try schema(db)
            try execute(db, "BEGIN IMMEDIATE; PRAGMA defer_foreign_keys=ON")
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                func quoted(_ s: String) -> String {
                    "'" + s.replacingOccurrences(of: "'", with: "''") + "'"
                }
                func sync<T: Encodable>(
                    _ table: String, _ items: [T], fields: (T) -> [String: String?]
                ) throws {
                    let old = Dictionary(
                        uniqueKeysWithValues: try rows(db, "SELECT id, payload FROM \(table)").map {
                            ($0[0], $0[1])
                        })
                    var live = Set<String>()
                    for item in items {
                        let values = fields(item)
                        guard let id = values["id"] ?? nil else { continue }
                        live.insert(id)
                        let json = String(decoding: try encoder.encode(item), as: UTF8.self)
                        if old[id] == json { continue }
                        var all = values
                        all["payload"] = json
                        let keys = all.keys.sorted()
                        let vals = keys.map { (all[$0] ?? nil).map(quoted) ?? "NULL" }
                        let updates = keys.filter { $0 != "id" }.map { "\($0)=excluded.\($0)" }
                            .joined(separator: ",")
                        try execute(
                            db,
                            "INSERT INTO \(table)(\(keys.joined(separator: ","))) VALUES(\(vals.joined(separator: ","))) ON CONFLICT(id) DO UPDATE SET \(updates)"
                        )
                    }
                    for id in Set(old.keys).subtracting(live) {
                        try execute(db, "DELETE FROM \(table) WHERE id=\(quoted(id))")
                    }
                }
                try sync("session", lib.sessions) { ["id": $0.id.uuidString] }
                try sync("question", lib.questions) {
                    [
                        "id": $0.id.uuidString, "session_id": $0.sessionID.uuidString,
                        "parent_id": $0.parentID?.uuidString,
                    ]
                }
                try sync("attempt", lib.attempts) {
                    ["id": $0.id.uuidString, "question_id": $0.questionID.uuidString]
                }
                try sync("review", lib.reviews) { ["id": $0.questionID.uuidString] }
                try execute(db, "COMMIT")
            } catch {
                try? execute(db, "ROLLBACK")
                throw error
            }
        }
        latestRevision = revision
    }
    public func backup(to destination: URL) throws {
        guard destination.standardizedFileURL != url.standardizedFileURL else {
            throw KkokkomuError.invalid("보관함 원본과 다른 위치를 선택하세요.")
        }
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(
            ".kkokkomu-backup-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try connection { source in
            try connection(at: temporary) { target in
                guard let backup = sqlite3_backup_init(target, "main", source, "main") else {
                    throw KkokkomuError.storage("백업을 준비하지 못했습니다.")
                }
                let status = sqlite3_backup_step(backup, -1)
                let finish = sqlite3_backup_finish(backup)
                guard status == SQLITE_DONE, finish == SQLITE_OK else {
                    throw KkokkomuError.storage("백업을 완료하지 못했습니다.")
                }
            }
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
    }
    public func restore(from source: URL, revision: UInt64) throws -> Library {
        guard
            source.standardizedFileURL.resolvingSymlinksInPath()
                != url.standardizedFileURL.resolvingSymlinksInPath()
        else { throw KkokkomuError.invalid("현재 보관함은 복원 대상으로 선택할 수 없습니다.") }
        let lib = try connection(at: source, readonly: true) { try readLibrary($0) }
        let recovery = url.deletingLastPathComponent().appendingPathComponent(
            "recovery-\(UUID()).sqlite")
        try backup(to: recovery)
        try save(lib, revision: revision)
        return lib
    }
}
