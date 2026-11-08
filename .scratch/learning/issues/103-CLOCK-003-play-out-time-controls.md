# CLOCK-003: Play-out time controls: 5+5 and no clock
Stage: to-implement
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/clock.gd (`CONTROLS`, `_init`, `left`, `tick`)
  - ui/clock.gd (showing a game with no clock)
  - ui/setup.gd (only to keep its control list to the sandbox's three)
  - tests/test_clock.gd

#### What to build

Play-outs run at 5+5 or with no clock, chosen on the unit page (spec §L8). The clock gains both, while the sandbox and Custom game keep offering only 1+0, 3+2 and 5+0.

#### Acceptance criteria

1. A `5+5` clock starts at 5:00 per side and adds 5 s after each move, the same way `3+2` adds its increment.
2. A no-clock control never flags and never emits `low_time`; `left()` stays at its start value, and the clock display shows no time for it (blank or a dash, never 0:00).
3. Custom game and quick play still offer exactly 1+0, 3+2 and 5+0 (Review's header matching may also recognise the new controls).
4. Existing clock tests pass unchanged.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_clock.gd`: a `5+5` clock adds 5 s per move; a no-clock control never flags after a long fake time (red: unknown controls).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L8.
