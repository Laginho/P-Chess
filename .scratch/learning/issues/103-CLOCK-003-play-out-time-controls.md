# CLOCK-003: Play-out time controls: 5+5 and no clock
Stage: done
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

#### Resolution (2026-11-07)
Verdict: Approve

- Standards: independent read-only review (`clock_standards`) found 0 documented-standard violations and 0 actionable baseline smells. Production changes stay within Primary files; tests and production are in separate commits. All pre-existing clock tests and assertions remain unchanged.
- Spec: independent read-only review (`clock_spec`) found 0 missing requirements, scope changes or regressions. All four numbered criteria pass:
  1. ✅ `core/clock.gd:13,34-38` initializes both sides at 300000 ms with a 5000 ms increment. The existing `moved()` implementation applies it with the same first-move rule as `3+2`; `tests/test_clock.gd:76-85` checks both initial times and both increments.
  2. ✅ `core/clock.gd:52-53` leaves an untimed clock stopped, so `left()` stays at its initial zero and `tick()` cannot emit `low_time` or `flagged`. `ui/clock.gd:28` displays blank text. `tests/test_clock.gd:88-115` covers a day of elapsed time, ordinary moves, a premove, stopping, both signals and the display.
  3. ✅ `Clock.CONTROLS` still contains exactly `1+0`, `3+2`, `5+0`; `PLAY_OUT_CONTROLS` holds the new choices separately. Setup's enumeration and Home's quick-play buttons remain unchanged; `tests/test_clock.gd:29-45` checks both visible lists.
  4. ✅ Existing clock tests are byte-for-byte unchanged and pass in the full gate.
- Examined the complete diff, commit contents, clock construction and all callers of its changed behavior: first-move/increment/flag/premove paths, `left()`/`tick()`/`stop()`, clock rendering, Setup/Home, `ui/main.gd` input and Maia callbacks, Maia's time-model lookup, PGN serialization and Review's control matching/move-time calculation. Unknown controls retain their previous failure behavior. Existing game, Maia, PGN and Review paths still use sandbox controls and receive the same values as before. No course screen, end-to-end play-out, graphical appearance, exported build or live Lc0 behavior was exercised.
- Files: `core/clock.gd`, `ui/clock.gd`, `tests/test_clock.gd`; the additional LEARN-007 change is an integration note. Review authored no production behavior and changes only this tracker record and the ledger.
- Red-green proof: test-only `8c4fd99` precedes production-only `5c19d0c`; the retained red log reports the unknown `5+5` control and failed initial/increment assertions. Test-only `dd0e990` precedes production-only `ab2857c`; its retained red log reports the unknown `none` control, unwanted signals and failed display assertion. Test-only `e50270a` checks the preserved sandbox lists; its mutation log shows both visible lists failing when an extra control is introduced. The final gate passes all these checks.
- Gate: reused the run on committed code `e50270a`: `godot --headless -s tests/run.gd`, exit 0, 574 passed, 0 failed. Seven checks printed skips: one graphical pixel check and six requiring Lc0. `Assert-GateEvidence` validated the receipt, log hash, recorded exit status and unchanged code, including after integration. Rebase was already current; merge `a58747d` had no conflicts and its tree exactly matches the reviewed ticket branch.

Acceptance: pending | Clock behavior and blank display pass at the approved automated seams. End-to-end course play-outs remain with LEARN-007; the graphical and live-engine checks above were not performed.
Disclosure: pending | release | [LEARN-007](111-LEARN-007-play-outs.md), CLOCK-003 integration note: adapt the existing main/Maia paths that index sandbox-only `Clock.CONTROLS` before exposing course games with `5+5` or `none`, and verify both choices in a real play-out. An untimed clock's stable `left()` value is zero. This does not block integrating CLOCK-003's clock capability into the session.
