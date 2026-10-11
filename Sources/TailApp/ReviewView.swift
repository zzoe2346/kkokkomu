import SwiftUI
import TailCore

struct ReviewView: View {
    @Bindable var store: StudyStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(store.library.sessions.isEmpty ? "내 말로 설명하는 연습" : "다시 말하면, 내 지식이 됩니다").font(
                    .largeTitle.bold())
                Text(
                    store.library.sessions.isEmpty
                        ? "궁금한 주제로 시작하세요. 답변을 따라 이어지는 질문이 생각의 빈틈을 찾아줍니다."
                        : "예전 답을 보기 전에 먼저 설명해보세요. 달라진 답변은 나란히 기록됩니다."
                )
                .font(.title3).foregroundStyle(.secondary).lineSpacing(4)
                if store.library.sessions.isEmpty {
                    HStack(spacing: 12) {
                        Button("새 학습 시작") { store.newStudy = true }.buttonStyle(.glassProminent)
                        Button("샘플 둘러보기") { store.addSample() }.buttonStyle(.glass)
                    }
                    Divider().padding(.vertical, 12)
                    Label("질문 하나에 답해보기", systemImage: "bubble.left").font(.headline)
                    Text("직접 쓰거나 전사한 텍스트를 붙여넣으세요.").foregroundStyle(.secondary)
                    Label("피드백과 꼬리 질문", systemImage: "arrow.turn.down.right").font(.headline)
                    Text("잘 설명한 부분과 보완할 부분을 확인하고 한 단계 더 들어갑니다.").foregroundStyle(.secondary)
                    Label("며칠 뒤 다시 설명하기", systemImage: "arrow.clockwise").font(.headline)
                    Text("막혔던 질문을 다시 답하고, 이전 답변과 비교하세요.").foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("오늘 복습 \(store.dueReviews.count)개").font(.title2.bold())
                        Spacer()
                        Picker("오늘 분량", selection: $store.reviewLimit) {
                            Text("3개씩").tag(3)
                            Text("5개씩").tag(5)
                            Text("10개씩").tag(10)
                            Text("모두").tag(Int.max)
                        }.frame(width: 170)
                    }
                    if store.dueReviews.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("오늘 예정된 복습을 마쳤어요", systemImage: "checkmark.circle").font(
                                .headline)
                            Text("새 주제로 연습하거나, 아래 예정된 질문을 미리 복습할 수 있어요.").foregroundStyle(
                                .secondary)
                            Button("새 학습") { store.newStudy = true }.buttonStyle(.glassProminent)
                        }.padding(.vertical, 18)
                    }
                    ForEach(Array(store.dueReviews.prefix(store.reviewLimit))) { item in row(item) }
                    let upcoming = store.library.reviews.filter { item in
                        !store.dueReviews.contains { $0.id == item.id }
                    }.sorted { $0.due < $1.due }
                    if !upcoming.isEmpty {
                        Divider()
                        Text("다음 복습").font(.title2.bold())
                        ForEach(upcoming) { item in row(item) }
                    }
                    if store.library.reviews.isEmpty {
                        Text("학습 중 ‘복습에 담기’를 누르거나, 마무리 화면에서 복습할 질문을 골라주세요.").foregroundStyle(
                            .secondary)
                    }
                    let unfinished = store.library.sessions.filter { $0.endedAt == nil }
                    if !unfinished.isEmpty {
                        Divider()
                        Text("이어갈 학습").font(.title2.bold())
                        ForEach(unfinished.sorted { $0.createdAt > $1.createdAt }.prefix(5)) { s in
                            Button {
                                store.selection = s.id.uuidString
                            } label: {
                                HStack {
                                    Text(s.title)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }.contentShape(Rectangle()).padding(.vertical, 8)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(36).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
    @ViewBuilder private func row(_ item: ReviewItem) -> some View {
        if let q = store.library.questions.first(where: { $0.id == item.questionID }),
            let s = store.library.sessions.first(where: { $0.id == q.sessionID })
        {
            VStack(alignment: .leading, spacing: 12) {
                Text(s.title).font(.caption).foregroundStyle(.secondary)
                Text(q.material.text).font(.headline).fixedSize(horizontal: false, vertical: true)
                HStack {
                    DatePicker(
                        "복습일",
                        selection: Binding(
                            get: { item.due },
                            set: { date in
                                store.change { lib in
                                    if let i = lib.reviews.firstIndex(where: { $0.id == item.id }) {
                                        lib.reviews[i].due = date
                                    }
                                }
                            }), displayedComponents: .date
                    ).fixedSize()
                    Spacer()
                    Button("다시 답하기") { store.reanswer(q, review: true) }.buttonStyle(.glass)
                        .disabled(store.busy != nil)
                    Button {
                        store.toggleReview(q)
                    } label: {
                        Image(systemName: "bookmark.slash")
                    }.buttonStyle(.borderless).help("복습 목록에서 제외").accessibilityLabel("복습에서 제외")
                }
            }.padding(.vertical, 10)
            Divider()
        }
    }
}
