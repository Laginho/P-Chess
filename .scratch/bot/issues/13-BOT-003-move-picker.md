# BOT-003: Move picker and time-pressure panic
Stage: to-implement
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

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-bot\c08c5649-0123-4dfd-9261-b61f041df001\scratchpad\BOT-003-review-gate.json

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
