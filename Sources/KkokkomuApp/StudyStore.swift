import AppKit
import Foundation
import KkokkomuCore
import Observation
import UniformTypeIdentifiers

@MainActor @Observable final class StudyStore {
    var library = Library()
    var selection = Preferences.defaults.string(forKey: "selection") ?? "today" {
        didSet {
            Preferences.defaults.set(selection, forKey: "selection")
            scheduleSave()
        }
    }
    var search = ""
    var reviewOnly = false
    var busy: String?
    var error: String?
    var notice = ""
    var loaded = false
    var loadFailed = false
    var newStudy = false
    var saveStatus = "저장됨"
    var authStatus = "연결을 확인하세요"
    var reviewLimit = 5
    let dataDirectory: URL
    @ObservationIgnored let repository: Repository
    @ObservationIgnored var clientOverride: CodexClient?
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var operationID: UUID?

    init(directory: URL? = nil) {
        let args = CommandLine.arguments
        if let directory {
            dataDirectory = directory
        } else if let i = args.firstIndex(of: "--data-dir"), args.count > i + 1 {
            dataDirectory = URL(fileURLWithPath: args[i + 1])
        } else {
            // Preserve the existing library when the app or checkout is renamed.
            dataDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(
                    "Tail")
        }
        repository = Repository(url: dataDirectory.appendingPathComponent("library.sqlite"))
    }
    var client: CodexClient {
        clientOverride
            ?? CodexClient(
                executable: Preferences.defaults.string(forKey: "codexPath")
                    ?? CodexClient.defaultExecutable)
    }
    var session: Session? { library.sessions.first { $0.id.uuidString == selection } }
    var currentQuestion: Question? {
        guard let session else { return nil }
        return library.questions.first { $0.id == session.currentQuestionID }
            ?? library.questions(in: session.id).last
    }
    var filteredSessions: [Session] {
        library.sessions.filter { session in
            if reviewOnly {
                let questions = Set(library.questions(in: session.id).map(\.id))
                guard library.reviews.contains(where: { questions.contains($0.questionID) }) else {
                    return false
                }
            }
            if search.trimmed.isEmpty { return true }
            let ids = Set(library.questions(in: session.id).map(\.id))
            let contents =
                [session.title, session.tags, session.experience]
                + library.questions(in: session.id).flatMap {
                    [$0.material.text, $0.material.presentation?.title ?? ""]
                }
                + library.attempts.filter { ids.contains($0.questionID) }.map(\.text)
            return contents.contains { $0.localizedCaseInsensitiveContains(search) }
        }.sorted { $0.createdAt > $1.createdAt }
    }
    var dueReviews: [ReviewItem] {
        let end =
            Calendar.current.date(
                byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return library.reviews.filter { $0.due < end }.sorted { $0.due < $1.due }
    }
    func load() async {
        guard !loaded else { return }
        do {
            library = try await repository.load()
            library.recoverInterrupted()
            loaded = true
            if CommandLine.arguments.contains("--sample"), library.sessions.isEmpty { addSample() }
            try await flush()
        } catch {
            self.error = error.localizedDescription
            loadFailed = true
            loaded = true
        }
    }
    func change(_ edit: (inout Library) -> Void) {
        edit(&library)
        scheduleSave()
    }
    func scheduleSave() {
        guard loaded, !loadFailed else { return }
        revision += 1
        saveStatus = "저장 중…"
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(450))
                try await self?.flush()
            } catch is CancellationError {} catch { self?.error = error.localizedDescription }
        }
    }
    func flush() async throws {
        guard loaded, !loadFailed else { return }
        saveTask?.cancel()
        saveTask = nil
        let value = library
        let version = revision
        do {
            try await repository.save(value, revision: version)
            if version == revision { saveStatus = "저장됨" }
        } catch {
            saveStatus = "저장 실패, 다시 시도"
            throw error
        }
    }
    func saveAgain() {
        Task { do { try await flush() } catch { self.error = error.localizedDescription } }
    }
    func editQuestion(_ id: UUID, _ edit: (inout Question) -> Void) {
        change { lib in
            if let i = lib.questions.firstIndex(where: { $0.id == id }) { edit(&lib.questions[i]) }
        }
    }
    func selectQuestion(_ q: Question) {
        selection = q.sessionID.uuidString
        change { lib in
            if let i = lib.sessions.firstIndex(where: { $0.id == q.sessionID }) {
                lib.sessions[i].currentQuestionID = q.id
            }
        }
    }
    func addSample() {
        let sample = Sample.library()
        change {
            $0.sessions += sample.sessions
            $0.questions += sample.questions
        }
        selection = sample.sessions[0].id.uuidString
    }
    func create(title: String, experience: String, tags: String) {
        guard loaded, !loadFailed, busy == nil, !title.trimmed.isEmpty, title.count <= 300,
            experience.count <= 30000
        else {
            error = "주제는 300자, 경험은 30,000자 이내로 입력하세요."
            return
        }
        let s = Session(title: title.trimmed, experience: experience.trimmed, tags: tags.trimmed)
        change { $0.sessions.append(s) }
        selection = s.id.uuidString
        newStudy = false
        generateFirst(s.id)
    }
    private func run(
        _ message: String, attemptID: UUID? = nil,
        body: @escaping @MainActor () async throws -> Void
    ) {
        guard busy == nil else { return }
        let token = UUID()
        operationID = token
        busy = message
        notice = ""
        operation = Task {
            do {
                try await flush()
                try Task.checkCancellation()
                try await body()
                try Task.checkCancellation()
                try await flush()
            } catch {
                if let attemptID, let i = library.attempts.firstIndex(where: { $0.id == attemptID })
                {
                    library.attempts[i].status = "failed"
                    library.attempts[i].error = error.localizedDescription
                    scheduleSave()
                }
                if error is CancellationError
                    || (error as? KkokkomuError)?.errorDescription
                        == KkokkomuError.cancelled.errorDescription
                {
                    notice = "생성을 취소했습니다. 저장된 내용에서 이어갈 수 있어요."
                } else {
                    self.error = error.localizedDescription
                }
                try? await flush()
            }
            if operationID == token {
                busy = nil
                operationID = nil
                operation = nil
            }
        }
    }
    func cancel() { operation?.cancel() }
    func generateFirst(_ id: UUID) {
        guard let s = library.sessions.first(where: { $0.id == id }),
            library.questions(in: id).isEmpty
        else { return }
        run("첫 질문을 준비하고 있습니다") {
            let result = try await self.client.generate(
                session: s, question: nil, attempt: nil, history: [])
            try Task.checkCancellation()
            let q = Question(sessionID: s.id, material: result.question)
            self.change { lib in
                lib.questions.append(q)
                if let i = lib.sessions.firstIndex(where: { $0.id == id }) {
                    lib.sessions[i].currentQuestionID = q.id
                }
            }
        }
    }
    func submit(_ id: UUID, unknown: Bool = false) {
        guard busy == nil, let q = library.questions.first(where: { $0.id == id }) else { return }
        do {
            if unknown { editQuestion(id) { $0.revealed = true } }
            let attempt = try library.submit(
                questionID: id, text: unknown ? "모르겠어요. 설명과 복습이 필요합니다." : q.draft)
            scheduleSave()
            evaluate(attempt.id)
        } catch { self.error = error.localizedDescription }
    }
    func evaluate(_ id: UUID, objection: String = "") {
        guard busy == nil, let index = library.attempts.firstIndex(where: { $0.id == id }),
            let q = library.questions.first(where: { $0.id == library.attempts[index].questionID }),
            let s = library.sessions.first(where: { $0.id == q.sessionID })
        else { return }
        let a = library.attempts[index]
        let history = library.attempts.filter { other in
            other.id != id
                && library.questions.contains { $0.id == other.questionID && $0.sessionID == s.id }
        }
        change {
            $0.attempts[index].status = "pending"
            $0.attempts[index].error = ""
        }
        run(objection.isEmpty ? "답변을 살펴보고 꼬리 질문을 준비합니다" : "피드백의 공식 근거를 다시 확인합니다", attemptID: id) {
            let result = try await self.client.generate(
                session: s, question: q, attempt: a, history: history, objection: objection)
            try Task.checkCancellation()
            self.change { lib in
                guard let i = lib.attempts.firstIndex(where: { $0.id == id }) else { return }
                if let old = lib.attempts[i].result { lib.attempts[i].previousResults.append(old) }
                lib.attempts[i].result = result
                lib.attempts[i].status = "complete"
            }
        }
    }
    func reanswer(_ q: Question, review: Bool = false) {
        guard busy == nil else { return }
        editQuestion(q.id) { v in
            if !v.isAnswering { v.draft = "" }
            v.isAnswering = true
            v.isReview = review
            v.revealed = false
            v.hintLevel = 0
        }
        selectQuestion(q)
    }
    func next(_ q: Question) {
        guard busy == nil else { return }
        if let child = library.questions.first(where: { $0.parentID == q.id }) {
            selectQuestion(child)
            return
        }
        guard let result = library.attempts(for: q.id).last?.result else { return }
        let next = Question(
            sessionID: q.sessionID, parentID: q.id, ordinal: q.ordinal + 1,
            material: result.nextQuestion)
        change {
            $0.questions.append(next)
            if let i = $0.sessions.firstIndex(where: { $0.id == q.sessionID }) {
                $0.sessions[i].endedAt = nil
            }
        }
        selectQuestion(next)
    }
    func finish(_ id: UUID) {
        guard busy == nil else { return }
        change { lib in
            if let i = lib.sessions.firstIndex(where: { $0.id == id }) {
                lib.sessions[i].endedAt = Date()
            }
            for q in lib.questions(in: id) {
                let a = lib.attempts(for: q.id).last
                if a?.result?.feedback.reviewSuggested == true || a?.sawAnswer == true
                    || (a?.hintLevel ?? 0) > 0,
                    !lib.reviews.contains(where: { $0.questionID == q.id })
                {
                    lib.reviews.append(ReviewItem(questionID: q.id))
                }
            }
        }
    }
    func toggleReview(_ q: Question) {
        change { lib in
            if lib.reviews.contains(where: { $0.questionID == q.id }) {
                lib.reviews.removeAll { $0.questionID == q.id }
            } else {
                lib.reviews.append(ReviewItem(questionID: q.id))
            }
        }
    }
    func rate(_ q: Question, _ rating: Rating) {
        guard let a = library.attempts(for: q.id).last, a.status == "complete", a.rating == nil
        else { return }
        let intervals = ["interval1", "interval2", "interval3"].enumerated().map { index, key in
            let n = Preferences.defaults.integer(forKey: key)
            return n > 0 ? n : [1, 3, 7][index]
        }
        change { lib in
            if !lib.reviews.contains(where: { $0.questionID == q.id }) {
                lib.reviews.append(ReviewItem(questionID: q.id))
            }
            if let i = lib.reviews.firstIndex(where: { $0.questionID == q.id }) {
                lib.reviews[i].rate(rating, intervals: intervals)
            }
            if let i = lib.attempts.firstIndex(where: { $0.id == a.id }) {
                lib.attempts[i].rating = rating.rawValue
            }
        }
        notice = "복습을 기록했습니다. 다음 일정은 오늘 복습에서 확인할 수 있어요."
    }
    func checkAuth() {
        guard busy == nil else { return }
        run("Codex 연결을 확인하고 있습니다") {
            try await self.client.checkAuth()
            self.authStatus = "ChatGPT 로그인 연결됨"
        }
    }
    func backup() {
        guard loaded, !loadFailed, busy == nil else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Kkokkomu-backup.sqlite"
        panel.allowedContentTypes = [.database]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        run("학습 기록을 백업합니다") {
            try await self.repository.backup(to: url)
            self.notice = "백업을 저장했습니다."
        }
    }
    func restore() {
        guard loaded, !loadFailed, busy == nil else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alert = NSAlert()
        alert.messageText = "이 백업으로 보관함을 복원할까요?"
        alert.informativeText = "현재 기록은 복구 사본으로 보관하고 선택한 백업으로 바꿉니다."
        alert.addButton(withTitle: "복원")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        run("백업을 검증하고 복원합니다") {
            self.revision += 1
            self.library = try await self.repository.restore(from: url, revision: self.revision)
            self.library.recoverInterrupted()
            self.selection = "today"
            self.notice = "백업을 복원했습니다. 이전 보관함의 복구 사본도 저장했습니다."
        }
    }
    func deleteSession(_ s: Session) {
        guard busy == nil else { return }
        let alert = NSAlert()
        alert.messageText = "이 학습 기록을 삭제할까요?"
        alert.informativeText = "‘\(s.title)’의 질문, 답변과 연결된 복습 기록이 함께 삭제됩니다."
        alert.addButton(withTitle: "삭제")
        alert.addButton(withTitle: "취소")
        if alert.runModal() == .alertFirstButtonReturn {
            change { $0.removeSession(s.id) }
            selection = "history"
        }
    }
    func shutdown() async -> Bool {
        cancel()
        CLIRunner.terminateAll()
        if let operation { await operation.value }
        do {
            try await flush()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
