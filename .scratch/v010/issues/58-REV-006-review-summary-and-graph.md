# REV-006: Review summary, eval graph and tooltips
Stage: implementing
Blocked by: REV-004, REV-005
Review: agent
Difficulty: normal
Gate evidence: C:\Users\bruno\AppData\Local\Temp\rev006-stage2-gate.json
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
