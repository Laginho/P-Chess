# BOT-005: Maia's think time (fallback formula)
Stage: done
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
- 2026-10-24 Stage 2 done. Commits: 0b82b10 test-only (red), d44c20b `bot/` production, 3be61c2 `ui/main.gd` (own commit, per the proxy).
  - Red at 0b82b10: `Preload file "res://bot/time_model.gd" does not exist`, test_time_model.gd fails to load; 102 passed, 1 failed. Green at 3be61c2: 112 passed, 0 failed (102 + 10 new).
  - Two wiring tests pass trivially on the old code, which answers at once, so each was proved red by mutating `bot/maia_player.gd` and restoring it: top_p never read → `test_a_premove_reads_maia_s_own_clock_and_the_starting_time` fails; legal count fixed at 2 → `test_maia_moves_once_lc0_answers_when_lc0_took_longer_than_the_delay` fails; White's clock read for Black → the premove test fails; no wait → `test_with_time_to_think_maia_does_not_answer_at_once` fails (expected [], got ["e2e4"]). Each run: 111 passed, 1 failed.
  - My readings, not proxy decisions: `moves_played` is Maia's own moves so far (`game.moves.size() / 2`, right for either colour). `top_p` is the highest probability among the legal policy entries, 0 when none is legal (scale 1.6). With under 0.05 s on Maia's clock the clamp's upper bound wins, overrides included, so Maia never waits past its own flag (c2 and c3 cannot both hold there; tested). Without a clock Maia answers at once, which keeps `tests/test_maia_player.gd` and the live Lc0 test unchanged.
  - Maia's first move is untimed (CLOCK-001), but it still waits the formula's delay: about 6 s at 3+2's start, not charged.
  - `latencies_ms` still measures think() to Lc0's answer (gate live test: `maia-1500 median 14.2 ms over 30 moves`). The end-of-game print now says so.
  - `test_with_time_to_think_maia_does_not_answer_at_once` leaves a SceneTree timer pending when the runner quits; the gate log shows no error or leak warning from it.
  - Not done: the manual 3+2 game from Verification (headless session).
Gate evidence: C:/Users/Lage/AppData/Local/Temp/claude/D--Desktop-Projects-P-Chess--artifacts-build-lanes-bot/ad96159a-6fc3-4fee-8c77-07fec4cb801f/scratchpad/BOT-005-gate.json

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents. Standards: no documented-standard breach; two judgement calls (`clock` and `control` travel together; `latencies_ms` measures only Lc0), neither worth a change. Spec: all seven criteria met, no scope creep, the proxy's conditions held. No fix in review.

Criteria:

1. ✅ `TimeModel.base` is `(clock_left / maxi(10, 40 − moves_played) + 0.8 × increment) × (1.6 − top_p)`; `noise` is `exp(randfn(0, 0.6))`, log-normal with median 1; `delay` multiplies them. Units are seconds throughout; `maia_player` converts the clock's ms. `moves_played` is Maia's own moves (`moves.size() / 2`, right for either colour); `top_p` is a fraction (`engine/uci.gd:73` divides Lc0's `P:` by 100). Tested by `test_base_formula_without_noise` (including the floor of 10 moves to go) and `test_the_delay_is_the_base_times_the_noise`.
2. ✅ `minf(maxf(seconds, FLOOR), clock_left)`; both bounds tested over 20 seeds. Under 0.05 s left the clock wins, so c2 and c3 cannot both hold there; tested, and stated in the code.
3. ✅ `legal_moves > 1` gates the formula; `test_one_legal_move_takes_the_floor`.
4. ✅ Strict on both sides: `top_p > 0.9 and clock_left < 0.15 × start`, with `start` from `Clock.CONTROLS[control][0]`. The 0.9 and 27.5 s boundaries are tested; the wiring test reads Black's clock at 10 s while White's reads 182 s.
5. ✅ `TimeModel.wait = max(0, delay − compute)`. Maia's clock runs in real time through Lc0's compute and the timer, so it is charged `max(delay, compute)`; with compute over the delay no timer is created and the move is emitted at once (`test_maia_moves_once_lc0_answers_when_lc0_took_longer_than_the_delay`).
6. ✅ `clock.left(_game.board.side_to_move)` is Maia's real clock (`ui/main.gd` hands it the game's clock in `_start`); nothing stops it during the wait, so Maia can flag.
7. ✅ `delay` is static with the RNG injected. Seed 7, 10,000 draws: median within ±0.05 of 1, log-σ within ±0.03 of 0.6. Each override and clamp holds over 20 seeds.

Test-first: I checked `diff --stat` on every commit. 0b82b10 is the test plus the ticket, d44c20b is `bot/` only, 3be61c2 is `ui/main.gd` only, 21ab3a8 is the ticket only. Every code file is in Primary files; `ui/main.gd` joined them by the proxy's decision.

