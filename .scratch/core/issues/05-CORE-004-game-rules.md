# CORE-004: Game results and draw rules
Stage: implementing
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

- 2026-10-24 Attempt 1 failed: exit 0. Log tail: ...ight-vs-rook flag, bishop colours, mate before the 50-move check). The tests caught all four. /  / **To finish:** approve the helper, or run this yourself in PowerShell from the lane folder with the `CORE-004-game-rules` branch checked out: /  / ```powershell / & 'C:\Users\Lage\.claude\skills\sweatshop\scripts\gate-evidence.ps1' -Repo 'D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\core' -Command 'godot --headless -s tests/run.gd' -Log 'C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\00f01cf5-65d9-4e7f-80a6-f69b138d9542\scratchpad\CORE-004-gate.log' -Receipt 'C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\00f01cf5-65d9-4e7f-80a6-f69b138d9542\scratchpad\CORE-004-gate.json' / ``` /  / Then I'll commit the `Gate evidence:` line and `Stage: to-review` together. The `ticket-state.ps1` lookup was blocked too, so I confirmed there was no existing CORE-004 branch with `git branch -a` instead. /  / Things to know: / - `auto_claim` defaults to off on the game, so UI-004 has to turn it on (§7 says auto-claim threefold defaults to on). / - `Game.new()` with an invalid FEN crashes. Nothing passes an outside FEN in yet.
