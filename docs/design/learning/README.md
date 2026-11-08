# Learning course UI design

The visual reference for the learning course screens (first unit: rook endgames). Same format as `docs/design/v0.1.0/`: each `.dc.html` file is one board of the design canvas, plain HTML with inline styles, so sizes, colours, spacing and copy can be read straight from the source. `{{name}}` bindings and `<sc-if>` / `<sc-for>` blocks are filled by the `renderVals()` script at the bottom of each file; `<dc-import name="X">` embeds `X.dc.html`.

**`png/<Board>.png` is the reference image of each board** at its canvas size. Boards with several states show their default one in the PNG; the other states are listed below and come from the `data-props` enum at the bottom of the file. `support.js` renders the boards in a browser when served over http from the repo root (`python -m http.server`, then open `/docs/design/learning/<Board>.dc.html`). After editing a board, regenerate the PNGs with `node docs/design/learning/render-png.js` (needs Microsoft Edge).

The live canvas is the Claude artifact https://claude.ai/artifact/RR5HJBpti7TqPz3Cjs4jhH. Piece images (`/_blob/...` in `Board.dc.html`) are the repo's own cburnett pieces; `support.js` maps them.

Behaviour lives in `.scratch/learning/spec.md`. Where the canvas and the spec disagree, the spec wins. Chess lines and positions on the boards are illustrative, not tablebase-checked content.

| Board | File | Other states |
|---|---|---|
| 1 · Home | `Main.dc.html` | `continueState`: part, review, game, done |
| 2 · Course map | `CourseMap.dc.html` | `unitStatus`: new, in progress, mastered, needs review |
| 3 · Unit page | `Unit.dc.html` | clock toggle (5+5 / No clock) |
| 4 · Theory pointer | `Theory.dc.html` | |
| 5 · Solving: entering a line | `SolvingEntry.dc.html` | `fromGame`: the "From your game" chip |
| 5 · Solving: feedback | `SolvingFeedback.dc.html` | `result`: miss, solved |
| 6 · Play-out: start | `PlayoutStart.dc.html` | `kind`: convert, hold |
| 6 · Play-out: end card | `PlayoutEnd.dc.html` | `result`: passed, failed: move, failed: time |
| 7 · Pass test: start | `TestStart.dc.html` | |
| 7 · Pass test: result | `TestResult.dc.html` | `result`: passed, not passed |
| 8 · Rating sentence, first time the course opens | `RatingModal.dc.html` | |
| 8 · Profile with the rating sentence | `Profile.dc.html` | |
| 9 · Review: from-your-game marker | `ReviewMarker.dc.html` | |
| Component · Board (with entry marks) | `Board.dc.html` | |
| Component · Class icon | `ClassIcon.dc.html` | copy of v0.1.0 |

`canvas.json` holds the board layout and titles.

## Notes for the build

- Tokens and fonts are the v0.1.0 ones (see that README's Tokens table).
- **Entry marks** (`Board.dc.html`, `marks`): each entered move tints its from and to squares `#c93230` at 26% alpha, plus 12% per extra use of the same square (capped at 50%), with a soft glow of the same colour (`size / 40` px) so neighbouring marks blur together. The marks sit under the pieces. No arrows while entering.
- Open copy: the Course map's `[Stage name]` and the theory pointer's `[chapter]` entries are placeholders until the content is drafted.
