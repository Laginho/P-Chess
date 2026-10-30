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

Each bucket stores the median and the log-σ of human think time. The delay is sampled from that log-normal distribution. An ordinary move waits at least `REACTION = 0.4 s` for human reaction and hand movement, after sampling either a bucket or the §4.2 formula. This is an initial value to tune by playing.

Overrides:
- With exactly one legal move, the delay is the `0.05 s` floor.
- A "premove": only when the human's last move was Maia's top prediction, Maia's own top-move probability is over 0.9, and its clock is under 10% of the starting time (§3.4), the delay is the `0.05 s` floor. Maia asks the same net about the position before the human's last move, then about its own reply, in FIFO order. Without a previous move or a prediction, this override does not apply.

Every delay is clamped to the clock left, even below the reaction or forced/premove floor: Maia never waits past its own flag. Lc0's compute time for both the prediction and reply is subtracted from the delay. It also counts against Maia's clock when it exceeds the delay.

### 4.2 Fallback

Until the calibration exists, a hand-tuned formula is used instead:

`base = clock_left / max(10, 40 − moves_played)`, plus `0.8 × increment`. That is scaled by `(1.6 − top_p)`, times log-normal noise with σ = 0.6.

### 4.3 Calibration (milestone M8)

`scripts/calibrate_time.py` runs offline:
1. Stream the start of one monthly Lichess `.pgn.zst` file (a partial download of a few GB — **ask Bruno first**).
2. Keep games at 60+0, 180+2 and 300+0 in the 1100–1900 bands.
3. Compute recorded differences from consecutive `%clk` comments for the same player, adding the increment back. First moves are untimed. The dump's clocks are whole seconds: a difference of 0 does not mean a true think time of 0.
4. Keep a seeded reservoir per `(control, Maia level, clock bin)` (`--per-stratum`, default 1,000; `--seed`, default 7). Run Lc0 with each position's full game history to get Maia's top-move probability, then split by its probability bin.
5. Fit each bucket's log-normal median and log-σ by maximum likelihood of the rounded differences. With uniform sub-second clock phase, a true time `t` records integer difference `d` with likelihood `max(0, 1 − |d − t|)`. Integrate this triangular kernel against the log-normal density using its CDF and partial expectation; group equal differences for speed. Zero differences enter unchanged, without the old 0.05 s clamp. An all-zero bucket has its likelihood supremum at zero; serialize a finite positive median of 0.000001 s and σ = 0. The game's reaction/premove rules still apply.
6. Write `data/time_model.json`, including each bucket's sample count. Buckets below `--min-samples` (default 50) are omitted and use the formula fallback.

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
- Board resize: a grip on the board's bottom-right corner lets you drag the board bigger or smaller (`nwse-resize` cursor). The side panel takes the remaining width, the board stays square, and it never drops below the minimum size or goes past what the window fits. The chosen size is saved in settings and restored on the next launch. Double-clicking the grip resets to the default fit-to-window.
- The side panel shows Maia's clock, the move list (SAN), your clock and buttons.
- `F11` toggles focus mode: only the board and the clocks.

## 9. Game flow, review, history

### 9.1 Setup and rematch

- The setup screen picks your colour (white / black / random), the time control, the Maia level and the opening mode with its selection.
- `Space` starts a rematch with the same settings and the colours swapped.
- Match score: consecutive rematches form a match. The game-over panel (§9.3) shows the running score between the two players (for example "2 – 1"), and from the first rematch onwards the game side panel shows each player's score in a small box beside their name. A win counts 1 and a draw ½ to each side. The score resets on New game, on any settings change, or when you return to Home. It is not saved across launches.

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
- **More engines:** pick the main analysis engine, or analyse one game with several.
- **Training-pal stats:** win rate per colour, time-scramble performance, clutch moments, brilliant-move highlights, most-played openings and where you leave your repertoire.
- **Import accounts** from chess.com, Lichess and chess24, several per site, each deletable on its own.
- **Portuguese translation** of the UI.
- **Adaptive rating ladder.**
- **Rebindable hotkeys.**
- **Blindfold mode:** play against Maia with the pieces hidden (move list and clocks stay).

The Stockfish review and the repertoire editor moved into v0.1.0 (§15).

## 15. v0.1.0: Stockfish review, history and home screen

Decided in a grilling session on 2026-10-29. Each patch below ships as its own `v0.0.x` tag; `v0.1.0` closes the set.

