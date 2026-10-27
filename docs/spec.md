# [P] Chess — MVP spec

A native Windows app for bullet and blitz practice against Maia, a human-like chess bot. It must feel as smooth as Lichess, and the bot must feel human: in its moves, in its openings and in its clock use.

Repo: `P-Chess` on GitHub, public, no licence file. UI language: English only.

## 1. Stack

| Part | Choice |
|---|---|
| Engine for the app | Godot 4.7, GDScript |
| Bot | Maia-1 nets `maia-1100` … `maia-1900`, run by Lc0 v0.32.1 (CPU, dnnl build) |
| Bot protocol | UCI over `OS.execute_with_pipe`, read on a worker thread |
| Openings data | `lichess-org/chess-openings` TSVs (CC0, 3,865 named lines), committed to the repo |
| Rules | Own GDScript move generator, checked by perft |

The bridge speaks generic UCI, so a second engine can be added later without touching the game code (see §13).

## 2. Repo layout

```
P-Chess/
  project.godot
  core/        board.gd (position, movegen, FEN, SAN), game.gd (history, results), pgn.gd
  engine/      uci.gd                          # engine/lc0 and engine/weights are gitignored
  bot/         maia_player.gd, move_picker.gd, time_model.gd, book.gd
  ui/          board_view, clock, move_list, setup, review, settings, opening_picker
  data/        openings/*.tsv, time_model.json
  themes/      boards/, pieces/, sounds/
  tests/       run.gd + test_*.gd
  scripts/     fetch-engine.ps1, calibrate_time.py
  docs/        spec.md, THIRD_PARTY.md
```

## 3. Engine and bot moves

### 3.1 Engine files

- `scripts/fetch-engine.ps1` downloads the pinned Lc0 zip and the 9 Maia nets into `engine/`, and checks their SHA-256 hashes. It must run in Windows PowerShell 5.1. CI uses the same script.
- At startup the app looks for `engine/lc0/lc0.exe` next to the executable (or in the project root inside the editor). If it is missing, the app shows how to run the fetch script.

### 3.2 Getting Maia's probabilities

- Lc0 starts once with `VerboseMoveStats=true`.
- Changing the level sends `ucinewgame`, then `setoption name WeightsFile`, then `isready`. Without `ucinewgame`, Lc0 keeps answering with the old net's probabilities (tested 2026-10-24). Every new game also starts with `ucinewgame`.
- Each bot move sends `position fen … moves …` and `go nodes 1`. The app parses `P:` for every legal move from the `info string` lines. That is Maia's policy.

### 3.3 Picking the move

The order matters: the book weight comes before the cut, so a book move Maia rates at 0.5% survives.

1. Start from Maia's policy: `p(m)` for every legal move.
2. Multiply by the book weight `w(m)` (§6.3), then renormalise.
3. Cut every move below the threshold `τ`, but always keep the top move. Renormalise.
4. Apply the temperature `T`: `p ← p^(1/T)`, then renormalise.
5. Sample one move.

Defaults: `τ = 2%`, `T = 1.0`. Both are settings.

### 3.4 Time-pressure panic

- When Maia's clock is under 10% of the starting time, `T` rises and `τ` falls linearly, reaching `T_max` and `τ_min` at 0 s.
- Intensity setting: off / low / medium / high. Off leaves `T` and `τ` unchanged; the others map to `(T_max, τ_min)` = (1.3, 1%), (1.7, 0.5%), (2.2, 0.2%). These are initial values, to be tuned by playing.

## 4. Bot think time

Maia's clock is real: its delay is spent from its clock, it can flag, and it loses on time like anyone else.

### 4.1 Model

The delay is sampled from a lookup table in `data/time_model.json`. The table has one bucket per combination of:
- time control (1+0, 3+2, 5+0)
- rating band (the Maia level)
- clock fraction left (bins)
- Maia's top-move probability (bins)

Each bucket stores the median and the log-σ of human think time. The delay is sampled from that log-normal distribution, then clamped to `[0.05 s, clock left]`.

