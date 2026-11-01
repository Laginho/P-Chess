# UI-036: Queued premoves highlight their from and to squares
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/board_view.gd (`_draw`, around the `LAST_MOVE_LIGHT/DARK` tint at line ~181)
  - tests/test_premove.gd

#### What to build

Bruno's QA of v0.0.2 (2026-11-01), item 4: a queued premove draws the ghost piece at half opacity on its target and nothing on its source, so "parece que a peça só sumiu e não tem como ver quem eu mexi".

As on Chess.com, every queued premove tints its from and to squares in a premove colour (Chess.com's reddish premove tint, a light and a dark variant like `LAST_MOVE_LIGHT/DARK`), drawn over the last-move tint. Works for both premove styles (Lichess's single replacing premove and Chess.com's queue). The tint goes away when the premove plays, is cancelled, or is dropped as illegal.

#### Acceptance criteria

1. With one premove queued, its from and to squares draw the premove tint; with three queued (Chess.com style), all six squares do.
2. When a premove plays, is cancelled (right click) or is dropped, its tint is gone on the next draw.
3. Both board orientations; both premove styles.
4. A capture of a board with two queued premoves compared by eye with a Chess.com premove. Gate green.

#### Verification

    Manual: a 1+0 game, queue two premoves while Maia thinks; their squares are tinted.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_premove.gd`: after queueing a premove, the board reports its from and to squares as highlighted (expose the set the draw uses; red: no such highlight exists).

## Comments

- 2026-11-01 Written from Bruno's QA of v0.0.2 (item 4).
- Red: focused premove tests reported 24 passed, 1 failed before the highlight set existed. Green: 25 passed, 0 failed.
- Gate: 490 passed, 0 failed; graphical pixel check and live Lc0 tests skipped in the headless environment without Lc0.

Acceptance: passed | Stage 3 completed reviewer visual comparison and the live 1+0 scenario using automated pointer input against real Lc0/Maia, both human colours; evidence and limits below.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-ui036-gate.json

#### Resolution (2026-11-01)

Verdict: Approve

- Reviewed complete `git diff 58deb41...d7bc989`: ticket, `tests/test_premove.gd`, `ui/board_view.gd`. Standards and Spec reviewed independently by the two code-review agents; no production changes authored during review.
- Standards: no actionable documented-standard violations or heuristic smells. Commit split confirmed: `a1ad01f` tests plus stage metadata, `62b6697` production only, `d7bc989` handoff only. Stage-2 red result (24 passed, 1 failed) is supplied evidence; stage 3 independently reran the focused file: **25 passed, 0 failed**, exit 0.
- Spec: all four numbered criteria satisfied; no scope creep or code findings. Examined queue enqueue/replacement, `take`/illegal-tail clearing, board `_submit`/`_commit`/`cancel_premoves`, Main `_on_maia_move`/`_on_move_played`/`_next_turn`/`_show_result`, style settings, ghost-piece projection, last-move overlay and flipped coordinate mapping.
- Criterion 1: focused test covers three queued moves/six squares. Real live-game captures show two queued knight moves/four tinted endpoints, with visible half-opacity destination pieces.
- Criterion 2: focused test covers played, cancelled and illegal-dropped queues. Graphical routed right-click checks prove the next rendered frame restores the underlying last-move colour.
- Criterion 3: graphical pixel checks passed for Chess.com and Lichess, each unflipped and flipped. A queued `e4e5` proves premove tint overrides the existing last-move tint on `e4`.
- Criterion 4: reviewers inspected the [white capture](C:/Users/bruno/AppData/Local/Temp/p-chess-ui036-review/live-w-two-premoves.png) and [black capture](C:/Users/bruno/AppData/Local/Temp/p-chess-ui036-review/live-b-two-premoves.png) beside the premove illustration in [Chess.com Help](https://support.chess.com/en/articles/8562432-what-are-pre-moves-and-how-do-they-work). Reddish origins and destinations are clear in both orientations and distinct from yellow last-move squares. The earlier integration disclosure is resolved by this evidence.
- Live verification used graphical Godot/OpenGL at 1000x800, installed Lc0 with Maia 1500 and real 1+0 clocks. `Viewport.push_input` routed pointer drags through the rendered game. White: `e2e4 e7e5 g1f3 f8c5 b1c3`; black: `e2e4 g8f6 b1c3 b8c6`. Both queued moves played naturally after Maia replies; engine policy latencies were recorded. No fake engine, injected reply or changed think time in these live runs.
- Evidence: [graphical/live harness](C:/Users/bruno/AppData/Local/Temp/p-chess-ui036-review/review.gd), [graphical/live log](C:/Users/bruno/AppData/Local/Temp/p-chess-ui036-review/review.log) (**0 review failures**, exit 0), [focused log](C:/Users/bruno/AppData/Local/Temp/p-chess-ui036-review/focused.log). Temporary fixture and engine junctions removed; user data isolated under the external evidence directory.
- Gate: existing receipt/log hash, exit marker and production equality validated with `Assert-GateEvidence`; **490 passed, 0 failed**, tested commit `62b6697f245c4c0d1ec1d6e4c48251fcc3617d1c`. Headless gate originally skipped graphical pixels and live-engine tests; the separate checks above supply this ticket's graphical/live evidence. Rebase onto session was unchanged; receipt reused without another gate run.
- Limits: this was automated live pointer verification plus reviewer visual inspection, not human hands-on play. Whole-suite graphical execution, other screen sizes/themes, unrelated live-engine cases and release acceptance were not assessed. No remaining integration blocker within UI-036.
- Integrated by merge commit `3c5742272bf01c5bfd272097a2417d477f5e0288` into `sweatshop/qa-input/2026-11-01-1407`; no push or PR (session driver owns publication).