This section supersedes, where they conflict:
- §3.1: `fetch-engine.ps1` also fetches Stockfish.
- §7: resigning also has a button; `Esc` twice still works.
- §9.1: the app opens on the home screen; the setup screen becomes "Custom game". `Space` rematch is unchanged.
- §9.3: the review is replaced by §15.6.
- §9.4: the player header holds your name, not "You", and the PGN gains `Reason`, `PracticeTarget` and `HumanColor` headers and a repertoire snapshot file (§15.7, §15.8).
- §10 and §12: the settings and the release additions below.

UI strings stay English only (Portuguese is in §14).

### 15.1 Patches

| Tag | Content |
|---|---|
| v0.0.2 | Draw offer and resign buttons (§15.2), match score (§9.1), board resize grip (§8.7) |
| v0.0.3 | Stockfish fetch and release, analysis engine, analysis files (§15.3) |
| v0.0.4 | Move classification and accuracy, headless (§15.4, §15.5) |
| v0.0.5 | The new review screen (§15.6) |
| v0.0.6 | History screen and analysis queue (§15.7) |
| v0.0.7 | Home screen, profile, your name, the searching screen (§15.8) |
| v0.0.8 | Repertoire from opening names, with a board to view it (§15.9) |
| v0.0.9 | Repertoire editor (§15.9) |
| v0.1.0 | Tune every threshold by playing |

Every tunable number in §15 (analysis budget, convergence, classification thresholds, the draw rule) lives in one constants file.

### 15.2 Draw offer and resign

- The side panel shows a resign button (flag) and a draw-offer button (½) between the clocks.
- **Resign** asks for a second click within 2 s, like `Esc`.
- **Draw offer:** at most one offer per 10 of your moves. Maia answers on its next move, and a notice says "Maia declined" or "Draw agreed". An agreed draw ends the game as a draw (`Termination: Normal`, reason "agreement") and counts as a draw in the stats.
- Maia never offers a draw.
- **Maia's decision** uses its own net's evaluation, the `score` Lc0 reports with each move (from Maia's side, in pawns):
  - `fp` = 1 − (non-pawn material on the board / 62), counting Q=9, R=5, B=N=3;
  - `ft` = 1 − Maia's clock left / its starting time;
  - `v = (fp + ft) / 2`.
  - Maia accepts when `eval ≤ +0.5` **and** `v ≥ 0.6`, or always when `eval ≤ −1.5`. Otherwise it declines. The rule is deterministic.
- **Verify first:** `engine/uci.gd` does not parse `score` yet. Check that Lc0 reports a usable `score cp` under `go nodes 1`.

### 15.3 Analysis engine

- **Engine:** Stockfish 19, the Windows `x86-64-universal` build (it picks the CPU path at runtime; the NNUE net is embedded). GPLv3, shipped unmodified with its `Copying.txt`. `fetch-engine.ps1` pins the release URL and the SHA-256 of the zip and the exe, like Lc0. `THIRD_PARTY.md` links the `sf_19` source tag.
- **Protocol:** UCI through the same bridge as Lc0. Stockfish 19 kills its own process on a malformed FEN or command, so the app validates every position before sending it.
- **Search:** `MultiPV 2`. Each game starts with `ucinewgame` and keeps the hash for the whole game. Positions are analysed **backwards**, from the last to the first, as Lichess does.
- **Budget:** a fixed 3M nodes per position, with no setting. The search stops early once it has reached depth 12 and the last 3 completed depths have the same best move and an expected-points change under 0.01.
- **Threads:** "Background" uses 1 thread; "Max" uses the logical cores − 1. No GPU (Stockfish is CPU only).
- **Speed** on the i5-12400F, roughly 6M nodes/s on 10 threads: up to ~40 s per 40-move game on Max, ~5 min on Background. Convergence should cut that. These numbers are this machine's.
- **Storage:** `user://analysis/<game file name>.json` holds, for every position, both PV lines with their scores and best moves, plus the engine version and the node budget. A file whose version or budget differs from the current one is **stale**. The PGN is never touched.
- **When:** analysis runs only when asked (§15.6, §15.7), never on its own after a game.

### 15.4 Move classification

Both sides are classified, so you and Maia both get accuracy.

- **Expected points (EP)** from the mover's side: `EP(cp) = 1 / (1 + e^(−0.00368208·cp))` (Lichess's win%), with cp clamped to ±1000.
- **Mate scores and game ends** enter EP, accuracy and the convergence check as ±1000 cp: mate-in-N for the mover is +1000, being mated is −1000. A position where the game is over is scored directly: checkmate given is +1000 for the side that gave it, any draw is 0. The mate-in-N rules below still grade the classes.
- **Loss** = `max(0, EP(PV1 before the move) − EP(after))`. When the played move is PV1 or PV2, use that line's score so depth noise doesn't count.

