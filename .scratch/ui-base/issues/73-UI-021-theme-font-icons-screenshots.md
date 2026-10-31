# UI-021: Shared theme, Noto Sans, icons and the screenshot tool
Stage: implementing
Blocked by: none
Review: human
Difficulty: hard

- Primary files:
  - New: ui/theme/p_chess.tres (the project theme and its type variations)
  - New: fonts/ (Noto Sans, the weights the canvas uses, and its OFL licence)
  - project.godot (`gui/theme/custom`)
  - New: ui/icons/*.svg (the canvas's inline icons)
  - ui/icons/classes/*.svg (redrawn to `ClassIcon.dc.html`)
  - New: scripts/screens.gd (the screenshot tool)
  - ui/settings.tscn, ui/setup.tscn, ui/promotion_picker.tscn, ui/repertoire_import.tscn (theme only)
  - New: tests/test_ui_theme.gd
  - docs/THIRD_PARTY.md (Noto Sans)
  - docs/design/v0.1.0/README.md (how to run the screenshot tool)

#### What to build

The foundation every other ticket of this feature stands on (`.scratch/ui-redo/spec.md`, Foundation): one project-wide theme from the design tokens, the canvas's font and icons, and a tool that screenshots any screen in a given state so it can be compared with `docs/design/v0.1.0/png/`.

#### Acceptance criteria

1. A Godot `Theme` built from the tokens in `docs/design/v0.1.0/README.md` is the project default. It styles the base Control types (panels, buttons, labels, line edits, check boxes, option buttons, scroll bars, tooltips, popups) in the canvas's look, plus named type variations for what the canvas repeats: at least a primary (green) button, a raised button, a card panel, muted text and a section label (uppercase, `#a8a49c`). Values come from the `.dc.html` sources, not by eye.
2. Noto Sans is bundled under the SIL OFL 1.1 with its licence file and is the theme's default font; the weights the canvas uses (400–800) are available to the variations. `docs/THIRD_PARTY.md` credits it.
3. The canvas's inline SVG icons (bullet, blitz, custom, history, profile, settings, quit, back, robot avatar, flag, copy, trash, pencil, chevrons, import, book, trophy) exist as SVG files under `ui/icons/`, copied from the `.dc.html` sources.
4. The twelve class icons in `ui/icons/classes/` match `ClassIcon.dc.html` and `png/ClassLegend.png` in colour and glyph.
5. `scripts/screens.gd` opens a named screen in a named state (at least every screen board in `docs/design/v0.1.0/canvas.json`) with fixture data in an isolated user folder, at a given window size, and saves a PNG. It never touches the player's own user folder. Its usage is in the design README. A screen whose ticket has not landed yet screenshots its current look.
6. Settings, Custom game setup, the promotion picker and Import PGN pick up the theme with no per-node grey left. No other screen's layout changes in this ticket.
7. The gate stays green.

#### Verification

    Manual: run the screenshot tool for every screen at 1280×800; compare Settings and Custom game with the tokens by eye.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_ui_theme.gd`: the project's default theme is the new resource and its default font is Noto Sans (red: no theme); each class icon's fill colour matches the canvas's (red: Best is `#92b844`, the canvas `#98bc49`).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md` (Foundation). Every other ticket in this feature waits on this one.
