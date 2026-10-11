import Foundation

public enum Sample {
    public static func library() -> Library {
        var lib = Library()
        var session = Session(
            title: "동시에 들어온 요청, 같은 번호", experience: "샘플 상황: 여러 요청에서 MAX(id) + 1로 번호를 생성했습니다.",
            tags: "DB, 동시성")
        session.isSample = true
        let material = Material(
            text: "현재 최댓값에 1을 더해 번호를 발급하면, 동시에 들어온 두 요청에서 어떤 문제가 생길까요?",
            intent: "조회와 할당 사이에 발생하는 경쟁 상태를 설명해봅니다.",
            hints: [
                "두 요청이 최댓값을 읽는 순간을 순서대로 생각해보세요.", "A가 10을 읽은 직후, A가 저장하기 전에 B도 조회한다면 어떤 값을 읽을까요?",
            ],
            clarification: "지금 저장된 가장 큰 번호가 10이라고 가정해보세요. A와 B가 각각 다음 번호를 계산하고 저장하는 순서를 설명하면 됩니다.",
            keywords: ["경쟁 상태", "원자성", "유일성"],
            sampleAnswer:
                "두 요청이 저장 전에 같은 최댓값을 읽으면 둘 다 같은 다음 번호를 계산할 수 있습니다. 예를 들어 A와 B가 모두 10을 읽으면 둘 다 11을 사용합니다. 조회와 번호 할당을 안전하게 묶거나 DB가 제공하는 채번 기능을 사용해야 합니다. 유니크 제약도 중복 저장을 막는 최종 방어선으로 둘 수 있습니다.",
            explanation:
                "문제는 조회와 저장이 하나의 원자적인 작업이 아니라는 점입니다.\n\n```text\nA: MAX 조회 → 10\nB: MAX 조회 → 10\nA: 11 저장\nB: 11 저장 시도\n```\n\n유니크 제약이 있다면 두 번째 저장은 실패합니다. 중복이 저장되지 않는 것과 모든 요청이 성공적으로 번호를 받는 것은 서로 다른 조건입니다. 트랜잭션의 존재만으로 해결을 단정할 수 없으며 격리 수준과 잠금 방식 등을 함께 봐야 합니다."
        )
        let q = Question(sessionID: session.id, material: material)
        session.currentQuestionID = q.id
        lib.sessions = [session]
        lib.questions = [q]
        return lib
    }
}
