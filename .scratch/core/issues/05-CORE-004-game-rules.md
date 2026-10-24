# CORE-004: Game results and draw rules
Stage: to-implement
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
