# 개발 안내

macOS 26 이상, Swift 6 도구와 macOS SDK를 사용한다. Swift Package Manager로 빌드하며 전역 도구 설정을 바꾸지 않는다.

```sh
./scripts/format.sh
./scripts/check.sh
```

포맷 검사, Swift Testing과 Release 빌드를 수행한다. 실제 앱 화면과 Codex 생성은 별도 확인한다. 로컬 빌드 산출물과 QA 데이터는 Git에서 제외한다.

실제 로그인으로 생성 흐름을 검증하려면 다음 명령을 사용한다. 새 AI 호출이 발생하며 결과는 별도 QA 보관함에 저장한다.

```sh
swift run TailQA --live work/qa-live
```

Codex CLI의 전역 설정과 인증정보는 수정하지 않는다. 작업 폴더는 임시 위치에서 생성하고 종료 뒤 정리한다. 프로세스 실행기는 배우자의 MIT 코드를 바탕으로 Swift 6 동시성과 macOS 26 API에 맞게 적용했다. 라이선스는 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)에 있다.
