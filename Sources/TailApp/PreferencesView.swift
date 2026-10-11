import AppKit
import SwiftUI
import TailCore

struct PreferencesView: View {
    @Bindable var store: StudyStore
    @AppStorage("fontSize", store: Preferences.defaults) private var size = 17.0
    @AppStorage("appearance", store: Preferences.defaults) private var appearance = "system"
    @AppStorage("codexPath", store: Preferences.defaults) private var codexPath = CodexClient
        .defaultExecutable
    @AppStorage("interval1", store: Preferences.defaults) private var first = 1
    @AppStorage("interval2", store: Preferences.defaults) private var second = 3
    @AppStorage("interval3", store: Preferences.defaults) private var third = 7
    var body: some View {
        Form {
            Section("읽기") {
                Picker("테마", selection: $appearance) {
                    Text("시스템").tag("system")
                    Text("밝게").tag("light")
                    Text("어둡게").tag("dark")
                }.pickerStyle(.segmented)
                LabeledContent("본문 \(Int(size))pt") {
                    Slider(value: $size, in: 14...36, step: 1).accessibilityLabel("본문 글자 크기")
                }
                Button("기본 17pt로 복원") { size = 17 }
            }
            Section("복습 간격") {
                Stepper("첫 복습, \(first)일", value: $first, in: 1...30)
                Stepper("두 번째, \(second)일", value: $second, in: 1...60)
                Stepper("이후, \(third)일", value: $third, in: 1...90)
                Text("새로 자기평가한 질문부터 적용합니다. ‘다시 필요’는 첫 단계로 돌아갑니다.").font(.caption).foregroundStyle(
                    .secondary)
            }
            Section("Codex 연결") {
                TextField("실행 파일", text: $codexPath).font(.system(.body, design: .monospaced))
                HStack {
                    Text(store.authStatus).foregroundStyle(.secondary)
                    Spacer()
                    Button("연결 확인") { store.checkAuth() }.disabled(store.busy != nil)
                }
                Text(
                    "기존 ChatGPT 로그인을 사용합니다. 로그인이 필요하면 터미널에서 codex login을 실행하세요. 생성에는 구독 사용 한도가 적용됩니다."
                ).font(.caption).foregroundStyle(.secondary)
            }
            Section("보관함") {
                Text("기록은 이 Mac에 저장됩니다. 질문과 피드백 생성에는 필요한 주제, 선택한 경험과 답변 맥락이 원격 AI로 전달됩니다.").font(
                    .callout)
                HStack {
                    Button("백업…") { store.backup() }
                    Button("복원…") { store.restore() }
                    Button("폴더 열기") { NSWorkspace.shared.open(store.dataDirectory) }
                }.disabled(store.busy != nil || store.loadFailed)
            }
        }.formStyle(.grouped).padding(12).frame(width: 560, height: 660)
    }
}
