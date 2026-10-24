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
