# REV-004: Accuracy per move and per game
Stage: done
Blocked by: REV-002
Review: agent
Difficulty: hard
Gate evidence: C:\Users\bruno\AppData\Local\Temp\rev004-stage2-gate.json
Acceptance: pending | Headless accuracy passes the recorded-game fixtures; real saved-game analysis and the displayed accuracy remain in REV-002 release QA and REV-006.

- Primary files:
  - New: core/accuracy.gd
  - core/tunables.gd (only if a constant belongs there)
  - New: tests/test_accuracy.gd
  - tests/fixtures/analysis/
  - docs/spec.md (§15.5)

#### What to build

Each side's accuracy for a game, from its analysis JSON, with Lichess's formulas (`AccuracyPercent.scala` in lila), restated in §15.5. Headless.

#### Acceptance criteria

1. Win% is `100·EP` (EP as REV-003), so drops and std-devs are in points 0–100.
2. Per move: 100 when the mover's win% did not drop; otherwise `103.1668·e^(−0.04354·drop) − 3.1669 + 1`, clamped 0–100.
3. Per game, per side: the mean of the volatility-weighted mean and the harmonic mean of that side's move accuracies. The window is `floor(plies/10)` clamped 2–8; the win% series starts at the initial position; windows slide one ply at a time and the first window is repeated so the opening plies get one, as in lila; a move's weight is the std-dev of win% in its window, clamped 0.5–12.
4. A side with no moves has no accuracy (null), which the UI shows as "–".
5. Results match lila to 0.1 on at least two real games whose Lichess accuracy is recorded in the fixture.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_accuracy.gd`: per-move values at drop 0, 10 and 50; the window size at 15, 40 and 200 plies; a no-move side is null; two recorded games match their Lichess accuracy within 0.1 (red: no module).

## Comments

- 2026-10-30 Written from spec §15.5. chess.com's CAPS2 is not published, so Lichess's formula it is.

- 2026-10-30 Stage 2: move accuracy red without the module (0 passed, 1 failed), then green. Game and empty/black-start cases red without `evaluate` (1 passed, 2 failed), then green. A mutation forcing window size 2 failed the 40- and 200-ply cases; restored production passes all 5 focused tests.
- Real-game fixtures project the score fields needed from Lichess exports [uqCv060v](https://lichess.org/uqCv060v) and [T1QrzasJ](https://lichess.org/T1QrzasJ); the site reports integer percentages (87/94 and 85/72). The code returns 86.9913/94.0677 and 84.9996/72.0022. Independently evaluating the full-precision lila formula on those exported scores yields 86.9901/94.0671 and 84.9982/71.9995 respectively; the initial score is 15 cp for the standard start. The fixtures are score projections, not complete analyser-produced game files.
- Gate on `4cb5bb2575837a19c046efaaa64f4772285adc81`: 306 passed, 0 failed, 0 skips, exit 0. Log: `C:\Users\bruno\AppData\Local\Temp\rev004-stage2-gate.log`. Godot reported it could not read the system certificate store; the headless tests passed.

#### Resolution (2026-10-30)

Verdict: Approve

- Standards: 0 documented violations and 0 actionable heuristic findings. Spec: 0 findings against criteria 1-5. Independent Standards and Spec reviewers examined the complete `9585120fece536d030ec74d06d5bb243202ea660...7335b4bb951efa3b8cc19a72fa589f02e42b04b6` diff; the primary reviewer read the changed code, documentation, fixture data and connected producer. Coverage: total_files=6, reviewed_files=6, skipped_files=0, coverage_rate=100%. OCR delegate excluded four files as `unsupported_ext` and two fixtures as `default_path`; all were reviewed directly with its resolved rules.
- Criterion 1: passed. Stored side-to-move cp/mate/terminal scores become a white-perspective series using the initial FEN, the shared EP factor and the +/-1000 cp clamp; win percentages are on the 0-100 scale.
- Criterion 2: passed. Non-dropping moves return 100; drops use the specified exponential and clamp. Tests cover unchanged/improved win percentage and drops of 10 and 50 points.
- Criterion 3: passed. The window uses floor(plies/10), clamped 2-8; `max(0, i-window_size+2)` repeats the first window with the same alignment as lila. Population standard deviation is clamped 0.5-12, and each side's weighted mean and harmonic mean are averaged. The initial position participates. The 15-, 40- and 200-ply tests exercise the window boundaries.
- Criterion 4: passed at the headless seam. Empty and one-move games preserve null for sides without a move; the black-start test checks mover selection. Displaying the dash belongs to [REV-006 criterion 1](../../v010/issues/58-REV-006-review-summary-and-graph.md).
- Criterion 5: passed. The two recorded fixtures contain Lichess source URLs and reported integer accuracies. Independent Python evaluation with the full-precision [lila coefficients and algorithm](https://raw.githubusercontent.com/lichess-org/lila/master/modules/analyse/src/main/AccuracyPercent.scala) returned White/Black 84.998184/71.999507 for T1QrzasJ and 86.990076/94.067064 for uqCv060v, within 0.1 of the recorded references. The implementation's rounded coefficients also satisfy that tolerance in the green gate. These fixtures project scores, rather than reproducing the complete analyser JSON; direct retrieval of the two game exports was unavailable during review, so their published values rely on stage-2 recorded evidence.
- Examined callers, failure paths and interactions: `engine/analyser.gd` game ordering, initial FEN, PV1 and terminal-score schema; `scripts/analyse.gd` PGN replay; classification's shared EP constants and score perspective; empty/black-start games, mates, terminal results and harmonic aggregation; test discovery in `tests/run.gd`. No production consumer of accuracy exists yet. Real Stockfish analysis and future review/history/profile rendering were not exercised here.
- Test-first evidence: `c5050fc`/`c48bd63` and `9d73fe3`/`fecc4fd` keep tests and production separate; `4cb5bb2` adds focused windows/mate coverage with the recorded window-size mutation proof. Historical red runs were not replayed. All changes stay within Primary files, with tracker metadata for handoff. No production behavior was authored during review.
- Verification: `Assert-GateEvidence` verified the receipt, log SHA-256 and unchanged tested code before rebase and after merge. The log contains 306 PASS records, 0 FAIL records, 0 SKIP markers and `ExitCode: 0`, for tested commit `4cb5bb2575837a19c046efaaa64f4772285adc81`. The certificate-store error and malformed-input warnings are recorded in that log. `git diff --check` passed. The green gate was reused because review, rebase and merge changed no tested code.
- Integration: rebased onto `sweatshop/analysis/2026-10-30-1831` (already current), then merged without squash as `ed9c90d`. This resolution, `Stage: done` and the ledger entry are committed together on the session branch.

Disclosure: pending | release | [REV-002 real saved-game acceptance](53-REV-002-analysis-engine-and-files.md) and [REV-006 summary acceptance](../../v010/issues/58-REV-006-review-summary-and-graph.md) carry the remaining product checks: analyse a real saved game, inspect its complete JSON and show both accuracies or the no-move dash in the UI. Fixture/headless verification supports this module's approval; the pending checks remain part of [Bruno's release QA](../../../docs/spec.md#151-release-and-tickets).
