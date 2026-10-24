# UI-001: Two-human game on a board
Stage: done
Blocked by: CORE-004, CORE-005
Review: agent
Difficulty: normal

- Primary files:
  - project.godot (main scene, window size)
  - New: ui/main.tscn, ui/main.gd
  - New: ui/board_view.tscn, ui/board_view.gd
  - New: ui/move_list.tscn, ui/move_list.gd
  - New: themes/pieces/cburnett/ (wK.svg … bP.svg)
  - New: docs/THIRD_PARTY.md
  - New: tests/test_board_view.gd

#### What to build

The first playable screen: two humans play a full game in one window by dragging pieces (§8.1, §8.7). The board renders with the default look (Lichess brown `#f0d9b5` / `#b58863`, cburnett pieces); loading other themes is UI-003.

#### Acceptance criteria

1. The app opens on the start position, white at the bottom; `F` flips the board.
2. Dragging a piece of the side to move makes it follow the mouse every frame; dropping it on a legal square plays the move; an illegal drop snaps it back with a tween. Pieces of the other side cannot be picked up.
3. The window opens at 1280×800, cannot shrink below 800×600, and the board stays square and scales with the window.
4. A side panel shows the move list in SAN, updated after every move.
5. Coordinates are drawn on the board edge and follow the flip.
6. When the game ends (any rule from CORE-004), input stops and the result and its reason are shown.
7. The pixel-to-square mapping is correct for both orientations at any board size (pure function, tested).
8. `docs/THIRD_PARTY.md` credits the cburnett pieces (Wikimedia Commons, BSD-3) with a source link.

#### Verification

    Manual: play Fool's mate and a game with castling, en passant and promotion to queen.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_board_view.gd`: pixel-to-square and square-to-pixel for white and black at two board sizes. Red because `ui/board_view.gd` does not exist.

## Comments

- 2026-10-24 Stage 2: the cburnett SVGs could not be fetched. Every network path was refused by the session's permissions (curl to Commons, WebFetch, python for python-chess's embedded copy), and reads outside the lane are blocked.
- Proxy decided (opus): reproduce the 12 cburnett SVGs from the known path data, check each by eye, label them as reproduced in `docs/THIRD_PARTY.md`, and hand off to-review with Acceptance pending and Disclosure `pending | integration` — follows the BOT-002 precedent (fixture rebuilt without network, labelled); a wrong piece is a file swap with no code change, while a glyph fallback would be throwaway code and leave UI-003 criterion 3 without its twelve files. Conditions: no workarounds, runtime loading (no `preload` of `.svg`), no labels inside the SVGs, BSD-3 text in THIRD_PARTY.md.
- All 12 were rasterised headless (`Image.load_svg_from_string`, scale 2, on both square colours) and checked by eye: each reads as the right cburnett piece.
- Fetch command for Bruno (PowerShell 5.1, from the repo root), then look at the board and commit:

  ```powershell
  foreach ($c in 'w','b') { foreach ($p in 'K','Q','R','B','N','P') { $t = if ($c -eq 'w') { 'l' } else { 'd' }; Invoke-WebRequest -UseBasicParsing -UserAgent 'P-Chess-asset-fetch' -OutFile "themes/pieces/cburnett/$c$p.svg" "https://commons.wikimedia.org/wiki/Special:FilePath/Chess_$($p.ToLower())$($t)t45.svg" } }
  ```

  If Commons refuses that user agent, `lichess-org/lila/public/piece/cburnett/` has the same file names.
- Red-green: b754f69 (test only) failed to load, `Preload file "res://ui/board_view.gd" does not exist`: 41 passed, 1 failed. On 3abb957 (production only): 46 passed, 0 failed, and all 5 `test_board_view.gd` tests pass. The one SKIP is the lc0 test, as on the base.
- The manual Verification was run as a scene smoke test (scratch script, not committed). It drives `ui/main.tscn` with synthetic mouse and key events through `Viewport.push_input`: Fool's mate ends `0-1, checkmate`, the move list reads `1. f3 e5 / 2. g4 Qh4#`, and no move is accepted after the end. A black piece cannot be picked up on white's turn. An illegal drop is mid-tween, then back home. `F` flips the board. Then a game through O-O on both sides, exf6 en passant and gxf8=Q+, with moves dragged on the flipped board. The window opens at 1280×800 with min_size 800×600, and the board is 612 px square at 900×650. Screenshots were checked. Nobody has played it by hand yet.
- Callers: none. All code is new; `core/` is only read (`play`, `is_over`, `result`, `reason`, `board.legal_moves`, `board.san`, `board.piece_at`, `board.side_to_move`). The only existing file touched is `project.godot`, which gains the main scene and window size.
- Shortcuts, each marked in the code: promotions always become a queen until UI-002 brings the picker. Pieces are read as raw `.svg`, so the Windows export (CI-002) must ship `*.svg` as non-resource files. Opening the project in the editor will also generate `.svg.import` files next to the pieces.
- Acceptance: pending | the cburnett SVGs are reproduced, not downloaded from Commons. Still to do: run the fetch command above, check the board visually, commit; and play one game by hand.
- Disclosure: pending | integration | Proxy decided (opus), see the line above: the cburnett pieces are reproduced, not fetched. Replace them with the Commons originals before the session PR is integrated. Only the files change, not the code.

