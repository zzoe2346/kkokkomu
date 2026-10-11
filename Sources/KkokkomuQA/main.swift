import Foundation
import KkokkomuCore

if CommandLine.arguments.contains("--live") {
    let directory = URL(fileURLWithPath: CommandLine.arguments.last!)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var lib = Library()
    var session = Session(
        title: "동시 요청과 채번", experience: "학습용 가정: MAX(id) + 1을 사용해 새 번호를 만들고 있다.", tags: "DB, 동시성")
    let client = CodexClient(timeout: 240)
    print("실제 Codex 첫 질문 생성 시작")
    let first = try await client.generate(
        session: session, question: nil, attempt: nil, history: [])
    let question = Question(sessionID: session.id, material: first.question)
    session.currentQuestionID = question.id
    lib.sessions = [session]
    lib.questions = [question]
    let repo = Repository(url: directory.appendingPathComponent("library.sqlite"))
    try await repo.save(lib, revision: 1)
    print("첫 질문 생성 완료. 실제 답변 피드백 생성 시작")
    let attempt = try lib.submit(
        questionID: question.id,
        text:
            "두 요청이 동시에 최댓값 10을 읽으면 둘 다 11을 계산할 수 있습니다. 유니크 제약이 있으면 중복 저장은 막을 수 있지만 두 번째 요청은 실패합니다. 트랜잭션으로 감싸기만 하면 해결되는지는 격리 수준과 잠금 방식에 따라 다르다고 생각합니다."
    )
    try await repo.save(lib, revision: 2)
    let evaluated = try await client.generate(
        session: session, question: question, attempt: attempt, history: [])
    lib.attempts[0].result = evaluated
    lib.attempts[0].status = "complete"
    lib.reviews = [ReviewItem(questionID: question.id, due: Date())]
    try await repo.save(lib, revision: 3)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(first).write(to: directory.appendingPathComponent("first.json"))
    try encoder.encode(evaluated).write(to: directory.appendingPathComponent("evaluation.json"))
    print("실제 Codex 생성 및 저장 완료: \(directory.path)")
    print("꼬리 질문: \(evaluated.nextQuestion.text)")
} else {
    print("사용법: swift run KkokkomuQA --live work/qa-live")
}
