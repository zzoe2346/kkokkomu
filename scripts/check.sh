#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
xcrun swift test --triple "$kkokkomu_triple"
xcrun swift build -c release --triple "$kkokkomu_triple"
