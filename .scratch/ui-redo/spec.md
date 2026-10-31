# UI redo: make the app look like the v0.1.0 design

Written 2026-10-31. The v0.1.0 tickets were built from the text of `docs/design-brief-v0.1.0.md` only: the design canvas reached the repo after they were done, and the app has no shared Godot theme, so every screen kept Godot's stock grey look. This feature restyles the app to the canvas. It ships inside v0.1.0: Bruno tags v0.1.0 after this lands and he has QA'd it.

## Sources

- **Look:** `docs/design/v0.1.0/png/<Board>.png` is the reference image of each screen; the matching `<Board>.dc.html` holds the exact sizes, colours, spacing, copy and inline SVG icons. `docs/design/v0.1.0/README.md` maps boards to screens and lists the tokens.
- **Behaviour:** `docs/spec.md`. Where the canvas and the spec disagree on behaviour or copy, the spec wins (for example: the name dialog is prefilled with "You"; New game on the game-over card returns Home and is labelled "New game", not "New 3+2"; the searching status reads "Loading Maia 1500…", not "Loading model…"; the review keeps Rematch beside New game when opened after a game). The canvas's sample data (names, numbers, dates) is illustration, not content.
- **Decided with Bruno on 2026-10-31**, overriding both sources where they conflict:
  - The game-over card's main button reads **"Review"** (canvas: "Game Review"), with the canvas's style and star icon.
  - **Profile** follows the canvas layout: the name card with "Playing since <month year>" (the first game's date), four tiles (Games, Avg. accuracy, W / D / L, Flag W / L), and the results table with one row per level, a W D L column per time control, and flag wins and flag losses per level. The accuracy chart keeps the spec: every analysed game, 0–100 axis.
  - The **game screen drops** what the canvas leaves out: the Settings button on the game screen (Settings stays reachable from Home and with `Ctrl+,`), the material-difference counters (§8.4), and the Review button that stays in the side panel after the game-over card is closed (§9.3: after closing the card, the game is reviewed from History).
- **Canvas additions adopted** (display-only or reuse of existing actions): game counts on the History tabs; a Copy PGN icon on the game-over card; the review header line ("3+2 · Won on time · 41 moves") and the number on the eval bar; the editor's "Unsaved changes" marker; the per-repertoire edit (pencil) button that opens the editor; the "Move classes" legend popover on the review.

## Foundation (one ticket, before every screen: UI-021, in `.scratch/ui-base/` so it runs as its own lane)

- **Theme:** one project-wide Godot `Theme` resource built from the README tokens (ground, panel, raised, border, text, muted, placeholder, accent green with dark text, gold, red; corner radii and borders as in the canvas), set as the project default (`gui/theme/custom`). Screens use theme type variations (for example a primary green button, a raised button, a panel card) instead of per-node colour overrides.
- **Font:** Noto Sans (SIL OFL 1.1) bundled in the repo, weights 400–800 as the canvas uses them, set as the theme default font. Attribution in `docs/THIRD_PARTY.md`.
- **Icons:** the canvas's inline SVG icons (bullet, blitz, custom, history, profile, settings, quit, back chevron, robot avatar, flag, copy, trash, pencil, chevrons, import, book) exported as SVG files under `ui/icons/`. The class icons in `ui/icons/classes/` are redrawn to `ClassIcon.dc.html`'s colours and glyphs (the current ones differ, e.g. Best is `#92b844`, the canvas `#98bc49`).
- **Screenshot tool:** a script that opens each screen in a given state, with fixture data in an isolated user folder, at a given window size, and saves a PNG. It runs with a window (Godot's headless mode does not render), outside the gate. Every screen ticket's review compares its output with the reference PNG.
- Screens the canvas does not draw (Settings, Custom game setup, the promotion picker, Import PGN) get the theme only: no stock grey left anywhere.

## Screens (one ticket each, after the foundation; they can run in parallel)

| Ticket | Boards |
|---|---|
| Home, name dialog, searching | `Main`, `NameDialog`, `Searching` |
| Game screen: board and side panel | `Game`, `GameSidePanel`, `GamePanelStates`, `Board` |
| Game-over card | `GameOver`, `GameOverStates`, `GameOverCard` |
| History | `History` |
| Review | `Review`, `ReviewAnalysing`, `ReviewNotAnalysed`, `ReviewSmall`, `ReviewLegend`, `ClassLegend` |
| Profile | `Profile` |
| Repertoires, picker, editor | `Repertoire`, `OpeningPicker`, `RepertoireEditor` |

Only the game screen ticket changes `ui/board_view.gd`'s look (highlight colours, coordinates); the other screens reuse the board as it is.

## Acceptance shared by every screen ticket

1. At 1280×800, the screenshot tool's PNG of each listed board's state matches the reference PNG in layout, colours, type sizes and weights, spacing, icons and copy (copy per the spec where they differ). Differences that remain are listed in the ticket's Comments with a reason.
2. At 800×600 the screen stays usable: nothing clipped or overlapping.
3. Behaviour is unchanged except where this spec says otherwise; the gate stays green.
4. Stage 3 attaches the before and after screenshots next to the reference PNG (paths in the Comments).

## Not in scope

New features, settings or strings beyond the adopted additions above; Portuguese; animations beyond what exists.
