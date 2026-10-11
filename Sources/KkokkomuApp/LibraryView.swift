import AppKit
import KkokkomuCore
import SwiftUI

struct LibraryView: View {
    @Bindable var store: StudyStore
    @AppStorage("fontSize", store: Preferences.defaults) private var fontSize = 17.0
    var body: some View {
        NavigationSplitView {
            List(selection: $store.selection) {
                Section {
                    Label("오늘 복습", systemImage: "arrow.clockwise").badge(store.dueReviews.count)
                        .tag("today")
                    Label("학습 기록", systemImage: "clock").tag("history")
                }
                Section("학습 주제") {
                    ForEach(store.filteredSessions) { session in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.title).lineLimit(2)
                            Text(
                                session.isSample
                                    ? "샘플, 흐름 둘러보기" : session.endedAt == nil ? "학습 중" : "마무리한 학습"
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4).tag(session.id.uuidString)
                            .contextMenu {
                                Button("삭제…", role: .destructive) { store.deleteSession(session) }
                                    .disabled(store.busy != nil)
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 205)
            .navigationSplitViewColumnWidth(min: 205, ideal: 245, max: 330)
            .searchable(text: $store.search, placement: .sidebar, prompt: "학습 기록 검색")
            .help("주제, 질문, 답변과 태그로 학습 기록을 검색합니다.")
        } detail: {
            VStack(spacing: 0) {
                if let busy = store.busy {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(busy)
                        Spacer()
                        Button("취소") { store.cancel() }
                    }
                    .font(.callout).padding(12).background(.bar)
                }
                if !store.notice.isEmpty {
                    HStack {
                        Text(store.notice)
                        Spacer()
                        Button {
                            store.notice = ""
                        } label: {
                            Image(systemName: "xmark")
                        }.buttonStyle(.plain).accessibilityLabel("안내 닫기")
                    }
                    .font(.callout).padding(12).background(Color.accentColor.opacity(0.07))
                }
                if store.loadFailed {
                    ContentUnavailableView {
                        Label("보관함을 열지 못했습니다", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("원본 파일을 유지했습니다. 저장 위치와 백업을 확인하세요.")
                    } actions: {
                        Button("저장 폴더 열기") { NSWorkspace.shared.open(store.dataDirectory) }
                    }
                } else if !store.loaded {
                    ProgressView("보관함을 여는 중입니다").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let session = store.session {
                    SessionView(store: store, sessionID: session.id).id(session.id)
                } else if store.selection == "history" {
                    history
                } else {
                    ReviewView(store: store)
                }
                Divider()
                HStack {
                    Image(systemName: "internaldrive")
                    Text(store.saveStatus)
                    if store.saveStatus.contains("실패") { Button("다시 저장") { store.saveAgain() } }
                    Spacer()
                    Text("꼬꼬무: 내 말로 설명하는 연습")
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(
                    .vertical, 8)
            }.background(Color(nsColor: .textBackgroundColor))
        }
        .navigationTitle(store.session?.title ?? (store.selection == "history" ? "학습 기록" : "오늘 복습"))
        .toolbar {
            ToolbarItem {
                Button {
                    store.newStudy = true
                } label: {
                    Label("새 학습", systemImage: "square.and.pencil")
                }.disabled(store.busy != nil || store.loadFailed)
            }
            ToolbarItem {
                Menu {
                    Button("글자 크게") { fontSize = min(36, fontSize + 2) }
                    Button("글자 작게") { fontSize = max(14, fontSize - 2) }
                    Button("기본 17pt") { fontSize = 17 }
                    Divider()
                    SettingsLink { Text("모든 설정…") }
                } label: {
                    Label("읽기 설정", systemImage: "textformat.size")
                }
            }
            ToolbarItem {
                Menu {
                    Button("보관함 백업…") { store.backup() }.disabled(
                        store.busy != nil || store.loadFailed)
                    Button("백업 복원…") { store.restore() }.disabled(
                        store.busy != nil || store.loadFailed)
                    Divider()
                    Button("저장 폴더 열기") { NSWorkspace.shared.open(store.dataDirectory) }
                    Button("샘플 둘러보기") { store.addSample() }.disabled(store.loadFailed)
                } label: {
                    Label("더 보기", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $store.newStudy) { NewStudyView(store: store) }
        .alert(
            "확인이 필요합니다",
            isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
        ) {
            Button("확인") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
    }
    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("쌓인 답변에서 다시 시작하세요").font(.title2.bold())
                Text("주제나 답변을 검색하고, 이전 학습을 이어가거나 같은 질문에 다시 답해보세요.").foregroundStyle(.secondary)
                Toggle("복습할 질문이 있는 기록만", isOn: $store.reviewOnly).toggleStyle(.checkbox)
                if store.filteredSessions.isEmpty {
                    ContentUnavailableView.search(text: store.search)
                }
                ForEach(store.filteredSessions) { s in
                    Button {
                        store.selection = s.id.uuidString
                    } label: {
                        HStack(alignment: .top) {
                            Image(
                                systemName: s.endedAt == nil
                                    ? "bubble.left.and.text.bubble.right" : "checkmark.circle"
                            ).font(.title2)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(s.title).font(.headline)
                                Text(
                                    "\(store.library.questions(in: s.id).count)개 질문, \(s.createdAt.formatted(date: .abbreviated, time: .omitted))"
                                ).font(.callout).foregroundStyle(.secondary)
                                if !s.tags.isEmpty {
                                    Text(s.tags).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }.padding(.vertical, 10).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
            }.padding(32).frame(maxWidth: 860, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}

struct NewStudyView: View {
    @Bindable var store: StudyStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("newTitle", store: Preferences.defaults) private var title = ""
    @AppStorage("newExperience", store: Preferences.defaults) private var experience = ""
    @AppStorage("newTags", store: Preferences.defaults) private var tags = ""
    @AppStorage("newFocus", store: Preferences.defaults) private var focus = ""
    private var studyTitle: String {
        focus.trimmed.isEmpty ? title : "\(title.trimmed), \(focus.trimmed)"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("무엇을 설명해볼까요?").font(.title2.bold())
            Text("첫 질문 하나에서 시작해, 답변에 맞춰 세 번 더 깊이 들어갑니다.").foregroundStyle(.secondary)
            Form {
                TextField("학습 주제", text: $title, prompt: Text("예: 트랜잭션 격리 수준"))
                TextField("소주제 (선택)", text: $focus, prompt: Text("주제가 넓다면 예: 격리 수준별 읽기 이상"))
                TextField("태그", text: $tags, prompt: Text("예: DB, 프로젝트"))
                VStack(alignment: .leading, spacing: 8) {
                    Text("관련 경험 (선택)").font(.headline)
                    TextEditor(text: $experience).font(.body).frame(height: 150).padding(6)
                        .background(.background).clipShape(.rect(cornerRadius: 8))
                    Text("이력서 문장이나 프로젝트에서 했던 일을 붙여넣으세요. 경험이 없어도 주제만으로 시작할 수 있어요.").font(.caption)
                        .foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
            Text("질문 생성에는 입력한 주제와 경험이 Codex로 전달됩니다. 기록은 이 Mac에 저장됩니다.").font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("질문 시작하기") {
                    store.create(title: studyTitle, experience: experience, tags: tags)
                    if !store.newStudy {
                        title = ""
                        experience = ""
                        tags = ""
                        focus = ""
                    }
                }
                .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
                .disabled(
                    title.trimmed.isEmpty || studyTitle.count > 300 || experience.count > 30000
                        || store.busy != nil)
            }
        }.padding(28).frame(width: 570)
    }
}
