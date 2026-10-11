#!/bin/zsh
# Keep the toolchain scoped to this command. Never change global xcode-select.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
kkokkomu_triple="$(uname -m)-apple-macosx26.0"
