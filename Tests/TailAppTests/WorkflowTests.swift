import Foundation
import TailCore
import Testing

@testable import TailApp

@MainActor private func waitForOperation(_ store: StudyStore) async throws {
    let until = Date().addingTimeInterval(6)
    while store.busy != nil && Date() < until { try await Task.sleep(for: .milliseconds(20)) }
    #expect(store.busy == nil)
}
@MainActor private func makeStore() async throws -> StudyStore {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "tail-workflow-\(UUID())")
    let store = StudyStore(directory: url)
    await store.load()
    store.addSample()
    var material = Sample.library().questions[0].material
    material.text = "AI가 임의로 다시 쓴 질문"
    material.presentation?.prompt = "기존 질문을 바꾸면 안 됩니다."
    var feedback = Feedback()
    feedback.strengths = ["핵심을 설명했습니다."]
    feedback.reviewSuggested = true
    let fixture = Generation(
        question: material, feedback: feedback,
        nextQuestion: Material(
            text: "유일성 제약만으로 충분할까요?", hints: ["실패한 요청"], sampleAnswer: "실패 처리가 필요합니다.",
            explanation: "요청 성공과 중복 방지는 다릅니다."))
    let fixtureFile = url.appendingPathComponent("fixture.json")
    try JSONEncoder().encode(fixture).write(to: fixtureFile)
    let cli = url.appendingPathComponent("fake-codex")
    let script = """
        #!/bin/sh
        if [ "$1" = "login" ]; then echo 'Logged in using ChatGPT'; exit 0; fi
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "--output-last-message" ]; then shift; cp '\(fixtureFile.path)' "$1"; fi
          shift
        done
        printf '{"type":"turn.completed"}\\n'
        """
    try Data(script.utf8).write(to: cli)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cli.path)
    store.clientOverride = CodexClient(executable: cli.path, timeout: 2)
    return store
}
@Test @MainActor func submittedAnswerPersistsAndNextQuestionIsUnique() async throws {
    let store = try await makeStore()
    defer { try? FileManager.default.removeItem(at: store.dataDirectory) }
    let q = try #require(store.currentQuestion)
    store.editQuestion(q.id) { $0.draft = "두 요청이 같은 값을 읽습니다." }
    store.submit(q.id)
    store.submit(q.id)
    try await waitForOperation(store)
    #expect(store.library.attempts.count == 1)
    #expect(store.library.attempts[0].status == "complete")
    #expect(store.library.attempts[0].result?.question.text == q.material.text)
    #expect(store.library.attempts[0].result?.question.presentation == q.material.presentation)
    store.next(q)
    store.next(q)
    #expect(store.library.questions.count == 2)
    try await store.flush()
    let disk = try await store.repository.load()
    #expect(disk.attempts[0].text == "두 요청이 같은 값을 읽습니다.")
    #expect(disk.questions[1].parentID == q.id)
}
@Test @MainActor func reviewHidesAnswerAndRatesOnlyOnce() async throws {
    let store = try await makeStore()
    defer { try? FileManager.default.removeItem(at: store.dataDirectory) }
    let q = try #require(store.currentQuestion)
    store.submit(q.id, unknown: true)
    try await waitForOperation(store)
    store.finish(q.sessionID)
    #expect(store.library.reviews.count == 1)
    store.reanswer(try #require(store.currentQuestion), review: true)
    let reviewing = try #require(store.currentQuestion)
    #expect(reviewing.isAnswering && reviewing.isReview && !reviewing.revealed)
    store.editQuestion(q.id) { $0.draft = "복습한 답변" }
    store.submit(q.id)
    try await waitForOperation(store)
    store.rate(reviewing, .good)
    store.rate(reviewing, .good)
    #expect(store.library.reviews[0].count == 1)
    #expect(store.library.attempts.count == 2)
    #expect(store.library.attempts[0].sawAnswer)
    try await store.flush()
}
@Test @MainActor func failureRetainsSubmittedTextAndRetryUsesSameAttempt() async throws {
    let store = try await makeStore()
    defer { try? FileManager.default.removeItem(at: store.dataDirectory) }
    let working = store.clientOverride
    store.clientOverride = CodexClient(executable: "/bin/false", timeout: 1)
    let q = try #require(store.currentQuestion)
    store.editQuestion(q.id) { $0.draft = "실패해도 남아야 하는 답변" }
    store.submit(q.id)
    try await waitForOperation(store)
    let id = store.library.attempts[0].id
    #expect(store.library.attempts[0].status == "failed")
    store.clientOverride = working
    store.evaluate(id)
    try await waitForOperation(store)
    #expect(store.library.attempts.count == 1 && store.library.attempts[0].id == id)
    #expect(store.library.attempts[0].status == "complete")
    #expect(store.library.attempts[0].text == "실패해도 남아야 하는 답변")
}
