# CI-002: Windows export on every push
Stage: to-implement
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
5. The downloaded artifact starts on Windows and shows the missing-engine message from BOT-002.

#### Verification

    gh run watch   # on the ticket branch: the artifact is listed; link the run in the ticket
    Manual: download the artifact, run it, see the missing-engine message.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: workflow and export preset. The evidence is the run link and the manual start.

## Comments

- 2026-10-24 UI-001 review: the board reads its pieces as raw `res://themes/pieces/cburnett/*.svg` through `FileAccess` (shortcut at `ui/board_view.gd:10`). A default export packs only imported textures, so the exported app would start with an empty board, and criterion 5 would still pass. The export must ship the twelve `.svg` files as they are (import mode Keep File, or a non-resource include filter; check which one survives the import step). A note, not a criterion yet: stage 1 folds it into the body.
