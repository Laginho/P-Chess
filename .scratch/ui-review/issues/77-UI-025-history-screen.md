# UI-025: History screen to the design
Stage: done
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

Acceptance: pending | Bruno's v0.1.0 QA before tagging; two selected games completed with real Stockfish 19, and graphical deletion/layout checks passed. See the final Resolution below.
- Integration condition resolved in the final Resolution: the simulated two-game check was supplemented by completion with real Stockfish 19.
Disclosure: pending | release | `.scratch/ui-redo/spec.md` requires Bruno's v0.1.0 QA before tagging.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui025-rereview-4351cfea-e71c-435a-a36f-9393e43a6e2e/gate-640666a.json

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
- Integration condition resolved in the final Resolution: the P1 wrong-game deletion was repaired and checked through mouse input, cancellation and queue refresh.
- Integration condition resolved in the final Resolution: the stopped-engine toolbar preserves navigation and retry at 800x600.
- Integration condition resolved in the final Resolution: the named reference icons/adornments and tab spacing were restored.

Returned to `Stage: to-implement` on the preserved ticket branch. No merge, push or PR; the next stage 2 handles all findings together.

#### Stage 2 rework (2026-10-31)

- Criterion 5: opening a second confirmation closes the first; the confirmation also carries and checks its own game path. The regression exercises A → B, queue refresh, cancel, and confirming A; it failed before the fix and passes afterward. Red and green logs: `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-delete-red.log` and `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-delete-green.log`.
- Criterion 6: the toolbar wraps a long engine error within 800×600, and the trend, queue clock/pill, warning and tab spacing follow the canvas. The layout test failed on all six control bounds and wrapping before the fix, then passed; the adornment checks failed on all three missing icons/states, then passed. Logs: `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-layout-red.log`, `pchess-ui025-layout-green.log`, `pchess-ui025-visual-red.log` and `pchess-ui025-visual-green.log` in the same Temp directory. The layout test initially had untyped window variables that prevented parsing; commit `012e853` corrected the harness before the recorded red run.
- Graphical fixture captures: [all states at 1280×800](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-reopen-6da1b593-8bf2-4852-b99e-0daba394b78b/normal-1280.png) and [injected stopped-engine error at 800×600](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-reopen-6da1b593-8bf2-4852-b99e-0daba394b78b/error-800.png). The error was injected, not a live engine crash. Stage 3 must independently review the fixes and compare the reference and captures.
- Gate on `9f798f6ee9198e86bfa7f66629d9a6624cc09491`: 418 reported passed, including six Lc0-dependent SKIPs (412 executed), zero failed. Log: `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-reopen-gate-9f798f6.log`.

Acceptance: pending | Stage 3 review, two selected games completed with a real Stockfish installation, and Bruno's v0.1.0 QA.
- Integration condition resolved in the final Resolution: both selected games completed using the production Stockfish runner.
Disclosure: pending | release | Bruno's v0.1.0 QA remains required before tagging.

#### Resolution (2026-10-31)
Verdict: Approve

Re-reviewed `e57090d..88ad122` and all prior failed criteria against lane base `841d4a43f4d91dbdca5acafb4818aff4135a1b6e`. Standards reviewer `/root/standards` and Spec reviewer `/root/spec` examined all six files of the full base diff. No unresolved P0-P2 findings remain.

##### Standards

No documented-standard or scope violations. Rework commits retain test-only/production-only separation; the recorded layout harness correction is valid. The previously reviewed legacy History/Profile test adaptations remain permitted by `stage2.md`. No refactoring outside the ticket.

##### Spec and prior findings

1. Pass: header, Back and counted tabs retained; tab spacing restored to the reference's x=220.
2. Pass: selection and queue controls retained. Two games selected through actual mouse input both completed through the production `StockfishRunner`, using the pinned Stockfish 19 executable (SHA-256 `45bc8e4969147db9c2eb533810637994619bff0eacc81ccfd9854394901bcbd0`). Each cache contains all three positions and each completed card reports both accuracies. This resolves the previous real-engine integration condition.
3. Pass: card metadata, outcome colours, orientation and known-only opening behavior retained.
4. Pass: analysis states retained; trend glyph, queue clock/raised pill and stale warning restored. Graphical stale and stale-confirm cards fit horizontally at 800x600, ending at x=768.
5. Pass: prior P1 resolved. Mouse input A -> B leaves only B's confirmation; a stale A callback changes neither file. Queue refresh preserves B, Cancel preserves both files, and confirming A deletes only A.
6. Pass: the long stopped-engine message wraps within 800x600, with navigation/retry accessible and cards scrollable. Reference adornments restored. The rework introduced a new toolbar grouping regression at 1280x800, corrected during this review as described below. Existing shared BoardView/typography differences and illustrative fixture data remain explained in earlier Comments; no additional visual deviation was accepted here.

