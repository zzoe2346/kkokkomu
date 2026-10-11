# Tail macOS 화면 기준

확인일은 2026-10-12다. macOS 26 이상 네이티브 앱으로 기본 NavigationSplitView, sidebar List, toolbar, sheet와 Form을 사용한다. 현재 질문과 답변 입력을 중심으로 구성하고 과거 문답은 접어둔다. 본문 기본 18pt, 14~36pt 조절과 시스템 테마를 제공한다. 본문에 Glass를 덮지 않고 시스템 툴바와 주요 조작에 사용한다. 코드 블록의 공백과 줄을 보존한다.

작은 창, 큰 글자, 키보드, 한글 입력, 생성 중 취소, 실패 후 재시도를 실제 앱에서 확인한다. Enter는 줄바꿈이고 제출은 Command-Return이다. 저장 상태를 표시한다.

근거: [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview), [Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons). 기본 시스템 컨트롤의 모양은 실제 실행 SDK와 OS에 맡기고 SDK 27로 빌드한 실제 화면을 검증한다.
