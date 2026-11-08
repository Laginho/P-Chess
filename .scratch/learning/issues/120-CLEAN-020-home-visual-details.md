# CLEAN-020: Align Home's remaining visual details with the learning canvas
Stage: done
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

- 2026-11-08 Bruno approved this `Review: human` review in the foreman chat (PR #44): "parece bom"; he may come back with comments. The hand checks under Acceptance stay pending.
- 2026-11-08 Opened during the [LEARN-009 stage-3 review](113-LEARN-009-home-and-continue.md) after comparing the [current Home capture](</run/media/lage/New Volume/Scratch/LEARN-009-review-capture-QwHiXE/Main.png>) with the learning canvas. These presentation details are absent from LEARN-009's numbered criteria; that implementation is approved. This is a needs-triage follow-up, with no integration condition or accepted release waiver. No Escaped-from line applies.

- Triage by the driver: ready for agent — the canvas specifies the arrangement and artwork; Home can use four dedicated SVGs without changing shared icons. Aggregate status counts describe multiple units without inventing a single course status.

## Resolution

- Home now stacks the canvas-colored Play icons and labels, shows a chevron in Continue, and summarizes the actual stage units and statuses in Course. Long review details and mixed status summaries fit at the minimum window size.
- `godot --headless -s tests/run.gd`: 677 passed, 0 failed at `fc42110`. Two pixel tests require a graphical display and six live engine tests skip without the Windows Lc0 executable.
- Compared isolated captures with `docs/design/learning/png/Main.png`: [1280×800 normal](</run/media/lage/New Volume/Scratch/CLEAN-020-captures/gate-normal-1280/Main.png>), [800×600 normal](</run/media/lage/New Volume/Scratch/CLEAN-020-captures/gate-normal-800/Main.png>), [1280×800 missing engine](</run/media/lage/New Volume/Scratch/CLEAN-020-captures/gate-missing-1280/Main.png>), and [800×600 missing engine](</run/media/lage/New Volume/Scratch/CLEAN-020-captures/gate-missing-800/Main.png>). Automated Home tests exercise destinations and preferences via signals; physical clicks and human visual acceptance remain for review.

Gate evidence: /run/media/lage/New Volume/Scratch/clean020-gate.json

## Stage 2 criteria check

- ✅ 1: `ui/home.gd:17`, `ui/home.gd:91`, and `ui/home.tscn:137` arrange the four buttons; `tests/test_home.gd:583` fails without the stacked artwork and captions, and `tests/test_home.gd:466` checks the row. The captures check the canvas colors.
- ✅ 2: `ui/home.gd:63`, `ui/home.gd:69`, and `ui/home.gd:247` reserve space, fit the detail and keep the progress bar inside the compact card; `tests/test_home.gd:583` and `tests/test_home.gd:620` fail without the chevron, bounds or long-detail fitting.
- ✅ 3: `ui/home.gd:74`, `ui/home.gd:171`, and `ui/home.tscn:99` show the icon and actual status counts; `tests/test_home.gd:561` and `tests/test_home.gd:620` cover empty, changing and mixed progress, and `tests/test_home.gd:481` checks Course navigation.
- ✅ 4: `ui/home.gd:129`, `ui/home.gd:151`, and `ui/home.gd:160` retain the existing actions and warning placement; existing tests at `tests/test_home.gd:7`, `tests/test_home.gd:102`, `tests/test_home.gd:186`, `tests/test_home.gd:262`, and `tests/test_home.gd:359` exercise destinations, preferences and the warning.

Independent criteria review identified clipped long review text and mixed statuses; test-only commits `0206cfd` and `5d1117b` recorded red cases, and production commits `13cc146` and `fc42110` fixed them. The reviewer rechecked the long-content fixes, including a full missing-engine message at 800×600. The additional compact progress-bar bounds test then found and verified the final correction. The normal warning-visibility transition also restores the Play artwork opacity.

#### Resolution (2026-11-08)
Verdict: Approve

Standards: 0 documented-standard violations; 1 optional duplication heuristic. Independent reviewer `/root/review_standards` checked the complete diff, Primary-file scope, domain vocabulary and all nine commits. The four cycles separate tests from production. The reviewer noted that `_fit_continue_detail` repeats the short font-fitting loop in `_fit_continue_title`. The integrating reviewer accepts the separate helpers: they express distinct title/detail size limits, and extracting this small idiom has no demonstrated maintenance benefit. This is not a confirmed defect or outstanding cleanup requirement.

Spec: 0 findings. Independent reviewer `/root/review_spec` and the integrating reviewer confirmed all four numbered criteria, with no scope creep:

- 1 ✅ `ui/home.gd:19` and `ui/home.gd:109` place the separate artwork above captions; dedicated Bullet/Blitz SVGs match the canvas's green/yellow. The existing row tests and new decoration test cover supported dimensions. Fresh rendered captures confirm four readable controls at 1280×800 and 800×600.
- 2 ✅ `ui/home.gd:65` reserves the chevron's space; title/detail fitting preserves long review text, and compact progress remains inside Continue. New bounds/long-content assertions and rendered review/solving states confirm separation. Mouse events over the chevron, title, detail and progress each reach Continue.
- 3 ✅ `ui/home.gd:174` derives the unit count and every present status count from the stage's actual units/progress, including `0 units`. `test_course_summary_tracks_available_units_and_progress` and `test_long_review_and_mixed_course_summary_remain_readable` check zero/new/in-progress and all four statuses. Fresh mixed-status captures verify wrapping after frame layout. Existing Home tests retain rating-dialog/course-map routing.
- 4 ✅ Existing action wiring and preferences remain unchanged. The green gate exercises all Continue targets, quick-play settings, Maia level, Custom and navigation. Added decorations ignore mouse events; 34 graphical mouse-event clicks passed across both dimensions. Full missing-engine guidance fits above navigation, including the mixed-status state at 800×600.

Examined callers, failure paths and cross-feature interactions: `_ready`, configuration, resize/warning visibility, `refresh_continue` after Profile/stage changes and returning Home, all Continue target kinds, course status derivation, main-screen Course/Continue routing, quick-play settings and missing-engine disabling. Engine startup, persistence failure handling and native Windows pointer behavior were inspected through unchanged callers or existing tests, not exercised against live engines during review. GUI mouse events were dispatched through Godot's viewport, not an OS-level pointer driver.

Files: `ui/home.gd`, `ui/home.tscn`, the four dedicated Home SVGs and `tests/test_home.gd`; no production or test repair was needed in stage 3. No proxy decision or contract change was introduced.

Red/green proof: reviewed the four test/production pairs (`571001c`/`5957784`, `3ac3250`/`27d3707`, `0206cfd`/`13cc146`, `5d1117b`/`fc42110`) and the decoration, long-content and progress red logs. The original summary log ends before the Home tests, so review independently reran the current summary test against the immutable session-base Home scene/script: it exits 1 with `Course displays a summary`, the intended missing-control failure ([red log](</run/media/lage/New Volume/Scratch/CLEAN-020-review/summary-red.log>)). The final green gate includes all three added Home tests.

Gate: reused the committed-code receipt for `fc421106289fedfd3b221e49df641e1e60133262`: `godot --headless -s tests/run.gd`, 677 passed, 0 failed, exit 0. `Assert-GateEvidence` verified the command, tested commit, log SHA-256, exit marker and unchanged code, including after the no-op rebase. Two headless pixel checks and six live Lc0 checks skip under the existing environment limitations. [Gate log](</run/media/lage/New Volume/Scratch/clean020-gate.log>); [receipt](</run/media/lage/New Volume/Scratch/clean020-gate.json>). `git diff --check` passed.

Graphical review: generated and inspected isolated captures under Xvfb with windows at `3000,3000`, comparing the new details against `docs/design/learning/png/Main.png`: [1280×800 normal](</run/media/lage/New Volume/Scratch/CLEAN-020-review/normal-1280.png>), [800×600 normal](</run/media/lage/New Volume/Scratch/CLEAN-020-review/normal-800.png>), [1280×800 missing engine](</run/media/lage/New Volume/Scratch/CLEAN-020-review/missing-1280.png>), [800×600 missing engine](</run/media/lage/New Volume/Scratch/CLEAN-020-review/missing-800.png>), and mixed statuses [normal](</run/media/lage/New Volume/Scratch/CLEAN-020-review/mixed-normal-800.png>)/[missing engine](</run/media/lage/New Volume/Scratch/CLEAN-020-review/mixed-missing-800.png>). The external harness confirms 34 mouse-event clicks and 0 failures, complete warning text and post-frame summary/detail bounds ([script](</run/media/lage/New Volume/Scratch/CLEAN-020-review/verify.gd>), [log](</run/media/lage/New Volume/Scratch/CLEAN-020-review/verify.log>)). An initial harness-only failure came from configuring a zero-sized detached Home before assigning its window dimensions; assigning the supported dimensions before `_ready`, as the main scene does, corrected the harness without source changes.

Integration: rebase onto `sweatshop/learning/2026-11-07-2234` changed no code or commits; merge `0ddc711` integrates the ticket without squash. This closure commits `Stage: done` and the ledger entry together on the session branch. `Review: human` remains for the driver's session PR.

Acceptance: pending | Automated scenarios, graphical mouse-event routing and the six rendered capture comparisons passed. Bruno's final visual acceptance and native pointer checks remain for human review.
Disclosure: pending | none | Human acceptance remains in the session PR; this ticket introduces no integration condition. The broader manual release checks remain recorded in [LEARN-009](113-LEARN-009-home-and-continue.md).
