#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
kkokkomu_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
kkokkomu_ictool="${kkokkomu_developer_dir}/../Applications/Icon Composer.app/Contents/Executables/ictool"
if [[ ! -x "$kkokkomu_ictool" ]]; then
    print -u2 "Icon Composer의 ictool을 찾을 수 없습니다. Xcode 설치와 DEVELOPER_DIR를 확인하세요."
    exit 1
fi
mkdir -p Artwork/AppIcon/Preview
"$kkokkomu_ictool" Artwork/AppIcon/AppIcon.icon --export-image \
    --output-file "$PWD/Artwork/AppIcon/Preview/AppIcon-default.png" \
    --platform macOS --rendition Default --width 1024 --height 1024 --scale 1 \
    --design-generation 27