Red-green:
- From stage 2: red at 0b82b10 (`Preload file "res://bot/time_model.gd" does not exist`, 102 passed, 1 failed); green at 3be61c2 (112 passed, 0 failed). Stage 2's four wiring mutants are in its comment above.
- Checked by me, mutating the lane worktree and restoring it (`git status` clean after): with the wait removed from `bot/maia_player.gd` and the premove at `top_p >= 0.9`, the gate gave 110 passed, 2 failed: `test_with_time_to_think_maia_does_not_answer_at_once` (expected [], got ["e2e4"]) and `test_a_sure_move_in_time_trouble_is_premoved` ("0.9 is not over 0.9"). Each mutant failed only its own test.

Examined:
- Callers: `ui/main.gd` (`_start` hands Maia the clock and control, `_next_turn` calls `think`, `move_ready` goes to `board_view.play`; the board ignores input while Maia is to move, so also during the wait). `tests/test_maia_player.gd`, including the live Lc0 test, sets no clock, so Maia answers at once as before. `latencies_ms` is still recorded at Lc0's answer, where the old synchronous emit was, so BOT-004's 50 ms acceptance stays measurable; the end-of-game print now says what it measures.
- Failure paths: Maia's clock at 0 gives a delay of 0 and no timer; under 0.05 s the clock wins; no legal move in the policy gives `top_p` 0 (scale 1.6) and falls back to any legal move; one legal move takes the floor; Lc0 slower than the delay creates no timer. Maia's clock is read when Lc0 answers, so a clamped delay leaves Maia at least Lc0's compute time before timer overshoot.
- Cross-feature: (a) at the clamp Maia's move lands as its clock reaches 0: the frame's tick flags first and the move finds the game over (`ui/main.gd` `_on_flagged`), or the move lands and `Clock.moved` flags after it with the move kept, the human-side defect of CLOCK-002. Disclosure below. (b) A rematch while Maia waits can fire the old move into the new game (the proxy's note above); UI-004 in the core lane already discards a late reply in its attempt 1. Disclosure below. (c) Maia's first move is untimed (CLOCK-001) but still waits the formula's delay, about 6 s at 3+2's start; §4 makes no exception, so it is no finding, and the manual game will show whether it feels right. (d) `top_p` is flattened by Lc0's policy temperature; still open in BOT-007, as the first comment says.
- Spec §4.1–4.2 still describes the result; the `move_ready` comment in `bot/maia_player.gd` still reads right next to the new header; no doc went stale.
- Not examined: timer accuracy under frame load, 1+0 and 5+0 by hand, the manual 3+2 game.

Rebase: none needed; `bot-005` descends from the session tip 8839816. The merge a31361e has the same tree as 21ab3a8, which differs from the tested 3be61c2 only in this ticket file.

Gate: `godot --headless -s tests/run.gd` on 3be61c2 gave 112 passed, 0 failed, exit 0. Receipt in the Gate evidence line above; I checked its log hash (E55CA370…76A9) and counts. Reused: no production changed after it.

Proxy decided lines: one, (opus): `ui/main.gd` joined Primary files (scope `_start` and `_show_result`). Its conditions held: the wait arithmetic is pure in `bot/time_model.gd` (`wait`), `latencies_ms` measures think() to Lc0's answer, and the `ui/main.gd` lines are their own commit (3be61c2).

Acceptance: pending | the manual 3+2 game against Maia from Verification has not been played (headless sessions only); this ticket's criteria pass, 112/112 on 3be61c2 (receipt above)
Disclosure: decision | none | Proxy decided (opus) under ## Comments: `ui/main.gd` joined Primary files, scope `_start` and `_show_result`; conditions checked above
Disclosure: pending | integration | from the proxy's decision: `ui/main.gd` overlaps the core lane (UI-004, UI-005, UI-007, BOT-008, HIST-001, HIST-002); expect a 3-line conflict in `_start`/`_show_result` at the second session merge
Disclosure: deferred | release | Maia's move at the c2 clamp can land as its clock reaches 0 and be kept while `Clock.moved` flags it (cross-feature (a) above). Destination: CLOCK-002 (.scratch/core/issues/32-CLOCK-002-move-after-flag.md, open, blocked for stage 1), which names it under Comments but whose criteria cover only the human; stage 1 folds it in there or slices its own ticket. No one has accepted the deferral yet
Disclosure: deferred | release | a rematch while Maia waits can fire its old move into the new game (the proxy's note under ## Comments). No exposure on this lane: nothing restarts a game. Destination: UI-004 (.scratch/core/issues/17-UI-004-setup-end-hotkeys.md, open, core lane), whose attempt 1 discards a late reply on rematch; its review must check the guard holds for a reply that comes seconds late