| Class | Rule |
|---|---|
| Forced | The only legal move |
| Book | The position and move are in the catalog, and every earlier move was book |
| Repertoire | The move matches your repertoire; same icon as Book, in blue |
| Best | The played move is PV1 |
| Excellent | Loss ≤ 0.02 |
| Good | Loss ≤ 0.05 |
| Inaccuracy | Loss ≤ 0.10 |
| Mistake | Loss ≤ 0.20 |
| Blunder | Loss > 0.20 |
| Great | PV1 was played and PV2 loses ≥ 0.10 (the only good move) |
| Brilliant | A piece sacrifice that is the best move (see below); outranks Great |
| Miss | The opponent's last move was a Mistake or Blunder, your EP before the move was ≥ 0.75, and the move drops you to ≤ 0.6 with a loss ≥ 0.10. Replaces Mistake or Blunder |

These thresholds are chess.com's published expected-points table. Unlike chess.com, they do not depend on rating.

- **One class per move**, the first that applies in this order: Forced, Repertoire, Book, Brilliant, Great, Best, then the loss bands (Excellent to Blunder) after the Miss and Lenient Blunder adjustments. Book and Repertoire replace the engine class; the summary counts each move once, under its class.

- **Great and Brilliant are never given when:**
  - PV2 is still ≥ +700 cp for the mover (winning anyway);
  - the mover is below EP 0.5 after the move;
  - the mover was in check;
  - the move is a promotion, or simply takes a free piece or recaptures.