Overrides:
- With exactly one legal move, the delay is the floor.
- A "premove": when Maia's top-move probability is over 0.9 and its clock is under 15% of the starting time, the delay is the floor.

Lc0's own compute time is subtracted from the sampled delay. It also counts against Maia's clock when it exceeds the delay.

### 4.2 Fallback

Until the calibration exists, a hand-tuned formula is used instead:

`base = clock_left / max(10, 40 − moves_played)`, plus `0.8 × increment`. That is scaled by `(1.6 − top_p)`, times log-normal noise with σ = 0.6.

### 4.3 Calibration (milestone M8)

`scripts/calibrate_time.py` runs offline:
1. Stream the start of one monthly Lichess `.pgn.zst` file (a partial download of a few GB — **ask Bruno first**).
2. Keep games at 60+0, 180+2 and 300+0 in the 1100–1900 bands.
3. Compute think times from the `%clk` comments.
4. Run Lc0 on a sample of those positions to get Maia's top-move probability.
5. Write `data/time_model.json`.

Python dependencies (`zstandard`, `python-chess`) are only for this script; the game does not need them.

## 5. Clocks and time controls

- Only three time controls: 1+0, 3+2 and 5+0. No custom field in the MVP, since the time model only has data for these three.
- Clocks are tracked in milliseconds. The display shows tenths under 10 s.
- A low-time sound plays once at 10% of the starting time, or at 10 s, whichever is lower.
- Your clock starts on your first move. Maia's clock starts on its first move, like Lichess.

## 6. Openings

### 6.1 Catalog

- Built from the TSVs: a searchable tree parsed from names ("Family: Variation, Sub-variation").
- Each node has a checkbox. Checking a family checks all its variations.
- Selections are saved with a name in `user://openings/`.

### 6.2 Bot opening modes

Chosen on the setup screen:

| Mode | Maia's book |
|---|---|
| Free | None. Plain Maia. |
| Catalog | The checked catalog lines |
| My repertoire | The lines of an imported PGN, on Maia's side |

The book is indexed by **position** (FEN without the move counters), so transpositions count.

### 6.3 Book weight

A **line** is one root-to-leaf path: one catalog entry, or one path through the imported PGN tree. In "My repertoire" mode the PGN's paths replace the catalog's, and everything below works the same way.

For each legal move `m` that keeps the game on a checked line:

`w(m) = 1 + (B − 1) · f(d)`, where `d` is the game's current ply number (positions are matched by FEN, so a ply count inside the line would be ambiguous after a transposition). Every other move has `w = 1`.

- `B = B_target` if `m` follows the **target line**, otherwise `B = B_other`.
- The target line is picked at game start: the checked line on Maia's side practised least often (counts are kept in stats), ties broken at random.
- Fade: `f(d) = 1` for `d ≤ 6`, then falls linearly to 0 at `d = 16`. So deep, complicated lines are not followed to the end.
- Intensity setting: weak / medium / strong, mapped to `(B_target, B_other)` = (5, 2), (20, 5), (100, 15). These are initial values.
- If the game leaves every checked line, the weights are all 1 and Maia plays freely.

### 6.4 Your repertoire

- Import a PGN with variations: comments, NAGs and several games (Lichess study chapters) are merged into one tree. At import you choose the colour.
- Toggle "check my moves against my repertoire", available in every mode.
- Nothing is shown during the game. The review shows the result (§9).

## 7. Rules (Lichess behaviour)

- Full legal-move generation: castling, en passant, promotion, check, checkmate, stalemate.
- 50-move rule: the game is drawn automatically.
- Fivefold repetition: drawn automatically.
- Threefold repetition: claimable through a "Claim draw" button. The setting "auto-claim threefold" defaults to on. Maia never claims.
- Insufficient material is an automatic draw for:
  - K vs K
  - K + one minor piece vs K
  - kings and bishops only, with every bishop on the same colour
- Flag falls when the opponent cannot mate by any legal sequence: draw. This follows scalachess's `opponentHasInsufficientMaterial`. Example: K+N vs K+R, the rook side flags, and the knight side **wins**.
- Resign: `Esc`, confirmed by a second `Esc` within 2 s.
- Nobody can abort.

