# 개발 안내

macOS 26 이상, Swift 6 도구와 macOS SDK를 사용한다. Swift Package Manager로 빌드하며 전역 도구 설정을 바꾸지 않는다.

```sh
./scripts/format.sh
./scripts/check.sh
```

포맷 검사, Swift Testing과 Release 빌드를 수행한다. 실제 앱 화면과 Codex 생성은 별도 확인한다. 로컬 빌드 산출물과 QA 데이터는 Git에서 제외한다.
