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
