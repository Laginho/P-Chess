# HIST-003: Save the repertoire snapshot beside the PGN
Stage: done
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/history.gd (`save`; `read_repertoire`, the reader criterion 4 requires)
  - ui/main.gd (`_start`: capture the repertoire colour beside `_review_repertoire`; `_show_result`: pass both)
  - tests/test_history.gd
  - docs/spec.md (§15.7)

#### What to build

When a game is played with a repertoire loaded, the lines it was checked against (the snapshot `ui/main.gd` already keeps for the review) are saved next to the PGN as `<game file name>.repertoire.json` (§15.7). A review opened later from the history (HIST-004) checks Repertoire and Left repertoire against that file, never against the repertoire as it is now.

#### Acceptance criteria

1. Saving a game with a non-empty snapshot writes `<stem>.repertoire.json` beside `<stem>.pgn`, holding those lines and the repertoire's colour, in a form `bot/badges.gd` can read back unchanged.
2. A game with no repertoire writes no snapshot file.
3. A failed snapshot write reports through `history.error` like a failed PGN write, and the PGN and stats are still saved.
4. A function reads a game's snapshot back, returning empty lines when the file is missing.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_history.gd`: a save with lines writes the file and reads back equal; a save without writes none; a missing file reads as empty (red: no file).

## Comments

- 2026-10-30 Written from spec §15.7.
- 2026-10-30 Implemented snapshot persistence and recovery. The red run failed to load the history test because the snapshot arguments were absent (275 passed, 1 failed); the green gate passed 287 tests, 0 failed. Snapshot write errors are reported while PGN and stats continue to save.

Gate evidence: C:\Users\bruno\AppData\Local\Temp\hist003-green.json

- 2026-10-30 Review ended at blocked (exit 0); branch HIST-003 holds the review; left for a human

- 2026-10-30 Proxy decided (opus-5.5 xhigh): Approve. Criterion 4 requires the reader and criterion 1 requires the colour, so both edits are authorized. Stage 1 does not need to clarify anything first. Fold the widened scopes below into Primary files so the boundary matches what was merged - both edits sit in files the ticket already names, and the numbered criteria require them. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-195501-HIST-003-ed4474.json)
  Primary-files interpretation: criteria 4 (snapshot reader) and 1 (repertoire colour) required `read_repertoire` in `core/history.gd` and the colour capture in `ui/main.gd` `_start`. Both files were already named. Scopes widened to match, numbered criteria unchanged. Asked by the foreman after stage 3 (gpt-6.1-sol xhigh) blocked with the proxy unreachable from Codex; resume stage 3 on the retained `HIST-003` branch (abb5e93).

#### Resolution (2026-10-30, first pass; superseded below)
Verdict: Needs your call: reconcile the scoped Primary files with the reader and immutable colour capture required by criteria 4 and 1 before integration.

- Standards: one contract-boundary discrepancy, no confirmed code defect or relevant smell. Primary files scopes `core/history.gd` to `save`, but the change adds `read_repertoire` at line 90. It scopes `ui/main.gd` to `_show_result`, but the change adds a private colour field at line 49 and captures/publishes it in `_start` at lines 218, 229 and 257. These edits directly support criteria 4 and 1; the written scope and numbered criteria need an explicit interpretation. No criteria or Primary files were rewritten in review.
- Spec criterion 1: passed in code and the committed round-trip test. The adjacent JSON stores colour, IDs, moves and positions; reading restores the packed arrays consumed by `bot/badges.gd`. Main captures colour together with the duplicated lines before the catalog await and passes both when saving the result.
- Spec criterion 2: passed. Empty lines skip snapshot creation; the committed test verifies that an ordinary save creates no snapshot.
- Spec criterion 3: passed by inspection. The PGN is flushed and closed before the snapshot write. Snapshot open/write failures set `history.error` and continue to the stats save; Main includes the error in the result and review. A later stats-save failure preserves the snapshot error. A snapshot-only I/O failure was not exercised dynamically.
- Spec criterion 4: passed. A missing file returns empty lines; the committed test covers this fallback.
- Coverage: 5/5 changed files reviewed, 100%, none skipped. OCR excluded all five as `unsupported_ext`; both Standards and Spec axes reviewed them directly. Examined all `History.save` callers, default arguments, result/clock accounting, immutable repertoire capture, no-repertoire starts, rematches, failed starts, repertoire replacement during play, JSON conversion, Badge consumption, stats/practice counters and test cleanup. History reopening and deletion belong to HIST-004 and HIST-005 and were not exercised here; malformed external snapshots and graphical input were not exercised.
- Test-first history: `c90d989` contains tests and tracker metadata, `ef9c3b2` production/spec changes only, and `946d924` the metadata handoff. The retained red log (`C:\Users\bruno\AppData\Local\Temp\hist003-red.log`) reports 275 passed, 1 failed because the old `save` accepts at most five arguments and the new test supplies seven. The green run reports 287 passed, 0 failed, no SKIP markers, exit 0. These historical runs were not repeated.
- Gate: reused the receipt above after checking its command, tested commit, SHA-256, exit marker and equality of non-tracker files against `946d924`. No production or tests changed during review.
- Blocking question for the proxy: are the new reader in the already-named `core/history.gd` and the minimal private colour capture in the already-named `ui/main.gd` authorized by criteria 4 and 1 despite the narrower parenthetical scopes, allowing approval with a recorded interpretation, or must stage 1 clarify Primary files before stage 2 hands this back? Return the minimal scope draft and who may fold it if clarification is necessary; do not change the numbered criteria.
- Proxy attempt: `proxy.ps1 -Repo . -Ticket HIST-003` could not reach the proxy. It returned: "The proxy is unreachable from this session. Stop now: commit Stage: blocked with your question under ## Comments. The driver asks the proxy and relaunches the stage." No proxy decision or receipt was produced. Work is preserved on `HIST-003`; no merge, push, PR or ledger entry was made.

