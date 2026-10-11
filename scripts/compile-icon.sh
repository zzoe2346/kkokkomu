#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p Artwork/AppIcon/Compiled
xcrun actool --compile Artwork/AppIcon/Compiled --platform macosx \
    --minimum-deployment-target 26.0 --app-icon AppIcon \
    --output-partial-info-plist Artwork/AppIcon/Compiled/icon-info.plist \
    --output-format human-readable-text --warnings --errors Artwork/AppIcon/AppIcon.icon
shasum -a 256 Artwork/AppIcon/AppIcon.icon/icon.json \
    Artwork/AppIcon/AppIcon.icon/Assets/mascot.png \
    Artwork/AppIcon/Compiled/AppIcon.icns Artwork/AppIcon/Compiled/Assets.car \
    > Artwork/AppIcon/checksums.sha256
