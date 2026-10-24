# CORE-004: Game results and draw rules
Stage: done
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

- Proxy decided (opus): defer the null-board crash in Game.new(fen) on a FEN that Board.from_fen rejects, with no follow-up ticket — only an outside FEN reaches it, no planned caller (UI-001, UI-004, CLOCK-001, HIST-001) passes one, and it joins the CORE-002/CORE-003 outside-FEN deferrals under the same trigger; a CLEAN cycle or a behaviour fix in review would cost more than the defect.

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents and found nothing to fix. Standards raised two judgement calls and kept both as they are: string-built piece lists in `cannot_mate`, which match `make_move`'s `castling.replace`, and one test message, which is accurate. I also read the whole diff myself and checked `cannot_mate` case by case against scalachess's per-colour `InsufficientMatingMaterial`. I made no code changes in review.

Criteria:

1. ✅ `test_checkmate_wins_and_stalemate_draws`: fool's mate gives `0-1` and scholar's mate `1-0`, both `checkmate`; Qf7 stalemate gives `1/2-1/2 stalemate`. `_after_move` uses production `legal_moves()` and `in_check()`.
2. ✅ `test_fifty_move_rule_draws_at_100_plies_unless_the_move_mates`: at 99 plies the game is on, and a quiet move draws `50-move`. Rh8# on the 100th ply wins, because mate is checked before the clock, in scalachess's order (`Situation.status`).
3. ✅ `test_fivefold_repetition_draws_automatically`: the game is on after the fourth occurrence and drawn `repetition` on the fifth, with `auto_claim` off.
4. ✅ `test_threefold_repetition_is_a_claim_unless_auto_claim_is_on`: `claim_draw()` on a second occurrence does nothing; `can_claim_draw()` is false at two occurrences and true at three; the game does not end by itself; the claim ends it `repetition`. With `auto_claim` on, the third occurrence ends it.
5. ✅ `test_insufficient_material_draws_automatically`: K vs K, K+B vs K, K+N vs K, K+B vs K+B same colour and K+2B vs K same colour are drawn. K+B vs K+B opposite, K+N vs K+N and K+2N vs K play on, and so does a capture that leaves K vs K. The draw requires both sides to fail `cannot_mate`. Going through the cases, that gives exactly the scalachess board rule: kings and minors only, with one non-king piece at most, or kings and bishops only with none on opposite colours.
6. ✅ `test_flag_loses_unless_the_opponent_cannot_mate`: white flagging at the start loses `0-1`. All three cases from the criterion pass: K+N vs K+R with the rook side flagging is `1-0`; a lone king opponent is a draw; K+N vs K+Q with the queen side flagging is a draw. `flag(side)` asks `cannot_mate` of the opponent, as lila's out-of-time finisher does.
7. ✅ `test_resignation_ends_the_game_for_the_other_side`: both colours are tested; `has_method("abort")` is false.
8. ✅ Every test checks `[result, reason]` together. The seven reason strings are exactly the ones in the criterion.

Test-first: I checked `diff --stat` on every commit:
- 8790ea9: `tests/test_rules.gd` and the Stage line only (red).
- 025c655: `core/board.gd` and `core/game.gd` only.
- ece9f75, 9ffd39a: the ticket only.
- 5f2dbe1: the `--no-ff` merge into the session.

All three code files are in Primary files.

Examined:
- Callers: `board.gd` only gains `cannot_mate`, and no existing function changed; `test_fen.gd` and `test_perft.gd` stay green. Nothing outside the tests calls `game.gd` yet. The planned callers use its API as follows: UI-001 reads result/reason, UI-004 uses claim, resign and `auto_claim`, CLOCK-001 uses `flag`, and HIST-001 reads `moves`.
- Failure paths:
  - `play()` refuses illegal moves and anything after the end, leaving the board and `moves` unchanged, so `Board.make_move`'s missing legality check is never exposed.
  - `resign`, `flag` and `claim_draw` after the end change nothing.
  - `can_claim_draw()` always finds its key, because the constructor records the start position.
  - `Game.new` on an invalid FEN crashes on a null board. The proxy deferred it; see the Disclosure below.
- Rule order: stalemate on the 100th ply reports `stalemate`, and insufficient material comes before repetition. Both orders give a draw either way and follow scalachess.
- Cross-feature: repetition keys come from `position_key()`, which includes the en-passant square only when the capture is legal (CORE-003), so positions reached by play compare correctly. The CORE-003 outside-FEN en-passant deferral is untouched.
- Performance: each `play()` generates legal moves twice, once to validate and once in `_after_move`. The suite still runs in seconds.
- Not examined: the Linux CI run (CI-001 is not built yet), and setting `auto_claim` mid-game when a claim is already available (the game ends at the next move; UI-004 sets it once, as a constant).

Red-green, from stage 2 and checked here: red at 8790ea9, because `res://core/game.gd` does not exist, so `test_rules.gd` fails to load (21 passed, 1 failed). Green at 025c655 (29 passed, 0 failed). Stage 2 also killed four mutants: fivefold at the sixth occurrence, a lone knight ignoring the opponent's pieces, bishop square colours ignored, and the 50-move check placed before mate.

Gate: the stage-2 receipt above (ece9f75, exit 0, log hash checked: `D8B29113…088D`) still holds. The ticket branch already sat on the session tip, and only this ticket changed after ece9f75. Result: 29 passed, 0 failed.

Proxy decided lines: two. One is the gate-evidence invocation form (attempt 2); the other is the deferral of the invalid-FEN crash in `Game.new`. The ticket's other comment, the gate-evidence follow-up, is about the skills repo, not this ticket. It is already on the foreman's Pending list (`.scratch/run-log/foreman-notes.md:22`).

Acceptance: passed | gate 29/29 on ece9f75 (receipt above): one test per rule in §7, including every flag case in §11 (K+N vs K+R)

Disclosure: decision | none | Proxy decided (opus), see ## Comments: gate evidence ran through the allowlisted `powershell -NoProfile -File` form of the helper, with no hand-made receipt. Process only; the contract is unchanged.
Disclosure: decision | none | stage-2 decision, see ## Comments (API): `Game.auto_claim` defaults to false. §7's "auto-claim threefold defaults to on" is carried by UI-004 criterion 5 (17-UI-004-setup-end-hotkeys.md), which turns it on.
Disclosure: decision | none | stage-2 decision, see ## Comments: beyond the criteria, `play()` refuses illegal moves and moves after the end (tested), and the constructor checks endings, so a FEN that is already over starts the game over.
Disclosure: deferred | none | Proxy decided (opus), see ## Comments: Game.new(fen) with a FEN that Board.from_fen rejects leaves board null, and _after_move() (core/game.gd:65) calls position_key() on null, a script error, so no game starts. Every caller today passes START or a test FEN; UI-001, UI-004, CLOCK-001 and HIST-001 use only result/reason, claim/resign/auto_claim, flag and moves, and no planned ticket feeds an outside FEN to Game.new. Fix: Game.new handles a null board (refuses or fails loudly), in the first ticket that adds outside FEN input, together with the CORE-002 counter guard and the CORE-003 en-passant fixes.
