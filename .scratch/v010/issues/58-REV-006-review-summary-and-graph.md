# REV-006: Review summary, eval graph and tooltips
Stage: done
Blocked by: REV-004, REV-005
Review: agent
Difficulty: normal
Gate evidence: C:\Users\bruno\AppData\Local\Temp\rev006-reopen-gate.json
Acceptance: pending | Review a real analysed game, inspect both accuracies and final counts, click the graph in both orientations and hover both help controls, including at the minimum window size.

- Primary files:
  - ui/review.gd
  - ui/review.tscn
  - New: ui/eval_graph.gd
  - tests/test_review.gd
  - docs/spec.md (§15.6)

#### What to build

The review's side panel gets its summary and graph (§15.6): both players with their accuracy, a table counting each class per side, a clickable eval graph, and "?" tooltips that explain the numbers.

#### Acceptance criteria

1. The summary shows both players and each side's accuracy (REV-004), "–" for a side with no moves.
2. A table counts each side's moves per class, each move once under its final class.
3. An eval graph of the PV1 score across the game; clicking it jumps the board to that move; the current move is marked; it follows the board's orientation.
4. A "?" beside the accuracy and one beside the table show tooltips that explain in plain English how accuracy is computed and each class's threshold, with the numbers read from `core/tunables.gd`.
5. While the analysis runs, the graph and counts fill in as positions land; the summary shows once the whole game is done.

