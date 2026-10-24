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
