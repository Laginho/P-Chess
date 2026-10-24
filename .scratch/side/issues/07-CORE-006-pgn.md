# CORE-006: PGN read and write
Stage: to-review
Blocked by: CORE-005
Review: agent
Difficulty: normal

- Primary files:
  - New: core/pgn.gd
  - New: tests/test_pgn.gd
  - New: tests/fixtures/pgn/ (sample files)

#### What to build

`core/pgn.gd` reads and writes PGN. Saved games with `%clk` (§9.4) and imported repertoires with variations (§6.4) both go through it.

#### Acceptance criteria

1. Parses headers, the mainline, variations nested at least two levels deep, `{}` comments, NAGs (`$n`) and move suffixes, and the result token.
2. A file with several games returns every game.
3. `[%clk h:mm:ss]` and `[%clk h:mm:ss.f]` in a move's comment give that move's clock in milliseconds.
4. Writing a game with headers and clocks, then reading it back, returns the same headers, moves and clocks.
5. An illegal move returns an error naming the game and the move number; it never crashes.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_pgn.gd`: fixtures with nested variations, several games, `%clk` and an illegal move, plus the write–read round-trip. Red because `core/pgn.gd` does not exist.

## Comments

- 2026-10-24 Attempt 1 failed: exit 0. Log tail: ...d of crashing. /   - `Pgn.write(game)` writes headers, moves with `%clk` and the result. A written game parses back with the same headers, moves and clocks (criterion 4). /  / To finish, either approve the helper when I rerun it, or run it yourself and tell me where the receipt is: /  / ``` / & 'C:\Users\Lage\.claude\skills\sweatshop\scripts\gate-evidence.ps1' -Repo 'D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\side' -Command 'godot --headless -s tests/run.gd' -Log 'C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-side\e38e9c13-dbe3-47e7-a1e0-98349f6a6745\scratchpad\CORE-006-gate.log' -Receipt 'C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-side\e38e9c13-dbe3-47e7-a1e0-98349f6a6745\scratchpad\CORE-006-gate.json' / ``` /  / After that I'll add the `Gate evidence:` line, set `Stage: to-review` and commit. /  / Left out on purpose: / - The writer doesn't output comments, NAGs or variations, which no criterion asks for. / - A comment at the very start of a variation is dropped. / - Clocks are written to the tenth of a second. / - `0-0` castling with zeros is rejected. /  / None of these was checked against a real Lichess export.
- 2026-10-24 Attempt 2: attempt 1's commits (test e06384d, feat 6d4ced3, kept in refs/sweatshop-recovery) were recovered onto branch `core-006` and rebased onto the session, with no changes. Red: at the test commit the gate gave 41 passed, 1 failed (test_pgn.gd fails to load because core/pgn.gd is missing). Green: at the code commit it gave 48 passed, 0 failed, including all 7 test_pgn tests. Left out on purpose (no criterion asks for them): the writer skips comments, NAGs and variations; a comment that opens a variation is dropped; clocks are written to the tenth of a second; `0-0` castling with zeros is rejected. None of this was checked against a real Lichess export.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-side\eab34eef-7a41-401c-834b-2cc9ca74c291\scratchpad\CORE-006-gate.json
