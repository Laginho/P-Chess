# UI-039: Reach Review's "Practise in Rook endgames" link with the keyboard
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/review.gd (the from-your-game marker row and its activation)
  - tests/test_review.gd (the existing Review seam)

#### What to build

REV-011's marker row in Review's move list is unselectable in every column (`ui/review.gd:1446`) and opens the unit only on a left mouse click (`ui/review.gd:348`). Keyboard users can walk the moves but never reach "Practise in Rook endgames". Found by the PR #44 integration review (gpt-6.1-sol xhigh, P2).

#### Acceptance criteria

1. The practice link is reachable by keyboard (Tab or the move list's arrow keys), has an accessible name, and Enter or Space opens the unit with the position as "From your game".
2. Selecting a chess move with the keyboard or mouse is unchanged; the marker never becomes a move.
3. The mouse click keeps working.

#### Verification

    Focused Review tests with input events.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_review.gd`: with a reviewed game that produces the marker, send keyboard input events to reach and activate the link; check `unit_requested` and that move selection is unchanged.

## Comments

- 2026-11-08 Opened by the PR #44 review loop (foreman) as the refutation of review finding 4: REV-011's criteria name no keyboard access; the gap is real and is new work.

- Triage by the driver: ready-for-agent — the marker opens only by mouse, leaving keyboard users unable to reach the saved position.
- Criteria check (independent agent): ✅ 1 — `ui/review.gd:1005`, `ui/review.gd:1451`; routed keyboard test `tests/test_review.gd:2395` was red before the fix and checks the saved position. The Tree cell text supplies its accessible name.
- Criteria check (independent agent): ✅ 2 — `ui/review.gd:353` ignores the marker's empty metadata; `tests/test_review.gd:2430` checks that it does not change the position and that Up selects the move. A metadata mutant failed this check; `tests/test_review.gd:824` also covers a real move click.
- Criteria check (independent agent): ✅ 3 — `ui/review.gd:348` retains the mouse handler; `tests/test_review.gd:2444` sends a viewport click, which failed when the handler was disabled.
- Resolution: focused Review suite 83 passed; the final keyboard and mouse test also passed after the test was strengthened. Gate: 684 passed, 0 failed, exit 0. Graphical pixel checks and Linux tablebase checks were skipped by the headless Windows gate; screen-reader acceptance was not run.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui039-gate.json

#### Resolution (2026-11-08)
Verdict: Approve

- Standards: 0 findings. Independent Standards review covered the complete three-file diff `3cd1b02...54322a2`, repository conventions and connected code. Commits preserve test/production separation: `770faf8` tests and tracker, `dfb1385` production, `5694217` tests, `54322a2` tracker. All code changes stay within Primary files.
- Spec: 0 findings. Independent Spec review confirmed all three numbered criteria. Review authored no production or test changes in the repository.
- Examined callers, failure paths and interactions: marker creation and stale-probe guard, every `_marker_rows` use, Tree selection metadata, `_show_ply`, keyboard shortcuts and the Settings guard, mouse routing, variation cleanup, `main`'s unit-request handler, and course storage of From your game positions. Routed checks covered both move columns, two markers and all three activation keys. Native input, rendered focus and screen-reader announcements were not examined; the probe used scripted tablebase answers.
- Criterion 1 ✅ `ui/review.gd:1451` leaves the named cell selectable; `ui/review.gd:1005` activates the focused marker with Enter, keypad Enter or Space. `ui/main.gd:292` opens the unit and `core/course.gd:181` stores the position with `from_your_game = true`. The committed input test and the external review probe passed. Down retains the current Tree column: from a black move, Left then Down reaches the marker. A first probe incorrectly required direct Down access from every column; that stronger assumption is outside the criterion. The permitted arrow-key route passed all 12 activation combinations across two markers and both starting columns.
- Criterion 2 ✅ `ui/review.gd:353` ignores the marker's empty metadata, preserving the shown position. The new test checks this and Up returning to a real move; the existing move-click test also passed. The additional probe verified preserved ply while selecting each marker.
- Criterion 3 ✅ `ui/review.gd:348` retains mouse activation. The committed keyboard test also sends an actual viewport click and passed in the focused suite.
- Red/green proof: independently loaded the base's unmodified Review script into a separate Godot process and ran the final committed test. It failed at Down reaching the marker and keyboard activation, as expected ([red log](<C:/Users/bruno/AppData/Local/Temp/ui039-stage3-red.log>), exit 1). With current code, all 83 Review tests passed ([focused log](<C:/Users/bruno/AppData/Local/Temp/ui039-stage3-review.log>), exit 0), and the additional routed probe passed ([probe log](<C:/Users/bruno/AppData/Local/Temp/ui039-stage3-probe-routed.log>), exit 0). All review runners and logs live outside the repository.
- Gate: reused the green receipt for tested commit `5694217a707b9a7fc27c3fcc75c31f925689685e`: `godot --headless -s tests/run.gd`, 684 passed, 0 failed, exit 0. Verified command, successful exit, log hash and identical code with `Assert-GateEvidence` before rebase, after rebase and on merge `dcd34ea`. The gate was not rerun. Two graphical pixel checks and three Linux tablebase/native-helper checks were skipped in that run. `git diff --check` passed.
- Integration: rebase onto `sweatshop/learning/2026-11-08-1410` required no changes; merged with `--no-ff` as `dcd34ea`. No conflicts, push or PR.

Acceptance: pending | Automated keyboard, mouse, move-selection and saved-position checks passed in the [focused suite](<C:/Users/bruno/AppData/Local/Temp/ui039-stage3-review.log>) and [additional probe](<C:/Users/bruno/AppData/Local/Temp/ui039-stage3-probe-routed.log>). Native UI and screen-reader confirmation, plus [feature acceptance scenario 5](../spec.md#acceptance-scenarios) with a real saved game, remain pending.
Disclosure: pending | release | [Feature acceptance](../spec.md#acceptance-scenarios) retains the real-game marker check; Bruno's rendered focus and screen-reader checks remain unverified. Session integration does not complete those checks.
