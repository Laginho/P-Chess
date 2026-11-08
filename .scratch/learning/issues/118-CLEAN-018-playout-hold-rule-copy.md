# CLEAN-018: Keep the play-out hold rule text in sync with its tunable
Stage: to-implement
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/playout.gd (the hold pass-rule text)
  - tests/test_course_screens.gd (the play-out start-screen seam)

#### What to build

The start screen currently advertises a literal "30 moves", while the judge uses `Tunables.COURSE_HOLD_MOVES`. They agree today. Derive the advertised hold limit from that same setting so a future tuning change keeps the rule the player sees accurate.

#### Acceptance criteria

1. The hold play-out start screen displays the configured `Tunables.COURSE_HOLD_MOVES` limit instead of a separate literal; changing the tunable for verification changes that visible number.
2. With the shipped limit of 30, the displayed pass/fail rules and play-out behavior remain the same.

#### Verification

    Focused start-screen test, including a temporary nondefault-limit mutation check.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course_screens.gd`: at the existing play-out start-screen boundary, check the advertised hold limit against the configured rule; prove sensitivity by temporarily changing the tunable during verification. Before the production correction, the hardcoded copy stays at 30. Restore the shipped value after verification.

## Comments

- 2026-11-08 Opened by the LEARN-007 stage-3 Standards review, [original ticket](111-LEARN-007-play-outs.md). Nonblocking cleanup: the current value and numbered LEARN-007 contract both require 30, so there is no current implementation failure or release condition. No `Escaped-from` line: this is a maintainability suggestion, not a defect shipped by a previously closed ticket.
