# UI-001: Two-human game on a board
Stage: to-review
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

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\b3148e8c-d123-45da-9587-64f9ca12d7f7\scratchpad\UI-001-gate.json
