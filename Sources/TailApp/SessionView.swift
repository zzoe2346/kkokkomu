import SwiftUI
import TailCore

struct RichText: View {
    let text: String
    @AppStorage("fontSize", store: Preferences.defaults) private var size = 18.0
    var body: some View {
        let parts = text.components(separatedBy: "```")
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index % 2 == 1 {
                    let code =
                        part.contains("\n")
                        ? String(part.drop(while: { $0 != "\n" }).dropFirst()) : part
                    ScrollView(.horizontal) {
                        Text(code).font(.system(size: size - 2, design: .monospaced)).fixedSize(
                            horizontal: true, vertical: false
                        ).textSelection(.enabled).padding(14)
                    }
                    .background(Color.primary.opacity(0.045)).clipShape(.rect(cornerRadius: 8))
                } else if !part.trimmed.isEmpty {
                    Text(
                        (try? AttributedString(
                            markdown: part,
                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                            ?? AttributedString(part)
                    )
                    .font(.system(size: size)).lineSpacing(5).textSelection(.enabled).fixedSize(
                        horizontal: false, vertical: true)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct SessionView: View {
    @Bindable var store: StudyStore
    let sessionID: UUID
    @ViewState<String> private var objection = ""
    @ViewState<Bool> private var showObjection = false
    @ViewState<Bool> private var showExplanation = false
    @AppStorage("fontSize", store: Preferences.defaults) private var size = 18.0
    private var session: Session? { store.library.sessions.first { $0.id == sessionID } }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    if let s = session {
                        if s.endedAt != nil, store.currentQuestion?.isReview != true {
                            summary(s)
                        }
                        if let q = store.currentQuestion, q.sessionID == sessionID {
                            questionBody(q, s).id("current")
                        } else {
                            ContentUnavailableView {
                                Label("첫 질문을 준비합니다", systemImage: "bubble.left.and.bubble.right")
                            } description: {
                                Text("주제와 경험은 저장됐습니다. 연결이 끊겨도 여기서 다시 시작할 수 있어요.")
                            } actions: {
                                Button("첫 질문 생성") { store.generateFirst(s.id) }.buttonStyle(
                                    .glassProminent
                                ).disabled(store.busy != nil)
                            }.frame(minHeight: 400)
                        }
                        let qs = store.library.questions(in: s.id)
                        if qs.count > 1 {
                            Divider()
                            DisclosureGroup("질문 흐름, \(qs.count)개") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(qs) { q in
                                        Button {
                                            store.selectQuestion(q)
                                            showExplanation = false
                                            proxy.scrollTo("current", anchor: .top)
                                        } label: {
                                            HStack(alignment: .top) {
                                                Text("\(q.ordinal).").monospacedDigit()
                                                Text(q.material.text).multilineTextAlignment(
                                                    .leading)
                                                Spacer()
                                                if q.id == store.currentQuestion?.id {
                                                    Image(systemName: "arrow.left")
                                                }
                                            }
                                        }.buttonStyle(.plain)
                                    }
                                }.padding(.top, 12)
                            }
                        }
                        if !s.experience.isEmpty {
                            DisclosureGroup("이 학습에 사용한 경험") {
                                RichText(text: s.experience).padding(.top, 12)
                            }
                        }
                    }
                }.padding(32).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
            }.onChange(of: store.currentQuestion?.id) { _, _ in
                showExplanation = false
                proxy.scrollTo("current", anchor: .top)
            }
        }
        .sheet(isPresented: $showObjection) {
            VStack(alignment: .leading, spacing: 20) {
                Text("어떤 부분을 다시 확인할까요?").font(.title2.bold())
                Text("공식 자료를 확인해 피드백을 재검토합니다. 이전 피드백도 기록에 남습니다.").foregroundStyle(.secondary)
                TextEditor(text: $objection).frame(height: 130).border(.quaternary)
                HStack {
                    Button("취소") { showObjection = false }
                    Spacer()
                    Button("근거 재검토") {
                        if let q = store.currentQuestion,
                            let a = store.library.attempts(for: q.id).last
                        {
                            store.evaluate(
                                a.id,
                                objection: objection.trimmed.isEmpty
                                    ? "이 피드백의 정확성을 공식 근거로 확인해 주세요." : objection)
                        }
                        showObjection = false
                        objection = ""
                    }.buttonStyle(.glassProminent).disabled(store.busy != nil)
                }
            }.padding(28).frame(width: 520)
        }
    }
    @ViewBuilder private func questionBody(_ q: Question, _ s: Session) -> some View {
        let attempts = store.library.attempts(for: q.id)
        let last = attempts.last
        HStack {
            Label(
                q.isReview ? "다시 설명해보기" : "질문 \(q.ordinal) / \(max(s.limit, q.ordinal))",
                systemImage: q.isReview ? "arrow.clockwise" : "bubble.left.and.text.bubble.right"
            )
            .font(.callout.weight(.medium)).foregroundStyle(.secondary)
            Spacer()
            if s.isSample { Text("샘플 질문").font(.caption).foregroundStyle(.secondary) }
            Button {
                store.toggleReview(q)
            } label: {
                Label(
                    store.library.reviews.contains { $0.questionID == q.id } ? "복습에 담김" : "복습에 담기",
                    systemImage: store.library.reviews.contains { $0.questionID == q.id }
                        ? "bookmark.fill" : "bookmark")
            }.buttonStyle(.borderless).disabled(store.busy != nil)
        }
        Text(q.material.text).font(.system(size: size + 6, weight: .semibold)).lineSpacing(5)
            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        Text(q.material.intent).font(.callout).foregroundStyle(.secondary).fixedSize(
            horizontal: false, vertical: true)
        if q.isAnswering {
            VStack(alignment: .leading, spacing: 12) {
                Text(q.isReview ? "이전 답을 보지 않고 다시 답해보세요" : "내 답변").font(.headline)
                TextEditor(
                    text: Binding(
                        get: { store.library.questions.first { $0.id == q.id }?.draft ?? "" },
                        set: { value in store.editQuestion(q.id) { $0.draft = value } })
                )
                .font(.system(size: size)).scrollContentBackground(.hidden).padding(12)
                .frame(minHeight: 190, maxHeight: 300).background(
                    Color(nsColor: .textBackgroundColor)
                )
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                .accessibilityLabel("내 답변 입력")
                Text("완벽한 문장이 아니어도 괜찮아요. 생각한 순서대로 적거나 전사한 내용을 붙여넣으세요.")
                    .font(.caption).foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack { answerActions(q) }
                    VStack(alignment: .leading, spacing: 12) { answerActions(q) }
                }
                if q.draft.count > 30000 { Text("답변은 30,000자 이내로 입력하세요.").foregroundStyle(.red) }
            }
            if q.hintLevel > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    Label("생각의 실마리", systemImage: "lightbulb").font(.headline)
                    ForEach(Array(q.material.hints.prefix(q.hintLevel).enumerated()), id: \.offset)
                    { _, hint in RichText(text: hint) }
                }.padding(18).background(Color.accentColor.opacity(0.06)).clipShape(
                    .rect(cornerRadius: 10))
            }
            if showExplanation { RichText(text: q.material.clarification) }
        } else if let last {
            VStack(alignment: .leading, spacing: 12) {
                Text("내 답변, \(attempts.count)번째 시도").font(.headline)
                RichText(text: last.text)
            }
            if last.status == "pending" {
                Text("답변은 저장됐습니다. 피드백을 준비하는 동안 기록을 살펴볼 수 있어요.").foregroundStyle(.secondary)
            } else if last.status == "failed" {
                VStack(alignment: .leading, spacing: 10) {
                    Text(last.error).foregroundStyle(.secondary)
                    Button("이 답변으로 다시 시도") { store.evaluate(last.id) }.buttonStyle(.glassProminent)
                        .disabled(store.busy != nil)
                }
            }
            if let result = last.result {
                Divider()
                feedback(result.feedback)
                if last.isReview, last.status == "complete" {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("다시 설명해보니 어땠나요?").font(.headline)
                        if let rating = last.rating {
                            Label("\(rating), 복습 기록됨", systemImage: "checkmark.circle")
                                .foregroundStyle(.secondary)
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack { ratingButtons(q) }
                                VStack(alignment: .leading) { ratingButtons(q) }
                            }
                        }
                    }.padding(18).background(.quaternary.opacity(0.4)).clipShape(
                        .rect(cornerRadius: 10))
                }
            }
            DisclosureGroup(
                isExpanded: Binding(
                    get: { q.revealed },
                    set: { value in store.editQuestion(q.id) { $0.revealed = value } })
            ) {
                let material = last.result?.question ?? q.material
                VStack(alignment: .leading, spacing: 16) {
                    Text(material.keywords.joined(separator: ", ")).font(.callout.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                    Text("1분 답변 예시").font(.headline)
                    RichText(text: material.sampleAnswer)
                    Text("조금 더 살펴보기").font(.headline)
                    RichText(text: material.explanation)
                }.padding(.top, 14)
            } label: {
                Label("참고 답안과 해설", systemImage: "book.closed").font(.headline)
            }
            if last.status != "pending" {
                ViewThatFits(in: .horizontal) {
                    HStack { nextActions(q, s, last) }
                    VStack(alignment: .leading, spacing: 12) { nextActions(q, s, last) }
                }
            }
            if attempts.count > 1 || !last.previousResults.isEmpty {
                DisclosureGroup("이전 답변과 피드백 기록") {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(attempts.dropLast()) { a in
                            Text(a.createdAt.formatted()).font(.caption).foregroundStyle(.secondary)
                            RichText(text: a.text)
                            if let r = a.result { feedback(r.feedback) }
                            Divider()
                        }
                        ForEach(Array(last.previousResults.enumerated()), id: \.offset) {
                            i, result in
                            Text("재검토 전 피드백 \(i+1)").font(.headline)
                            feedback(result.feedback)
                        }
                    }.padding(.top, 16)
                }
            }
        }
        if s.endedAt == nil {
            Button("여기까지 마무리") { store.finish(s.id) }.disabled(store.busy != nil).padding(.top, 8)
        }
    }
    private func answerActions(_ q: Question) -> some View {
        Group {
            Button("답변 제출") { store.submit(q.id) }.buttonStyle(.glassProminent)
                .disabled(store.busy != nil || q.draft.trimmed.isEmpty || q.draft.count > 30000)
                .help("답변 제출 (⌘ Return)")
            Button("힌트 \(min(q.hintLevel+1, q.material.hints.count))/\(q.material.hints.count)") {
                store.editQuestion(q.id) { $0.hintLevel += 1 }
            }.disabled(q.hintLevel >= q.material.hints.count)
            Button("질문 쉽게 풀어보기") { showExplanation.toggle() }
            Button("모르겠어요") { store.submit(q.id, unknown: true) }.disabled(store.busy != nil)
        }
    }
    private func ratingButtons(_ q: Question) -> some View {
        ForEach(Rating.allCases, id: \.self) { r in
            Button(r.rawValue) { store.rate(q, r) }.buttonStyle(.glass)
        }
    }
    private func nextActions(_ q: Question, _ s: Session, _ last: Attempt) -> some View {
        Group {
            if last.status == "complete" {
                Button(q.ordinal >= s.limit ? "추가 질문 이어가기" : "다음 꼬리 질문") { store.next(q) }
                    .buttonStyle(.glassProminent).disabled(store.busy != nil)
            }
            Button("같은 질문에 다시 답하기") { store.reanswer(q) }.disabled(store.busy != nil)
            if last.result != nil {
                Button("근거 재검토…") { showObjection = true }.disabled(store.busy != nil)
            }
        }
    }
    private func feedback(_ f: Feedback) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("답변 돌아보기").font(.title3.bold())
            feedbackSection("잘 설명한 부분", f.strengths, "checkmark.circle")
            feedbackSection("다시 확인할 부분", f.corrections, "arrow.triangle.2.circlepath")
            feedbackSection("덧붙이면 좋은 설명", f.gaps, "text.badge.plus")
            if !f.comparison.isEmpty {
                feedbackSection("이전 답변에서 달라진 점", [f.comparison], "clock.arrow.circlepath")
            }
            if !f.evidence.isEmpty {
                DisclosureGroup("내 답변에서 확인한 근거") {
                    ForEach(Array(f.evidence.enumerated()), id: \.offset) { _, text in
                        RichText(text: text).padding(.top, 8)
                    }
                }
            }
            Text(f.verificationNote).font(.caption).foregroundStyle(.secondary)
            ForEach(f.sources, id: \.url) { source in
                if let url = source.safeURL { Link(source.title, destination: url).font(.callout) }
            }
        }
    }
    @ViewBuilder private func feedbackSection(_ title: String, _ values: [String], _ icon: String)
        -> some View
    {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon).font(.headline)
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RichText(text: value)
                }
            }
        }
    }
    private func summary(_ s: Session) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("오늘의 설명을 남겼어요", systemImage: "checkmark.circle").font(.title2.bold())
            Text("다시 확인할 개념을 살펴보고, 복습할 질문을 골라두세요.").foregroundStyle(.secondary)
            ForEach(store.library.questions(in: s.id)) { q in
                let a = store.library.attempts(for: q.id).last
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(
                        isOn: Binding(
                            get: { store.library.reviews.contains { $0.questionID == q.id } },
                            set: { _ in store.toggleReview(q) })
                    ) { Text(q.material.text).fixedSize(horizontal: false, vertical: true) }
                    .toggleStyle(.checkbox)
                    if let f = a?.result?.feedback {
                        ForEach(
                            Array((f.corrections + f.gaps).prefix(2).enumerated()), id: \.offset
                        ) { _, text in
                            Text(LocalizedStringKey(text)).font(.callout).foregroundStyle(
                                .secondary
                            ).padding(
                                .leading, 22)
                        }
                    } else {
                        Text(a == nil ? "아직 답하지 않은 질문" : "피드백 확인이 남은 질문")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Button("오늘 복습으로") { store.selection = "today" }.buttonStyle(.glass)
                Button("이 주제로 새 학습") {
                    store.create(title: s.title, experience: s.experience, tags: s.tags)
                }.disabled(store.busy != nil)
            }
        }.padding(22).background(Color.accentColor.opacity(0.06)).clipShape(.rect(cornerRadius: 12))
    }
}
