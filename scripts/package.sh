#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
shasum -a 256 --check Artwork/AppIcon/checksums.sha256
tail_sdk_path=$(xcrun --sdk macosx --show-sdk-path)
tail_sdk_version=$(xcrun --sdk macosx --show-sdk-version)
tail_options=(-c release --triple "$tail_triple" --sdk "$tail_sdk_path" -Xlinker -platform_version -Xlinker macos -Xlinker 26.0 -Xlinker "$tail_sdk_version")
xcrun swift build "${tail_options[@]}" --product Tail
tail_bin=$(xcrun swift build "${tail_options[@]}" --show-bin-path)
mkdir -p dist/Tail.app/Contents/MacOS dist/Tail.app/Contents/Resources
cp "$tail_bin/Tail" dist/Tail.app/Contents/MacOS/Tail
cp AppResources/Info.plist dist/Tail.app/Contents/Info.plist
plutil -replace DTSDKName -string "macosx$tail_sdk_version" dist/Tail.app/Contents/Info.plist
cp Artwork/AppIcon/Compiled/AppIcon.icns Artwork/AppIcon/Compiled/Assets.car dist/Tail.app/Contents/Resources/
cp THIRD_PARTY_NOTICES.md dist/Tail.app/Contents/Resources/
codesign --force --deep --sign - dist/Tail.app
codesign --verify --deep --strict dist/Tail.app
printf 'Tail.app 생성 완료: %s/dist/Tail.app\n' "$PWD"
