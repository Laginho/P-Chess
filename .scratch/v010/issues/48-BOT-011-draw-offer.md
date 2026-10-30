# BOT-011: Draw offer, answered by Maia
Stage: done
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

- 2026-10-30: The cooldown test was red with a nine-move mutant and green at ten; the live UCI test was red when score delivery was removed and green with it restored. The existing resignation session tests were updated for the action row.

- 2026-10-30 Stage 3: Standards and Spec found no blocking defect in the complete diff. Updated only the `core/game.gd` reason-list comment to include `agreement`; behavior is unchanged. A fresh gate will cover this review commit before session integration.

## Resolution

- Added the draw-offer button, ten-human-move cooldown, timed notice and deterministic Maia decision using the evaluation of the reply search; agreement ends the game before the move and is saved in PGN and stats.
- Focused tests demonstrated red/green for agreement, score parsing and delivery, decision boundaries, offer acceptance and button symbol; cooldown and score-delivery mutants were detected. Live Lc0 with maia-1100 supplied the score.
- Gate `godot --headless -s tests/run.gd`: 281 passed, 0 failed, 0 skipped; exit 0. Layout and malformed-fixture warnings appear in the log.
- Manual acceptance pending: offer in a dead-equal endgame with low clocks (accepted) and in the opening (declined); check the visible notice and side-panel layout.

Gate evidence: C:\Users\bruno\AppData\Local\Temp\bot011-stage3-gate.json

#### Resolution (2026-10-30)

Verdict: Approve

Reviewed the complete `654326dcc0459ba03ce72e7caa8389cc3f24bcd5...4a56c1e07574f5bca2d4b4fb3c0b57974c164992` diff against this ticket and spec §15.1/§15.2. Standards and Spec ran independently in parallel. All 12 changed files were examined, including documentation and tracker metadata; none was skipped. Review commit `e871769ca6acce545cb896b00d0c315241af98f0` only updates the stale reason-list comment in `core/game.gd` and records the review stage; it changes no behavior.

- Standards: 0 unresolved findings. All production and test changes respect Primary files. Every implementation commit was inspected for the test/production split; later test-only additions have the recorded mutation proof. No material smell finding or unrelated refactor.
- Spec: 0 findings. No missing requirement, incorrect behavior or scope expansion was identified.

Numbered criteria:

1. ✅ `core/tunables.gd` holds the five draw-rule constants: 10, +0.5, -1.5, 0.6 and 62.
2. ✅ The ½ button offers a draw, counts ten further human moves before re-enabling, and is disabled in setup, after game end and after engine stop. Rematch resets the offer and cooldown.
3. ✅ UCI captures the reply search's centipawn score in pawns, from the side to move, or `null` without a score. Maia snapshots that reply's score before waiting, independently of the prediction search and subsequent bridge values.
4. ✅ The pure decision sums nonpawn material on both sides and applies the specified clock/material formula and inclusive evaluation/phase boundaries. Missing evaluation declines.
5. ✅ The first returned move resolves the offer. Agreement ends the game before playing that move, saves `1/2-1/2`, `Reason: agreement` and `Termination: Normal`, and increments draws. A decline plays the reply normally.
6. ✅ The side notice uses a three-second one-shot timer; the result panel reads `Draw` / `by agreement`.
7. ✅ Maia has no path that offers a draw.

Examined callers, failure paths and cross-feature interactions: UCI queue/poll and FIFO prediction/reply searches; Maia's request snapshots, timer completion and stale-generation guards; human white/black turn selection; flag before reply, premoves and terminal games; offer cooldown, setup/rematch and engine stop; Settings arbitration and focus mode; shared resignation button paths; game-result display, History.save, PGN/Reason/Termination, stats and Review export. Focus mode already preserves required transient messages; the timed draw notice is consistent with that behavior. No new proxy or contract decision was needed.

Inspected the retained stage-2 red/green logs: session integration 15 passed/3 failed then 18/0; nine-move cooldown mutant 19/1 then 20/0; missing button symbol 19/1 then 20/0; missing live UCI score delivery 8/1 then 9/0. The associated committed tests exercise production seams. Earlier rule/parser/decision test commits and their production successors were inspected; this review did not rerun the red cases or claim new red executions.

After the documentation correction and a no-op rebase onto the session, ran the bound gate once on committed `e871769ca6acce545cb896b00d0c315241af98f0`: `godot --headless -s tests/run.gd`, 281 PASS records, 0 failures, 0 SKIP records, exit 0. The log contains the existing layout warning and malformed theme/time-model fixture warnings, with no script errors. The stage-3 receipt records the tested commit, matching SHA-256 log and exit status. The original stage-2 receipt was also validated before the comment correction. Only tracker/ledger metadata changes after the final tested tree.

Integrated with `--no-ff` into `sweatshop/v010/2026-10-30-1831` as `38c4b2b4cee685e54db8f2c5e1a68accc971a45a`; no conflict, PR or push. The merge tree matches the tested commit. This closure changes only this ticket and the feature ledger.

Acceptance: pending | Automated contract checks pass. Running-application checks remain: offer in the opening (declined), offer in a dead-equal endgame with low clocks (accepted), visible ½ button, three-second notice and side-panel layout. Physical input and rendered UI were not exercised in this review.
Disclosure: pending | release | [Manual verification](#verification): the product checks above remain a release condition; implementation approval permits integration into the session branch. No unresolved code finding or accepted defect deferral remains.
