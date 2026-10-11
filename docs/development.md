# 개발 안내

macOS 26 이상, Swift 6 도구와 macOS SDK를 사용한다. Swift Package Manager로 빌드하며 전역 도구 설정을 바꾸지 않는다. Xcode가 설치돼 있으면 각 스크립트 안에서만 해당 도구 모음을 선택한다. 사용자가 지정한 DEVELOPER_DIR는 유지한다. 컴파일 대상과 패키지의 최소 OS를 모두 macOS 26으로 지정한다.

```sh
./scripts/format.sh
./scripts/check.sh
./scripts/package.sh
open dist/Tail.app
```

포맷 검사, Swift Testing과 Release 빌드를 수행한다. 실제 앱 화면과 Codex 생성은 별도 확인한다. 로컬 빌드 산출물과 QA 데이터는 Git에서 제외한다.

검사는 전체 Xcode 설치를 권장한다. 현재 Mac의 Command Line Tools만 사용했을 때 Swift Testing 매크로를 찾지 못하는 오류가 재빌드 중 발생했고, 같은 Swift 6.4의 Xcode 도구 모음에서는 통과했다. 검사 규칙이나 테스트를 끄는 방식으로 회피하지 않는다.

패키징은 `dist/Tail.app`에 실행 파일, Info.plist, Icon Composer로 컴파일한 아이콘과 라이선스 고지를 넣고 ad-hoc 서명을 검증한다. 공증과 원격 배포는 별도 작업이다. 아이콘을 바꾸면 `./scripts/compile-icon.sh`로 원본과 결과의 체크섬을 다시 만든다.

개인 기록과 분리해 화면을 확인할 때는 앱을 종료한 후 아래처럼 실행한다. 같은 데이터 폴더를 여러 프로세스에서 동시에 열지 않는다. `--data-dir`를 사용하면 읽기 설정과 새 학습 초안도 별도 QA 설정 영역에 저장한다.

```sh
open dist/Tail.app --args --data-dir "$PWD/work/qa-live"
```

실제 로그인으로 생성 흐름을 검증하려면 다음 명령을 사용한다. 새 AI 호출이 발생하며 결과는 별도 QA 보관함에 저장한다.

```sh
swift run TailQA --live work/qa-live
```

Codex CLI의 전역 설정과 인증정보는 수정하지 않는다. 작업 폴더는 임시 위치에서 생성하고 종료 뒤 정리한다. 프로세스 실행기는 배우자의 MIT 코드를 바탕으로 Swift 6 동시성과 macOS 26 API에 맞게 적용했다. 라이선스는 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)에 있다.
