# REV-004: Accuracy per move and per game
Stage: to-review
Blocked by: REV-002
Review: agent
Difficulty: hard
Gate evidence: C:\Users\bruno\AppData\Local\Temp\rev004-stage2-gate.json

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
