# 꼬꼬무 macOS 화면 기준

## 앱 이름과 기존 설정

2026-10-12 Apple의 [CFBundleDisplayName](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledisplayname)과 [CFBundleIdentifier](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleidentifier)를 확인했다. 표시 이름은 시스템에 보이는 이름이고, 번들 식별자는 앱과 해당 환경설정을 식별한다. 이에 따라 `CFBundleName`, `CFBundleDisplayName`, 기본 창과 상태 문구는 꼬꼬무로 바꾸고, 번들 식별자 `com.zzoe.tail`과 기존 UserDefaults 영역을 유지한다. 영문 실행 파일과 Swift 모듈은 Kkokkomu로 통일한다.

## 화면 구성

확인일은 2026-10-12다. macOS 26 이상 네이티브 앱으로 기본 NavigationSplitView, sidebar List, toolbar, sheet와 Form을 사용한다. 현재 질문과 답변 입력을 중심으로 구성하고 과거 문답은 접어둔다. 본문 기본 17pt, 14~36pt 조절과 시스템 테마를 제공한다. 본문에 Glass를 덮지 않고 시스템 툴바와 주요 조작에 사용한다. 코드 블록의 공백과 줄을 보존한다.

작은 창, 큰 글자, 키보드, 한글 입력, 생성 중 취소, 실패 후 재시도를 실제 앱에서 확인한다. Enter는 줄바꿈이고 제출은 Command-Return이다. 저장 상태를 표시한다.

근거: [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview), [Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons). 기본 시스템 컨트롤의 모양은 실제 실행 SDK와 OS에 맡기고 SDK 27로 빌드한 실제 화면을 검증한다.


## 긴 질문의 읽기 구조

2026-10-12 사용자 검토를 반영했다. 전체 질문을 24pt 굵은 글씨로 표시하던 방식을 바꾸고 제목 20pt, 본문과 입력 17pt, 코드 15pt를 기본으로 사용한다. 사용자 글자 크기를 변경하면 제목은 본문보다 3pt 크게, 코드는 2pt 작게 따라간다. 본문은 보통 굵기이고 중심 질문만 medium으로 구분한다. 단락 사이 간격은 16pt, 본문 줄 간격은 5pt다. 본문 폭은 최대 900pt(좌우 여백 포함)로 제한한다.

새 질문은 짧은 제목, 상황과 코드, 핵심 질문을 별도 데이터로 생성한다. 가정 여부는 작은 표시로 구분하고 학습 의도는 기본적으로 접어둔다. 정답을 암시하는 문구나 비교 후보의 차별 강조는 피한다. 기존 데이터에 표시 정보가 없으면 질문 원문을 그대로 일반 본문 크기로 표시한다. 사용자가 저장한 읽기 설정은 덮어쓰지 않는다.

Apple의 [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)에서 읽기 순서, 정렬, 본문 폭을 통한 정보 계층 원칙을 확인했고, [Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles)의 간결한 표현과 필요한 조작 중심 배치를 참고했다. 확인일은 2026-10-12다. 구체적인 글자 크기와 간격은 꼬꼬무 화면 검토를 바탕으로 정한 값이며 Apple의 필수 수치가 아니다.
