# CI-005: Bundle the tablebase files the unit needs
Stage: to-review
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


## Resolution

- The fetch script pins all 40 RES-001 files, verifies them before publishing to `engine/tablebase/`, and checks existing files on reruns. Staging is outside the probe directory and on the same volume.
- Linux PowerShell: downloaded all 40 tables into an empty tablebase directory with the final script; a second run downloaded nothing. Engines and Maia nets were pre-populated from existing local caches, so this was not a completely clean-clone run. Corrupt cached and newly downloaded files failed with the filename and were removed; a failed transfer left no table or staging directory.
- Executed the release workflow's package check and archive commands with fixture non-table files and the downloaded tables: the ZIP contained all 40 at `engine/tablebase/`, and a missing `KBvK.rtbw` stopped the check by name. The actual Windows release workflow has not run here.
- `godot --headless -s tests/run.gd`: 574 passed, 0 failed. Windows release-root UCI acceptance by Bruno remains pending as described above.

Gate evidence: /run/media/lage/New Volume/Scratch/CI-005/gate-final.json

## Criteria check

- ✅ 1: `scripts/fetch-engine.ps1:61` and `:216`; independently compared all 40 names and hashes with RES-001; real download and no-download rerun verified the behavior.
- ✅ 2: `scripts/fetch-engine.ps1:104` and `:116`; wrong cached/downloaded hash and failed transfer were exercised, and same-volume staging keeps interrupted downloads outside the probe folder.
- ✅ 3: `.github/workflows/release.yml:111` and `:128`; the manifest matches RES-001, and the fixture package check verified ZIP paths and missing-file failure.
- ✅ 4: `docs/THIRD_PARTY.md:139` names the Lichess mirror and the public-domain status attributed to Gentoo's package.
- ✅ 5: the release workflow's existing package operations remain unchanged apart from requiring and including the newly fetched tables; `THIRD_PARTY.md` gains their attribution. No automated tests were prescribed by this ticket.

The criteria were checked independently by a read-only subagent; its interruption finding was fixed by same-volume staging before the final gate.
