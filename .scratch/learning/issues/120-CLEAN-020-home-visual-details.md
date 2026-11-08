# CLEAN-020: Align Home's remaining visual details with the learning canvas
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - ui/home.gd, ui/home.tscn (Continue, Course and Play presentation)
  - tests/test_home.gd (existing Home screen/layout seam)
  - ui/icons/home-bullet.svg, ui/icons/home-blitz.svg, ui/icons/home-course.svg, ui/icons/home-chevron.svg (canvas decorations)

#### What to build

Triage the remaining presentation differences between the new Home and `docs/design/learning/Main.dc.html`: Play icons sit above their labels with green Bullet and yellow Blitz accents; Continue has a chevron; Course has an icon and unit/status summary. Preserve the existing Continue destinations, preferences and navigation. If implementing this requires additional asset or renderer files, list their concrete paths during triage before implementation.

#### Acceptance criteria

1. At 1280×800 the Play controls use the canvas's vertical icon/label arrangement and accent colors, retaining the four-button row and readable labels at 800×600.
2. Continue displays its chevron without obscuring the unit title, activity detail or progress bar in any target state.
3. Course shows its icon and a summary derived from the available stage units and their statuses: unit count and counts for each present status (new, in progress, mastered, needs review). With no available units it says "0 units". It still opens the rating dialog or course map as appropriate.
4. Existing Continue, quick-play, level-picker, Custom and navigation behavior remains unchanged, and missing-engine guidance stays above navigation at 800×600.

#### Verification

    Capture Home at 1280×800 and 800×600 with isolated data, normal and missing-engine states.
    Compare against docs/design/learning/png/Main.png and exercise the existing controls.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- At the existing `tests/test_home.gd` seam, assert the Course summary comes from fixture data/progress, the Play layout meets the accepted arrangement and added decoration does not obscure labels or intercept clicks. Reuse existing destination and engine-warning assertions. Asset color checks are by capture comparison; do not mirror drawing code in tests.

## Comments

- 2026-11-08 Opened during the [LEARN-009 stage-3 review](113-LEARN-009-home-and-continue.md) after comparing the [current Home capture](</run/media/lage/New Volume/Scratch/LEARN-009-review-capture-QwHiXE/Main.png>) with the learning canvas. These presentation details are absent from LEARN-009's numbered criteria; that implementation is approved. This is a needs-triage follow-up, with no integration condition or accepted release waiver. No Escaped-from line applies.

- Triage by the driver: ready for agent — the canvas specifies the arrangement and artwork; Home can use four dedicated SVGs without changing shared icons. Aggregate status counts describe multiple units without inventing a single course status.
