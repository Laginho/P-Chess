# BOT-009: Maia premoves only expected moves, and never moves faster than a human hand
Stage: done
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
- Prediction cycle: test-only `a59fe3e` was red (46 passed / 9 failed across the five affected suites, including the not-yet-added delay argument); production-only `0f5b94f` was green (73 passed / 0 failed). This includes a real Lc0 game of 30 plies, with one latency sample per played move. Logs: `%TEMP%/BOT-009-prediction-{red,green}.log`.
- Additional boundary tests in test-only `a4241aa` cover an empty history and prediction compute time. Mutation proof (all mutations restored without a source diff): restoring the old unconditional/15% premove gives 17 passed / 2 failed in time-model tests; clearing stale FIFO entries gives 9 passed / 1 failed in Maia tests; resetting the reply timestamp after prediction gives 9 passed / 1 failed in Maia tests. Logs: `%TEMP%/BOT-009-mutant-{premoves,stale-fifo,prediction-compute}.log`.
- Final bound gate on `a4241aa`: `godot --headless -s tests/run.gd`, 268 passed / 0 failed, exit 0. Godot 4.7.2 was found under `%TEMP%/P-Chess-CI-003/godot`; a temporary PATH shim exposes the bound command. Full output and exit status are in `C:/Users/bruno/AppData/Local/Temp/BOT-009-gate.log`; the receipt records the tested commit and log hash. `git diff --check` passed. Test and production changes remain separate commits.

Acceptance: pending | The two manual 1+0 scenarios under Verification (hanging a piece / expected recapture under 6 s, and a premove scramble reaching Maia's flag) still need a human play session. Automated checks cover the delay rules, strict thresholds, both sampling paths, clock clamp, FIFO invalidation, and compute accounting.

Disclosure: pending | unknown | This ticket's Verification section: human 1+0 feel and tuning of the initial 0.4 s reaction value were not assessed during stage 2.

Gate evidence: C:\Users\bruno\AppData\Local\Temp\BOT-009-gate.json

#### Resolution (2026-10-27)

Verdict: Approve

Standards: 0 findings. Independent Standards review checked all six commit diffs/stats: tests and production remain separate, and the session/repertoire/premove test edits only replace the obsolete one-request harness contract. Runtime changes stay within Primary files and reuse the existing dictionary/FIFO conventions.

Spec: 0 findings. Independent Spec review and the closing review examined `MaiaPlayer.think`/`_on_policy`, `TimeModel.delay`/`wait`, Main's turn and flag handling, the real UCI queue/parser, clock accounting, repertoire weighting, human premoves, rematches, synchronous replies, empty history, empty prediction policies and obsolete requests/waits. No production repair was authored during review. Manual 1+0 play and reaction-value tuning were not examined.

1. ✅ Expected/unexpected prediction pairs select the 0.05 s override or ordinary reaction floor only under the strict panic and probability thresholds (`test_only_the_top_predicted_human_move_allows_a_premove`, `test_only_an_expected_sure_move_under_ten_percent_is_premoved`).
2. ✅ The exact 10% edge and 10–15% band retain ordinary delay, even for an expected move above 0.9 probability.
3. ✅ Formula and table samples receive the 0.4 s reaction floor; timer/clock integration tests cover compute subtraction and the resulting move delay.
4. ✅ Exactly one legal move retains the 0.05 s floor in both sampling modes.
5. ✅ Ordinary moves with at most 0.4 s left clamp to the remaining clock, including zero. The explicit forced/premove overrides in criteria 1 and 4 retain their own floor, also clamped to the remaining clock.
6. ✅ Both pending entries exist before either bridge call; old predictions and replies consume their FIFO slots without selecting a current move or recording latency. Shared timestamps count both queries, with one latency sample per actual move. Session/rematch tests retain CLEAN-005's guarantee.
7. ✅ `docs/spec.md` §4.1 documents prediction, strict 10% panic, reaction floor, both overrides, clock clamp and combined compute time.

Red-green evidence reviewed: reaction cycle 15 passed / 4 failed → 19 passed / 0 failed; prediction cycle 46 passed / 9 failed → 73 passed / 0 failed. The prediction red run includes the not-yet-added `delay` argument plus behavioral failures at the public seams. Mutation logs independently reject unconditional/15% premoves (17 passed / 2 failed), cleared stale FIFO slots (9 passed / 1 failed), and a reset reply timestamp (9 passed / 1 failed). The final gate includes the supplementary empty-history and compute-boundary tests.

Gate: reused the bound run on `a4241aa21824dff9170a941f77748d928d1ac314`, 268 passed / 0 failed, exit 0. Validated the receipt command, commit, SHA-256 log hash, recorded exit and unchanged tested files using `Assert-GateEvidence`; no gate rerun was needed. The log records a real Lc0 game of 30 moves, median 9.3 ms. `git diff --check` passed. External log: `C:/Users/bruno/AppData/Local/Temp/BOT-009-gate.log`; receipt: `C:/Users/bruno/AppData/Local/Temp/BOT-009-gate.json`.

Files: `bot/time_model.gd`, `bot/maia_player.gd`, `docs/spec.md`, the two primary test files, and the three replaced-contract test harnesses. Rebase onto `sweatshop/qa/2026-10-27-1653` required no changes; integrated without squash as `3e4e850`. Only this ticket and the QA ledger change after the tested code. The existing Acceptance/Disclosure lines remain pending: implementation approval does not claim the two human 1+0 scenarios passed.
