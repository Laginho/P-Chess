# v0.1.0 UI design

The visual reference for the v0.1.0 screens. Each `.dc.html` file is one board of the design canvas: plain HTML with inline styles, so exact sizes, colours, spacing and copy can be read straight from the source. `{{name}}` bindings and `<sc-if>` / `<sc-for>` blocks are filled by the small `renderVals()` script at the bottom of each file; `<dc-import name="X">` embeds `X.dc.html`.

The files don't render standalone (they need the canvas runtime). The live canvas is the Claude artifact https://claude.ai/code/artifact/977e2ff4-7862-4e2b-b49b-4c84e232a5f5. Piece images (`/_blob/...` in `Board.dc.html`) are the repo's own theme pieces.

Behaviour lives in `docs/spec.md`; `docs/design-brief-v0.1.0.md` is the brief the canvas was built from. Where the canvas and the spec disagree, the spec wins.

| Board | File |
|---|---|
| 1 · Home | `Main.dc.html` |
| 2 · First-launch name dialog | `NameDialog.dc.html` |
| 3 · Searching | `Searching.dc.html` |
| 4 · Game (with board resize grip) | `Game.dc.html` |
| 4 · Side panel: resign confirm, Maia declined | `GamePanelStates.dc.html` |
| 4 · Game over (win) | `GameOver.dc.html` |
| 4 · Game over: loss, draw | `GameOverStates.dc.html` |
| 5 · History (all card states) | `History.dc.html` |
| 6 · Review: done | `Review.dc.html` |
| 6 · Review: analysing | `ReviewAnalysing.dc.html` |
| 6 · Review: not analysed | `ReviewNotAnalysed.dc.html` |
| 6 · Review at 800×600 | `ReviewSmall.dc.html` |
| 6 · Review: move class legend | `ReviewLegend.dc.html` |
| 7 · Profile | `Profile.dc.html` |
| 8 · Repertoires | `Repertoire.dc.html` |
| 8 · From openings picker | `OpeningPicker.dc.html` |
| 9 · Repertoire editor | `RepertoireEditor.dc.html` |
| Component · Board | `Board.dc.html` |
| Component · Game side panel | `GameSidePanel.dc.html` |
| Component · Game over card | `GameOverCard.dc.html` |
| Component · Class icon | `ClassIcon.dc.html` |
| Move classes and colours | `ClassLegend.dc.html` |

`canvas.json` holds the board layout and titles.

## Tokens

| Token | Value |
|---|---|
| Ground (page background) | `#1f1e1c` |
| Panel | `#2b2a27` |
| Raised | `#363430` |
| Border | `#45423d` |
| Text | `#ece9e4` |
| Muted text | `#a8a49c` |
| Placeholder | `#6b675f` |
| Accent (green) | `#7fa650`, text on it `#141412` |
| Gold | `#f4bf44` |
| Red | `#c93230` |
| Bot avatar | `#5a5650` |
| Font | Noto Sans, 400–800 |

Move-class colours are in `ClassIcon.dc.html`.
