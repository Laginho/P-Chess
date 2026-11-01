# UI-033: The UI scales with the window; board centred on Home and Game
Stage: done
Status: ready-for-agent
Blocked by: none
Review: human
Difficulty: hard

- Primary files:
  - project.godot (`[display]`: no `window/stretch/*` today, so Godot draws at 1:1 pixels)
  - ui/main.tscn, ui/main.gd (the `Layout` HBoxContainer: `BoardView` + `Side`; `min_size` at line ~137)
  - ui/home.tscn, ui/home.gd (Home's board + Quick play panel)
  - ui/resize_grip.gd (the grip turns mouse movement into a board size)
  - ui/review.gd (`size.x <= 800` compact breakpoints at lines ~395, 404, 488, 751)
  - scripts/screens.gd (capture sizes)
  - ui/repertoire_screen.gd, ui/repertoire_editor.gd (embedded fullscreen sizing)
  - tests/ touching window or panel sizes

#### What to build

Bruno's QA of v0.0.2 (2026-11-01), items 1 and 2. At 1280×720 the layout looks right; fullscreen at 1080p draws the same pixel sizes on a bigger window, so the panel stretches across half the screen and its text stays tiny ([before](../game-1080p-before.png)).

1. **Same picture at every 16:9 size.** Set the project's stretch mode to `canvas_items` with aspect `expand` on the 1280×800 base. 1280×720, 1920×1080 and 2560×1440 then render the same 1422×800 virtual layout, scaled. Other aspect ratios expand the virtual size on the longer axis. Every size, breakpoint and test that assumed window pixels now sees virtual pixels: check them all (the `size.x <= 800` breakpoints in Review, the 800×600 minimum window, which now maps to a 1280×960 virtual canvas, and the capture script).
2. **Board centred on Home and Game.** Bruno chose the board at the exact horizontal centre of the screen, with the side panel in the space to its right (narrower than the canvas's 440 px: about 270 virtual px at 16:9). Default taken for sizes where that leaves the panel too narrow (16:10 leaves ~200, 4:3 less): the panel has a floor width, the narrowest at which the Game panel's controls still fit (armed "Click again to resign" inside its button, as UI-031 required); below the floor the board moves left and keeps the panel at the floor. Review, History, Profile and the other screens only get item 1.
3. **The resize grip** keeps working in virtual pixels and keeps the board centred while it resizes.

There is no reference PNG for the centred layout: the canvas (`docs/design/v0.1.0/png/Main.png`, `Game.png`) is 1280×800 with the board on the left. Waiver: the canvas still fixes every component's look (tiles, panel rows, clocks); only their placement changes. Because nothing images this, `Review: human`: Bruno judges the captures.

#### Acceptance criteria

1. Captures of Home and Game at 1280×720, 1920×1080 and 2560×1440 are identical once scaled to the same size.
2. At 16:9 the board's centre is the window's horizontal centre on Home and Game; the panel sits to its right with equal outer margin.
3. At 1280×800 and 800×600 the panel keeps its floor width, all its controls fit unclipped, and the armed Resign label stays inside its button.
4. Review at 800×600 and 1280×800 shows no clipped or overlapping element (its compact breakpoint may need to move to virtual sizes).
5. The resize grip still resizes the board and the board stays centred.
6. Gate green.
7. With embedded subwindows, the Repertoires screen and editor opened at 1920?1080 and resized to 800?600 fill the visible virtual canvas at (0,0), and Save and Cancel remain visible. Native popups retain physical-window sizing.

#### Verification

    Manual: Home and a 3+2 game in a 1280x720 window, then fullscreen at 1080p or 1440p; the two look the same.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- A test that sets the window (or root viewport) to 1920×1080 and checks the Game board's centre is at the viewport's horizontal centre, and that at 1280×800 the side panel is at least its floor width (red: today the board is left-aligned).

- A regression test opens and resizes the embedded Repertoires screen and editor with stretch enabled, checking canvas bounds and footer visibility.

## Comments

- Proxy decided (opus-5.5 xhigh): Yes, with one condition. Add `ui/repertoire_screen.gd`, `ui/repertoire_editor.gd` and `tests/test_repertoire.gd` to Primary files now. Leave `ui/opening_picker.gd` and `tests/test_catalog.gd` out unless a red test shows the picker clipping. The P1 is a regression caused by this ticket's own stretch change, and the fix is two lines with no change to any interface. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261101-143745-UI-033-f49cda.json)

- 2026-11-01 Written from Bruno's QA of v0.0.2 (items 1–2). He asked whether this needs a design session; answer given: no, it is a placement rule over the existing canvas components, checked by him on captures (`Review: human`).
- Default taken: the panel floor and the board sliding left below it. Correct it if the board should instead shrink to stay centred.
- Stage 2: `canvas_items`/`expand` scales the canvas; Home and Game centre the board when the panel floor allows it. Review uses its compact layout at the expanded 4:3 minimum. The grip and window resizing keep the panel within the canvas.
- Updated the History toolbar and Review window, popup, legend, compact-actions and repertoire-callout tests to use virtual coordinates or accept a single line when it fits. The containment check fails when the History screen is moved outside the canvas; the compact Review tests failed before its layout fix. The callout's no-wrap case is equivalent to wrapping when its text fits, so the test also checks the available width.
- Verification: focused session/board 61 passed; History 14 passed. One long Review test timed out in the focused file, passed alone, and passed in the final gate. Gate: 490 passed, 0 failed. Captures: `C:/Users/bruno/AppData/Local/Temp/pchess-ui033/` (`home-720.png`, `home-1080.png`, `home-1440.png`, `game-720.png`, `game-1080.png`, `game-1440.png`, `armed-600.png`, `armed-800.png`, `review-600-compact.png`, `review-800.png`). Downscaled 16:9 captures differ by about 0.9/255 mean RGB due to rasterization.
- Acceptance: pending | Bruno to judge the captures and manually compare Home and a 3+2 game between a 1280x720 window and fullscreen 1080p or 1440p.
- Reopen stage 2: embedded Repertoires and editor now fill the visible virtual canvas on open and resize; native popup sizing stays unchanged. The opening picker is unchanged: its 700-pixel cap fits the minimum 800-pixel virtual height.
- Regression test: with stretch enabled, the pre-fix focused run reported 46 passed, 1 failed, including clipped Save/Cancel at 1920?1080 and wrong popup sizes at 800?600 (`C:/Users/bruno/AppData/Local/Temp/ui033-repertoire-red.log`). The new test passes in the final gate.
- Updated `test_long_repertoire_name_keeps_viewer_and_editor_inside_minimum_window`, `test_full_screen_repertoire_windows_follow_the_main_window_size`, and `test_viewer_keeps_a_long_line_inside_the_minimum_window` to compare with the visible virtual canvas. The first gate exposed the superseded physical-size expectations (488 passed, 3 failed); final gate: 491 passed, 0 failed, exit 0. Six live-Lc0 tests and one graphical pixel check were skipped.
- Acceptance: pending | Bruno to judge the Home/Game captures and manually compare a 1280?720 window with fullscreen 1080p or 1440p; the repertoire fix awaits stage 3 review.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui033-reopen-final.json
- 2026-11-01 Bruno's QA follow-up (fixed on the PR branch, no new ticket):
  1. Searching: the board was pinned to the left margin with a 280-wide card. `ui/searching.gd` now uses Home's rule (centred, sliding left at the 260 panel floor), so the board stays put from Home to Searching to Game. Home's board gap went from 48 to 40 to match Game, so the three also agree below the floor (800x600). The Searching chips centre by their real width in the narrower card.
  2. Centring: measured board centre against window centre on Home, Searching and Game at 1280x720, 1920x1080, 2560x1440 (plus 3440x1440 and maximised-window heights). Home and Game were already exactly centred (0.0 px off in the captures and in virtual geometry, including after OS window resizes); only Searching was off (-311 virtual px). No code cause for a rightward offset was found. Likely reading: the board is centred but the panel sits only on its right, so the board-plus-panel group leans right; that is this ticket's chosen placement, left for Bruno to confirm. New test `test_board_stays_centred_on_home_searching_and_game` (tests/test_session.gd) asserts the centre to 1 px on all three screens through the real stretch, and equal positions below the floor; it was red on Searching before the fix.
  3. Quick play tiles (`ui/home.gd`, `ui/home.tscn`, `ui/icon_button.gd`): tiles keep Main.png's 210:160 landscape proportion (shorter, not thinner, in a narrow panel); the label is centred on the tile with the icon 6 px to its left, and the font shrinks until the icon fits rather than pushing the label off-centre. Test `test_quick_play_tiles_are_landscape_with_centred_labels` (tests/test_home.gd).
  Gate: 495 passed, 0 failed, exit 0 (`C:/Users/bruno/AppData/Local/Temp/pchess-qa-followup/gate.log`; six live-Lc0 checks and one graphical pixel check skipped). Captures: `C:/Users/bruno/AppData/Local/Temp/pchess-qa-followup/after/` (Main, Searching, Game at 720, 1080, 1440, 600); before: `.../before/`.
  Acceptance: pending | Bruno to confirm the centring on his own screen and judge the tiles.

#### Resolution (2026-11-01)

Verdict: Reopen — P1 regression: global stretch clips the existing repertoire screens and hides the editor's Save/Cancel actions.

- Reviewed the complete nine-file diff `536c74e...73cc16b` against the lane session base. Standards: 0 findings; Spec: 1 finding. The seven stage-2 commits separate tests from production, and the supplied red logs fail on board centring, window shrinking and the compact Review layout before their fixes.
- Examined Home layout/configuration and missing-engine state; Game board fit, saved size, panel floor, armed resignation and grip input; Review compact layout, notice, legend, tooltips, actions and callout tests; History containment; screenshot dimensions; and the repertoire popup callers affected by global stretch. Fullscreen on physical hardware, live Lc0 play and every screen's rendered state were not exercised.

**Unresolved finding (stage 2):**

- **P1 — `project.godot:25-26`**, regression caused by global stretch. `ui/repertoire_screen.gd:54,62` and `ui/repertoire_editor.gd:55,62` still use physical `root.size` for embedded popup sizing. Open Custom game -> Repertoires -> edit a repertoire at 1920x1080: the visible canvas is 1422x800, but both popups are 1920x1080 virtual pixels. Save is at `(1544,984,320,44)` and Cancel at `(1214,984,320,44)`, entirely below the visible area; the editor also extends past the right edge. Without stretch, the same controls fit the physical 1920x1080 canvas. Default embedding is enabled. Suggested fix: use virtual viewport bounds for embedded fullscreen popup targets and resize handlers, preserving native-window coordinate handling; audit the opening picker's physical-height calculation too. These production files are outside the current Primary files, so stage 2 must obtain the ticket-flow proxy's seam decision before editing them. Regressing an existing feature is a reopen condition even though the six numbered criteria focus on Home/Game/Review.
- Reproduction: existing `scripts/screens.gd` with `RepertoireEditor 1920 1080`, using the design README's isolated data root. Graphical evidence: `C:/Users/bruno/AppData/Local/Temp/ui033-stage3-editor-1080/editor-1080.png` (capture exit 0). Independent geometry and baseline logs: `C:/Users/bruno/AppData/Local/Temp/ui033-spec-popup-probe.log` and `C:/Users/bruno/AppData/Local/Temp/ui033-spec-popup-baseline.log` (both exit 0). Add a regression test that opens and resizes the embedded repertoire screen/editor at scaled window sizes and contains their footer controls in the visible virtual canvas.

**Numbered criteria:**

1. ✅ Automated layout evidence: actual root sizes 1280x720, 1920x1080 and 2560x1440 all produce the same 1422x800 canvas and identical Home/Game board and panel rectangles. Existing stage-2 captures support the scaled appearance; Bruno's visual acceptance remains pending.
2. ✅ Both boards have horizontal centre 711 at all three 16:9 sizes; the Game panel ends at 1382, leaving the 40-pixel virtual outer margin.
3. ✅ Game panel floor is 260 virtual pixels at 1280x800 and 800x600; supplied armed-state captures at both sizes show the label inside its button. The floor exception intentionally moves the board left.
4. ✅ Inspected the supplied `review-600-compact.png` and `review-800.png`; the existing compact/containment tests are green in the validated gate.
5. ✅ Independent routed mouse probe at 1920x1080, including physical-to-virtual input transformation: dragging by -135 physical pixels changes the board from 720 to 620 virtual pixels while its centre remains 711. Log: `C:/Users/bruno/AppData/Local/Temp/ui033-stage3-probe-data/physical-grip-output.log` (exit 0).
6. ✅ Revalidated the existing receipt against reviewed HEAD, including tested-code equality, SHA256 log hash and exit marker: 490 passed, 0 failed, exit 0. Reused the run because production is unchanged. Six live-Lc0 checks and one graphical pixel check report skips.

Acceptance: pending | Bruno's capture judgement and real window/fullscreen comparison remain pending; the repertoire regression also prevents integration.
Disclosure: pending | integration | UI-033 P1 above; restore visible repertoire editor actions before lane integration.
Disclosure: pending | release | Bruno to judge the existing Home/Game captures and manually compare a 1280x720 window with fullscreen 1080p or 1440p; no aesthetic acceptance is inferred from the green gate.

#### Resolution (2026-11-01, re-review)

Verdict: Approve

- Re-reviewed `73cc16b...d44c06b` against the prior P1 and criterion 7, with the complete `536c74e...d44c06b` diff for context. Independent Standards and Spec reviewers found 0 findings each. The previous P1 is resolved; there are no unresolved integration findings. No production behavior was authored during this review.
- Standards: changes stay within the proxy-approved Primary files. Regression-test commit `0563347` precedes production-only fix `408f61a`; `0d8b2fc` adapts the superseded physical-size assertions while retaining containment checks. The supplied red log fails the intended popup-size and Save/Cancel assertions (46 passed, 1 failed, exit 1).
- Spec: both embedded popup `_fit()` methods now use the root's visible virtual canvas on open and resize. The existing `popup_centered(root.size)` native path and embedding guard remain intact. Examined the Setup -> Repertoires -> editor callers, resize connections, reopen lifecycle, footer containment, and the opening picker's capped size; no scope creep or new regression found.
- Reviewed the existing `Proxy decided (opus-5.5 xhigh)` decision and its receipt `C:/Users/bruno/AppData/Local/Temp/sweatshop-proxy/20261101-143745-UI-033-f49cda.json`. It authorizes the two repertoire popup files and their tests, preserving native sizing. The opening picker remains unchanged; the independent probe confirms its bounds fit the virtual canvas.

**Numbered criteria:**

1. Pass for implementation: retained the earlier layout/capture evidence at 1280x720, 1920x1080 and 2560x1440; the re-review changes only repertoire popup sizing and its tests. Bruno's judgement of the supplied Home/Game captures remains pending.
2. Pass: the previously verified board centring and outer-margin layout are unchanged.
3. Pass: the panel-floor and armed-Resign containment evidence are unchanged.
4. Pass: Review's compact layout and containment evidence are unchanged; its tests remain green in the validated gate.
5. Pass: the earlier routed physical-to-virtual grip probe remains applicable; no grip or board-layout code changed in this pass.
6. Pass: validated the existing receipt against `d44c06b` and again after lane integration, including tested-code equality, SHA256 log hash and exit marker: 491 passed, 0 failed, exit 0. Reused the run because production did not change. Six live-Lc0 checks and one graphical pixel check were skipped.
7. Pass: an independent probe opened both embedded screens at 1920x1080 (1422x800 canvas), resized them to 800x600 (1280x960), and reopened them at 2560x1440 (1422x800); both stayed at (0,0), filled the canvas and contained Save/Cancel. The native `_fit()` guard preserved the popup sizes. Probe: `C:/Users/bruno/AppData/Local/Temp/ui033-rereview-spec/result.log`, exit 0. New graphical editor captures at 1920x1080 and 800x600 were inspected: Save/Cancel are visible in both. Captures: `C:/Users/bruno/AppData/Local/Temp/ui033-rereview-editor-80640d4c-4caa-4928-8e0a-199ee7b598c1/editor-1080.png` and `editor-600.png`, both capture exits 0.

Rebase onto the lane was already up to date. Integrated without squashing into `sweatshop/qa-layout/2026-11-01-1407` as `27fa11c`; no PR or push is part of this stage. Stage and ledger close together in this commit.

Acceptance: pending | Bruno to judge the Home/Game captures in `C:/Users/bruno/AppData/Local/Temp/pchess-ui033/` and compare a 1280x720 window with physical fullscreen at 1080p or 1440p. Native desktop-window sizing and live Lc0 play were not exercised in this review.
Disclosure: decision | none | The proxy-approved repertoire sizing correction resolves the prior integration P1; independent probe and graphical evidence are recorded above.
Disclosure: pending | release | Bruno's Home/Game visual judgement and physical window/fullscreen comparison remain required; implementation approval and lane integration do not establish that acceptance.
