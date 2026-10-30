# REV-003: Classify every move
Stage: to-review
Blocked by: REV-002
Review: human
Difficulty: hard
Gate evidence: C:\Users\bruno\AppData\Local\Temp\rev003-reopen-gate.json
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

- 2026-10-30 Stage 2 reopen: `63fccd0` tests a defended pawn captured after a non-capturing push; it failed with Best instead of Great before `94fc5a9` and passed afterward. `4882a86` tests free and defended en passant captures for both colours; both free captures failed with Great instead of Best before `ce9aae8` and all four cases passed afterward. The existing true-recapture and lost-mate boundary tests remain in the full gate. `ce9aae8` also moved the 0 cp mate cutoff into tunables. Gate on `ce9aae8904aaeee1d7ff01325a1e580e78e21457`: 301 passed, 0 failed, exit 0; log `C:\Users\bruno\AppData\Local\Temp\rev003-reopen-gate.log`.
- 2026-10-30 Stage 2: focused red/green cycles cover stored JSON, both colours, opening precedence and FEN-rooted repertoire, score bands and clamping, mate rules, forced and terminal positions, Miss, Great/Brilliant, all named exclusions and a pre-existing material deficit. The complete gate on `734dd43056be17c8b8520ab024f2215a8f5d5a07` passed with 299 passed, 0 failed and exit 0; log `C:\Users\bruno\AppData\Local\Temp\rev003-gate.log`.
- The initial expected loss-band examples used incorrect EP differences; commit `5f16013` corrected the test expectations, and the corrected tests were verified red against the preceding implementation before the production change. The PV2 fixture's resulting FEN was also corrected in `2890489`.
- Under the clamped EP formula, ordinary centipawn bands cannot produce a Blunder when the resulting score is at least +600 cp, or when the initial best score is at most -600 cp: the largest possible EP loss in either case is about 0.075, below the 0.20 Blunder threshold. The tests verify these boundaries do not wrongly turn an Inaccuracy into Good, and exercise the already-losing leniency branch with an allowed mate. The +600 cp would-be-Blunder case has no reachable ordinary-score fixture under this contract.

- 2026-10-30 Written from spec §15.4. Brilliant uses the simple material count; if it gives false Brilliants in play, the fallback is WintrChess's attacked-and-undefended-pieces test, reimplemented from its description (GPL-3.0, no code copied). `Review: human` because the classes are what you will judge by eye.

#### Resolution (2026-10-30)

Verdict: Reopen — criterion 5 misclassifies captures; criterion 9 leaves a named cutoff outside tunables.

- Standards: 0 documented violations and 0 actionable heuristic findings. Spec: two P2 defects in criterion 5 and one minor P3 omission in criterion 9. Independent Standards and Spec reviewers examined `3835ec0c44d211a23e41272c2e85dbf18862c677...8a7b8177feb8462b7c2efa5ce7541d11c7b359c3`; the primary reviewer read the complete diff and connected code. Coverage: total_files=7, reviewed_files=7, skipped_files=0, coverage_rate=100%. OCR delegate excluded six files as `unsupported_ext` and the fixture as `default_path`; all seven were manually reviewed using the resolved rules.
- Criterion 1: passed. Mover-relative EP, clamping, mate conversion and terminal scores are implemented, including a delivered checkmate off PV1/PV2.
- Criterion 2: passed. PV1/PV2 played-line scores override the subsequent search; loss is nonnegative.
- Criterion 3: passed apart from the criterion-5 detection defects below. The precedence chain produces one class and retains the separate repertoire marker.
- Criterion 4: passed. The classifier reuses catalog/repertoire badges, preserves the expected SAN moves and starts from the stored initial FEN. The optional badges parameter preserves its existing UI caller.
- Criterion 5: ❌ P2 at `core/classification.gd:114`: matching consecutive destination squares does not prove a recapture. From FEN `6k1/3p4/5n2/8/4P3/8/8/6K1 b - - 0 1`, play `d7d5`, then `e4d5`. The first move is a pawn push; the captured pawn on d5 is defended by Nf6. With White's PV1 `e4d5` at +100 cp and PV2 at -100 cp, the second move is returned as Best instead of Great. Check that the preceding move actually captured before excluding a recapture, and add a regression fixture distinguishing a pawn push from a true capture/recapture.
- Criterion 5: ❌ P2 at `core/classification.gd:116-120`: en passant has an empty destination, so the free-capture exclusion never examines its victim. From FEN `6k1/8/8/3pP3/8/8/8/6K1 w - d6 0 1`, `e5d6` captures the undefended pawn on d5. With PV1 +100 cp and PV2 -100 cp, it is returned as Great instead of Best. Resolve the actual captured square for en passant before checking whether the victim is defended, and add a regression fixture for the free capture.
- Criterion 6: passed. Miss uses the previous opponent class and the three configured EP/loss thresholds, replacing only Mistake or Blunder.
- Criterion 7: passed. Leniency applies only to a would-be Blunder. The documented unreachable ordinary-score +600 cp Blunder fixture is consistent with the EP clamp and bands; the already-losing mate case exercises leniency.
- Criterion 8: passed. The implemented winning-mate, lost-mate and allowed-mate rules match the written thresholds and fixture expectations.
- Criterion 9: ❌ P3 at `core/classification.gd:104`: the named 0 cp cutoff between Mistake and Blunder after losing a winning mate remains a literal. Move this cutoff into `core/tunables.gd`, as required for every threshold, without changing its value.
- Examined callers, failure paths and interactions: `engine/analyser.gd` JSON producer, side-to-move scores, terminal/forced records and storage format; `core/board.gd` legal moves, captures, en passant, attacks and material; `bot/badges.gd` catalog continuity, repertoire exit, FEN roots and the existing `ui/review.gd` caller; all new classification tests and the JSON fixture. Future accuracy/analysis UI consumers are not implemented here and were not exercised. Malformed external analysis input is not a new numbered validation requirement. No changed file was skipped.
- Verification: the existing gate receipt's commit, log SHA-256 and exit marker were verified: 299 passed, 0 failed, no SKIP marker, exit 0 on `734dd43056be17c8b8520ab024f2215a8f5d5a07`; only this tracker ticket changed afterward. The 17 implementation commits preserve test/production separation, including the documented test-harness correction. Historical red runs were not replayed. The full gate was reused because no production code changed during review.
- Targeted runtime evidence: an external Godot 4.7.2 probe validated both FENs and legal moves, printed `previous_move_captures=false`, `d5_defended_by_black=true`, the incorrect Best for the first capture, and `ep_victim=p`, `ep_victim_defended=false`, the incorrect Great for en passant. Probe: `C:\Users\bruno\AppData\Local\Temp\rev003-review-probe.gd`; output: `C:\Users\bruno\AppData\Local\Temp\rev003-review-probe.log`, exit 0. The process also reported a system certificate-store startup error; both local classification cases completed without script errors. This probe is separate from the earlier full gate.
- Handoff: retain branch `rev-003` and its implementation. Stage 2 should address the three ❌ items above with focused red/green proof for the behavioral repairs and a fresh gate receipt after production changes. No production fix was authored in review; no merge, ledger entry or push was made.

Disclosure: pending | integration | [Criterion 5 and 9 review findings](#resolution-2026-10-30): fixes for the capture-classification defects and missing tunable await stage 3 review before session integration.
Disclosure: pending | release | [Existing product acceptance](#comments): inspect classifications on a real analysed game, including Great and Brilliant sacrifices; fixture/headless checks and the external probes do not establish that visual acceptance.
