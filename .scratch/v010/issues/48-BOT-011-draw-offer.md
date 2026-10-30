# BOT-011: Draw offer, answered by Maia
Stage: implementing
Blocked by: UI-013
Review: agent
Difficulty: hard

- Primary files:
  - engine/uci.gd (read `score cp` from Lc0's search)
  - bot/maia_player.gd
  - core/game.gd (`agree_draw`)
  - ui/main.gd
  - ui/main.tscn (the ½ button beside the resign button, the notice)
  - New: core/tunables.gd
  - tests/test_uci.gd
  - tests/test_maia_player.gd
  - tests/test_rules.gd
  - tests/test_session.gd
  - tests/fixtures/lc0_verbose.txt (only if a score line must be added)
  - docs/spec.md (§15.1, §15.2)

#### What to build

A ½ button beside the resign button offers Maia a draw (§15.2). Maia answers with its next move, from its own net's evaluation and a deterministic rule, and a notice says "Maia declined" or "Draw agreed". An agreed draw ends the game as a draw by agreement. Maia never offers.

**Verify first:** check that Lc0 reports a usable `score cp` in its `info` lines under `go nodes 1` with a Maia net, and record what it prints under `## Comments` before writing the rule. If it does not, ask the proxy.

#### Acceptance criteria

1. `core/tunables.gd` is created as the single home of every tunable number of spec §15; this ticket puts the draw rule's numbers there (10 moves, +0.5, −1.5, 0.6, 62).
2. The ½ button offers a draw. After an offer it stays disabled until you have made 10 more moves; it is disabled when no game is running.
3. `engine/uci.gd` reads the `score cp` of the search that produced Maia's move and hands it to the player in pawns from Maia's side. A search without a score yields no evaluation.
4. Maia's decision is a pure function of eval, board and Maia's clock: `fp = 1 − nonpawn/62` (Q=9, R=5, B=N=3, both sides), `ft = 1 − maia_left / start`, `v = (fp + ft) / 2`. It accepts when `eval ≤ +0.5 and v ≥ 0.6`, or when `eval ≤ −1.5`; otherwise, and when there is no evaluation, it declines.
5. Maia answers on the first move it returns after the offer. On "Draw agreed" the game ends at once as `1/2-1/2`, reason `agreement`, `Termination: Normal`, without playing Maia's move; the PGN's `Reason` header says `agreement` and the stats count a draw. On "Maia declined" its move is played as usual.
6. The notice shows for a few seconds in the side panel; the game-over panel says "Draw" / "by agreement".
7. Maia never offers a draw.

#### Verification

    Manual: offer a draw in a dead-equal endgame with low clocks (accepted) and in the opening (declined).
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_uci.gd`: a verbose search transcript with `score cp 34` yields +0.34 for the side to move; one without a score yields none (red: not parsed).
- `tests/test_maia_player.gd`: the decision function at the boundaries of criterion 4 (eval +0.5 / +0.51, v 0.6 / 0.59, eval −1.5, no eval) (red: no function).
- `tests/test_rules.gd`: `agree_draw()` ends the game `1/2-1/2` by `agreement`, and does nothing on a finished game.
- `tests/test_session.gd`: an offer with a fake accepting reply ends the game without Maia's move; the button stays disabled for 10 of your moves.

## Comments

- 2026-10-30 Written from spec §15.2. Decided while slicing: an agreed draw ends the game before Maia's move, as an accepted offer does on Lichess.

- 2026-10-30: Lc0 v0.32.1, maia-1100, start position, `go nodes 1`: `info depth 1 seldepth 1 time 21 nodes 1 score cp 116 tbhits 0 pv e2e4`; `bestmove e2e4`.
