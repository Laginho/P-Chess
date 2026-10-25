# HIST-001: Game history and stats
Stage: done
Blocked by: CORE-006, UI-004
Review: agent
Difficulty: normal

- Primary files:
  - New: core/history.gd
  - core/pgn.gd (writer, if a header or clock case is missing)
  - ui/main.gd
  - New: tests/test_history.gd
  - tests/test_session.gd (only isolated History injection in the session harness and necessary test-directory lifecycle; preserve existing behavior assertions)
  - tests/test_premove.gd (only isolated History injection in the session harness and necessary test-directory lifecycle; preserve existing behavior assertions)
  - tests/test_input_modes.gd (only isolated History injection before Main enters the tree in test_settings_screen_changes_reach_the_board_and_survive_reload, necessary test-directory lifecycle, and a startup assertion retaining that injected History; preserve all existing settings assertions)

#### What to build

Every finished game is saved as PGN with clocks, and per-level stats are kept (§9.4).

#### Acceptance criteria

1. At game end the game is saved to `user://games/` as one PGN file, with `[%clk]` after every played move giving that side's clock after applicable move accounting. This includes the final move, increments and premoves under the existing clock rules.
2. Headers: the players are "Maia 1500" (the net's level) and "You"; `TimeControl` is `60+0`, `180+2` or `300+0`; `Result`; `Termination` (`Normal` or `Time forfeit`); `Opening` when a name is known (filled by OPEN-002). No rating headers.
3. Stats per (level, time control): wins, draws, losses, flag wins and flag losses, updated at each game end and persisted under `user://`.
4. A saved PGN parses back with `core/pgn.gd` to the same moves and clocks.
5. A failed write is reported visibly in the game's result UI and does not crash the app.
6. Flag, resignation, checkmate and draw each trigger one save and one stats update for the finished game. Repeated result handling does not duplicate either; a rematch starts with fresh move-clock snapshots and save state.
7. Automated Main session tests use isolated history storage and do not read or modify the player's normal game-history or stats files.

#### Verification

    Manual: play two games, open the files in user://games/.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_input_modes.gd`: construct real History with a unique isolated test-storage root and assign it before adding Main to the tree. Assert after startup that Main retains that same History instance; clean up only the owned test storage. Preserve every existing settings assertion. This repairs the existing Main integration harness for criterion 7 and adds no new production seam.
- `tests/test_history.gd`, History persistence seam: save a finished game to isolated test storage and parse it back; verify moves, clocks and headers; verify persisted stats after a flag win and a draw, and failed-write reporting. Red because `core/history.gd` does not exist.
- `tests/test_history.gd`, Main session integration seam: instantiate the real `ui/main.tscn` using the existing session-test pattern, replacing only the external UCI/timer boundary, injecting a fake time source into the real Clock and an isolated History store. Exercise flag, resignation, checkmate and draw through their Main paths; inspect saved PGNs and stats to verify one save/update, per-move clocks including final moves, applicable increments and premoves, fresh state after rematch, and a visible result-UI error on write failure. Red because Main does not yet persist finished games or capture move clocks.
- `tests/test_session.gd` and `tests/test_premove.gd`: isolate History storage in their session helpers before Main can access normal history storage, with necessary test-directory lifecycle only. Keep existing behavior assertions unchanged; these are harness adaptations, not new behavior seams.

## Comments

- Proxy decided (gpt-6-astra high, fallback): Approve isolated History injection, necessary storage lifecycle and a startup identity assertion in test_input_modes.gd, preserving its settings assertions — this closes the omitted Main harness under existing criterion 7 without production changes or another seam.
- Reopened stage-2 read-around: the settings test is the only remaining real-Main caller without isolated History; History reads stats in its constructor and Main constructs the default only when history is null. The repair changes the test harness only. A pre-tree identity guard must fail closed before Main can load normal history, and the startup assertion must verify Main retains the injected instance. Existing settings assertions remain unchanged.

Disclosure: decision | none | HIST-001 proxy amendment: narrowly authorizes the omitted settings-test harness repair; no added integration or release dependency.

- Proxy decided (gpt-6-astra high, fallback): Approve isolated History harnesses in test_session.gd and test_premove.gd plus the real-Main history integration seam — existing scene tests finish games, and persistence-only tests cannot verify clock capture, save-once behavior or visible write failures. Contract amendments above are the proxy's draft; no additional product scope or release dependency.
- Read-around before red: Main's `_show_result` is reached from claim, resignation, terminal moves and clock flags. `_on_move_played` is called synchronously by BoardView for human, Maia and premoves; `_next_turn` charges premoves before playing them. Clock flags may re-enter result handling during move accounting. Preserve terminal-move precedence, capture the last move before saving, and reset state on rematch. Degenerate cases: no moves before resignation/flag, a first untimed move, final moves, repeated result handling, and failed PGN/stats writes. PGN's existing writer/reader already support exact millisecond clocks and need no change.
- First red: focused runner (`godot --headless -s tests/run.gd -- res://build/hist-tests`, a disposable copy of test_history.gd) reports `0 passed, 1 failed`: `res://core/history.gd` does not exist. The unprivileged full run also encounters unrelated user:// write denials; subsequent filesystem tests will run with authorized Godot access.

Disclosure: decision | none | HIST-001 Comments: approved test isolation and Main integration coverage for existing history requirements; no added release dependency.

- Stage 2 red/green cycles: `7aef730` fails because History is missing; `8a93259` passes PGN round-trip (1/1). `b5ed8d4` fails because `History.stats` is missing; `7e5b8a4` passes persistence and PGN (2/2). `896b2e7` fails because Main has no history integration; `e5a4680` isolates existing scene harnesses and `b2ed7eb` passes Main's mate/rematch lifecycle (3/3). Each production commit changes only production files; test/contract commits are separate.
- Additional boundary coverage: headers for all three controls and actual Maia level/colour, known Opening, ordinary flags, claimed draw, first/later premoves, reentrant flag during move accounting, terminal-move precedence at zero time, failed game-folder creation and failed stats write with a visible result-UI error. Focused runner: `9 passed, 0 failed`. The cleanup harness initially enumerated an absent games directory after an intentional write failure; corrected it to check directory existence, also in the existing scene harnesses. No production change was needed.
- Mutation proof for the additional integration coverage, with original production restored in `finally`: zeroed clock snapshots => `6 passed, 3 failed`; disabled save-once guard => `6 passed, 3 failed`; hidden result-UI write errors => `8 passed, 1 failed`. Logs: `$TEMP/HIST-001-mutant-clock-snapshot.log`, `$TEMP/HIST-001-mutant-save-once.log`, `$TEMP/HIST-001-mutant-visible-write-error.log`.

> #### Stage 2 handoff (2026-10-25)
>
> - Implemented `History.new(root := "user://")`, `save(game, clocks, settings, opening_name := "") -> String` (PGN path or empty string with `error`), and `stats(level, control) -> Dictionary`. Games live under `<root>/games/`, stats under `<root>/stats.cfg`. Counts are from the human's perspective; flag wins/losses are subsets of wins/losses. OPEN-002 supplies the optional known opening name; setup's `Free` selection is not an opening name.
> - Main snapshots the mover's clock after move accounting, including the final move, and waits for a snapshot before handling a synchronous clock flag. Premoves retain their existing single charge. A per-game guard prevents duplicate PGNs/stats, and rematch resets snapshots and guard. Failed writes appear after the result and rematch hint. Test scene histories use isolated directories and remove their files on teardown.
> - Full bound gate on committed code `24085c8344288fbba0aea60a6a2164710d4cdca0`: `godot --headless -s tests/run.gd` => `180 passed, 0 failed`, `ExitCode: 0`. Includes all 9 new history tests, existing session/premove tests, and real Lc0 integration (no skips). Expected warnings are existing malformed-theme/time-model fixtures; no script errors. Log: `C:\Users\Lage\AppData\Local\Temp\HIST-001-24085c8-gate.log`.
> - Final diff checked for Primary-files scope, test/production commit separation, whitespace, unintended artifacts and unrelated changes. Stage 2 stops here for independent stage-3 review.
>
> Gate evidence: C:\Users\Lage\AppData\Local\Temp\HIST-001-isolation-623-gate.json
>
> Acceptance: pending | Automated real-Main games and saved-PGN inspection pass in tests/test_history.gd; the ticket's manual check of playing two games in the interactive app and opening their user://games/ files has not been performed.
> Disclosure: pending | release | HIST-001 Verification and Stage 2 handoff: interactive two-game acceptance remains; headless tests cover all end paths, clocks, persistence, rematch and visible write errors.
>
> #### Resolution (2026-10-25, first review)
>
Verdict: Reopen — criterion 7: the real-Main settings test still reads the player's normal history stats.
>
> Reviewed `11cd68bf37bc778f784d729c10e53a597458f84a...4c9a1fa01cc09a746576a4c924a26646990e613b` against the ticket and docs/spec.md §9.4, with independent Standards and Spec sub-agents. No production or test changes were authored during review. Preserve `HIST-001-history-stats` for the repair; it has not been merged into `sweatshop/core/2026-10-25-0159`, and no ledger entry was added.
>
> ##### Standards
>
> No hard documented-standard violations. Every implementation commit stays within the amended Primary files; production commits change only production, test commits change only tests and permitted tracker metadata. Existing session/premove behavior assertions are preserved.
>
> One optional judgment call, possible Duplicated Code: directory cleanup repeats in `tests/test_history.gd:75`, `tests/test_session.gd:152` and `tests/test_premove.gd:38`, and the same directory-existence correction was needed in all three. This is a non-blocking observation on this open ticket, not an additional repair criterion or permission for unrelated refactoring.
>
> ##### Spec
>
> 1. ✅ Main records the mover's remaining milliseconds after applicable accounting, including the final move and exactly one premove charge, and saves one PGN per finished game.
> 2. ✅ Headers use the actual Maia level and colour, the three specified time controls, result and termination; the persistence API accepts a known Opening name for OPEN-002. No rating headers.
> 3. ✅ Human-perspective wins, draws, losses and flag subsets persist independently per level/control.
> 4. ✅ Saved moves and exact millisecond clocks round-trip through the production PGN reader.
> 5. ✅ Folder/PGN/stats write failures return a reportable error; Main displays it with the result and keeps the rematch hint.
> 6. ✅ Flag, resignation, checkmate and draw paths converge on guarded saving; reentrant flags wait for the last snapshot. Rematch resets the snapshots and guard.
> 7. ❌ `tests/test_input_modes.gd:266` instantiates Main and adds it to the tree at line 271 without assigning isolated `history`. The new `ui/main.gd:100-101` path constructs `History.new()` with its default `user://` root, and `core/history.gd:16` immediately loads the player's normal `user://stats.cfg`. The settings test need not finish or even start a game for this read to happen. This is a regression introduced by the new ready-time initialization, despite the isolated session/premove harnesses. Inject isolated history before this scene enters the tree, or otherwise prevent the normal-history read, preserving its current settings assertions. The omitted test file is outside Primary files: obtain the required stage-1/proxy contract amendment before editing it; this review does not expand the boundary or rewrite criterion 7.
>
> No unasked product behavior or further incorrect implementation was found. Standards: 0 hard violations and 1 optional cleanup observation. Spec: 1 finding, criterion 7 (P2).
>
> Examined: the entire diff and all nine commit stats; Main result callers for claims, resignation, terminal moves and ordinary/reentrant flags; BoardView's synchronous move emission; Clock first moves, increments and premove accounting; Game terminal-result precedence; Maia callbacks and rematch lifecycle; PGN writing/parsing; stats keys and human perspective; directory/PGN/stats write errors; and every real-Main scene instantiation in tests, including the omitted input-settings caller. Not experimentally examined: real disk-full/permission failures, simultaneous app processes, exported builds, or interactive two-game acceptance. The criterion-7 call chain was confirmed statically without opening or modifying the player's normal history files during this review.
>
> Red/green: inspected the committed test-first cycles and retained logs. The initial red log identifies the missing `core/history.gd` (that unprivileged full run also has unrelated denied-write failures). The recorded focused cycles cover the missing History, stats and Main integration before their separate production commits. Retained mutation logs confirm clock-snapshot and save-once mutations each yield **6 passed, 3 failed**, and suppressing the visible write error yields **8 passed, 1 failed**. The final bound gate is **180 passed, 0 failed**, including the 9 history tests. It does not detect the criterion-7 read above.
>
> Gate: the installed `Assert-GateEvidence` helper verified the existing receipt against HEAD: bound command `godot --headless -s tests/run.gd`, tested commit `24085c8344288fbba0aea60a6a2164710d4cdca0`, exit 0, matching log SHA-256 `2CBF6418A2A1C4519A0213C5D11D651CC6AF0C7ECA79DBCE1A990A14E9068D25` and exit marker. Only ticket metadata follows that tested code. No gate rerun is needed for this metadata-only review; `git diff --check` passes. The repair will require new validation.
>
> Proxy review: the existing `Proxy decided (gpt-6-astra high, fallback)` approved isolated History injection in session/premove tests and real-Main integration coverage. That intent is not fully met because the input-settings Main caller was omitted. No new proxy decision or contract amendment was made during this review.
>
> Acceptance: pending | Criterion 7 must be repaired and independently reviewed before integration. The manual two-game check in Verification remains pending for release.
> Disclosure: decision | none | The existing proxy-approved history-test isolation and Main integration seams remain the contract; this review makes no contract changes.
> Disclosure: pending | integration | The criterion-7 finding is scheduled on this reopened HIST-001 ticket. Stage 2 must resolve the missing Primary-file scope through the stage-1/proxy workflow, isolate the remaining Main test, preserve its settings assertions and return with valid gate evidence.
> Disclosure: pending | release | Interactive play of two games and inspection of their user://games/ PGNs remains as recorded in Verification and the Stage 2 handoff.
>
> #### Stage 2 repair handoff (2026-10-25)
>
> - Repaired the first review's criterion-7 finding in `tests/test_input_modes.gd`. The settings scene receives a real History rooted at a unique owned test directory before entering the tree, and startup must retain that same instance. Teardown removes only that test directory and its files. Every existing settings assertion is unchanged; no production file changed in this repair.
> - The pre-tree regression guard fails closed if injection is omitted, freeing the off-tree scene and its unparented nodes before Main can construct default History or read the player's normal history. This also makes the negative proof safe for player data.
> - Committed red/green harness cycle: `ddbac01` adds the regression assertion and proxy-approved scope amendment; the focused input-mode suite reports **14 passed, 1 failed**, with the sole failure naming missing isolated History before tree entry. `b4f0e89` injects the isolated store and adds its cleanup; the same suite reports **15 passed, 0 failed**. Logs: `build/HIST-001-isolation-red.log` and `build/HIST-001-isolation-green.log` (ignored local evidence). The initial restricted red run also failed existing settings-file writes; rerunning with authorized Godot filesystem access produced the clean red result above. Both repair commits are test-only, with tracker metadata permitted; there is no production change to pair with this harness-only correction.
> - Full bound gate on clean committed code `b4f0e896c059fbb0c3b65f42029b08b1869417d6`: `godot --headless -s tests/run.gd` => **180 passed, 0 failed**, `ExitCode: 0`, including the settings scene, all 9 history tests and real Lc0 integration. Expected malformed-fixture warnings only; no script errors. The Gate evidence line above now points to this run's receipt, replacing the pre-repair receipt.
> - Final diff against reopened commit `89b5635` contains only this ticket and the narrowly approved settings-test harness. `git diff --check` passes. The branch is preserved for independent re-review of the prior criterion-7 failure; no merge or new review verdict was performed in stage 2.
>
> Acceptance: pending | Automated criterion-7 repair and full gate pass; independent stage-3 re-review remains before integration. Interactive two-game acceptance remains pending for release.
> Disclosure: decision | none | Proxy amendment under Comments authorizes only the omitted settings-test harness; criterion 7 and production behavior are unchanged.
> Disclosure: pending | integration | The first-review criterion-7 finding is repaired on this branch and awaits independent re-review on HIST-001.
> Disclosure: pending | release | The original Verification step to play two games interactively and inspect their user://games/ PGNs has not been performed.
>
> #### Resolution (2026-10-25, re-review)
>
> Verdict: Approve
>
> Independent Standards and Spec sub-agents reviewed `89b56356d14fe4946b4a82b148713f87b7f60f95...69be6b1fcc8ab50908b9d44e293143468c3c1f5d`, the first review's criterion-7 finding and all three repair commits. This review authored no production or test changes. Rebase onto `sweatshop/core/2026-10-25-0159` was already up to date; the ticket was merged without squash as `21b1790`. The merge tree is identical to the reviewed ticket tree.
>
> ##### Standards
>
> No documented-standard violations. `ddbac01` changes the test harness and permitted ticket metadata; `b4f0e89` changes only the approved test harness; `69be6b1` is ticket metadata only. Every existing settings assertion is preserved. This harness-only repair adds no production behavior and does not need a production commit to follow its test correction.
>
> One optional possible Duplicated Code observation continues the first review's cleanup note: the settings test now repeats the same owned-directory cleanup used by the history, session and premove tests. It is tracked for triage in [CLEAN-003](34-CLEAN-003-history-test-cleanup.md), without expanding this repair or blocking integration.
>
> ##### Spec
>
> 7. ✅ The settings test constructs real History with a unique isolated root and injects it before Main enters the tree. History's constructor loads only that root's `stats.cfg`; Main retains the supplied instance at startup. The pre-tree guard fails and returns before Main can load normal player history if injection is omitted. Cleanup removes files only from the captured test root and its `games` child. All existing settings behavior assertions remain intact. Criteria 1–6 retain the passing verdicts of the first review; production code is unchanged by this repair.
>
> Examined: History construction, Main's ready-time null guard, every real-Main test caller (settings, session, premove and history integration), settings startup/reload assertions, normal tree-exit cleanup, and the fail-closed off-tree cleanup path. Static Main usages do not instantiate the scene. No new miss in previously reviewed code was identified. Interactive two-game acceptance, exported builds and real disk-full/permission failures remain unexamined.
>
> Red/green: inspected both committed test-only changes and the retained focused logs. `ddbac01` gives **14 passed, 1 failed**, with the sole failure identifying the missing isolated History before tree entry. `b4f0e89` gives **15 passed, 0 failed**. These exercise real History and Main; the negative guard returns before normal history can be read.
>
> Gate: the installed `Assert-GateEvidence` helper validated the current receipt before integration and on merge `21b1790`: bound command `godot --headless -s tests/run.gd`, tested commit `b4f0e896c059fbb0c3b65f42029b08b1869417d6`, **180 passed, 0 failed**, exit 0. The log SHA-256 `F64A21F526043FDB7298BE18646D45ED0DAA29577E7B40CE2E8489BE78CA7420` and exit marker match, and the tested commit exists. Only permitted tracker metadata differs from the tested code, so the green gate is reused. `git diff --check` passes.
>
> Proxy review: both existing `Proxy decided (gpt-6-astra high, fallback)` decisions are satisfied: session/premove history isolation and real-Main integration coverage from the original implementation, and the narrowly approved settings-test isolation/startup assertion from the repair. No new proxy decision or contract amendment was made during this review. The previous criterion-7 integration holds are resolved by this approval and merge.
>
> Acceptance: pending | Automated acceptance and independent criterion-7 re-review pass. The original Verification step to play two games interactively and inspect their user://games/ PGNs remains pending for release.
> Disclosure: decision | none | Both existing proxy-approved test seams are implemented and independently approved; their prior integration condition is resolved.
> Disclosure: deferred | none | [CLEAN-003](34-CLEAN-003-history-test-cleanup.md) retains the optional repeated-cleanup observation for triage. It is not a runtime defect or a release condition.
> Disclosure: pending | release | Interactive play of two games and inspection of their user://games/ PGNs remains as recorded in Verification.

#### Session review reopen (2026-10-25, PR #10)

Verdict: Reopen — persisted result records are used without schema validation: a parseable stats.cfg with a partial or scalar record raises a script error, and the real Main opens the review with history.error empty.

Source: independent review of session PR #10, head 6fbac3e (gpt-6.1-sol xhigh, relayed by the supervising session): "do not merge", two blocking findings. Review gate 235/0 with live Lc0, no skips.

Finding 1 (blocking), `core/history.gd:91` and the game-end accounting in `save`: the result record for the current level/control is read from `user://stats.cfg` and used as a Dictionary with every counter present. A parseable file holding `{"wins": 12}` for that level/control raises a script error when the abandonment accounting reads `losses`; a scalar record fails the same way. The real Main then opens the review without reporting anything, because `history.error` stays empty. Criterion 3 (stats per level and time control, persisted) and criterion 5 (a failure is reported visibly in the result UI and does not crash the app) are the contract this breaks.

Scope for this ticket: validate each result record before use (a Dictionary whose five counters are non-negative integers; anything else is corrupt), keep the records and keys that are valid, treat a corrupt record as zeros for the update, and report the corruption visibly through the same `history.error` path the result screen already shows. The practice counters in the same file belong to OPEN-002 (reopened with this one); share the reporting path, do not duplicate it.

Regressions to write first (own commit, red), in `tests/test_history.gd`: a partial dictionary (`{"wins": 12}`) and a scalar record for the current level/control, each through `save` and through the real Main's game end: no script error, the other levels' records unchanged, the counters written back complete, and the error visible on the result/review screen.

Reopen diagnosis: earlier review miss, not a new defect. The unvalidated read is in `7e5b8a4` (stage 2's first pass) and was present at both ticket reviews (`89b5635`, `396b21b`); neither examined a hand-edited or partially written `stats.cfg`. The session review is the consolidated review of the affected path (`core/history.gd` persisted-data reads); no contract gap (criteria 3 and 5 already require it), no review-induced churn. Next action: stage 2 (two reopens, so the hard implementer), repairing within `core/history.gd`, `ui/main.gd` if the error must reach the review screen, and `tests/test_history.gd`.

- Stage-2 corruption repair read-around: `History.stats()` feeds `save()` and history tests; Main calls `save()` once at game end and copies `history.error` into both the result label and review screen. `practice_counts()` is read during Main startup and shares `stats.cfg`, but its corruption repair belongs to OPEN-002. Preserve existing valid level/control records and practice keys, missing-record defaults, PGN saving, and the save-once guard. Boundaries under test at the existing History persistence seam: partial/scalar/null/array records, missing fields, and negative, float, bool, string or null values in each of the five required counters. The existing real-Main seam will verify the visible game-end warning independently.
- Test harness correction: `ConfigFile.set_value(section, key, null)` removes the key instead of storing a null record. The initial matrix wrongly required a corruption warning for that absent record; removed that equivalent-to-missing fixture while retaining null values inside dictionaries. Missing records remain valid zero defaults. The corrected matrix is rechecked red against pre-repair production, with the current production restored in `finally`.

#### Stage 2 result-record corruption repair handoff (2026-10-25)

- Repaired the PR #10 finding under criteria 3 and 5 in `core/history.gd`. `stats()` checks that a stored result record is a Dictionary containing all five counters as non-negative integers before using or duplicating it. A corrupt record returns complete zero counters, so `save()` records the finished game's result normally and persists a complete replacement. Existing valid records and keys, including other levels/controls and the practice section, are preserved. Missing records retain the existing zero defaults.
- Corruption is reported through `history.error`, naming the affected level/control and explaining the reset. The existing Main result/review UI already displays that error, including after a successful recovery save; no Main change was necessary. `_report_corrupt_stats(section, key)` is the shared warning path for OPEN-002 to reuse for its separate practice-counter repair. Practice validation remains outside this repair.
- Test-first evidence: `5dab0d9` adds the persistence regression, initially **9 passed, 1 failed** with the missing `losses`/scalar `duplicate()` script errors; `db7dd63` contains production only. The separate harness correction `d680b08` removes the null-record fixture described above. Against pre-repair production from `5dab0d9`, the corrected persistence suite is **9 passed, 1 failed**; restored production gives **10 passed, 0 failed**. Logs: `build/HIST-001-corruption-corrected-red.log` and `build/HIST-001-corruption-green.log`. The matrix covers 35 corrupt records, including every counter with negative, fractional/integral float, bool, string and null values.
- Additional real-Main coverage in test-only commit `0c10154` ends games with both partial and scalar persisted records. It verifies one PGN/update despite repeated result handling, complete repaired counters, preserved unrelated records, and the warning on the visible review screen. Against pre-repair production, **9 passed, 2 failed**; with production restored, **11 passed, 0 failed**. Logs: `build/HIST-001-corruption-main-red.log` and `build/HIST-001-corruption-main-green.log`. Each negative run temporarily substitutes the original production file and restores its exact bytes in `finally`; the final working tree is clean.
- Full bound gate on committed `0c1015456fa79ce5163e4a9d311dfa4d0fa61bcf`: `godot --headless -s tests/run.gd` => **237 passed, 0 failed**, exit 0, including all 11 history tests and live Lc0, with no skips or script errors. Expected malformed-time-model fixture warnings remain. External log: `C:\Users\Lage\AppData\Local\Temp\HIST-001-corrupt-stats-0c10154-gate.log`; SHA-256 `5869A4DE24B9E73643E612717D43F12A42867EC33EA913A3BAF1E2C93575E124`.
- Final diff against session reopen `24783fc` is limited to this ticket, `core/history.gd` and `tests/test_history.gd`. All production and test commits are separated; existing behavior assertions are unchanged. `git diff --check` passes. The branch is ready for independent stage-3 re-review; this stage performs no merge or approval.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\HIST-001-corrupt-stats-0c10154-gate.json

Acceptance: pending | Automated result-record recovery and real-Main result/review tests pass. Independent stage-3 re-review remains before integration; the original interactive two-game PGN inspection remains pending for release.
Disclosure: pending | integration | The PR #10 result-record finding is repaired on HIST-001 and awaits independent re-review. [OPEN-002](24-OPEN-002-book-weight.md) remains open for the separate corrupt practice-count finding and must be resolved before integration of session PR #10.
Disclosure: pending | release | The original Verification step to play two games interactively and inspect their user://games/ PGNs has not been performed.

#### Resolution (2026-10-25, result-record corruption re-review)

Verdict: Approve

Independent Standards and Spec sub-agents reviewed the entire `24783fcce76f1a216bbb6c6f774a19b950da86ba...a385ed3e153da7dc0326c43967b483d649c0835a` repair and all five commit stats against the PR #10 finding, criteria 3 and 5, and docs/spec.md §9.4. This review authored no production or test changes. Rebase onto `sweatshop/core/2026-10-25-0159` was already up to date; merge `3e65bc2` preserves the ticket commits without squash, and its tree is identical to the reviewed tree. This closure and the restored ledger entry are committed together on the session branch.

##### Standards

No documented-standard violations or new optional smell findings. Changes stay within `core/history.gd`, `tests/test_history.gd` and permitted ticket metadata. `5dab0d9` contains tests and tracker metadata; `db7dd63` is production only; `d680b08` corrects the test harness with tracker metadata; `0c10154` adds tests only; `a385ed3` is the metadata handoff. Existing assertions are unchanged. The null-record fixture correction records why ConfigFile deletion represents a missing record and supplies corrected red/green evidence. The shared warning helper implements the explicitly requested reporting path for OPEN-002. The earlier optional repeated-cleanup observation remains scheduled on [CLEAN-003](34-CLEAN-003-history-test-cleanup.md).

##### Spec

3. ✅ Persisted result records are validated before dictionary access or arithmetic: all five counters must be present, non-negative integers. Missing records retain zero defaults; corrupt records supply complete zero counters and are replaced with the finished game's update. Valid records for other controls/levels and practice keys survive unchanged.
5. ✅ The affected level/control is named in `history.error`. Successful recovery preserves the warning, which Main shows in both the result label and visible review screen. Partial and scalar records no longer raise script errors or prevent saving the game.

Criteria 1, 2, 4, 6 and 7 retain their previous passing verdicts. Recovery coverage verifies one PGN and one update even after repeated result handling. No unasked behavior, additional earlier-review miss or new regression was found. Standards: 0 hard violations and 0 new optional findings. Spec: 0 findings.

Examined: the complete repair diff; History initialization, stats validation, save accounting and write-failure paths; Main result callers, save-once guard, rematch reset and review presentation; existing stats/book callers; shared practice storage; missing records; the 35-record corruption matrix; and partial/scalar real-Main game ends. The original unchecked-record defect is the earlier-review miss already recorded in the session reopen. The separate corrupt-practice-count defect remains open on [OPEN-002](24-OPEN-002-book-weight.md). Interactive visual acceptance, exported builds, concurrent processes and real disk-full/permission failures were not experimentally examined.

Red/green: inspected the separate test/production commits and retained logs. Corrected persistence tests fail against pre-repair production with **9 passed, 1 failed**, then pass with **10 passed, 0 failed**. Real-Main coverage fails against pre-repair production with **9 passed, 2 failed**, then passes with **11 passed, 0 failed**. Red logs identify the missing-counter/scalar production errors; green tests exercise the real History, Main and review screen.

Gate: the installed `Assert-GateEvidence` helper validated the receipt against the reviewed HEAD, after rebase and on merge `3e65bc2`. Command: `godot --headless -s tests/run.gd`; tested commit `0c1015456fa79ce5163e4a9d311dfa4d0fa61bcf`; **237 passed, 0 failed**, exit 0, including all 11 history tests and live Lc0. The log hash is `5869A4DE24B9E73643E612717D43F12A42867EC33EA913A3BAF1E2C93575E124`; its exit marker matches, with no script errors, errors or skipped tests. Only permitted tracker metadata differs from the tested code, so this green gate is reused. `git diff --check` passes.

Proxy review: both existing `Proxy decided (gpt-6-astra high, fallback)` amendments remain satisfied: session/premove isolation with real-Main integration coverage, and the settings-test isolation/startup identity assertion. This repair preserves those seams and adds no proxy decision or contract amendment. Approval resolves the HIST-001 result-record integration hold; it does not resolve OPEN-002's separate practice-count hold on session PR #10.

Acceptance: pending | Automated result-record recovery and independent re-review pass. The original manual check of playing two games interactively and opening their user://games/ PGNs remains pending for release.
Disclosure: decision | none | Both existing proxy-approved test amendments remain implemented and approved; this review makes no contract changes.
Disclosure: deferred | none | [CLEAN-003](34-CLEAN-003-history-test-cleanup.md) retains the optional cleanup observation for triage, without an integration or release condition.
Disclosure: pending | integration | [OPEN-002](24-OPEN-002-book-weight.md) must resolve the separate corrupt-practice-count finding before integration of session PR #10. HIST-001's result-record finding is resolved by this approval and session merge.
Disclosure: pending | release | Interactive play of two games and inspection of their user://games/ PGNs remains as recorded in Verification.
