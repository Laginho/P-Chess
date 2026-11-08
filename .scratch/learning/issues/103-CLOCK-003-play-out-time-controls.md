# CLOCK-003: Play-out time controls: 5+5 and no clock
Stage: to-review
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

- 2026-11-07 Stage 2: `5+5` and `none` are accepted by the clock through `PLAY_OUT_CONTROLS`; `CONTROLS` remains the three sandbox controls so the existing test and Custom game stay unchanged. The untimed clock returns zero as its stable start value, including after premoves.
- Criterion 1 ✅ Independent criteria check: `core/clock.gd:13,31` supplies 300000 ms and a 5000 ms increment; `tests/test_clock.gd:76` checks both sides. The test failed on the unknown control before implementation.
- Criterion 2 ✅ Independent criteria check: `core/clock.gd:33,52` and `ui/clock.gd:28` prevent time changes, signals and display; `tests/test_clock.gd:88` covers long elapsed time, premove, signals and display. Both tests failed before implementation.
- Criterion 3 ✅ Independent criteria recheck: `core/clock.gd:12`, `ui/setup.gd:43` and `ui/home.tscn:63` retain the three controls; `tests/test_clock.gd:29` checks both visible lists exactly. Temporarily adding an extra control to each list made the test fail for both.
- Criterion 4 ✅ Independent criteria check: existing clock tests remain unchanged; the full gate passed 574 tests with 0 failures. The headless run skipped the graphical pixel check and six live Lc0 checks because the engine was unavailable.

Gate evidence: /run/media/lage/New Volume/Scratch/clock-003-gate.json
