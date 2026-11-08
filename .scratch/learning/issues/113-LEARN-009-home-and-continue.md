# LEARN-009: The new Home and Continue, with review checks
Stage: done
Blocked by: LEARN-008
Review: human
Difficulty: normal

- Primary files:
  - ui/home.gd, ui/home.tscn (`configure`, `_layout_home`: Continue card, Course button, Play row with Custom)
  - ui/main.gd (wiring Continue to each target)
  - core/course.gd (the Continue target and review checks, spec §L9)
  - ui/solving.gd (a review-check mode: 3 positions, one commit each)
  - tests/test_home.gd (including test-only updates to the layout assertions this redesign replaces: `test_home_shows_quick_play_and_navigation_icons`, `test_quick_play_tiles_are_landscape_with_centred_labels`, `test_home_restores_quick_play_size_when_engine_warning_is_hidden`, `test_missing_engine_message_does_not_overlap_navigation_at_minimum_window`)
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - docs/spec.md (§15.8, Home)
  - scripts/screens.gd (`Main` board refresh)

#### What to build

Home as designed in `Main.dc.html` (spec §L9, §L11): a large Continue card first, naming the target ("Continue: Rook endgames, solving 4/12"); the Course button; the Play row (1+0, 3+2, 5+0, Custom) with the Maia level picker; History, Profile, Settings and Quit. Home's board shows the position Continue will open. Continue's order comes from the course module, including the review checks 7 and 30 days after mastery.

#### Acceptance criteria

