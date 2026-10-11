#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
shasum -a 256 --check Artwork/AppIcon/checksums.sha256
kkokkomu_sdk_path=$(xcrun --sdk macosx --show-sdk-path)
kkokkomu_sdk_version=$(xcrun --sdk macosx --show-sdk-version)
kkokkomu_options=(-c release --triple "$kkokkomu_triple" --sdk "$kkokkomu_sdk_path" -Xlinker -platform_version -Xlinker macos -Xlinker 26.0 -Xlinker "$kkokkomu_sdk_version")
xcrun swift build "${kkokkomu_options[@]}" --product Kkokkomu
kkokkomu_bin=$(xcrun swift build "${kkokkomu_options[@]}" --show-bin-path)
mkdir -p dist/꼬꼬무.app/Contents/MacOS dist/꼬꼬무.app/Contents/Resources
cp "$kkokkomu_bin/Kkokkomu" dist/꼬꼬무.app/Contents/MacOS/Kkokkomu
cp AppResources/Info.plist dist/꼬꼬무.app/Contents/Info.plist
plutil -replace DTSDKName -string "macosx$kkokkomu_sdk_version" dist/꼬꼬무.app/Contents/Info.plist
cp Artwork/AppIcon/Compiled/AppIcon.icns Artwork/AppIcon/Compiled/Assets.car dist/꼬꼬무.app/Contents/Resources/
cp THIRD_PARTY_NOTICES.md dist/꼬꼬무.app/Contents/Resources/
codesign --force --deep --sign - dist/꼬꼬무.app
codesign --verify --deep --strict dist/꼬꼬무.app
printf '꼬꼬무.app 생성 완료: %s/dist/꼬꼬무.app\n' "$PWD"