- **Sacrifice test for Brilliant:** play the move plus PV1 on `core/board.gd`, up to a fixed number of plies (a constant, default 4) or the end of PV1. It is a sacrifice when the mover's non-pawn material balance (own minus the opponent's) is lower there than in the position before the move. A deficit the mover already had does not count. If this gives too many false Brilliants, switch to an attacked-and-undefended-pieces test (WintrChess's approach).
- **Lenient Blunder:** a would-be Blunder becomes Good when the mover is still ≥ +600 cp after the move, or was already ≤ −600 cp.
- **Mates**, in mate-in-N:
  - Winning mate to winning mate: Best if not slower, Excellent if up to 2 moves slower, Good otherwise.
  - Losing a winning mate: graded by the resulting cp. ≥ 800 Excellent, ≥ 400 Good, ≥ 200 Inaccuracy, ≥ 0 Mistake, otherwise Blunder.
  - Allowing a mate: mated in ≤ 2 is a Blunder, in ≤ 5 a Mistake, otherwise an Inaccuracy.
- **Left repertoire** stays a separate marker, on the move where you left your repertoire, with the expected moves shown.

These rules are restated from public descriptions (chess.com's help pages, Lichess, Chesskit, WintrChess). No code is copied: Chesskit is AGPL-3.0 and WintrChess GPL-3.0.

### 15.5 Accuracy

Lichess's formulas (`AccuracyPercent.scala` in lila). Win% is `100·EP`, so drops and the std-dev below are in percentage points (0–100), not EP's 0–1.
- **Per move:** 100 when the win% did not drop. Otherwise `103.1668·e^(−0.04354·drop) − 3.1669 + 1`, clamped to 0–100.
- **Per game:** the mean of the volatility-weighted mean and the harmonic mean of that side's move accuracies. The window is plies/10 rounded down, clamped to 2–8. The win% series starts at the initial position; windows slide over it one ply at a time, and the first window is repeated so the opening plies also get one, as in lila. A move's weight is the std-dev of win% in its window, clamped to 0.5–12.

chess.com's CAPS2 is not published.

### 15.6 Review screen

- **Layout:** copies chess.com's game review.
- **Board:** steps through the moves with ←/→. The **eval bar is on the left** of the board, and it and the graph follow the board's orientation.
- **Graph and move list:** a clickable eval graph that jumps to the move, and a move list with a classification icon on every move.
- **On the board:** the classification icon on the destination square, and an arrow for the best move.
- **Summary:** each side's accuracy, and the count of moves per class.
- A "?" tooltip next to the accuracy and the class counts explains in plain English how each is computed and the thresholds.
- Copy PGN and Open in Lichess stay. Rematch and New game appear only when the review was opened from the post-game panel, whose game settings are still in memory; a review opened from the history has neither, and `Space` does nothing there; it has a **Back to History** button instead, also on `Esc`. There is no coach text and no retry.
- **Icons:** our own SVGs in chess.com's style and colours; chess.com's icons are proprietary.
- **Entry points:**
  - The post-game panel's **Review** button opens it and starts analysing at once on Max. Moves fill in as their analysis lands.
  - From the history, a game without analysis that is not queued opens with an **Analyze** button. Pressing it analyses the game on Max ahead of the queue, as in §15.7.

### 15.7 History screen and analysis queue

- **Tabs:** All, 1+0, 3+2 and 5+0. The default tab is a setting.
- **Each game card shows:**
  - a thumbnail from your side of the board, at the deepest ply that still matches a catalog opening, with the last move highlighted;
  - the opening name, only when the game matched the catalog. Without a match there is no name and the thumbnail shows ply 10;
  - the date, each player's colour, "{name} x Maia 1500", the result and reason, and the number of moves;
  - the analysis state: not analysed / queued / analysing x% / both accuracies / stale.
- **Actions per game:** Review, Analyze (Re-analyze when stale), Delete with confirmation, and Copy PGN as a discreet square icon that is still easy to hit. Delete removes the PGN, its analysis, and its share of the stats (read back from the PGN headers) and of the practice counts, so the profile always matches the history.
- **Practice target in the PGN:** from v0.0.6, a game played with a target line (§6.3) records its id in a `PracticeTarget` header, so Delete can take it off the practice counts. Games saved earlier have no such header; deleting one leaves the practice counts as they are.
- **Result reason:** from v0.0.2 every PGN records `game.reason` (`checkmate`, `resignation`, `time`, `agreement`, `repetition`, `stalemate`, `50-move`, `insufficient material`) in a `Reason` header, since `Termination: Normal` alone cannot tell an agreed draw from a claimed repetition. For older games the card replays the moves: checkmate, stalemate, insufficient material and the 50-move rule are read off the final position, a decisive `Normal` game that is not mate is a resignation, and any other draw shows just "Draw".
- **Repertoire snapshot:** from v0.0.5, when a game is played with a repertoire loaded, its lines (the snapshot `ui/main.gd` already keeps for the review) are saved next to the PGN as `<game file name>.repertoire.json`. A review opened from the history checks Repertoire and Left repertoire against that file, never against the repertoire as it is now. Games without the file get no repertoire markers. Delete removes it with the PGN.
- **Batch:** select several games, or use **Analyze all** per tab.
- **Queue:**
  - Games run one at a time, in the thread mode set in the settings (Background by default).
  - Clicking Review on a queued game, or Analyze inside the review of an unqueued one, jumps it ahead on Max; the batch then resumes where it stopped.
  - The queue pauses while a game is played and resumes after it, and also survives restarting the app.

### 15.8 Home screen, profile and your name

- **Home screen:** the app opens on it.
  - Quick-play buttons for 1+0, 3+2 and 5+0 reuse your last level, colour and opening mode. The first time they use Maia 1500, a random colour and Free mode. A small level selector sits next to them.
  - Also: Custom game (today's setup screen), History, Profile, Settings and Quit.
- **Searching screen:** shown between the click and the game for at least 0.5 s. Its message follows the real work: pausing the analysis, loading the Maia net, preparing the game.
- **Your name:**
  - On first launch, a dialog asks for it, prefilled with "You". It has only OK, no skip.
  - The name changes in the Profile.
  - New PGNs write it in the player header, plus a `HumanColor` header (`w` or `b`), since a name such as "Maia 1500" could match the opponent's. Stats, thumbnails and Delete read your side from `HumanColor`; older PGNs have none, and there your side is the one named "You". Old PGNs keep "You" in the file but show the current name.
- **Profile:** your name, W/D/L per level and time control (with flag wins and losses), and your accuracy over time.

### 15.9 Repertoire from names, viewer and editor

- **v0.0.8, from names:**
  - The repertoire screen gets a **From openings** button next to Import PGN. It opens the catalog picker with names only, as on Lichess ("Caro-Kann Defense: Advance Variation"), without the move sequence.
  - You check lines, pick your colour and a name. It is saved like an imported repertoire, so "check my moves" and the review badges work with it.
- **v0.0.8, viewer:** a board beside the list, from the repertoire colour's side. Clicking a name shows the line's final position, and ←/→ steps through it.
- **v0.0.9, editor:**
  - Start from a checked line or the start position, and play moves on the board to extend a line or add a branch.
  - A tree list shows the branches. Right-clicking a move deletes it and everything after it.
  - It works on every repertoire, imported or built from names, and saves in the same format.
  - No comments, NAGs or main-line marking.

### 15.10 Settings added

| Setting | Default |
|---|---|
| History default tab | All |
| Batch analysis threads | Background (1 thread) |
| Board size (§8.7) | Fit to window |

### 15.11 Tests

- **Classification and accuracy:** headless tests on fixed engine output (fixture JSON). CI has no Stockfish.
- **Also covered:** the convergence rule, the draw rule, the history thumbnail ply, and deleting a game from the stats.
