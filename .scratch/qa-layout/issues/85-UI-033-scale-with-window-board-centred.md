# UI-033: The UI scales with the window; board centred on Home and Game
Stage: to-implement
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

#### Verification

    Manual: Home and a 3+2 game in a 1280x720 window, then fullscreen at 1080p or 1440p; the two look the same.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- A test that sets the window (or root viewport) to 1920×1080 and checks the Game board's centre is at the viewport's horizontal centre, and that at 1280×800 the side panel is at least its floor width (red: today the board is left-aligned).

## Comments

- 2026-11-01 Written from Bruno's QA of v0.0.2 (items 1–2). He asked whether this needs a design session; answer given: no, it is a placement rule over the existing canvas components, checked by him on captures (`Review: human`).
- Default taken: the panel floor and the board sliding left below it. Correct it if the board should instead shrink to stay centred.
- Stage 2: `canvas_items`/`expand` scales the canvas; Home and Game centre the board when the panel floor allows it. Review uses its compact layout at the expanded 4:3 minimum. The grip and window resizing keep the panel within the canvas.
- Updated the History toolbar and Review window, popup, legend, compact-actions and repertoire-callout tests to use virtual coordinates or accept a single line when it fits. The containment check fails when the History screen is moved outside the canvas; the compact Review tests failed before its layout fix. The callout's no-wrap case is equivalent to wrapping when its text fits, so the test also checks the available width.
- Verification: focused session/board 61 passed; History 14 passed. One long Review test timed out in the focused file, passed alone, and passed in the final gate. Gate: 490 passed, 0 failed. Captures: `C:/Users/bruno/AppData/Local/Temp/pchess-ui033/` (`home-720.png`, `home-1080.png`, `home-1440.png`, `game-720.png`, `game-1080.png`, `game-1440.png`, `armed-600.png`, `armed-800.png`, `review-600-compact.png`, `review-800.png`). Downscaled 16:9 captures differ by about 0.9/255 mean RGB due to rasterization.
- Acceptance: pending | Bruno to judge the captures and manually compare Home and a 3+2 game between a 1280x720 window and fullscreen 1080p or 1440p.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui033-gate-final.json

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