## 8. Board, input and feel

### 8.1 Input

- Drag and drop is on by default. The piece follows the mouse every frame and snaps back with a tween on an illegal drop.
- Click-click moves: a setting, off by default.
- Auto-queen setting: off / on / only on premoves. The default is off, which opens the promotion picker. With auto-queen on, holding `Alt` while dropping opens the picker.

### 8.2 Premoves

- Premove style setting: off / Lichess (one premove) / Chess.com (a queue). The default is Chess.com.
- Premove targets follow piece geometry, ignoring pieces on and between squares; king squares cannot be targeted. Queued moves replace their targets in the ghost position and show as ghost pieces.
- When a queued premove turns out illegal as it comes to run, it and the rest of the queue are dropped.
- A right click cancels the whole queue.
- Premoves are played the moment Maia moves and cost 0.1 s, as on Chess.com.

### 8.3 Drawing

- Right-drag draws an arrow; a right click on one square draws a circle.
- A left click on the board clears the drawings.

### 8.4 Feedback

- Move slide animation: 120 ms by default, adjustable down to 0.
- Highlights for the last move and for a king in check.
- Legal-move dots (setting, on by default).
- Coordinates on the board.
- A material-difference counter.

### 8.5 Sounds

Events: move, capture, castle, check, promote, premove, low time, game start, game end.

### 8.6 Themes

Themes are folders in `res://themes/` (built in) or `user://themes/` (your own):
- **Board:** `theme.json` with two colours or a texture.
- **Pieces:** `wK.svg` … `bP.svg`.
- **Sounds:** one `.ogg` per event.

Defaults:
- Board: Lichess brown colours (`#f0d9b5` / `#b58863`).
- Pieces: cburnett, taken from Wikimedia Commons under BSD-3.
- Sounds: Lichess's free sets `sfx`, `nes`, `piano` and `futuristic` (AGPL) are all bundled. Bruno picks the default by ear. Lichess's `standard` set is **not free** and must not go in the repo.

All attributions go in `docs/THIRD_PARTY.md`.

### 8.7 Layout and window

- The window is resizable; the default size is 1280×800 and the minimum 800×600. The board scales with the window.
- The side panel shows Maia's clock, the move list (SAN), your clock and buttons.
- `F11` toggles focus mode: only the board and the clocks.

## 9. Game flow, review, history

### 9.1 Setup and rematch

- The setup screen picks your colour (white / black / random), the time control, the Maia level and the opening mode with its selection.
- `Space` starts a rematch with the same settings and the colours swapped.

### 9.2 Hotkeys

| Key | Action |
|---|---|
| `Space` | Rematch |
| `F` | Flip the board |
| `Esc` | Resign (press twice) |
| `F11` | Focus mode |

### 9.3 Review

After a game, a panel over the final board shows the result and reason, with Review,
Rematch, New game and close actions. Closing it leaves a Review button in the side panel.
The review screen opens on request:
- The result and the reason for it.
- The move list with these badges:
  - **Book:** the position and move appear in the catalog. The badge runs up to the point where the opening left the catalog.
  - **Repertoire:** the move matches your PGN.
  - **Left repertoire:** where you left your PGN, with the expected move or moves shown.
