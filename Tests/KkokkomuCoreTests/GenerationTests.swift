import Foundation
import Testing

@testable import KkokkomuCore

@Test func largeInputDoesNotBlockProcessPipes() async throws {
    let input = String(repeating: "한글 답변과 코드\n", count: 15000)
    let result = try await CLIRunner.run(
        executable: "/bin/cat", arguments: [], input: input, timeout: 5)
    #expect(result.exitCode == 0)
    #expect(String(decoding: result.output, as: UTF8.self) == input)
}
@Test func cancellationStopsChildGroup() async throws {
    let start = Date()
    let task = Task {
        try await CLIRunner.run(
            executable: "/bin/sh", arguments: ["-c", "sleep 20 & wait"], timeout: 30)
    }
    try await Task.sleep(for: .milliseconds(100))
    task.cancel()
    await #expect(throws: (any Error).self) { try await task.value }
    #expect(Date().timeIntervalSince(start) < 3)
}
@Test func timeoutRetainsFailureInsteadOfSuccess() async {
    await #expect(throws: KkokkomuError.self) {
        try await CLIRunner.run(executable: "/bin/sleep", arguments: ["10"], timeout: 0.1)
    }
}
@Test func completionAndFailureEventsAreNotConfused() async throws {
    let result = try await CLIRunner.run(
        executable: "/bin/echo",
        arguments: ["{\"type\":\"turn.failed\"}\n{\"type\":\"turn.completed\"}"], timeout: 2)
    #expect(result.completed && result.failed)
    let env = CLIRunner.environment([
        "PATH": "/bin", "OPENAI_API_KEY": "test", "CODEX_API_KEY": "test",
    ])
    #expect(env == ["PATH": "/bin"])
}
@Test func emptyEvaluationCannotBecomeFeedback() {
    let material = Sample.library().questions[0].material
    #expect(throws: KkokkomuError.self) {
        try Generation(question: material, nextQuestion: material).validate(evaluation: true)
    }
    #expect(Source(title: "file", url: "file:///private/test").safeURL == nil)
}