Reviewer-authored correction: `/root` removed one expanding-size property from the status label, leaving the existing spacer to absorb spare width. Test-only `64a18ec` failed exactly the new short-status spacing assertion; production-only `640666a` passed with zero failures, preserving the existing minimum-size error assertions. Logs: [red](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-rereview-4351cfea-e71c-435a-a36f-9393e43a6e2e/toolbar-red.log), [green](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-rereview-4351cfea-e71c-435a-a36f-9393e43a6e2e/toolbar-green.log). Independent reviewer `/root/spec` examined `88ad122..640666a`, both fresh captures and these logs: **Approve**, no blocking finding. This was introduced by rework commit `8b29ebb`, not missed in the earlier review.

##### Coverage and verification

**6/6 changed files reviewed, 100%, 0 skipped:** this ticket, both History resources and all three changed History/Profile tests. OCR delegate preview excluded all six as `unsupported_ext`; they were inspected directly. Rechecked deletion callbacks, cancellation/failure preservation, queue-driven card refresh, status/error transitions, responsive layout and state adornments; the first review's connected-caller coverage remains above. No gameplay changes were made.

| Reference | Before | Final after |
|---|---|---|
| [History reference](../../../docs/design/v0.1.0/png/History.png) | [Base fixture, 1280x800](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/before-1280-retry/History.png) | [All states, 1280x800](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-rereview-4351cfea-e71c-435a-a36f-9393e43a6e2e/final-1280/History.png) |
| Minimum-size usability | [Previous broken error state](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-review-299f9246-b3a6-4a50-b55a-48d830d57cf3/error-stop-800/History.png) | [Full engine error, 800x600](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-rereview-4351cfea-e71c-435a-a36f-9393e43a6e2e/final-error-800/History.png) |

Isolated graphical probe: [script and log](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-rereview-4351cfea-e71c-435a-a36f-9393e43a6e2e/probe.log), with `PROBE_FAILURES=0`, exit 0; adjacent `probe.gd` reproduces it. Captures include [stale confirmation](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-rereview-4351cfea-e71c-435a-a36f-9393e43a6e2e/stale-confirm-800.png) and [completed real-engine batch](C:/Users/bruno/AppData/Local/Temp/pchess-ui025-rereview-4351cfea-e71c-435a-a36f-9393e43a6e2e/live-completed-1280.png). The probe ran on `88ad122`; the subsequent one-property layout correction received the independent graphical checks above. Data was isolated before Godot started. The engine error was injected, not a live crash.

After rebase onto the unchanged lane base, the bound gate ran once on final code `640666a8bd0c03331455a09d2c1bb56dc145f4b4`: **418 reported passed, 0 failed; six Lc0 SKIPs, 412 executed; exit 0**. Receipt and complete log are adjacent to the probe evidence; `Gate evidence:` above points to the receipt. Only tracker/ledger metadata changes after that commit. Integration merge: `124dce0bc4f8d112288db4d05b7de50a4de7c646` into `sweatshop/ui-review/2026-10-31-1734`; no PR or push from stage 3.

Acceptance: pending | Bruno's v0.1.0 QA before tagging. Required ticket-level mouse deletion, graphical states/minimum-size checks and two-game Stockfish completion passed; full keyboard/screen-reader acceptance and Lc0 gameplay were not established by these probes.
Disclosure: pending | release | [.scratch/ui-redo/spec.md](../../ui-redo/spec.md): Bruno's v0.1.0 QA remains required before tagging. Prior integration disclosures are resolved by the evidence above.

- 2026-10-31 Foreman feature check on the integrated session 1b4af20 (includes CLEAN-012 font weights): `scripts/screens.gd` History at 1280x800 and 800x600, exit 0, captures `C:/Users/bruno/AppData/Local/Temp/pchess-ui-review-acceptance-1b4af20/History-1280x800/History.png` and `C:/Users/bruno/AppData/Local/Temp/pchess-ui-review-acceptance-1b4af20/History-800x600/History.png`. Weights now render (title, Analyze selected bold); nothing clipped at 800x600. Against `docs/design/v0.1.0/png/History.png`, the tab labels, card player names, outcome text and Analyze all button still render regular where the canvas is bold, and the tabs are separate buttons rather than one segmented pill. The tool's fixture holds one unanalysed game, so the other card states rely on the stage-3 captures above. Unexamined: live gameplay and keyboard/screen reader.

Acceptance: pending | Bruno's v0.1.0 QA; weight/segmented-tab differences above to judge against the canvas.
Disclosure: pending | release | [History.png](../../../docs/design/v0.1.0/png/History.png): tab, name, outcome and secondary-button weights still regular after CLEAN-012; Bruno decides whether QA accepts them or a follow-up ticket is needed.
