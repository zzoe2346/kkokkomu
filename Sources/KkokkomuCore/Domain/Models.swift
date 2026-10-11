import Foundation

public enum KkokkomuError: Error, LocalizedError, Sendable {
    case invalid(String)
    case generation(String)
    case storage(String)
    case cancelled, timeout
    public var errorDescription: String? {
        switch self {
        case .invalid(let s), .generation(let s), .storage(let s): return s
        case .cancelled: return "생성을 취소했습니다. 작성한 내용은 저장되어 있습니다."
        case .timeout: return "응답 시간이 초과됐습니다. 저장된 답변에서 다시 시도하세요."
        }
    }
}
extension String {
    public var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
public struct Source: Codable, Sendable, Equatable {
    public var title: String
    public var url: String
    public init(title: String, url: String) {
        self.title = title
        self.url = url
    }
    public var safeURL: URL? {
        guard let u = URL(string: url), u.scheme == "https", u.host != nil else { return nil }
        return u
    }
}
public struct QuestionPresentation: Codable, Sendable, Equatable {
    public var title: String
    public var context: String
    public var prompt: String
    public var isHypothetical: Bool
    public init(title: String, context: String, prompt: String, isHypothetical: Bool) {
        self.title = title
        self.context = context
        self.prompt = prompt
        self.isHypothetical = isHypothetical
    }
    public var fullText: String {
        [context.trimmed, prompt.trimmed].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
public struct Material: Codable, Sendable, Equatable {
    public var text = ""
    public var presentation: QuestionPresentation?
    public var intent = ""
    public var hints: [String] = []
    public var clarification = ""
    public var keywords: [String] = []
    public var sampleAnswer = ""
    public var explanation = ""
    public init(
        text: String = "", intent: String = "", hints: [String] = [], clarification: String = "",
        keywords: [String] = [], sampleAnswer: String = "", explanation: String = "",
        presentation: QuestionPresentation? = nil
    ) {
        self.text = text
        self.intent = intent
        self.hints = hints
        self.clarification = clarification
        self.keywords = keywords
        self.sampleAnswer = sampleAnswer
        self.explanation = explanation
        self.presentation = presentation
    }
    public func validate() throws {
        guard !text.trimmed.isEmpty, !sampleAnswer.trimmed.isEmpty, !explanation.trimmed.isEmpty,
            !hints.isEmpty, text.count < 8000
        else { throw KkokkomuError.invalid("질문이나 해설이 비어 있습니다. 다시 생성하세요.") }
        if let presentation {
            guard !presentation.title.trimmed.isEmpty, presentation.title.count <= 100,
                !presentation.prompt.trimmed.isEmpty, presentation.fullText.count < 8000
            else { throw KkokkomuError.invalid("질문의 제목이나 핵심 질문이 올바르지 않습니다.") }
        }
    }
}
public struct Feedback: Codable, Sendable, Equatable {
    public var strengths: [String] = []
    public var corrections: [String] = []
    public var gaps: [String] = []
    public var evidence: [String] = []
    public var comparison = ""
    public var reviewSuggested = false
    public var verificationNote = ""
    public var sources: [Source] = []
    public init() {}
}
public struct Generation: Codable, Sendable, Equatable {
    public var question: Material
    public var feedback: Feedback
    public var nextQuestion: Material
    public init(
        question: Material, feedback: Feedback = Feedback(), nextQuestion: Material = Material()
    ) {
        self.question = question
        self.feedback = feedback
        self.nextQuestion = nextQuestion
    }
    public func validate(evaluation: Bool) throws {
        try question.validate()
        if evaluation {
            try nextQuestion.validate()
            guard !(feedback.strengths + feedback.corrections + feedback.gaps).isEmpty else {
                throw KkokkomuError.invalid("피드백이 비어 있습니다. 저장된 답변에서 다시 시도하세요.")
            }
        }
        guard feedback.sources.allSatisfy({ $0.safeURL != nil }) else {
            throw KkokkomuError.invalid("참고 자료 주소가 올바르지 않습니다.")
        }
    }
}
public struct Session: Codable, Identifiable, Sendable, Equatable {
    public var id = UUID()
    public var title: String
    public var experience: String
    public var tags: String
    public var createdAt = Date()
    public var endedAt: Date?
    public var currentQuestionID: UUID?
    public var isSample = false
    public var limit = 4
    public init(title: String, experience: String = "", tags: String = "") {
        self.title = title
        self.experience = experience
        self.tags = tags
    }
}
public struct Question: Codable, Identifiable, Sendable, Equatable {
    public var id = UUID()
    public var sessionID: UUID
    public var parentID: UUID?
    public var ordinal: Int
    public var material: Material
    public var draft = ""
    public var hintLevel = 0
    public var revealed = false
    public var isAnswering = true
    public var isReview = false
    public init(sessionID: UUID, parentID: UUID? = nil, ordinal: Int = 1, material: Material) {
        self.sessionID = sessionID
        self.parentID = parentID
        self.ordinal = ordinal
        self.material = material
    }
}
public struct Attempt: Codable, Identifiable, Sendable, Equatable {
    public var id = UUID()
    public var questionID: UUID
    public var text: String
    public var createdAt = Date()
    public var status = "pending"
    public var error = ""
    public var hintLevel: Int
    public var sawAnswer: Bool
    public var isReview: Bool
    public var rating: String?
    public var result: Generation?
    public var previousResults: [Generation] = []
    public init(question: Question, text: String) {
        self.questionID = question.id
        self.text = text
        self.hintLevel = question.hintLevel
        self.sawAnswer = question.revealed
        self.isReview = question.isReview
    }
}
public enum Rating: String, CaseIterable, Sendable {
    case again = "다시 필요"
    case uncertain = "조금 헷갈림"
    case good = "설명 가능"
}
public struct ReviewItem: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID { questionID }
    public var questionID: UUID
    public var due: Date
    public var stage: Int = 0
    public var count = 0
    public init(
        questionID: UUID,
        due: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    ) {
        self.questionID = questionID
        self.due = due
    }
    public mutating func rate(
        _ rating: Rating, now: Date = Date(), intervals: [Int] = [1, 3, 7],
        calendar: Calendar = .current
    ) {
        if rating == .again {
            stage = 0
        } else if rating == .good && count > 0 {
            stage = min(2, stage + 1)
        }
        let days = intervals.count == 3 ? intervals.map { max(1, $0) } : [1, 3, 7]
        due = calendar.date(byAdding: .day, value: days[stage], to: now) ?? now
        count += 1
    }
}
public struct Library: Codable, Sendable, Equatable {
    public var sessions: [Session] = []
    public var questions: [Question] = []
    public var attempts: [Attempt] = []
    public var reviews: [ReviewItem] = []
    public init() {}
    public func questions(in session: UUID) -> [Question] {
        questions.filter { $0.sessionID == session }.sorted { $0.ordinal < $1.ordinal }
    }
    public func attempts(for question: UUID) -> [Attempt] {
        attempts.filter { $0.questionID == question }.sorted { $0.createdAt < $1.createdAt }
    }
    public mutating func submit(questionID: UUID, text: String) throws -> Attempt {
        guard let i = questions.firstIndex(where: { $0.id == questionID }),
            questions[i].isAnswering,
            !attempts.contains(where: { $0.questionID == questionID && $0.status == "pending" }),
            !text.trimmed.isEmpty
        else {
            throw KkokkomuError.invalid("답변을 입력하거나 진행 중인 제출이 끝날 때까지 기다려주세요.")
        }
        guard text.count <= 30000 else { throw KkokkomuError.invalid("답변은 30,000자 이내로 입력하세요.") }
        let attempt = Attempt(question: questions[i], text: text)
        attempts.append(attempt)
        questions[i].isAnswering = false
        questions[i].draft = ""
        return attempt
    }
    public mutating func recoverInterrupted() {
        for i in attempts.indices where attempts[i].status == "pending" {
            attempts[i].status = "failed"
            attempts[i].error = "이전 생성이 중단되었습니다. 다시 시도할 수 있습니다."
        }
    }
    public func validate() throws {
        let ss = Set(sessions.map(\.id))
        let qs = Set(questions.map(\.id))
        guard ss.count == sessions.count, qs.count == questions.count,
            Set(attempts.map(\.id)).count == attempts.count,
            Set(reviews.map(\.questionID)).count == reviews.count,
            questions.allSatisfy({ q in
                ss.contains(q.sessionID) && q.ordinal > 0
                    && (q.parentID == nil
                        || questions.contains {
                            $0.id == q.parentID && $0.sessionID == q.sessionID
                                && $0.ordinal < q.ordinal
                        })
            }),
            attempts.allSatisfy({
                qs.contains($0.questionID) && ["pending", "complete", "failed"].contains($0.status)
            }),
            reviews.allSatisfy({ qs.contains($0.questionID) && (0...2).contains($0.stage) }),
            sessions.allSatisfy({ s in
                s.currentQuestionID == nil
                    || questions.contains { $0.id == s.currentQuestionID && $0.sessionID == s.id }
            })
        else { throw KkokkomuError.invalid("학습 기록의 연결이 올바르지 않습니다. 원본을 유지했습니다.") }
    }
    public mutating func removeSession(_ id: UUID) {
        let ids = Set(questions.filter { $0.sessionID == id }.map(\.id))
        attempts.removeAll { ids.contains($0.questionID) }
        reviews.removeAll { ids.contains($0.questionID) }
        questions.removeAll { $0.sessionID == id }
        sessions.removeAll { $0.id == id }
    }
}
