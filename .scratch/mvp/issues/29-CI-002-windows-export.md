# CI-002: Windows export on every push
Stage: to-review
Blocked by: CI-001
Review: agent
Difficulty: normal

- Primary files:
  - New: export_presets.cfg
  - .github/workflows/ci.yml

#### What to build

Every push also builds the Windows app and uploads it as an artifact (§12), code only, without the engine.

#### Acceptance criteria

1. `export_presets.cfg` has a Windows Desktop preset.
2. On every push, a job exports the Windows build with pinned Godot 4.7 export templates.
3. The build is uploaded as a workflow artifact and contains nothing from `engine/lc0/` or `engine/weights/`.
4. The export job fails when the export fails.
5. The downloaded workflow artifact starts on Windows without `engine/lc0/` or `engine/weights/` present and visibly shows how to run `scripts/fetch-engine.ps1`, using BOT-002's missing-engine reporting through the setup UI required by BOT-004 criterion 6.
6. The exported app preserves the bundled theme files required by ThemeLoader's raw-file APIs: all twelve cburnett SVG pieces, the brown board's `theme.json`, and every bundled OGG sound file in sfx, nes, piano and futuristic. Verify their presence and readability in the exported package and manually confirm visible pieces and audible move feedback when the board is available.

#### Verification

    gh run watch   # on the ticket branch: the artifact is listed; link the run in the ticket
    Manual: download the artifact, run it, see the missing-engine message.
    godot --headless -s tests/run.gd

Export implementation may proceed after CI-001. Criterion 5 additionally depends on BOT-002 and BOT-004 being integrated. Record Windows startup and theme checks separately from missing-engine UI acceptance. A successful local export is supporting evidence, not a substitute for the specified Actions run and downloaded-artifact verification. CI-002 must not be closed, counted as satisfying CI-003's dependency, or merged into the session while these required checks remain pending.

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: workflow and export preset. The evidence is the run link and the manual start.

## Comments

- 2026-10-24 UI-001 review: the board reads its pieces as raw `res://themes/pieces/cburnett/*.svg` through `FileAccess` (shortcut at `ui/board_view.gd:10`). A default export packs only imported textures, so the exported app would start with an empty board, and criterion 5 would still pass. The export must ship the twelve `.svg` files as they are (import mode Keep File, or a non-resource include filter; check which one survives the import step). A note, not a criterion yet: stage 1 folds it into the body.

- 2026-10-24 Review ended at blocked (exit 0); branch ci-002 holds the review; left for a human
- 2026-10-24 Proxy decided (gpt-6-astra high, fallback): implement and independently review the CI-002 exporter now within its existing Primary files; preserve criterion 5 as pending until BOT-002 and BOT-004 provide the visible missing-engine flow, and include raw theme assets — export work is separable, but the product requirement and Bruno's prior integration restriction remain binding.
- Stage 2 starts from session commit 50f64b9. CI-001 is done. No GDScript function changes; the affected consumers are ThemeLoader's raw-file APIs and the exported main scene. The ticket explicitly exempts new unit tests. Verification covers successful export, export failure propagation, archive exclusions, raw theme data and Windows startup; absent BOT-002/BOT-004 UI remains pending.

Acceptance: pending | Criterion 5 requires BOT-002 and BOT-004 integration, followed by a fresh Actions artifact download and Windows verification. Startup/theme evidence: not yet run.
Disclosure: decision | integration | Proxy decision in CI-002 Comments: exporter implementation may proceed separately; pending criterion 5 prevents CI-002 closure and session integration. See BOT-004 criterion 6 and BOT-002's final foreman comment.
Disclosure: pending | integration | CI-002 criterion 5: no missing-engine UI exists in the current app. Resolve after BOT-002 and BOT-004 integration; preserve and rerun the original downloaded-artifact acceptance check.
- 2026-10-25 Stage 3 (opus-5.5) resumed the stalled handoff: rebased ci-002 onto main (af8997c), committed one review fix to export_presets.cfg (data/* in include_filter, adf2acf), then ran the gate on adf2acf: 253 passed, 0 failed.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\claude\C--Users-bruno-Desktop-Pastinha-Programas-Projects-P-Chess\3da8f19c-6a93-4fff-b0c6-6bfbd2688adf\scratchpad\ci002-gate.json
