# CLAUDE.md

**Twinly**: an offline iOS (SwiftUI, iOS 18+) celebrity-lookalike app. It matches
against ~10k film and TV actors worldwide (9,675 indexed). Non-commercial
portfolio project; the InsightFace model weights are non-commercial only. See README.md
for the pipeline and how to rebuild the data.

## Build

```bash
xcodegen
xcodebuild -scheme Twinly -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build
```

`project.yml` (XcodeGen) generates the project. Run `xcodegen` after adding or removing
files. The installed xcodegen is a standalone binary without setting presets, so all
base build settings are spelled out in `project.yml`; keep them there.

## Layout

- `Twinly/Core/`: face pipeline shared with the macOS indexer (`tools/indexer`).
  Platform-neutral (Vision, CoreGraphics, Core ML, Accelerate). **No UIKit here.**
- `Twinly/Engine/LookalikeEngine.swift`: app entry point (photo → matches) + face-crop cache.
- `Twinly/App/`: `TwinlyApp` (root view, sheets) and `AppModel` (stage: home → reveal → result).
- `Twinly/Features/`: Home, Camera (live face guidance + auto-capture), Reveal (slot-machine
  reveal), Result (+ ShareCard), About (+ credits).
- `Twinly/DesignSystem/`: `Theme` tokens and shared components. Use tokens; no ad-hoc colours.
- `Twinly/Features/Scope/`: the "Match within" chip and universe picker; universes come from
  `Twinly/Resources/franchises.json` (built by `tools/fetch_franchises.py`).
- `Twinly/Resources/FaceEmbedder.mlpackage` is **not in git** (the InsightFace licence doesn't
  cover redistribution); `tools/convert_model.py` downloads and converts it.
- `Twinly/Resources/Celebs/` is **generated** by `tools/build_index.sh` (`celebs.json`,
  `embeddings.bin`, `faces.pack`); don't hand-edit. The indexer computes all-pairs
  similarity in row blocks; never materialise the full n×n matrix.
- The Simulator's Vision landmarks are broken (collapsed points), so matching can only
  be verified on a real device. `TWINLY_DEMO_IMAGE` + `devicectl` can do that headlessly.

## Invariants

- The app and the indexer must embed faces identically. Change alignment or encoding
  only in `Core/`, then rebuild the index (`tools/build_index.sh`).
- Photos never leave the device: no networking code in the app.
- Every celebrity portrait shown must stay credited (artist + licence + source link).

## Git

Public repo (`github.com/m-afham/Twinly`), PolyForm Noncommercial. Commit or push only when asked.
Never commit the model weights, the celebrity data or portraits.
