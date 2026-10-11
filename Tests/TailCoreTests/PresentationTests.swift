import Foundation
import Testing

@testable import TailCore

@Test func legacyQuestionKeepsItsOriginalTextWithoutPresentation() throws {
    let json =
        #"{"text":"원래 질문\nSELECT id FROM orders;","intent":"학습 의도","hints":["힌트"],"clarification":"설명","keywords":["SQL"],"sampleAnswer":"답안","explanation":"해설"}"#
    let material = try JSONDecoder().decode(Material.self, from: Data(json.utf8))
    #expect(material.presentation == nil)
    #expect(material.text == "원래 질문\nSELECT id FROM orders;")
    try material.validate()
}

@Test func structuredAndLegacyQuestionsSurviveBackupTogether() async throws {
    let url = temporaryDB()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let repo = Repository(url: url)
    var library = fixture()
    let original = library.questions[0]
    var material = original.material
    material.presentation = QuestionPresentation(
        title: "인덱스 순서", context: "```sql\ncustomer_id = ? AND created_at >= ?\n```",
        prompt: "어떤 순서를 먼저 검토하겠나요?", isHypothetical: true)
    material.text = try #require(material.presentation).fullText
    library.questions.append(
        Question(
            sessionID: original.sessionID, parentID: original.id, ordinal: 2, material: material))
    try await repo.save(library, revision: 1)
    let backup = url.deletingLastPathComponent().appendingPathComponent("backup.sqlite")
    try await repo.backup(to: backup)
    let restored = try await repo.restore(from: backup, revision: 2)
    #expect(restored == library)
    #expect(restored.questions.first { $0.id == original.id } == original)
    let reopened = try await Repository(url: url).load()
    #expect(reopened == library)
}

@Test func incompleteQuestionPresentationIsRejected() {
    var material = Sample.library().questions[0].material
    material.presentation?.prompt = "  "
    #expect(throws: TailError.self) { try material.validate() }
}
