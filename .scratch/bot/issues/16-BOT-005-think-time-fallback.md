# BOT-005: Maia's think time (fallback formula)
Stage: implementing
Blocked by: BOT-003, CLOCK-001
Review: agent
Difficulty: hard

- Primary files:
  - New: bot/time_model.gd
  - bot/maia_player.gd
  - New: tests/test_time_model.gd
  - ui/main.gd (scope: `_start` hands Maia the game's clock and control; `_show_result`'s latency print names what it measures)

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
- 2026-10-24 From CLOCK-001's close (a note, not a criterion): `Clock.moved(side)` in `core/clock.gd` flags that side, instead of adding the increment, when its clock already reads 0, but the move itself stays on the board. c2 clamps the delay to `clock_left`, so a delay at the clamp makes Maia's move land as its clock reaches 0: either it flags with its move shown, or the frame's tick flags it first and the move finds the game over (`BoardView.play` returns false). Stage 1 may want the clamp a frame below `clock_left`, or the flag to win explicitly. The human side of the same race is CLOCK-002 (.scratch/core/issues/32-CLOCK-002-move-after-flag.md).
- 2026-10-24 Stage 2: `bot/maia_player.gd` cannot reach the game's clock (only `ui/main.gd` owns it, built in `_start`), and `core/clock.gd` does not keep the starting time, so Maia also needs the control to read `Clock.CONTROLS[control][0]`. Asked the proxy whether `ui/main.gd` may join Primary files.
- Proxy decided (opus): ui/main.gd joins Primary files (scope: _start hands Maia the game's clock and control; _show_result's latency print says what it measures); core/clock.gd and tests/test_maia_player.gd stay out — main.gd is the only owner of the clock, so criteria 1, 4 and 6 cannot be met without it, and Maia needs the control string anyway for BOT-006's table, which §4.1 keys by time control. Conditions: the wait arithmetic stays pure in `bot/time_model.gd`; `latencies_ms` keeps measuring think() → Lc0's answer, so BOT-004's pending 50 ms acceptance stays measurable; the `ui/main.gd` lines go in their own commit. For stage 3: `Disclosure: pending | integration | ui/main.gd overlaps the core lane (UI-004, UI-005, UI-007, BOT-008, HIST-001, HIST-002); expect a 3-line conflict in _start/_show_result at the second session merge.`
- 2026-10-24 Note for stage 1 to put on UI-004 (from the proxy, not a BOT-005 criterion): Maia can now sit on a timer for seconds. If a rematch starts while it waits (Esc Esc, then Space), its old move can fire into the new game, and with colours swapped `play` could accept it as the human's move. Cheapest guard, in `bot/maia_player.gd`: when the timer fires, emit only if `_game` and its move count are unchanged since `think()`. Today nothing restarts a game, so there is no exposure yet.
