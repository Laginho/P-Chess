# UI-021: Shared theme, Noto Sans, icons and the screenshot tool
Stage: done
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
- 2026-10-31 Stage 2: the theme/font and canvas class-colour tests failed before the implementation and passed afterwards. Graphical captures of the 22 canvas boards and the four auxiliary screens at 1280×800 are in `C:/Users/bruno/AppData/Local/Temp/pchess-ui021-verify-20261031160945/`; Settings and Setup were also inspected at 800×600 in `C:/Users/bruno/AppData/Local/Temp/pchess-ui021-small-7ab26ca2-374b-4d6e-aaa7-301a6781b712/`. These show the current application where the corresponding redesign has not landed. The final screenshot-tool change additionally captures resign and declined-draw states under `C:/Users/bruno/AppData/Local/Temp/pchess-ui021-states-1496b759-b277-44ea-bd0d-6c8e9e7a1ae5/`.
- Gate on `d19cf70`: 410 reported passed, including six Lc0-dependent SKIPs (404 executed), zero failed. `C:/Users/bruno/AppData/Local/Temp/pchess-ui021-gate-d19cf70.log`.

Acceptance: pending | Bruno's v0.1.0 QA, as recorded in `.scratch/ui-redo/spec.md`.
Disclosure: pending | release | `.scratch/ui-redo/spec.md` requires Bruno's QA before the v0.1.0 tag.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui021-review-0aac0dbe-e1b3-4e44-a592-2d5a237d588e/gate-9fb8c24.json

#### Resolution (2026-10-31)
Verdict: Approve

Reviewed the complete 42-file diff `784a675...f02e82a`, then the correction through `9fb8c24`, on separate Standards and Spec axes. All numbered criteria pass after the correction below.

##### Standards

No documented-standard violations or actionable smells. Primary files and the test/production/metadata commit split were respected. The original test-only commit is `f27c1ff`; its implementation is `157bd0d`.

##### Spec

- Criteria 1-2: the project theme, canvas tokens, required base types and variations, Noto Sans variable font (400-800) and OFL attribution are present.
- Criterion 3: found and fixed a P2 at `ui/icons/trash.svg:1`: the delete asset duplicated the copy glyph. It now copies the Delete game SVG from `docs/design/v0.1.0/History.dc.html:115`. The other inline icons match their canvas sources.
- Criterion 4: all twelve class colours and glyphs match the canvas; font outlines and geometric glyphs were checked against the source.
- Criterion 5: all 22 canvas board names and the four auxiliary screens have capture routes. Traced fixture settings, history, analysis and repertoire storage to the isolated data root, plus invalid-argument, headless and PNG-save failure paths. Existing stage-2 capture logs cover all 26 routes and the final resign/declined states.
- Criterion 6: freshly rendered and inspected Settings, Setup, PromotionPicker and RepertoireImport at 1280x800, plus Settings and Setup at 800x600. Their controls use the final theme; Settings and Setup fit at the minimum window size. These captures supersede the earlier previews for final-theme details such as the green checkbox icons.
- Criterion 7: the single new gate on committed code `9fb8c24` exited 0: 411 reported passed, six Lc0-dependent SKIPs, 405 executed, zero failed. The receipt and log hash were validated against the integrated code.

Coverage included Settings' dynamically built controls, popup inheritance, promotion buttons, all class-icon consumers, Main/Review/History/Repertoire fixture routes and font redistribution notices. No layout or behavioral redesign outside this foundation was included. Physical keyboard/mouse gameplay, audio and live Lc0 were not exercised; Bruno's release QA remains pending as disclosed above.

Correction proof: test-only `7771db8` failed on the old copy glyph (one expected failure); production-only `9fb8c24` passed it. Author: `/root`. Independent reviewer: `/root/spec`; examined `f02e82a..9fb8c24`, verdict Approve, no remaining findings. Red/green logs and the six fresh PNGs are under `C:/Users/bruno/AppData/Local/Temp/pchess-ui021-review-0aac0dbe-e1b3-4e44-a592-2d5a237d588e/` (`trash-red.log`, `trash-green.log`, `<screen>-<width>/<screen>.png`).

Integrated without squashing into `sweatshop/ui-base/2026-10-31-1604` as `845b1b3`. The session driver owns pushing and the session PR; `Review: human` and Bruno's release QA remain recorded for that handoff.

- 2026-10-31 Follow-up from UI-028 review: criterion 2's FontVariation weights are present as declarations but do not render on Godot 4.7 because their `wght` axis keys are strings. The graphical probe renders the declared 800-weight title with the regular font's 152 px width; the numeric axis key renders it bold at 166 px. This was missed in the foundation review. Open destination: [CLEAN-012](82-CLEAN-012-theme-font-weights.md); probe and PNG `C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/font-compare.{gd,log,png}`. The follow-up records integration impact for UI-028; no deferral was accepted.