#### Verification

    Manual: review an analysed game; click the graph; hover both "?".
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_review.gd`: from fixture JSON, the accuracies and per-class counts match `core/accuracy.gd` and `core/classification.gd`; a graph click at a ply moves the board there; the tooltip text contains the current thresholds (red: no summary).

## Comments

- 2026-10-30 Written from spec §15.6.
- Stage 2: the fixture test verifies incremental counts and completed accuracy; disabling the count increment made it fail. The graph test initially emitted `gui_input` directly, which does not invoke the control's virtual input handler; it was corrected to call that handler. The original missing-graph test failed before the implementation.
- Gate on code commit `905e185`: 350 passed, 0 failed; receipt and full log are local. Headless tests do not establish rendered layout, physical input, tooltip readability, or real Stockfish acceptance.

#### Resolution (2026-10-31)
Verdict: Reopen — criterion 4: both help tooltips exceed the window width, hiding the explanations and thresholds.

Reviewed the complete five-file diff `a7762daa7f66aa907c9c04c59a093fb9828bc705...9e398fe00f82092f862c0f9b6194ccf642977e3f`, including this ticket, both scripts, the scene and all test changes. Independent reviewers `/root/standards_review` and `/root/spec_review` examined the Standards and Spec axes. Stage 3 authored no production behavior. REV-004 and REV-005 are done on the session base.

- Standards: no blocking code-standard violation. Primary-file boundaries and the nine commits' test/production separation were checked. The historical commits have empty bodies despite the flow's request for a reason and ticket ID in the body; their subjects cite REV-006. This is a nonblocking process observation on this open ticket, not a failed product criterion. Possible duplicated PV1-to-white-probability conversion is an optional maintenance heuristic, with no defect established and no additional scope requested.
- Spec: **P2**, `ui/review.gd:54-55,77-83`, with the help Labels in `ui/review.tscn:84,95`. Criterion 4 requires tooltips that explain accuracy and every class's thresholds. A Godot 4.7 probe with an 800x600 viewport and hover dispatched through `Viewport.push_input` created an AccuracyHelp popup at `(0,113)` sized **1241x27**, and a ClassHelp popup at `(0,186)` sized **3517x79**. Their tooltip Labels have `autowrap_mode = 0`. The explanations extend outside the viewport; the class help is wider than even the default 1280-pixel window. Merely asserting that `tooltip_text` contains the thresholds does not catch this failure.
- Repair criterion 4 within the existing Primary files: keep both explanations fully readable inside the supported window, using bounded wrapping or suitable line breaks, while retaining the live tunable values. Add a regression that opens each actual tooltip at 800x600 after analysis completes and checks that its full contents fit; assigning or reading the text alone is insufficient.
- Correct the same help text's two misleading rules: `ui/review.gd:82` should say "up to %s moves slower", because a mate in 6 becoming mate in 7 is Excellent when the allowed increase is 2; the threshold is relative to the previous mate distance. At `ui/review.gd:83`, say "moves made while in check" instead of "checks": the classifier tests the starting board's `in_check()`, not whether the played move gives check. These are corrections to criterion 4's explanation, not changes to classification.

Criterion verdicts:

1. ✅ Both player names and per-side accuracy delegate to the existing PGN and Accuracy modules; a side with no moves displays "–".
2. ✅ Counts are rebuilt from the settled final class of each ply, once per side.
3. ✅ PV1/terminal evaluation, side-to-move conversion, orientation and the current-ply marker are implemented. The probe's viewport click selected ply 1 and moved both the board and graph marker there.
4. ❌ Both native tooltips overflow the window as above; the class explanation also needs the relative-mate and in-check wording corrections.
5. ✅ Counts and graph update as positions land; accuracy stays hidden until every position has analysis.

Coverage includes post-game presentation, rematch/setup and cancellation, cached and partial/terminal analysis, classification priority and final counts, accuracy/no-move handling, graph navigation/orientation and minimum-window geometry. The completed fixture's board, summary, counts, graph, move list and Setup action fit 800x600 in the headless probe; tooltip overflow is the confirmed failure. No rendered GUI or physical-input acceptance, real Stockfish game, or long-game responsiveness check was performed. The new count fixtures cover Best rather than every classification; classification itself is covered by its separate existing suite and the count loop was inspected directly.

Verification: independently validated receipt `C:\Users\bruno\AppData\Local\Temp\rev006-stage2-gate.json`, its bound gate command, available tested commit `905e1857ba28406e287e5934bb2c2c785a328030`, matching SHA256 `41326CF57F8AB9BFBA99FA127788C209508D49CC0E12B23443CA06F038362BED`, and the log's **350 passed, 0 failed; ExitCode: 0**. Only this ticket changed after the tested commit; no standalone SKIP records were found. The gate was reused, not rerun. The focused observational probe and log are `C:\Users\bruno\AppData\Local\Temp\rev006-stage3-probe.gd` and `C:\Users\bruno\AppData\Local\Temp\rev006-stage3-probe.log`; exit 0 means the probe completed, while the popup dimensions above establish the failure. The initial sandbox denial of access to installed Godot was resolved by running that focused probe with escalation.

Acceptance: pending | Repair criterion 4, then review a real analysed game, inspect both accuracies and final counts, click the graph in both orientations and read both help controls at the minimum window size.
Disclosure: pending | integration | Criterion 4 must be repaired and re-reviewed before REV-006 is integrated; the existing ticket branch is preserved at to-implement, with no merge or ledger entry.
Disclosure: pending | release | Real Stockfish, rendered layout/tooltips, physical input/orientation and long-game responsiveness remain product acceptance checks, separate from the reused green gate.


#### Stage 2 rework (2026-10-31)

The actual tooltip popups now fit the 800?600 viewport using bounded text lines, and the mate-distance and in-check explanations are corrected. The regression hovers each help control after analysis completes, checks the displayed full text and popup bounds, and checks both corrected phrases. Before the fix it failed on both popup bounds and both phrases; after the fix it passed. The first test harness looked only at direct root children and was corrected to search recursively before the red test was committed.

Gate on code commit `69773246cd8a290ebf02dd40a6435b63e8e25ede`: 351 passed, 0 failed, exit 0. The receipt and log are local. Rendered tooltip readability, physical input and a real analysed Stockfish game remain pending acceptance as described above. The prior integration disclosure remains pending until stage 3 re-reviews this fix.

#### Resolution (2026-10-31)
Verdict: Approve

Re-reviewed every reopened item and the complete repair diff `0ab235f0543792cfe666e013e6a34b8117876e0c...e3a83a9317d0e724550ee2892beaddf0dbb3ba1b`. All five files in the full session diff `a7762daa7f66aa907c9c04c59a093fb9828bc705...e3a83a9317d0e724550ee2892beaddf0dbb3ba1b` were examined, with no skipped files. Independent reviewers `/root/standards_review` and `/root/spec_review` examined the Standards and Spec axes. Stage 3 authored no production behavior.

- Standards: zero new findings. The repair respects Primary files and the test/production split: `7241348` adds the red regression, `6977324` repairs production, and `e3a83a9` records the handoff. It uses local text wrapping without new dependencies. The first review's nonblocking historical commit-body observation remains recorded above.
- Spec: zero unresolved findings. Criterion 4 is repaired: both native tooltips fit the supported window, retain the live tunable values and explain relative mate distance and moves made while in check correctly. The regression opens each actual popup through viewport input after analysis completes and checks its bounds, displayed full text and corrected wording.
- Coverage: summary/count updates, graph navigation and orientation, minimum-window geometry, tooltip construction/input and the classification/accuracy/tunables contracts were checked. The prior review's passed criteria and coverage limits remain applicable; no new regression or scope expansion was established.

Criterion verdicts:

1. ✅ Both player names and per-side accuracy are shown; a side with no moves displays "–".
2. ✅ Each settled move is counted once under its final class and side.
3. ✅ The PV1 graph supports navigation, the current-ply marker and board orientation.
4. ✅ Both explanations fit 800×600, preserve current thresholds and use the corrected mate/in-check wording.
5. ✅ Counts and graph fill incrementally; accuracy waits for complete analysis.

Verification: stage 2 records that `7241348` failed on both popup bounds and both phrases before the fix, then passed after `6977324`. Stage 3 independently validated receipt `C:\Users\bruno\AppData\Local\Temp\rev006-reopen-gate.json` with `Assert-GateEvidence`: the bound command, available tested commit `69773246cd8a290ebf02dd40a6435b63e8e25ede`, log SHA256 `7FC3FC03A54037ED39531EFD9C5C534A8C21E503FCC34ED0961E6E11974AE4C2` and `ExitCode: 0` all match. The log prints **351 passed, 0 failed**, including the actual-tooltip regression; no standalone SKIP or script-error records were found. Only this ticket changed after the tested commit. The gate was reused, not rerun.

Stage 3 also reran the existing observational probe `C:\Users\bruno\AppData\Local\Temp\rev006-stage3-probe.gd` with installed Godot 4.7. The new log `C:\Users\bruno\AppData\Local\Temp\rev006-rereview-probe.log` records an 800×600 viewport, AccuracyHelp at `(328,113)` sized **472×79**, and ClassHelp at `(262,157)` sized **538×443**. Both fit completely; the graph click selected board ply 1 and marker 1. This is headless geometry and synthetic viewport input, not rendered or physical-input acceptance.

Rebase onto `sweatshop/v010/2026-10-30-2302` required no changes. Merge `d3e9aa60399e2cd1cb8c6bbcb7d706236b9f5ebf` preserves the reviewed code. The closing commit changes only this ticket and the feature ledger.

Acceptance: pending | Review a real Stockfish-analysed game, inspect both accuracies and final class counts, click the graph in both orientations using physical input, read both rendered help controls at 800×600, and check long-game responsiveness. These remain release checks; the headless probe and reused green gate do not establish them.
Disclosure: decision | none | This approval resolves the earlier integration disclosure for criterion 4. REV-006 is integrated into the local session branch.
Disclosure: pending | release | The manual real-Stockfish, rendered-layout/tooltips, physical-input/orientation and long-game checks listed in this Resolution remain required before release.
