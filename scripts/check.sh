#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build -c release
