# CI-005: Bundle the tablebase files the unit needs
Stage: done
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

#### Resolution (2026-11-07)
Verdict: Approve

Reviewed the complete diff `1771954...bcb0990` and all four ticket commits. Independent read-only reviewers `/root/review_standards` and `/root/review_spec` checked Standards and Spec respectively; the closing reviewer checked their evidence. Standards: 0 findings. Spec: 0 findings. No production repairs or contract changes were made during review. All changed production files are Primary files, and the ticket explicitly exempts automated test commits.

- ✅ 1: `scripts/fetch-engine.ps1:61`, `:104` and `:216` pin, verify and fetch exactly RES-001's 40 files. Independently compared every name/hash and downloaded byte: 47,896,448 bytes total. Re-ran the complete fetch script against the populated installation with PowerShell: exit 0, 51 verified download skips (40 tables, nine nets and two archives), no downloads or extraction. The earlier empty-table-directory run fetched all 40; existing engine/net caches mean a completely clean clone was not exercised.
- ✅ 2: `scripts/fetch-engine.ps1:108` and `:124` reject mismatches by filename and stage outside the probe directory on the destination volume. Loaded the actual production function definitions through the PowerShell AST and injected successful, corrupt and interrupted transfers. Verified publication, cache skip, corrupt-cache removal, corrupt-download rejection and partial-transfer cleanup; no table or staging directory remained after failures. This negative/positive manual evidence is the prescribed verification in place of test commits.
- ✅ 3: `.github/workflows/release.yml:111` requires precisely the same 40 files, and `:128` archives their tree. Executed the current workflow's package step verbatim against a fixture containing real tables and placeholder non-table files. All 40 ZIP entries at `engine/tablebase/` matched their pinned hashes; removing `KBvK.rtbw` made the actual step fail with that filename.
- ✅ 4: `docs/THIRD_PARTY.md:139` names the Lichess source and links the Gentoo package's public-domain attribution; the linked package metadata was checked during review.
- ✅ 5: Existing engine/network pins, other package requirements and archive operations are unchanged. The package gains the prescribed tables and their attribution only; `.gitignore` and `docs/spec.md` document their location.

Affected callers and interactions examined: every `Get-PinnedDownload`/`Test-PinnedFile` caller (Lc0 and Stockfish archives, extracted engine files, Maia nets and tables), default versus staged downloads, missing/corrupt cached files, corrupt downloaded files, transfer failure and cleanup, release required-file checks and archive creation, export filters, third-party attribution, RES-001's dependency closure and LEARN-006's documented probe directory. Existing archive/net callers retain their default behavior. Not examined live: Windows PowerShell 5.1, the actual Windows release job, the shipped Windows executable's UCI probe or the future LEARN-006 adapter.

Gate: reused `/run/media/lage/New Volume/Scratch/CI-005/gate-final.json`, tested commit `14ae8df677055f4c863e663132a4e5fe68069a12`: `godot --headless -s tests/run.gd`, 574 passed, 0 failed, exit 0. Verified the log SHA-256, exit marker and unchanged production tree with the official `Assert-GateEvidence` helper. Rebase onto the session was already up to date; review and integration changed no production code. Additional local review evidence is under `/run/media/lage/New Volume/Scratch/CI-005/review/`.

Integrated without squash into `sweatshop/learning/2026-11-07-2234` as `0ea989c`. The implementation is approved; product acceptance remains pending under the existing RES-001 review decision.

Acceptance: pending | [RES-001's dated review](101-RES-001-tablebase-and-maia-spike.md#resolution-2026-11-07) and [Windows procedure](../../../docs/research/tablebase.md#stockfish-loading-and-real-output): Bruno must check the actual Windows release package; the Linux checks and fixture ZIP do not establish Windows acceptance.
Disclosure: pending | release | [RES-001's existing deferral and release condition](101-RES-001-tablebase-and-maia-spike.md#resolution-2026-11-07) permits session integration while Windows verification remains pending Bruno. Before release, run the fetch script twice on a clean Windows checkout, run the real Windows packaging workflow and execute the documented release-root UCI probe, checking `Found 20 WDL and 20 DTZ` and `bestmove a1h1`. Record the results here; closing implementation does not waive this condition. No new proxy decision was made in CI-005.
