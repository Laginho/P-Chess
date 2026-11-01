# UI-036: Queued premoves highlight their from and to squares
Stage: to-review
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

Acceptance: pending | Capture two queued premoves and compare with Chess.com; verify a 1+0 game while Maia thinks, as specified in Verification above.
Disclosure: pending | integration | UI-036 Verification and acceptance criterion 4 require the visual comparison and manual game.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-ui036-gate.json
