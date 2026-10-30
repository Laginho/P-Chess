# REV-004: Accuracy per move and per game
Stage: implementing
Blocked by: REV-002
Review: agent
Difficulty: hard

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