1. With no rating saved, the Continue card says "Start the course" and opens the rating dialog.
2. The course module's Continue target, in order: a due review check; else the first from-your-game position not yet solved; else the current unit's first unfinished part; else the next unit's first part; else "done".
3. A review check is due 7 days after the mastered date and again 30 days after it; it draws 3 positions from the unit's practice and test pools.
4. A review check is solved on the solving board with one commit per position; any miss marks the unit "needs review" and keeps the mastered date; a fully passed check marks that check done and clears "needs review".
5. The card shows the target's eyebrow (Continue, Review check, From your game, or Unit done), the unit title and a detail line ("Solving · 4/12", "3 positions · mastered 7 days ago", "1 new position from your games"); for "done" it says "Unit done, go play some slow games" and points to Custom game and the Play row.
6. Clicking the card opens the target screen directly (the solving board, the theory pointer, the play-out start, the test start, or the review check).
7. Home's board shows the target's position (the next position, the first play-out's, or the start position when done).
8. Quick play, the level picker, Custom, History, Profile, Settings and Quit behave as before; the missing-engine message still disables quick play and doesn't overlap the buttons at 800×600.
9. `docs/spec.md` §15.8 describes the new Home.

#### Verification

    Manual: compare Home at 1280×800 with docs/design/learning/png/Main.png; click Continue in each state.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: the Continue order across fixture progress, with the time passed in: review check at day 7 and day 30, own-game position before the next part, "done" at the end; a missed check gives needs review and keeps mastery (red: no target function).
- `tests/test_home.gd`: the card shows the target from a fixture progress file and opens it; quick play unchanged; the replaced layout assertions rewritten for the new layout (red: no card).

## Resolution

- Continue selects due reviews, positions from games, unfinished parts and subsequent units; review misses survive leaving the board and passing a check clears the review status.
- Home shows the target and its board, opens the selected activity, and retains the Play row and navigation. The 1280×800 capture was compared with `docs/design/learning/png/Main.png`; automated screen tests exercise the card's destinations.
- `godot --headless -s tests/run.gd`: 662 passed, 0 failed at commit `130a6e0`.

Gate evidence: /run/media/lage/New Volume/Scratch/learn009-gate-final.json

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L9, §L11. `Review: human`: the Home redesign is the first thing Bruno sees.
- Stage 2 criteria check, independently reviewed against the committed diff:
  - ✅ 1: `ui/home.gd:124`, `ui/main.gd:570`; `tests/test_home.gd:7` checks the visible start label and rating dialog.
  - ✅ 2: `core/course.gd:211`; `tests/test_course.gd:4`, `tests/test_course.gd:37` and `tests/test_course.gd:71` check priority, incomplete mastered units, next unit and done.
  - ✅ 3: `core/course.gd:207`, `core/course.gd:211`; `tests/test_course.gd:71` checks both deadlines, local-date boundary, distinct positions and eligible pools.
  - ✅ 4: `ui/solving.gd:58`, `ui/main.gd:649`, `core/course.gd:254`; `tests/test_course_screens.gd:8` checks three commits, an interrupted miss and preserved mastery, and `tests/test_course.gd:71` checks clearing on a later pass.
  - ✅ 5: `ui/home.gd:124`, `ui/home.gd:179`; `tests/test_home.gd:7`, `tests/test_home.gd:38` and `tests/test_home.gd:102` check visible labels and the completed message at 800×600.
  - ✅ 6: `ui/main.gd:570`, `ui/main.gd:616`; `tests/test_home.gd:7`, `tests/test_home.gd:38` and `tests/test_home.gd:102` exercise every destination.
  - ✅ 7: `ui/home.gd:124`; `tests/test_home.gd:38` and `tests/test_home.gd:102` compare the Home board with the opened review, solving and play-out positions, and the starting board when done.
  - ✅ 8: `ui/home.gd:24`, `ui/home.gd:88`; Home and session tests cover quick play, controls and engine guidance. `tests/test_session.gd:516` replaces Home's old centred-board expectation with the approved left-aligned design while retaining Searching and Game placement checks; the replacement was proved red with a left-margin mutation and green after restoration.
  - ✅ 9: `docs/spec.md:484` documents Home and review checks; verified by reading the section.

#### Resolution (2026-11-08)
Verdict: Approve

Standards: 0 documented-standard violations, 0 actionable baseline smells. Independent reviewer `/root/standards_review` inspected the entire diff and all 22 commits against AGENTS.md, the domain vocabulary, ADRs and the flow rules. Every commit separates tests, production and tracker metadata. The `tests/test_session.gd` update is allowed by stage 2's explicit exception for tests asserting replaced behavior: only Home's retired centering expectations change, with the replacement and mutation proof named above. Production stays within Primary files.

Spec: 0 numbered-criterion failures. Independent reviewer `/root/spec_review` and the integrating reviewer read the whole diff and confirmed all nine criteria:

- 1 ✅ Home displays Start the course without a rating and opens the rating dialog; `test_continue_starts_course_and_opens_the_next_part` checks both visible text and navigation.
- 2 ✅ `Course.continue_target` prioritizes due reviews, unsolved from-your-game positions, unfinished parts and subsequent units, then done. Course fixture tests cover the sequence and mastered units with unfinished parts.
- 3 ✅ Reviews become due at the local calendar boundary 7 and 30 days after mastery, drawing three distinct positions from practice/test pools. Course tests pass time explicitly and check both deadlines, the eligible pools and the time-zone boundary.
- 4 ✅ Review mode grades each position once, persists a miss before advancing, preserves mastery after Back, records completion and clears needs review after a passed check. The screen scenario checks interrupted/completed misses; the course seam checks a later pass.
- 5 ✅ The card's visible labels show the selected activity, unit and detail. The done message and Custom/Play guidance remain readable at 800×600.
- 6 ✅ The card routes directly to rating, theory pointer, solving, play-out start, test start, review or Custom. Home screen tests exercise every destination.
- 7 ✅ Home displays the selected solving/from-game or review position, the selected play-out position and the starting position when done. Screen tests compare the preview and opened board; the theory/test preview branches were inspected.
- 8 ✅ Existing quick-play preferences, level selection, Custom and navigation connections remain intact. Existing Home/session tests cover these controls, missing-engine disabling and non-overlap at the minimum window size.
- 9 ✅ `docs/spec.md` §15.8 describes Continue, review checks, Course, Play and missing-engine guidance.

Affected callers, failure paths and cross-feature interactions examined: Home configuration/refresh, rating entry and Profile stage changes, course/unit navigation, Continue selection across units, practice selection and from-your-game priority, mastery/review status, local-date conversion, shared solving/test grading and callback cancellation, interrupted reviews, persistence refusal and retry, play-out/test entry, completed-course Custom routing, engine-warning layout, quick-play preferences and screenshot fixtures. Shared grader/probe-error and async serialization coverage was inspected. Live tablebase grading, native Windows gameplay, physical input and human visual acceptance were not exercised. The fully passed review is covered at the course-module seam rather than by a complete solving-screen scenario.

Test-first proof: test-only `674bf1d` precedes review scheduling `ca79b7b`; `8b228d6` precedes Continue selection `5db3918`; `11eb1c0` precedes Home routing `94ce33e`; `fdd72d8` precedes review-screen wiring `6ea6093`. Inspected the [missing-target red log](</run/media/lage/New Volume/Scratch/learn009-red.log>), [missing-card red log](</run/media/lage/New Volume/Scratch/learn009-home-red.log>), [review-routing red log](</run/media/lage/New Volume/Scratch/learn009-review-red.log>) and [elapsed-age red log](</run/media/lage/New Volume/Scratch/learn009-age-red.log>). The final green gate includes all corresponding tests. Additional replacement-layout mutation proof is recorded in the stage-2 comments above; its historical execution was not independently reconstructed.

The branch was already based on `sweatshop/learning/2026-11-07-2234`; rebase changed no commits or code. Reused the existing gate at `130a6e0f790831157f0d5bee4faaaef082cef6af`: `godot --headless -s tests/run.gd`, **662 passed, 0 failed**, exit 0. The official `Assert-GateEvidence` helper verified the command, commit, log SHA-256, exit marker and unchanged code. [Gate log](</run/media/lage/New Volume/Scratch/learn009-gate-final.log>) and [receipt](</run/media/lage/New Volume/Scratch/learn009-gate-final.json>). Existing skips: two headless pixel checks and six live Lc0 checks because the Windows engine executable is unavailable. `git diff --check` passed.

Generated and inspected a fresh [1280×800 Home capture](</run/media/lage/New Volume/Scratch/LEARN-009-review-capture-QwHiXE/Main.png>) from the reviewed code under Xvfb, with isolated data on the hard disk and the window at `3000,3000`, against `docs/design/learning/png/Main.png`. The structure and required text are present. The canvas additionally shows vertically stacked Play icons/labels with different accent colors, a Continue chevron and Course icon/status text; the implementation uses inline Play icons/labels and a plain Course button. These details are described by the design/prose, rather than a numbered criterion; [CLEAN-020](120-CLEAN-020-home-visual-details.md) records them for triage, as required by the review rules. The different board position is expected: the capture uses the actual next course position rather than the canvas's illustrative position.

No production review fix, proxy decision or contract change was introduced. Merge `be3c3d6` integrates the ticket without squash; this closure commits Stage: done and the ledger entry together on the session branch. Review: human remains in force for the driver's session PR.

Acceptance: pending | Automated Continue/review scenarios and the fresh capture comparison passed. Bruno's visual approval and manual clicks through Continue's states remain, including a review check using the real tablebase.
Disclosure: pending | release | Before release, complete the ticket's manual Verification and human visual/input review; [current capture](</run/media/lage/New Volume/Scratch/LEARN-009-review-capture-QwHiXE/Main.png>) and the tests above provide the review evidence.
Disclosure: pending | none | [CLEAN-020](120-CLEAN-020-home-visual-details.md) tracks the remaining canvas details for triage. No numbered criterion depends on this optional visual work; it does not block session integration.
