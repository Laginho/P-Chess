# CI-005: Bundle the tablebase files the unit needs
Stage: to-implement
Blocked by: RES-001
Review: agent
Difficulty: normal

- Primary files:
  - scripts/fetch-engine.ps1
  - .github/workflows/release.yml (the required-files check and the package)
  - .gitignore (only if the tablebase folder must be ignored like `engine/weights/`)
  - docs/THIRD_PARTY.md
  - docs/spec.md (§3.1 Engine files, one line on the tablebase folder)

#### What to build

The release carries exactly the Syzygy files RES-001 lists for rook and pawn against rook (spec §L12), fetched with pinned hashes the way the Stockfish binary and the Maia nets are, so a fresh clone and the release zip both have them.

#### Acceptance criteria

1. `scripts/fetch-engine.ps1` downloads each file RES-001 recommends into one tablebase folder beside the engines, verifies each file's SHA-256, and skips files already present with the right hash.
2. A wrong hash stops the script with an error naming the file; nothing half-downloaded stays in the folder.
3. The release workflow's required-files check includes every tablebase file, and the zip contains them at the path the probe (LEARN-006) will pass as `SyzygyPath`.
4. `docs/THIRD_PARTY.md` names the tablebase source and its licence.
5. No other file in the package changes.

#### Verification

    Manual: run scripts/fetch-engine.ps1 twice on a clean clone; the second run downloads nothing.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None: a fetch script and a workflow; covered by the manual check and the release workflow's own required-files step.

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L12.

- 2026-11-07 RES-001 review follow-up: the 40-file manifest in `docs/research/tablebase.md` was independently verified (47,896,448 bytes). Windows acceptance remains a release condition: once packaged, Bruno runs the documented UCI probe from the release root and checks `Found 20 WDL and 20 DTZ` and `bestmove a1h1`. Linux evidence does not replace this Windows check. Record its result here; see RES-001's dated Resolution for the proxy-authorized Linux substitution.
