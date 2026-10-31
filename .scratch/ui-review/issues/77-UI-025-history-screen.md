# UI-025: History screen to the design
Stage: to-review
Blocked by: UI-021
Review: agent
Difficulty: normal

- Primary files:
  - ui/history_screen.gd, ui/history_screen.tscn
  - tests/test_history_screen.gd

#### What to build

Restyle History to `docs/design/v0.1.0/png/History.png`, which shows every card state on one screen (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. Header: back button, "History", and the tabs All, 1+0, 3+2 and 5+0 as a segmented control, each with its game count.
2. Toolbar: select-all checkbox with "N selected", "Analyze selected" (green), the queue status line with a spinner ("Analysing 2 of 7 · Background"), and "Analyze all in “<tab>”".
3. Each card matches the canvas: checkbox, thumbnail, opening name (only when known), "Bruno x Maia 1500" with colour dots, date, time-control chip, the result coloured by outcome (green win, red loss, grey draw) and the move count.
4. Every analysis state matches the canvas: analysed (both accuracy boxes, white's light and black's dark); analysing (bar and percentage, the action disabled as "Analysing…"); queued ("Queued · 3rd in line", the action disabled as "Queued"); stale (dimmed accuracies, "Stale: <reason>" and "Re-analyze" in gold); not analysed ("Not analysed", "Analyze").
5. Review (green when analysed), the Copy PGN and Delete icon buttons, and the inline delete confirm ("Delete this game?", red Delete, Cancel) replace today's controls; behaviour unchanged.
6. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the board.

#### Verification

    Manual: screenshot tool on a fixture history holding every state; delete a game; analyse two selected games.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_history_screen.gd`: tab labels carry their counts; a queued card's action reads "Queued" and is disabled; the delete confirm is inline in the card (red where today's controls differ).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. Tab counts are a canvas addition adopted in the spec.

- 2026-10-31 Stage 2: red tests for tab counts, queued action and inline delete failed on the old screen; batch selection/progress and stale-cache display were added in separate red/green cycles. Existing History/Profile tests now follow the new card controls and inline confirmation; the black-player fixture's expected outcome was corrected from loss to win because White resigned. Focused History, History screen and Profile checks: 42 passed, 0 failed.
- Screenshot fixture with six states, isolated data and a fake analysis runner: `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-final3-1280/History.png` and `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-final3-800/History.png`; fixture script `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-fixture.gd`. At 800x600 the list scrolls and metadata wraps. The shared BoardView and theme are reused, so board rendering and typography retain their project styling rather than duplicating the canvas components. Stage 3 still needs its own before/after comparison against the reference.
- Manual UI on isolated fixture: confirmed delete reduced All from 6 to 5; selected two games and Analyze selected changed the simulated batch from 1 of 2 to 1 of 4, with both new cards queued. This did not run Stockfish.
- Gate on `2c2c710`: 416 reported passed, including six Lc0-dependent SKIPs (410 executed), zero failed; log `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-gate-2c2c710.log`.

Acceptance: pending | Complete the two-selected-games check with a real Stockfish installation and Bruno's v0.1.0 QA; simulated evidence above.
Disclosure: pending | integration | `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-fixture.gd`: the required two-game analysis completion was not verified against a real Stockfish executable, absent in this worktree.
Disclosure: pending | release | `.scratch/ui-redo/spec.md` requires Bruno's v0.1.0 QA before tagging.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui025-reopen-gate-9f798f6.json

#### Resolution (2026-10-31)
Verdict: Reopen — criterion 5 deletes the wrong game; criterion 6 fails the minimum-size error state and the required visual icon match.

Reviewed `841d4a43f4d91dbdca5acafb4818aff4135a1b6e...9dbfa2d86cbe1329c0b4d513eaf901d7552e789a` against the lane base `sweatshop/ui-review/2026-10-31-1734`. Separate reviewers: `/root/standards` and `/root/spec`; the latter independently inspected the graphical error evidence and the before/reference/after comparison. No production fixes were authored in this review.

##### Standards

No blocking documented-standard or test-first violations confirmed. All 15 commits keep test changes separate from production changes. The existing-test adaptations in `tests/test_history.gd` and `tests/test_profile.gd` are permitted by ticket-flow `stage2.md`'s test-only Primary-file exception for assertions on replaced behavior; their omission from the original Primary files is not a finding.

##### Spec

- **P1 — `ui/history_screen.gd:350`, `:371`, criterion 5 ("behaviour unchanged"): confirming card A can delete game B.** Open Delete on A, then on B, then click A's inline red Delete. Both confirmations remain visible, while the shared `_delete_path` points to B. The graphical probe used `Viewport.push_input` mouse events and printed `Both inline confirms visible: true / true`, then `After mouse Confirm A: A exists=true, B exists=false`. This deletes a different PGN and its associated data from the game the user confirmed. Bind confirmation/cancellation to its own card's path and keep the active confirmation consistent; add a regression covering A -> B -> confirm A, cancellation, and a queue refresh. Evidence: [probe log](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/delete-probe.log), [two visible confirmations](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/two-confirms.png), [repro script](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/delete_probe.gd). All data was isolated.
- **P2 — `ui/history_screen.gd:51`, `:488`, criterion 6 / shared acceptance 2: a Stockfish failure cuts off the screen at 800x600.** The fixture emitted the exact existing `engine/uci.gd:160` stopped message through `queue._finished(false, message)`; this was an injected production error string, not a live engine crash. The unwrapped toolbar grows to 1179 px at x=-189.5. Back, History, selection and card actions leave the viewport; Analyze all starts at x=858.5, making the advertised retry inaccessible. Constrain and wrap the status, and let the toolbar adapt to the available width. Evidence: [PNG](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/error-stop-800/History.png), [measured rectangles](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/error-stop-800/capture.log), [fixture](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/error_stop_capture.gd). The ordinary active and short-error fixtures fit, so those screenshots alone missed this failure.
- **P2 — `ui/history_screen.gd:35`, `:302`, `:276`, criterion 6 / shared acceptance 1: required reference icons and state adornments are missing.** The fresh 1280x800 capture omits Analyze selected's trend glyph, the queued state's clock and raised pill, and the stale state's warning triangle. The shared acceptance explicitly includes icons; the existing BoardView/theme justification does not describe these omissions. Reproduce these reference adornments, or resolve an explicitly accepted visual deviation through stage 1. Tabs also begin at x=188 rather than the reference's x=220; include that spacing difference in the same visual correction or justified-difference record.

Numbered criterion disposition:

1. Pass: Back, History and the four counted tabs are present.
2. Pass for the stated controls: select-all, selection count, selected/all analysis actions and active queue indicator are present; real two-game completion remains pending below.
3. Pass for card data: orientation, known-only opening, player markers, date/control, outcome colours and move count are retained.
4. Pass for state data and actions: both accuracy boxes, progress, queued/analysing disabled actions, stale cache/reason and unanalysed action are present. Missing visual adornments are recorded under criterion 6.
5. ❌ **Fail:** the confirmation can remove the wrong game (P1 above).
6. ❌ **Fail:** error-state usability at 800x600 and visual parity of the named icons/adornments (both P2 above).

##### Coverage and evidence

Complete coverage: **6/6 changed files, 100%, 0 skipped** — ticket, `ui/history_screen.gd`, `ui/history_screen.tscn`, `tests/test_history.gd`, `tests/test_history_screen.gd`, `tests/test_profile.gd`. OCR delegate preview excluded all six as `unsupported_ext`; every diff was reviewed directly. Examined History -> Review -> History/Home callers, legacy rename/HumanColor and thumbnail orientation, selection across tabs, tab counts, active/waiting queue actions and retry, stale/invalid cache handling, delete cancellation/failure and analysis cleanup, and Profile-facing test adaptations. Connected sources included `ui/main.gd`, `core/history.gd`, `core/analysis_queue.gd`, `core/accuracy.gd`, `engine/analyser.gd`, `engine/uci.gd`, the shared theme and design HTML/PNG.

Reference and screenshots (the base History resources were loaded into the same isolated six-state fixture for the before capture):

| Reference | Before | After |
|---|---|---|
| [History reference](../../../docs/design/v0.1.0/png/History.png) | [1280x800](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/before-1280-retry/History.png) | [1280x800](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/after-1280/History.png) |
| Same reference; minimum-size usability check | — | [800x600](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/after-800/History.png) |
| Error-path usability check | — | [800x600 stopped-engine state](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/error-stop-800/History.png) |

The ordinary 800x600 fixture scrolls and wraps metadata; the stopped-engine case does not fit. Fixture names, dates, move counts and accuracy values are illustrative. The pre-existing shared BoardView/typography differences remain documented in the stage-2 comments; they are not separate findings here. Capture scripts and logs are under [the review evidence directory](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/).

Reused the existing green gate on `2c2c710983551f1e62111e3435885c79b5e40962`: receipt command/commit/exit, log SHA-256 and final `ExitCode: 0` were validated. Only this tracker ticket changed between that tested commit and reviewed HEAD. The log reports **416 passed, 0 failed**, including **six Lc0-dependent SKIPs (410 executed)**. No code changed during review, so the gate was not rerun. The graphical reproductions above are separate checks, not additional gate tests. Historical red/green logs were inspected without rerunning them: initial controls 9 passed / 1 failed -> 36 passed / 0 failed; selection 10 / 1 -> 11 / 0; stale cache 11 / 1 -> 12 / 0; final focused History/History screen/Profile run 42 / 0. These logs are `pchess-ui025-{red,green,selection-red,selection-green2,stale-red,stale-green,layout-green4}.log` under the same system Temp folder. The failed tests name the intended missing controls/states.

Acceptance: pending | Resolve the three findings above; complete two selected games with real Stockfish, then Bruno's v0.1.0 QA. Mouse-input deletion and graphical layout were checked only with isolated fixtures; live engine completion, full keyboard/screen-reader acceptance and gameplay remain unverified here.
Disclosure: pending | integration | This Resolution's P1: UI-025 must bind confirmation to the intended game before integration; wrong-game data deletion was reproduced.
Disclosure: pending | integration | This Resolution's minimum-size P2: the stopped-engine state must preserve navigation and retry at 800x600 before integration.
Disclosure: pending | integration | This Resolution's visual P2: restore the named reference icons/adornments or obtain an explicitly accepted visual deviation before integration.

Returned to `Stage: to-implement` on the preserved ticket branch. No merge, push or PR; the next stage 2 handles all findings together.

#### Stage 2 rework (2026-10-31)

- Criterion 5: opening a second confirmation closes the first; the confirmation also carries and checks its own game path. The regression exercises A → B, queue refresh, cancel, and confirming A; it failed before the fix and passes afterward. Red and green logs: `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-delete-red.log` and `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-delete-green.log`.
- Criterion 6: the toolbar wraps a long engine error within 800×600, and the trend, queue clock/pill, warning and tab spacing follow the canvas. The layout test failed on all six control bounds and wrapping before the fix, then passed; the adornment checks failed on all three missing icons/states, then passed. Logs: `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-layout-red.log`, `pchess-ui025-layout-green.log`, `pchess-ui025-visual-red.log` and `pchess-ui025-visual-green.log` in the same Temp directory. The layout test initially had untyped window variables that prevented parsing; commit `012e853` corrected the harness before the recorded red run.
- Graphical fixture captures: [all states at 1280×800](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-reopen-6da1b593-8bf2-4852-b99e-0daba394b78b/normal-1280.png) and [injected stopped-engine error at 800×600](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-reopen-6da1b593-8bf2-4852-b99e-0daba394b78b/error-800.png). The error was injected, not a live engine crash. Stage 3 must independently review the fixes and compare the reference and captures.
- Gate on `9f798f6ee9198e86bfa7f66629d9a6624cc09491`: 418 reported passed, including six Lc0-dependent SKIPs (412 executed), zero failed. Log: `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-reopen-gate-9f798f6.log`.

Acceptance: pending | Stage 3 review, two selected games completed with a real Stockfish installation, and Bruno's v0.1.0 QA.
Disclosure: pending | integration | Real Stockfish completion of two selected games remains unverified; the earlier selection check used a fake runner.
Disclosure: pending | release | Bruno's v0.1.0 QA remains required before tagging.
