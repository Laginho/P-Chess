# BOT-003: Move picker and time-pressure panic
Stage: reviewing
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

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-bot\17e253f5-0c0c-424b-a299-1e203e1f2fb6\scratchpad\BOT-003-gate.json
