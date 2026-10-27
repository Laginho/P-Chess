# BOT-009: Maia premoves only expected moves, and never moves faster than a human hand
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: hard

- Primary files:
  - bot/time_model.gd (`delay`, the floors)
  - bot/maia_player.gd (`think`, `_on_policy`)
  - tests/test_time_model.gd
  - tests/test_maia_player.gd
  - docs/spec.md (§4.1 overrides)

#### What to build

Maia is nearly impossible to flag in 1+0 (Bruno's QA, 2026-10-27: "é quase impossível dar flag no maia, porque ele começa a jogar instantaneamente. mesmo que o lance seja óbvio, tipo eu pendurar uma peça, não faz sentido ele jogar instantaneamente, só faria sentido em um caso de pre-move ou um lance que ele já estivesse esperando"). Two causes, each fixed and tested separately:

1. **The premove override fires on the wrong moves.** Today any move with top_p over 0.9 under 15% of the starting time takes the 0.05 s floor, and hanging a piece is exactly what makes top_p high. A premove is a reply planned before the opponent moved, so it needs the opponent's move to have been expected. New rule: the floor applies only when (a) the human's last move was Maia's top prediction for the human, (b) Maia's top_p is over 0.9, and (c) Maia's clock is under 10% of the starting time (the §3.4 panic threshold).
   The prediction is Maia's policy for the position before the human's last move (`moves` minus its last entry), with the same net. Suggested approach: `think()` queues that request ahead of the usual one, so both FIFO replies are matched to `_pending` entries as now. It is one `go nodes 1` query and its time counts against Maia's clock like the other.
2. **A fraction of what is left never reaches zero.** The §4.2 formula spends `clock_left / N` per move, so Maia's clock decays geometrically and does not flag on its own. Every move that is not a premove (rule 1) or a forced move (one legal move) waits at least `REACTION := 0.4` s, a human's reaction and hand time. This applies in table mode too, after the bucket sample. 0.4 s is an initial value, to be tuned by playing.

The clamp to `clock_left` stays: Maia never waits past its own flag.

#### Acceptance criteria

1. Under 10% of the starting time with top_p over 0.9, the delay is the 0.05 s floor when the human's last move was Maia's top prediction, and at least `REACTION` when it was not.
2. Between 10% and 15% of the starting time, a top_p over 0.9 no longer gives the floor.
3. A move that is neither a premove nor forced waits at least `REACTION`, from the formula and from a table bucket whose sample falls below it.
4. One legal move still takes the 0.05 s floor.
5. With `REACTION` left or less, the delay is the clock left.
6. The prediction request does not shift which policy answers which `think()`: a stale game's replies are still consumed and dropped (CLEAN-005's guarantee).
7. §4.1 describes both overrides as above.

#### Verification

    Manual: a 1+0 game; hang a piece with Maia under 6 s; it does not take instantly. Recapture after a trade with Maia under 6 s; it may.
    Manual: a 1+0 scramble against Maia with only premoves on your side; Maia's clock reaches zero.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_time_model.gd`: the expected/unexpected premove pair, the 10–15% band, the `REACTION` floor from formula and from a bucket. The three asserts that pin 0.05 s for non-premove cases (one legal move, the premove case, under the floor left) are updated to the new rule.
- `tests/test_maia_player.gd`: the prediction request is sent before the move request; with a fake bridge, an expected human move gives the floor and an unexpected one does not.

## Comments

- 2026-10-27 Written from Bruno's QA session. Bruno saw it in 1+0. The cheaper "recapture on the square just captured" heuristic was set aside for the real prediction: the extra query is a single `go nodes 1`, and Bruno asked why it should wait.
- 2026-10-27 Stage 2 scope: `TimeModel.delay` is called only by `MaiaPlayer._on_policy` and the time-model tests; `think` is called by Main and bot/session tests. Test seams are the ticket's `delay` and `think` boundaries, with fake engine, clock and timer signals. Check empty histories (no prediction), synchronous and FIFO replies, stale games, both clock sides, forced moves, table samples, and clocks at/below reaction. Existing session tests that deliver one policy per think will need test-only harness updates for the extra query.
- Reaction cycle: test-only `fa5c8c2` failed with 15 passed / 4 failed; production-only `92fa7f2` passed all 19 time-model tests. Logs: `%TEMP%/BOT-009-reaction-{red,green}.log`. The first sandbox run could not write Godot's existing user-data fixtures; the recorded red/green runs used the installed Godot with that access.
- Replaced-contract test-only updates: `test_session.gd` now supplies both prediction and reply policies and expects both FIFO requests; `test_repertoire.gd` supplies the prediction before its existing book-weight reply; `test_premove.gd` counts both requests per actual human move. These change only the engine harness/assertion replaced by BOT-009; other assertions stay unchanged, per ticket-flow's replaced-contract exception.
