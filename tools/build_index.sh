#!/bin/zsh
# Compiles the Core ML model for macOS, builds the indexer against the app's
# shared Core sources, and regenerates Twinly/Resources/Celebs.
set -euo pipefail
cd "${0:A:h}/.."

xcrun coremlcompiler compile Twinly/Resources/FaceEmbedder.mlpackage tools/cache/ >/dev/null
xcrun swiftc -O -o tools/cache/twinly-indexer \
  Twinly/Core/FaceAligner.swift Twinly/Core/FaceEncoder.swift Twinly/Core/CelebrityIndex.swift \
  tools/indexer/main.swift
tools/cache/twinly-indexer "$PWD"
du -sh Twinly/Resources/Celebs