- Time spent on every move, for both sides.
- Buttons: Copy PGN, and Open in Lichess (a Lichess analysis page with the game's moves).

### 9.4 History and stats

- Every game is saved to `user://games/` as PGN, with `%clk` on each move. Headers: players ("Maia 1500" / "You"), `TimeControl`, `Result`, `Termination`, and the opening name.
- The level is shown as the net's name only.
- Stats per (level, time control): wins, draws and losses, plus flag wins and flag losses.
- A practice count per opening line, used to pick the target line (§6.3).

## 10. Settings

Stored in `user://settings.cfg`. Each setting with its default:

| Setting | Default |
|---|---|
| Premove style | Chess.com |
| Click-click moves | off |
| Auto-queen | off |
| Legal-move dots | on |
| Animation length | 120 ms |
| Board, pieces, sounds | brown, cburnett, chosen by ear |
| Volume | 20 % |
| Threshold `τ` | 2% |
| Temperature `T` | 1.0 |
| Panic intensity | medium |
| Book intensity | medium |
| Auto-claim threefold | on |
| Check my repertoire | off |

## 11. Tests

`tests/run.gd` is a minimal `SceneTree` runner, with no add-on. It runs with:

```
godot --headless -s tests/run.gd
```

and exits with a non-zero code when a test fails.

- **Perft:** the start position to depth 4 (197,281 nodes), and Kiwipete plus positions 3–6 from the Chess Programming Wiki at depth 3. Depths are kept low enough for CI.
- **Rules:** each draw rule, and the insufficient-material and flag cases in §7, including K+N vs K+R.
- **Notation:** FEN round-trip, SAN in and out (disambiguation, check `+` and mate `#`), and the PGN parser with nested variations and `%clk`.
- **Bot:** the move picker (weights, cut, temperature and renormalisation, with a seeded RNG), the book weight and its fade, and the bounds of the time model.

## 12. CI (GitHub Actions)

- **Every push:**
  - Ubuntu runner with Godot 4.7 headless runs the tests.
  - The Windows build is exported with the export templates and uploaded as an artifact (code only, without the engine).
- **`v*` tags:** the same build plus `fetch-engine` output is zipped and attached to a GitHub release.
  - The zip ships Lc0 and the Maia nets unmodified, with their `COPYING` files, and `THIRD_PARTY.md` links the exact upstream source tags. That is required because both are GPL-3.
- `.gitignore`: `engine/lc0/`, `engine/weights/`, `.godot/`, `build/` (`engine/uci.gd` is committed, §2).

## 13. Build order

| # | Milestone | Done when | Tickets |
|---|---|---|---|
| M1 | Core rules, test runner, CI test job | Perft and rule tests pass in CI | CORE-001, CI-001, CORE-002, CORE-003, CORE-004, CORE-005, CORE-006 |
| M2 | Board view: drag, animation, promotion, highlights, sounds, themes | A two-human game plays smoothly in one window | UI-001, UI-002, UI-003 |
| M3 | UCI bridge and Maia move picker | A full game against Maia; latency under 50 ms | BOT-001, BOT-002, BOT-003, BOT-004 |
| M4 | Clocks, fallback time model, game end, rematch, hotkeys, focus mode | A 1+0 game ends by flag, mate or draw correctly | CLOCK-001, BOT-005, UI-004 |
| M5 | Premoves (3 styles), click-click, auto-queen, arrows, settings screen | Every setting works and persists | UI-005, UI-006, UI-007 |
| M6 | History, stats, review screen | Badges and times are correct on saved games | HIST-001, HIST-002 |
| M7 | Opening catalog picker, saved selections, book weight, repertoire import and check | Maia follows the chosen lines and drifts off them | OPEN-001, OPEN-002, OPEN-003, OPEN-004 |
| M8 | Time-model calibration from Lichess data | `time_model.json` loaded; delays feel human | BOT-006, BOT-007 |
| M9 | Windows export and release workflow | A tag produces a downloadable zip that runs | CI-002, CI-003 |

Tickets live in `.scratch/<lane>/issues/`, one folder per sweatshop lane: `skeleton`, `core`, `bot`, `side`, and `mvp` for the `Review: human` tickets and CI-002.

The GitHub repo is created before M1's CI job, and **only after Bruno confirms** it.

## 14. Later (not in the MVP)

- **Allie 2.0 as a second engine:** run it in a Linux Docker container (CPU int8, about 6.4 GB RAM) behind a small UCI wrapper, using its think-time head for the delay. First measure RAM, milliseconds per move, and whether its timing feels human.
- **Maia-3 test:** install it, measure milliseconds per move, and decide whether it replaces Maia-1.
- **Chess.com-style review with Stockfish:** an evaluation bar, move classification and the best move.
- **Repertoire editor:** record lines by playing them on the board.
- **Adaptive rating ladder.**
- **Rebindable hotkeys.**
- **Blindfold mode:** play against Maia with the pieces hidden (move list and clocks stay).
