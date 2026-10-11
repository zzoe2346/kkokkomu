import Foundation
import Testing

@testable import TailCore

func fixture() -> Library {
    var lib = Library()
    let session = Session(title: "트랜잭션", experience: "SELECT 'MAX'", tags: "DB")
    var question = Question(
        sessionID: session.id,
        material: Material(
            text: "동시에 채번하면?", hints: ["읽는 순서"], sampleAnswer: "두 요청이 같은 값을 읽을 수 있습니다.",
            explanation: "조회와 할당 사이에 다른 요청이 실행됩니다."))
    question.draft = "임시 답변\nSELECT MAX(id) FROM sample;"
    lib.sessions = [session]
    lib.questions = [question]
    return lib
}
func temporaryDB() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
        "tail-test-\(UUID())/library.sqlite")
}

@Test func submissionIsImmutableAndDeduplicated() throws {
    var lib = fixture()
    let id = lib.questions[0].id
    let first = try lib.submit(questionID: id, text: "두 요청이 같은 값을 읽습니다.")
    #expect(lib.questions[0].draft.isEmpty)
    #expect(throws: TailError.self) { try lib.submit(questionID: id, text: "중복 클릭") }
    lib.attempts[0].status = "complete"
    lib.questions[0].isAnswering = true
    _ = try lib.submit(questionID: id, text: "순서를 보완한 답변")
    #expect(lib.attempts.count == 2)
    #expect(
        lib.attempts[0]
            == {
                var a = first
                a.status = "complete"
                return a
            }())
}
@Test func interruptedAttemptsCanResumeWithoutLosingText() throws {
    var lib = fixture()
    _ = try lib.submit(questionID: lib.questions[0].id, text: "작성한 원문")
    lib.recoverInterrupted()
    #expect(lib.attempts[0].status == "failed")
    #expect(lib.attempts[0].text == "작성한 원문")
}
@Test func invalidCrossSessionParentIsRejected() {
    var lib = fixture()
    let other = Session(title: "다른 주제")
    lib.sessions.append(other)
    lib.questions.append(
        Question(
            sessionID: other.id, parentID: lib.questions[0].id, ordinal: 2, material: Material()))
    #expect(throws: TailError.self) { try lib.validate() }
}
@Test func spacedReviewUsesCalendarAndSelfRating() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let now = Date(timeIntervalSince1970: 1_792_000_000)
    var review = ReviewItem(questionID: UUID(), due: now)
    for (index, days) in [1, 3, 7, 7].enumerated() {
        review.rate(.good, now: now, calendar: calendar)
        #expect(review.due == calendar.date(byAdding: .day, value: days, to: now))
        #expect(review.count == index + 1)
    }
    review.rate(.again, now: now, calendar: calendar)
    #expect(review.stage == 0)
    review.rate(.uncertain, now: now, calendar: calendar)
    #expect(review.stage == 0)
}
@Test func sqliteRoundTripBackupAndRevisionOrdering() async throws {
    let url = temporaryDB()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let repo = Repository(url: url)
    _ = try await repo.load()
    var lib = fixture()
    let original = lib
    try await repo.save(lib, revision: 2)
    lib.questions[0].draft = "오래된 저장"
    try await repo.save(lib, revision: 1)
    let loaded = try await repo.load()
    #expect(loaded == original)
    let backup = url.deletingLastPathComponent().appendingPathComponent("backup.sqlite")
    try await repo.backup(to: backup)
    lib.removeSession(lib.sessions[0].id)
    try await repo.save(lib, revision: 3)
    let restored = try await repo.restore(from: backup, revision: 4)
    #expect(restored == original)
    let reopened = try await Repository(url: url).load()
    #expect(reopened == original)
}
@Test func corruptRestorePreservesCurrentLibrary() async throws {
    let url = temporaryDB()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let repo = Repository(url: url)
    let lib = fixture()
    try await repo.save(lib, revision: 1)
    let corrupt = url.deletingLastPathComponent().appendingPathComponent("corrupt.sqlite")
    try Data("invalid".utf8).write(to: corrupt)
    await #expect(throws: (any Error).self) { try await repo.restore(from: corrupt, revision: 2) }
    let current = try await repo.load()
    #expect(current == lib)
}
@Test func deletedSessionRemovesAllRelatedHistory() async throws {
    let url = temporaryDB()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let repo = Repository(url: url)
    var lib = fixture()
    _ = try lib.submit(questionID: lib.questions[0].id, text: "답변")
    lib.reviews.append(ReviewItem(questionID: lib.questions[0].id))
    try await repo.save(lib, revision: 1)
    lib.removeSession(lib.sessions[0].id)
    try await repo.save(lib, revision: 2)
    let empty = try await repo.load()
    #expect(
        empty.sessions.isEmpty && empty.questions.isEmpty && empty.attempts.isEmpty
            && empty.reviews.isEmpty)
}
