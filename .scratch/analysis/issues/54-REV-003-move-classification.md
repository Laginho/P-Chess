# REV-003: Classify every move
Stage: to-review
Blocked by: REV-002
Review: human
Difficulty: hard
Gate evidence: C:\Users\bruno\AppData\Local\Temp\rev003-gate.json
Acceptance: pending | Review classifications by eye on a real analysed game, including Great and Brilliant sacrifices.

- Primary files:
  - New: core/classification.gd
  - core/tunables.gd (the thresholds)
  - bot/badges.gd (read-only reuse for Book, Repertoire and Left repertoire; touch only if it must expose something)
  - New: tests/test_classification.gd
  - tests/fixtures/analysis/ (hand-written or recorded JSON)
  - docs/spec.md (§15.4)

#### What to build

From a game, its analysis JSON (REV-002), the catalog and the repertoire, give every move of both sides one class (§15.4): Forced, Repertoire, Book, Brilliant, Great, Best, Excellent, Good, Inaccuracy, Mistake, Miss, Blunder. Headless, from fixture JSON.

#### Acceptance criteria

1. EP from the mover's side is `1 / (1 + e^(−0.00368208·cp))`, cp clamped ±1000; mate for the mover is +1000, being mated −1000; a game-over position uses its terminal score.
2. Loss is `max(0, EP(PV1 before) − EP(after))`; when the played move is PV1 or PV2, that line's score is used.
3. One class per move, the first that applies: Forced, Repertoire, Book, Brilliant, Great, Best, then the loss bands (≤0.02 Excellent, ≤0.05 Good, ≤0.10 Inaccuracy, ≤0.20 Mistake, else Blunder) after the Miss and Lenient Blunder adjustments.
4. Book: the position and move are in the catalog and every earlier move was book. Repertoire: the move matches the repertoire snapshot. Left repertoire stays a separate marker with the expected moves, as `bot/badges.gd` gives it.
5. Great: PV1 played and PV2 loses ≥ 0.10. Brilliant: Great's conditions plus a sacrifice: after the move plus up to 4 plies of PV1 (a constant), the mover's non-pawn material balance is lower than before the move; a deficit the mover already had does not count. Neither is given when PV2 is ≥ +700 cp for the mover, the mover is below EP 0.5 after the move, the mover was in check, or the move is a promotion, takes a free piece or recaptures.
6. Miss: the opponent's last move was a Mistake or Blunder, the mover's EP before was ≥ 0.75, and the move drops it to ≤ 0.6 with a loss ≥ 0.10; it replaces Mistake or Blunder.
7. Lenient Blunder: a would-be Blunder is Good when the mover is still ≥ +600 cp after, or was already ≤ −600 cp.
8. Mates: winning mate to winning mate is Best if not slower, Excellent if up to 2 moves slower, Good otherwise; losing a winning mate is graded by the resulting cp (≥800 Excellent, ≥400 Good, ≥200 Inaccuracy, ≥0 Mistake, else Blunder); allowing a mate in ≤2 is a Blunder, ≤5 a Mistake, otherwise an Inaccuracy.
9. Every threshold above lives in `core/tunables.gd`.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_classification.gd`, one fixture per rule: each class from a position built for it; the precedence order (Book beats Best, Brilliant beats Great); each of the five Great/Brilliant exclusions; a pre-existing deficit is not a sacrifice; Miss replacing a Blunder; both Lenient Blunder cases; the three mate cases (red: no module).

## Comments

- 2026-10-30 Stage 2: focused red/green cycles cover stored JSON, both colours, opening precedence and FEN-rooted repertoire, score bands and clamping, mate rules, forced and terminal positions, Miss, Great/Brilliant, all named exclusions and a pre-existing material deficit. The complete gate on `734dd43056be17c8b8520ab024f2215a8f5a07` passed with 299 passed, 0 failed and exit 0; log `C:\Users\bruno\AppData\Local\Temp\rev003-gate.log`.
- The initial expected loss-band examples used incorrect EP differences; commit `5f16013` corrected the test expectations, and the corrected tests were verified red against the preceding implementation before the production change. The PV2 fixture's resulting FEN was also corrected in `2890489`.
- Under the clamped EP formula, ordinary centipawn bands cannot produce a Blunder when the resulting score is at least +600 cp, or when the initial best score is at most -600 cp: the largest possible EP loss in either case is about 0.075, below the 0.20 Blunder threshold. The tests verify these boundaries do not wrongly turn an Inaccuracy into Good, and exercise the already-losing leniency branch with an allowed mate. The +600 cp would-be-Blunder case has no reachable ordinary-score fixture under this contract.

- 2026-10-30 Written from spec §15.4. Brilliant uses the simple material count; if it gives false Brilliants in play, the fallback is WintrChess's attacked-and-undefended-pieces test, reimplemented from its description (GPL-3.0, no code copied). `Review: human` because the classes are what you will judge by eye.
