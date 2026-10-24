# BOT-005: Maia's think time (fallback formula)
Stage: to-implement
Blocked by: BOT-003, CLOCK-001
Review: agent
Difficulty: hard

- Primary files:
  - New: bot/time_model.gd
  - bot/maia_player.gd
  - New: tests/test_time_model.gd

#### What to build

Maia spends human-like time on its moves, from its own clock (§4). This ticket builds the hand-tuned fallback (§4.2) and the overrides (§4.1); the calibrated table is BOT-006.

#### Acceptance criteria

1. Base delay: `clock_left / max(10, 40 − moves_played) + 0.8 × increment`, scaled by `(1.6 − top_p)`, times log-normal noise with median 1 and σ = 0.6.
2. The delay is clamped to `[0.05 s, clock_left]`.
3. With exactly one legal move, the delay is 0.05 s.
4. Premove override: when `top_p > 0.9` and Maia's clock is under 15% of the starting time, the delay is 0.05 s.
5. Lc0's compute time is subtracted from the delay before Maia waits; when compute takes longer than the delay, Maia moves once Lc0 answers. Maia's clock is charged `max(delay, compute)`.
6. The time is spent from Maia's real clock, so Maia can flag.
7. The delay function is pure with an injected RNG: with a fixed seed, the median of 10,000 noise draws is within ±5% of 1, and each override and clamp holds.

#### Verification

    Manual: a 3+2 game against Maia; its moves take varied, plausible time.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_time_model.gd`: base formula with noise off, the noise median, both overrides, both clamps, and the compute-time charge. Red because `bot/time_model.gd` does not exist.

## Comments

- 2026-10-24 From BOT-004's close (a note, not a criterion): `top_p` in c1 and c4 is Lc0's `P:` for the top move, printed at Lc0's default `PolicyTemperature` 1.359. That flattens Maia's raw policy, so `top_p > 0.9` fires less often than §4.1 may assume. Bruno's question, open in BOT-007 ## Comments; this ticket takes `top_p` as given and does not wait on the answer. History: BOT-002 Resolution, BOT-004 ## Comments.