Historical delivery fields, superseded by the resumed review below:

> Acceptance: unknown | This review confirms the ticket-level automated evidence and static behavior above; product acceptance through the future History screen remains with HIST-004.
> Disclosure: pending | integration | The Primary-files interpretation in this Resolution remains assigned to HIST-003; the ticket is blocked awaiting the proxy/driver decision, with no accepted deferral.

#### Resolution (2026-10-30, resumed review)
Verdict: Approve

- Standards: 0 unresolved findings. The recorded `Proxy decided (opus-5.5 xhigh): Approve.` decision above authorizes `read_repertoire` and the immutable colour capture in `_start`. Its receipt was read and verified for HIST-003; the authorized scopes are folded into Primary files. This resolves the first pass's only integration blocker without changing any numbered criterion. No actionable baseline smell or other documented violation was found.
- Spec: 0 findings. Criterion 1 passes: the adjacent JSON stores the original colour and complete line data, and the reader restores the packed arrays consumed by badges. Criterion 2 passes: empty lines create no snapshot. Criterion 3 passes by inspection: snapshot open/write failures report through `history.error`, preserve the completed PGN and continue to stats; a later stats failure preserves both error messages. Criterion 4 passes: a missing file returns empty lines.
- Coverage: both independent Standards and Spec reviews examined all 5 changed files, the previous blocked finding and the metadata-only diff since `abb5e93`. Connected paths examined include every `History.save` caller, default arguments, JSON round-trip, badges, immutable lines/colour captured before the catalog await, starts without a repertoire, rematches, failed starts, result error display, stats/practice counters and test cleanup. No new production or test code was authored in review.
- Red-green proof: original `c90d989` (rebased `9416f56`) contains tests plus tracker metadata, followed by production/spec-only `ef9c3b2` (rebased `0cb52e4`), then metadata handoff `946d924` (rebased `c6b9c74`). The retained red log reports 275 passed, 1 failed for the old five-argument `save` called with seven arguments. The retained green log contains 287 PASS records, 0 failures, 0 SKIPs and `ExitCode: 0`.
- Gate: reused `C:\Users\bruno\AppData\Local\Temp\hist003-green.json`, command `godot --headless -s tests/run.gd`, tested commit `ef9c3b25a0766a840a94c2f85ce55ce260587373`. Validated receipt, exit code, log SHA-256 and equality of all non-tracker/non-ledger files against the reviewed and rebased code. No code changed, so the gate was not repeated.
- Integration: rebased onto `sweatshop/v010/2026-10-30-1831`; conflicts affected only this ticket's Stage/comments and were resolved preserving the implementation evidence, earlier review and proxy record. The reviewed production/test diff is unchanged. Integrated locally with merge commit `2858e4ab7efea233d4a6e153da40dd2c166e9686`; this closure sets done and records that merge in the ledger. No push or PR was made in this stage.
- Limits: snapshot-only I/O failure was inspected rather than injected at runtime. Malformed external snapshots, graphical input and the future history reopen/delete flows were not exercised. History reopening belongs to HIST-004 and deletion to HIST-005.

Acceptance: pending | [HIST-004](59-HIST-004-history-screen.md), criterion 6: product acceptance of reopening a game and showing badges from its saved snapshot awaits the History screen; HIST-003 save/read automation passes as recorded above.
Disclosure: decision | none | The proxy receipt in Comments resolves the former scope blocker. Only the parenthetical scopes in already-named files were widened; numbered criteria and production code are unchanged.
Disclosure: pending | release | [HIST-004](59-HIST-004-history-screen.md), criterion 6 owns the remaining History-screen acceptance against a saved snapshot. This permits session integration; the product check remains pending before release.
