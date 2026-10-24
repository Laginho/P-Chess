# BOT-003: Move picker and time-pressure panic
Stage: to-review
Blocked by: CORE-001
Review: agent
Difficulty: hard

- Primary files:
  - New: bot/move_picker.gd
  - New: tests/test_move_picker.gd

#### What to build

`bot/move_picker.gd` turns Maia's policy into one sampled move (§3.3): book weight, cut, temperature, sample, in that order. It also gives the panic-adjusted `T` and `τ` when Maia's clock runs low (§3.4). Pure functions with an injected RNG.

#### Acceptance criteria

1. The pick applies, in order: multiply each `p(m)` by its book weight `w(m)` and renormalise; cut every move below `τ` but always keep the top move, and renormalise; apply `p ← p^(1/T)` and renormalise; sample one move.
2. A move with `p = 0.5%` and `w = 20` survives the cut at `τ = 2%` (the weight is applied before the cut).
3. When every move is below `τ`, only the top move is left.
4. With `T = 1` the distribution after the cut is unchanged; with a seeded RNG, 10,000 draws match the final distribution within ±2 percentage points per move.
5. Defaults are `τ = 2%`, `T = 1.0`; missing weights count as 1.
6. Panic: above 10% of the starting time, `T` and `τ` are unchanged; at 0 s they equal `T_max` and `τ_min`; between, they move linearly. Intensity low / medium / high gives `(T_max, τ_min)` = (1.3, 1%), (1.7, 0.5%), (2.2, 0.2%); off leaves `T` and `τ` unchanged.
7. Nothing uses a global RNG; the same seed gives the same move.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_move_picker.gd`: each criterion above with hand-made policies and a seeded RNG, including the panic curve at 10%, 5% and 0%. Red because `bot/move_picker.gd` does not exist.

## Comments

- 2026-10-24 Stage 2 (opus-5.5) on branch `bot-003`. Two red/green cycles:
  - Cycle 1 (7779908 red, 6322ec2 green): criteria 1–5 and 7, plus the empty and all-zero policies the renormalisation creates. Red: `Preload file "res://bot/move_picker.gd" does not exist`.
  - Cycle 2 (90e352e red, 7318aee green): criterion 6. Red: `Static function "panic()" not found`.
  - Interface: `distribution(policy, weights := {}, tau := DEFAULT_TAU, temperature := DEFAULT_TEMPERATURE) -> Dictionary` (steps 1–4), `pick(policy, rng, weights, tau, temperature) -> String` (step 5; `""` for an empty policy), `panic(temperature, tau, intensity, time_left, start_time) -> {"temperature", "tau"}` with intensity `"off" | "low" | "medium" | "high"` and both times in one unit. No `class_name`; callers `preload` it, like the tests.
  - Spec §3.4 maps off to `(1, τ)`; criterion 6 says off leaves `T` unchanged. I followed the criterion. The two agree at the default `T = 1`.
  - Mutants checked by hand and killed: no renormalisation after the weights (2 tests fail), global `randf()` instead of the injected RNG (1), `p^T` instead of `p^(1/T)` (1).
  - Not separated by any test: `>= τ` against `> τ` at exactly `τ` (float equality at the boundary; no criterion names it). An all-zero policy picks its first move; an unknown intensity string is a script error; `start_time = 0` is not handled (only 1+0, 3+2 and 5+0 exist).
  - Callers: none yet. BOT-004 and OPEN-002 will call `pick`.
  - Gate: 24 passed, 0 failed, exit 0 on 7318aee.
- Proxy decided (opus): run gate-evidence.ps1 via the Bash tool as "powershell -NoProfile -File ..." (allowlisted as Bash(powershell:*); powershell.exe and the PowerShell tool are not), log/receipt in the session scratchpad; if that too is refused, hand off to-review without a receipt (option A), never a hand-made receipt — CORE-001 stages 2 and 3 produced receipts with this exact form.
- 2026-10-24 Stage 2, reopen 1 (opus-5.5) on `bot-003`, fast-forwarded to the session tip d1dcdd1. Review 2's five items, two cycles:
  - Cycle 3 (eea557a red, 348ae38 green): blocking 1 and the zero-mass part of non-blocking 5. Red: at `T = 0.001` `distribution()` came out all zero and `pick()` drew `c` 100 times out of 100; `T = 0`, an all-zero policy and all-zero weights also gave zero mass. Fix: `p^(1/T)` is taken on `p / p_top`, so the top move stays at 1 and nothing underflows to an all-zero distribution; input with no positive mass returns the first move with all of it.
  - Cycle 4 (66229f6, test only): blocking 2 and 3, non-blocking 4. Green on 348ae38, so each test was proven red by a production mutant, each failing only its own test: `pick()` dropping weights and τ (`c` drawn 420 times, `d` never), dropping weights (`d` never drawn), dropping τ (`c` drawn 457 times), `> τ` for `>= τ` (`b` cut from `{a:0.98, b:0.02}`), an extra discarded `randf()` (RNG state differs from a reference advanced once).
  - Non-blocking 5, behaviour now defined and tested: `T = 0` keeps only the top move (the limit of `p^(1/T)`); all-zero policy or weights give the first move all the mass, not the policy's top move, since §6.3 weights are `1 + (B − 1)·f(d) ≥ 1` and cannot be zero. Not guarded: a NaN weight or policy entry still gives NaN mass, and a negative `T` is undefined. Neither can come from Maia's softmax, §6.3 or the settings defaults; UI-005 owns the `T` setting's range.
  - Callers: none outside the tests (`git grep move_picker`). The change creates two degenerate inputs: `p_top = 0`, which only an input with no positive mass reaches and the early return covers, and `1/T = inf` at `T = 0` (tested). Spec §3.3 needs no edit: scaling before renormalising does not change the result.
  - Gate: 29 passed, 0 failed, exit 0 on 66229f6. The stage-3 receipt this line replaces (`c08c5649-…\scratchpad\BOT-003-review-gate.json`, 8cb80e4) is superseded.
- 2026-10-24 Stage 2, reopen 2 (opus-5.5, hard) on `bot-003`, fast-forwarded to the session tip 3489479. Review 3's one blocking item, one cycle:
  - Cycle 5 (a1bac01 red, 77451eb green): `test_a_draw_of_exactly_one_picks_a_move_with_mass` uses Review 3's seed 1 and state -6990051623618564479. It first asserts that a reference RNG at that state draws exactly 1.0, so on a Godot whose `randf()` never reaches 1.0 the test fails instead of passing vacuously. Red: `expected "a", got "c"` (77 passed, 1 failed). Fix: `pick()` skips zero-mass keys in the cumulative loop, so a draw of 1.0, or a sum left short by rounding, falls back to the last move with mass. A draw below 1.0 picks the same move as before, because a zero-mass key could only be returned by falling through. RNG use is unchanged (`test_pick_draws_once_from_the_rng` still passes).
  - Callers: none outside the tests (`git grep move_picker`). The change creates no new degenerate input: `distribution()` always gives the top move mass 1 before renormalising, so a non-empty policy always has a key with mass; the empty policy still returns `""`. NaN stays deferred, as Review 3 recorded: a NaN entry is not `<= 0`, so it is not skipped.
  - Gate: 78 passed, 0 failed, exit 0 on 77451eb. The reopen-1 receipt (`a130588f-…\scratchpad\BOT-003-reopen1-gate.json`, 66229f6) is superseded.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-bot\7fe85063-0203-4a45-8e24-992827b49355\scratchpad\BOT-003-reopen2-gate.json

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents. Standards: no documented-standard breach; one judgement call (the second scan for the top move could share a loop), not worth a change. Spec: all seven criteria met, no scope creep; the only disagreement is criterion 6 against spec §3.4 on "off", fixed below.

Criteria:

1. ✅ `distribution` weights then renormalises, cuts below `τ` keeping the top move (taken after weighting) and renormalises, applies `p^(1/T)` and renormalises; `pick` samples it. Order pinned by `test_weights_are_renormalised_before_the_cut`, `test_top_move_is_taken_after_weighting`, `test_cut_comes_before_temperature` and `test_temperature_is_p_to_the_one_over_t_then_renormalised`.
2. ✅ `test_weighted_book_move_survives_the_cut`: 0.5% × 20 becomes 9.1% after renormalising and survives `τ = 2%`; unweighted it is cut.
3. ✅ `test_only_the_top_move_is_left_when_every_move_is_below_tau`, including 60 moves all under 2%.
4. ✅ `T = 1` leaves the cut distribution unchanged; 10,000 seeded draws at `T = 1` and `T = 2` stay within ±2 pp per move and never draw a cut move.
5. ✅ `DEFAULT_TAU = 0.02`, `DEFAULT_TEMPERATURE = 1.0`, `weights.get(move, 1.0)`; tested at 1.9% (cut) and 2.1% (kept).
6. ✅ `panic` clamps `1 − time_left / (0.1 · start_time)` to [0, 1] and lerps to `PANIC[intensity]`. I checked the test values by hand: 5% on medium gives (1.35, 1.25%), 2.5% on high gives (1.9, 0.65%). 10% and above, 0 s, below 0 s and "off" are tested.
7. ✅ The only randomness is `rng.randf()` on the injected RNG; the seed test reseeds the global RNG between runs and gets the same 50 moves.

Test-first: I checked `diff --stat` on every commit. 7779908 (test + Stage line) and 90e352e are test only; 6322ec2 and 7318aee are `bot/move_picker.gd` only; a7c1972 is the ticket only; 8cb80e4 is my docs fix. Every file is in Primary files, except `docs/spec.md` in the docs fix.

Examined:
- Callers: none yet (`git grep move_picker` finds only the test). BOT-004 and OPEN-002 will call `pick`; OPEN-002's weight keys must be the same move ids as the policy keys (UCI), or the weight is silently ignored as 1.
- Failure paths: empty policy (`""`), all-zero policy (first move, no NaN), clock overrun below 0 (stays at the targets). An unknown intensity string is a script error and `start_time = 0` divides by zero; neither can come from the spec (four intensities, three non-zero time controls), so no finding.
- Cross-feature, a note for later tickets: `panic` moves `T` and `τ` toward the targets, as criterion 6 says, even when the setting is already past them. A `T` setting above `T_max` (or `τ` below `τ_min`) makes the bot steadier near the flag, not wilder. With the defaults (T 1.0, τ 2%, medium) it cannot happen; UI-005 decides whether the settings allow it.
- Not examined: the `>= τ` against `> τ` boundary at exactly `τ` (no criterion names it), and wall-clock cost per move (M3's 50 ms budget belongs to BOT-004).

Fix in review (8cb80e4, docs only, by stage 3): spec §3.4 mapped "off" to `(1, τ)`. It now says off leaves `T` and `τ` unchanged, matching criterion 6 and the code. No behaviour changed, so it needed no independent review.

Rebase: none needed; the ticket branch was cut from the session tip ae9a579. The merge a0218f1 has the same tree as the tested 8cb80e4.

Red-green, from stage 2:
- Cycle 1: red at 7779908 (`Preload file "res://bot/move_picker.gd" does not exist`); green at 6322ec2.
- Cycle 2: red at 90e352e (`Static function "panic()" not found`); green at 7318aee.

Gate: `godot --headless -s tests/run.gd` on 8cb80e4 gave 24 passed, 0 failed, exit 0, with the receipt in the Gate evidence line above. The stage-2 receipt for 7318aee is superseded because the docs fix changed a file after it.

Proxy decided lines: one, (opus), on running `gate-evidence.ps1` through the Bash tool. It is about running the gate, not the contract; both receipts came from the real helper.

Acceptance: pending | M3 ("a full game against Maia; latency under 50 ms") needs BOT-001, BOT-002 and BOT-004; this ticket's own criteria pass 24/24 on 8cb80e4 (receipt above)

Disclosure: decision | none | spec §3.4 "off" now reads as criterion 6 (8cb80e4); the old text differed only when the `T` setting is not 1
Disclosure: decision | none | Proxy decided (opus) on how to run the gate helper; process only, no contract change

#### Review 2 (2026-10-24), independent: gpt-6.1-sol xhigh via codex exec on PR #2 head 263983d

Verdict: Reopen — criteria 1 and 2 (temperature underflow at small T; a pick() that ignores weights and τ, and the τ boundary, go undetected)

Requested by Bruno; he approved the reopen. Gate 24/24 green on 263983d. The docs/spec.md:63 edit (8cb80e4) was judged justified and stays.

Criteria:

1. ❌ The temperature step underflows. With policy `{a:0.4, b:0.35, c:0.25}` and `T = 0.001`, every `p^(1/T)` becomes 0, so `pick()` always returns `c`, though the distribution should overwhelmingly favour `a` (bot/move_picker.gd:31). No documented minimum T excludes this. The cut's "below τ" boundary is also unpinned: for `{a:0.98, b:0.02}`, `b` must survive the default `τ = 0.02`, but changing `>=` to `>` still passes every test (tests/test_move_picker.gd:75).
2. ❌ Pinned through `distribution()` only. Every sampling test uses empty book weights and the default τ (tests/test_move_picker.gd:63). A mutant where `pick()` ignores its weights and τ arguments passes all 16 picker tests, so a 0.5% book move weighted ×20 could stay unsampleable unnoticed.
3. ✅ 4. ✅ 5. ✅ 6. ✅ 7. ✅ (see finding 4)

Left for stage 2, in this order:

- BLOCKING 1: make the temperature step numerically stable (for example, log space, or dividing by the max before exponentiating). Add a regression test with the T = 0.001 case above.
- BLOCKING 2: pin criteria 1 and 2 through `pick()`: sampling tests with non-empty book weights and a non-default τ.
- BLOCKING 3: pin the τ boundary. `{a:0.98, b:0.02}` keeps `b` at the default τ.
- NON-BLOCKING 4 (fix if cheap), tests/test_move_picker.gd:85: seed reproducibility and frequencies don't prove exactly one random draw; an extra discarded `randf()` passes every test. Assert the RNG state against a reference generator advanced exactly once.
- NON-BLOCKING 5 (fix if cheap), bot/move_picker.gd:65: all-zero weights give zero-mass output, a NaN weight propagates NaN, and `T = 0` gives zero mass. None has a defined validation, fallback or test. The documented book weights exclude zero and NaN, so either define the behaviour or guard it.

#### Resolution (2026-10-24), re-review after reopen 1

Verdict: Approve

Stage 3 (opus-5.5), re-review of Review 2's items and the diff 263983d..7bfb5b0. The Standards and Spec axes ran as separate sub-agents; neither found anything. No fix in review.

Review 2's items:

1. ✅ BLOCKING 1. `p^(1/T)` is taken on `p / p_top` (bot/move_picker.gd:33–35), so the top move stays at 1 and no `T` can zero the whole distribution; scaling before renormalising leaves every other `T` unchanged. `top` is still the maximum of `kept`, which holds it and is renormalised by a positive total. `test_small_temperature_does_not_underflow` has Review 2's `{a:0.4, b:0.35, c:0.25}` at `T = 0.001`: distribution `{a:1}` and 100 of 100 draws `a`.
2. ✅ BLOCKING 2. `test_pick_samples_after_the_book_weight_and_the_cut` samples 10,000 times through `pick()` with `d ×20` and `τ = 6%`: `d` (0.5% raw) is drawn, `c` (4.1% after weighting) never.
3. ✅ BLOCKING 3. `test_a_move_at_exactly_tau_is_kept`: `{a:0.98, b:0.02}` keeps `b` at the default `τ`.
4. ✅ NON-BLOCKING 4. `test_pick_draws_once_from_the_rng` compares the RNG state with a reference advanced once.
5. ✅ NON-BLOCKING 5. `T = 0` keeps only the top move; an all-zero policy or all-zero weights give the first move all the mass (early return, bot/move_picker.gd:25–26). Both tested. NaN and negative `T` stay unguarded, as stage 2 wrote: Review 2 itself notes the book weights exclude NaN, and UI-005 criterion 5 makes an out-of-range setting fall back to its default. No finding.

Criteria 1–7: ✅, as in the first Resolution and Review 2; nothing in the diff weakens them.

Red-green, checked by me in a scratch worktree, not only read from stage 2:
- Cycle 3: eea557a (tests, old code) gives 23 passed, 3 failed: `test_small_temperature_does_not_underflow` (`a` got 0.0, drew `c` every time), `test_zero_temperature_keeps_only_the_top_move`, `test_degenerate_policies`. Green at 348ae38.
- Cycle 4 (test only, green on arrival), against mutants of 66229f6: `>= τ` → `> τ` fails only `test_a_move_at_exactly_tau_is_kept` (28/1); `pick()` passing `{}` and `DEFAULT_TAU` fails only `test_pick_samples_after_the_book_weight_and_the_cut` (`c` drawn 420 times, `d` never; 28/1). The extra-`randf()` mutant I took from stage 2's record.

Test-first: `diff --stat` on every commit since the reopen. eea557a is the test plus the ticket, 348ae38 is `bot/move_picker.gd` only, 66229f6 is the test only, 7bfb5b0 is the ticket only. Every code file is in Primary files.

Examined:
- Callers: none outside the tests (`git grep move_picker`). BOT-004 will call `pick` with the defaults.
- Failure paths the change creates: `p_top = 0` (only input with no positive mass, early return), `1 / T = inf` at `T = 0` (`pow(1, inf) = 1`, `pow(x < 1, inf) = 0`), a tie for the top (both ratios 1, tie kept). All fine.
- Spec §3.3 still describes the result exactly; no doc went stale.
- Not examined: wall-clock cost per move (BOT-004's 50 ms budget).

Rebase: none needed; `bot-003` descends from the session tip d1dcdd1. The merge 589eb2a has the same `bot/` and `tests/` tree as the tested 66229f6.

Gate: `godot --headless -s tests/run.gd` on 66229f6 gave 29 passed, 0 failed, exit 0. Receipt in the Gate evidence line above; I checked its log hash and counts. Reused: no production changed after it.

Proxy decided lines: one, (opus), on running `gate-evidence.ps1` through the Bash tool. Process only; this round's receipt came from the real helper.

Acceptance: pending | M3 ("a full game against Maia; latency under 50 ms") needs BOT-001, BOT-002 and BOT-004; this ticket's own criteria pass 29/29 on 66229f6 (receipt above)

Disclosure: decision | none | spec §3.4 "off" now reads as criterion 6 (8cb80e4); the old text differed only when the `T` setting is not 1
Disclosure: decision | none | Proxy decided (opus) on how to run the gate helper; process only, no contract change

#### Review 3 (2026-10-24), independent: gpt-6.1-sol xhigh via codex exec on PR #2 head 2337b40

Verdict: Reopen — criterion 1 (pick() can return a zero-probability move when randf() returns exactly 1.0)

Requested by Bruno; he approved the reopen. Findings 1–4 of Review 2 were confirmed fixed and pinned by mutants. Finding 5 is partly fixed: the NaN case is non-blocking and stays deferred.

Criteria:

1. ❌ The sample can land on a move with zero mass. Godot 4.7's `randf()` range includes 1.0. With policy `{a:0.4, b:0.35, c:0.25}` and `T = 0.000001`, the distribution is `{a:1, b:0, c:0}`. After `rng.seed = 1` and `rng.state = -6990051623618564479`, the next `randf()` is exactly 1.0 (the foreman reproduced this on Godot 4.7.2). In `pick()` (bot/move_picker.gd:48–50), `r -= dist[m]` never goes below 0, the loop never breaks, and it returns the last key, `"c"`, instead of `"a"`. The same fall-through happens whenever float rounding leaves the cumulative sum just under `r`.
2. ✅ 3. ✅ 4. ✅ 5. ✅ 6. ✅ 7. ✅

Left for stage 2:

- BLOCKING: fix the endpoint handling so `pick()` never returns a key with zero probability. For example, fall back to the last key with positive probability, or compare correctly at the boundary. Pin it with a deterministic regression test that uses the seed and state above.

Reopen diagnosis: earlier review miss of an implementation defect. The fall-through has been in `pick()` since 6322ec2 (stage 2, round 1). Neither Opus stage 3 nor the first independent review caught it. It is not a contract gap: criterion 1 already says "sample one move" from the final distribution. It is not review churn either: the Review-2 rework changed only the temperature step, which turns this endpoint case into a zero-mass move. The second independent review (head 2337b40) is the consolidated review of the affected paths; it read the whole picker and raised only this finding. Next action: stage 2 on the hard model fixes the sampling endpoint and adds the seeded regression test; the NaN deferral stays as recorded.