Gate evidence (superseded, before the review's fix commit): C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\b3148e8c-d123-45da-9587-64f9ca12d7f7\scratchpad\UI-001-gate.json

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\01c75f9f-0786-4326-b7ae-41246b8b2b84\scratchpad\UI-001-done-gate.json

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents, and neither found anything. I also read the whole diff myself, rendered the twelve piece SVGs in Godot, and ran the main scene headless for 30 frames with no errors. My fix commit 2ddc70e changes one code comment and one doc line, and no behaviour.

Criteria:

1. ✅ `ui/main.tscn` is the main scene, `Game.new()` starts from the start position, and `flipped` defaults to false. `F` toggles `board_view.flipped` (`ui/main.gd:18-20`).
2. ✅ Only a piece of the side to move can be picked up, and none once the game is over (`ui/board_view.gd:113-120`). `_drag_pos` follows every motion event and queues a redraw. A legal drop plays through `game.play`. Any other drop, including off the board or back on its own square, tweens back in 0.15 s, and input is locked until it lands.
3. ✅ `project.godot` sets 1280×800 and `main.gd` sets `min_size` to 800×600. The board is `min(size)` square, centred in an expanding control.
4. ✅ The SAN is taken from the board before `play`, then added to the list one ply at a time, one full move per line, with `scroll_following` on.
5. ✅ Files are drawn along the bottom and ranks along the left. Each label is read back through `square_at`, so it follows the flip, and it is drawn in the other square colour.
6. ✅ Every automatic end in `core/game.gd` `_after_move` (checkmate, stalemate, 50-move, insufficient material, fivefold) makes `is_over()` true, so `_pick_up` refuses input and the label shows "result, reason". A threefold claim does not end the game by itself; the claim button is UI-004 criterion 5.
7. ✅ `square_at` and `square_position` are static and pure. `tests/test_board_view.gd` covers both orientations at 800 and 480, points off the board, and a round trip for all 64 squares.
8. ✅ `docs/THIRD_PARTY.md` credits Colin M.L. Burnett, from Wikimedia Commons, under BSD-3 with the full text, a category link and one link per file.

Red-green, from stage 2 and checked here: red on b754f69, where `Preload file "res://ui/board_view.gd" does not exist` gave 41 passed and 1 failed. Green on 3abb957: 46 passed, 0 failed.

Test-first: I checked `diff --stat` on every commit:
- b754f69: `tests/test_board_view.gd` and the Stage line (red).
- 3abb957: production only (`ui/`, `themes/`, `project.godot`, `docs/THIRD_PARTY.md`).
- 80564e0: the ticket only.
- 2ddc70e (review): one comment in `ui/board_view.gd`, one line in `docs/THIRD_PARTY.md`, and the Stage line.

All code files are in Primary files.

Examined:
- Callers: none, because all the code is new. `core/` is only read. `project.godot` gains the main scene and window size, and the gate runs with `-s`, so the tests never load the main scene.
- Failure paths: a drop off the board or on the piece's own square snaps back. A press during a snap is ignored. A release outside the control still reaches it, because Godot keeps mouse focus on the control that took the press. `F` during a drag maps the drop through the new orientation.
- The core contract: castling is the king's move (`e1g1`), so dragging the king two squares castles, and dropping it on its own rook snaps back. Promotion picks the `q` variant (a shortcut; the picker is UI-002 criterion 4). En passant is a plain legal move.
- The twelve SVGs, rendered at scale 3 on both square colours: each reads as the right cburnett piece.
- Not examined: play by hand with a real mouse (stage 2's smoke test used synthetic events), Godot versions other than 4.7.2, and an exported build (see the second disclosure).

Review fixes (2ddc70e), written by this review and text only: the raster comment said 180 px covered any square, but squares above 180 px (a 4K window) upscale. `docs/THIRD_PARTY.md` said "before release", while the first disclosure below makes the swap an integration condition.

Gate: rerun on 1a6c3d8, the session tip after the merge a23096b and the CI-002 note, exit 0, 46 passed, 0 failed. The one SKIP is the lc0 test, as on the base. Log hash `AE87F0BA…CBEB`. 2ddc70e also ran 46/46 before the merge.

Proxy decided lines: one, `Proxy decided (opus)` under ## Comments: reproduce the 12 cburnett SVGs from their path data instead of fetching them. I rendered them and agree they are correct. Swapping in the originals is the first disclosure below.

Acceptance: pending | still to do: replace the reproduced SVGs with the Commons originals (fetch command under ## Comments), look at the board, and play one game by hand. Gate 46/46 on 1a6c3d8. Stage 2's synthetic smoke test covered Fool's mate, castling, en passant and promotion.

Disclosure: pending | integration | Proxy decided (opus), see ## Comments: the cburnett pieces are reproduced, not fetched. Replace them with the Commons originals before the session PR is integrated. Only the files change, not the code.

Disclosure: deferred | release | the pieces are loaded as raw `.svg` files (shortcut at `ui/board_view.gd:10`), so an export that does not ship them shows an empty board. Open destination: a note under CI-002 ## Comments (1a6c3d8), for stage 1 to fold into a criterion.
