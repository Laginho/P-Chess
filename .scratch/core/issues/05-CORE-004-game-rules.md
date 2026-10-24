# CORE-004: Game results and draw rules
Stage: to-review
Blocked by: CORE-003
Review: agent
Difficulty: hard

- Primary files:
  - New: core/game.gd
  - core/board.gd (insufficient-material helpers)
  - New: tests/test_rules.gd

#### What to build

`core/game.gd` plays a game on top of the board: the move history, and every way a game ends under Lichess behaviour (§7). The UI and the bot only ask the game whether it is over and why.

#### Acceptance criteria

1. Checkmate ends the game with a winner; stalemate is a draw.
2. 50-move rule: when the halfmove clock reaches 100 plies the game is drawn automatically, unless the move that reached it gives mate.
3. Fivefold repetition (the same position key a fifth time) is drawn automatically.
4. Threefold: the game reports a draw claim as available when the current position key has occurred three times; claiming ends the game drawn. An `auto_claim` flag on the game ends it as soon as a claim becomes available.
5. Insufficient material is an automatic draw for K vs K, K + one minor vs K, and kings plus bishops only with every bishop on one square colour. K+B vs K+B on opposite colours, K+N vs K+N and K+2N vs K are not drawn.
6. Flag: the side whose time ran out loses, unless the opponent cannot mate by any legal sequence (scalachess `opponentHasInsufficientMaterial`); then it is a draw. K+N vs K+R, the rook side flags: the knight side wins. Lone king, the other side flags: draw. K+N vs K+Q, the queen side flags: draw.
7. Resignation ends the game for the other side. There is no abort.
8. Each result has a PGN result string (`1-0`, `0-1`, `1/2-1/2`) and a reason (checkmate, stalemate, 50-move, repetition, insufficient material, time, resignation).

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_rules.gd`: one test per rule above from a crafted FEN or move sequence, including each flag case. Red because `core/game.gd` does not exist.

## Comments

- 2026-10-24 Stage 2, one red/green cycle, criteria 1–8: red on d852f04 (`core/game.gd` does not exist, so `test_rules.gd` fails to load; 21 passed, 1 failed), green on bccbda9 (29 passed, 0 failed). Rebased onto the session after attempt 1 as 8790ea9 (red) and 025c655 (green). Four mutants of bccbda9, each killed by the suite: fivefold at the sixth occurrence, a lone knight ignoring the opponent's pieces, bishop square colours ignored, the 50-move check before mate.
- API for UI-001, UI-004, CLOCK-001 and HIST-001: `Game.new(fen := START)`. `play(uci) -> bool` refuses an illegal move or any move after the end, changing nothing (`Board.make_move` does not check legality). `moves` is the UCI history. `is_over()`; `result` is `"*"` while the game is on, then `1-0`, `0-1` or `1/2-1/2`; `reason` is one of the seven strings of criterion 8 (fivefold and threefold both say `repetition`, a flag draw says `time`). `can_claim_draw()`, `claim_draw()` and `auto_claim` (default false: UI-004 turns it on, per §7's default). `resign(side)` and `flag(side)` take `"w"` or `"b"`, like `Board.side_to_move`. `Board.cannot_mate(side)` is scalachess's per-colour `InsufficientMatingMaterial`; the automatic draw is both sides failing it, which gives exactly criterion 5's list.
- Beyond the criteria: `play()` validation, tested by `test_play_records_legal_moves_and_refuses_the_rest`. Endings are also checked at construction, so a FEN already in mate, stalemate, insufficient material or at 100 plies starts over.
- Callers: `board.gd` only gains `cannot_mate`; no existing function changed, and nothing calls `game.gd` yet. Degenerate inputs: `Game.new` with an invalid FEN fails on a null board (no caller passes outside FENs yet). A start FEN with an en-passant square but no legal capture still counts its first repetition one short — the CORE-003 deferral, untouched here.
- 2026-10-24 Attempt 1 failed: exit 0. Log tail: ...ight-vs-rook flag, bishop colours, mate before the 50-move check). The tests caught all four. /  / **To finish:** approve the helper, or run this yourself in PowerShell from the lane folder with the `CORE-004-game-rules` branch checked out: /  / ```powershell / & 'C:\Users\Lage\.claude\skills\sweatshop\scripts\gate-evidence.ps1' -Repo 'D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\core' -Command 'godot --headless -s tests/run.gd' -Log 'C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\00f01cf5-65d9-4e7f-80a6-f69b138d9542\scratchpad\CORE-004-gate.log' -Receipt 'C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\00f01cf5-65d9-4e7f-80a6-f69b138d9542\scratchpad\CORE-004-gate.json' / ``` /  / Then I'll commit the `Gate evidence:` line and `Stage: to-review` together. The `ticket-state.ps1` lookup was blocked too, so I confirmed there was no existing CORE-004 branch with `git branch -a` instead. /  / Things to know: / - `auto_claim` defaults to off on the game, so UI-004 has to turn it on (§7 says auto-claim threefold defaults to on). / - `Game.new()` with an invalid FEN crashes. Nothing passes an outside FEN in yet.
- 2026-10-24 Attempt 2: resumed attempt 1's work from refs/sweatshop-recovery/67aa8b7f65464a20a5c3c67d6218aace, rebased onto the session (comment conflict only). Re-reviewed against criteria 1–8 and scalachess `InsufficientMatingMaterial`, no code change. Red re-proved on 8790ea9 (21 passed, 1 failed: `res://core/game.gd` does not exist); gate through the helper on ece9f75: 29 passed, 0 failed, exit 0.
- Proxy decided (opus): retry gate-evidence.ps1 once via the Bash tool in the exact allowlisted form CORE-002/003 used (`powershell -NoProfile -File "<helper>" ...`, single command, no `.exe`/`cd`/`&&`/variables); no hand-made receipt; if denied in that form, `Stage: blocked` with the command for the foreman — the receipt exists so gate evidence does not rest on the stage's word, and the earlier denials came from command shape, not the helper. That form ran.
- Follow-up for the foreman (impact none on this ticket): the driver allowlists only `Bash(powershell:*)` / `PowerShell(powershell:*)` prefixes, so `powershell.exe`, the PowerShell tool's `&`, `cd ... &&` or `$VAR` forms of the helper are denied headless; naming the working form in ticket-flow's "Gate evidence at handoff" would save the next lost attempt.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\d39f98d4-b128-4c71-854c-be8e2230cca3\scratchpad\CORE-004-gate.json
