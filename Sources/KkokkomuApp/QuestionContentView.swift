import KkokkomuCore
import SwiftUI

struct QuestionContentView: View {
    let material: KkokkomuCore.Material
    @AppStorage("fontSize", store: Preferences.defaults) private var size = 17.0
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let presentation = material.presentation {
                VStack(alignment: .leading, spacing: 8) {
                    if presentation.isHypothetical {
                        Text("가정 문제").font(.callout).foregroundStyle(.secondary)
                    }
                    Text(presentation.title)
                        .font(.system(size: size + 3, weight: .semibold))
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                if !presentation.context.trimmed.isEmpty {
                    RichText(text: presentation.context)
                }
                RichText(text: presentation.prompt, weight: .medium)
            } else {
                RichText(text: material.text)
            }
            if !material.intent.trimmed.isEmpty {
                DisclosureGroup("이 질문의 학습 의도") {
                    RichText(text: material.intent).padding(.top, 8)
                }.font(.callout).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
