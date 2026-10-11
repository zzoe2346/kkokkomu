# Tail 앱 아이콘

사용자가 선택한 첫 번째 빨간 머리띠 캐릭터다. 배우자의 흰색 캐릭터, 빈 원형 눈과 작은 입을 참고하고 생각하는 손과 파란 질문 말풍선을 더했다. 머리띠를 지운 변형은 최종 앱에 사용하지 않는다.

`AppIcon.icon/Assets/mascot.png`는 imagegen으로 제작한 투명 전경 원본이다. 노란 배경과 그림자, 반투명 재질은 `AppIcon.icon/icon.json`에서 지정한다. 생성 프롬프트와 참고 이미지 기록은 `prompts.json`에 보관한다. 제작일은 2026-10-12다.

Icon Composer 형식은 Xcode의 actool로 컴파일한다.

```sh
./scripts/compile-icon.sh
./scripts/package.sh
```

`Compiled/AppIcon.icns`와 `Compiled/Assets.car`를 앱 번들에 함께 넣는다. 소스와 컴파일 결과의 SHA-256을 `checksums.sha256`으로 확인하며, 원본을 수정한 경우 다시 컴파일해야 패키징 검사를 통과한다.
