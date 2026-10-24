# CORE-006: PGN read and write
Stage: done
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

Gate evidence (superseded, before the reopen): C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-side\eab34eef-7a41-401c-834b-2cc9ca74c291\scratchpad\CORE-006-gate.json

#### Review (2026-10-24)

Verdict: Reopen — criterion 1: a `{}` comment that opens a variation is dropped; criterion 4: header backslashes and millisecond clocks do not round-trip

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents, and neither found anything. I also read the whole diff and ran `Pgn.parse`/`Pgn.write` in Godot on the inputs below.

Criteria:

1. ❌ Headers, the mainline, variations three levels deep, `$n` NAGs, `!?`/`?!` as NAGs 5 and 6, `;` comments and the result all pass (`test_headers_mainline_comments_nags_and_result_parse`, `test_variations_nest_under_the_move_they_replace`). But a `{}` comment that opens a variation is read and then thrown away. `1. e4 e5 ({Better is} 1... c5) *` keeps the comment nowhere: the variation's first move and the game both have `comment == ""`. The `shortcut:` comment at `core/pgn.gd:54` says so. The criterion asks for `{}` comments with no exception, and repertoire import (spec §6.4) merges comments into the tree. Annotated exports such as ChessBase write `({Better is} 12... Nf6)`.
2. ✅ `test_every_game_of_a_file_is_returned`.
3. ✅ `test_clk_comments_give_each_move_its_clock_in_milliseconds`: `h:mm:ss`, `h:mm:ss.f`, a `%clk` after a `%eval`, and -1 when there is no clock.
4. ❌ Two ways:
   - **Headers.** A header value with a backslash before `n`, `t`, `r`, `a`, `b`, `f`, `v`, `'` or `?` comes back changed. Reading uses `String.c_unescape()` (`core/pgn.gd:47`), which decodes C escapes, but PGN escapes only `\\` and `\"`. In Godot, writing `{"Event": "C:\\new\\test", "White": "a\\tb"}` and reading it back gives `C:\` + newline + `ew\` + tab + `est`, and `a\` + tab + `b`.
   - **Clocks.** A clock whose milliseconds are not a multiple of 100 comes back changed, because `_clock_text` truncates to tenths. Spec §5 says "Clocks are tracked in milliseconds", and §9.4 saves every game with `%clk`, so most saved clocks would change. In Godot, 297534 is written as `0:04:57.5` and reads back as 297500, and 180050 is written as `0:03:00.0` and reads back as 180000. The round-trip test only uses multiples of 100, so it could not see this. The criterion can hold: `_clock_ms` already reads three decimals. Keeping tenths would be a rewrite of criterion 4, which is a question for the proxy or stage 1, not stage 2.
5. ✅ `test_an_illegal_move_is_an_error_naming_the_game_and_move_number` and `test_malformed_text_is_an_error_not_a_crash`. I also traced `before` (never null when `(` follows a move) and an invalid `FEN` header (returns an error).

What is left for stage 2: criteria 1 and 4. First a test-only commit that is red on these three things:
- a comment that opens a variation is kept where a caller can read it (stage 2 picks the field and documents it in the module header);
- headers containing `\n`- and `\t`-style backslashes round-trip;
- clocks of 297534 and 180050 ms round-trip.

Then a production-only commit in `core/pgn.gd`.

Test-first: I checked `diff --stat` on every commit:
- 1ecc613: `tests/test_pgn.gd`, the four fixtures, and the Stage line. Red: 41 passed, 1 failed, because `test_pgn.gd` cannot load without `core/pgn.gd`, as the ticket predicted.
- 51d6412: `core/pgn.gd` only.
- 28e4117: the ticket only.

All code files are in Primary files.

Examined:
- Callers: `core/pgn.gd` is new, and a grep finds no caller outside the tests. It uses `Board.from_fen`, `parse_san`, `san`, `make_move`, `copy`, `side_to_move` and `fullmove_number`, and none of them changed.
- Failure paths I ran or traced:
  - Error, no crash: unclosed or stray parentheses, an unclosed `{`, a result inside a variation, a variation before any move, and an invalid FEN.
  - Error, no crash, as stage 2 disclosed: `0-0` castling written with zeros.
  - Error, no crash: `%` escape lines and an `e.p.` suffix.
  - Parses cleanly: a Lichess-style export with CRLF line endings and `+`, `#` and `??`.
- Cross-feature: §9.4 saved games led to finding 4 (clocks). §6.4 repertoire import led to finding 1.
- Seen but not required by any criterion (stage 2 may leave these):
  - A `{}` comment before the first tag gives an extra empty game.
  - `write()` crashes on an invalid `FEN` header or an illegal uci. No criterion covers what `write` accepts, and its callers will pass the app's own games.
- Standards: the repo documents no coding standards, and the sub-agent found no smells worth a change.
- Not examined: real Lichess or chess.com export files at scale, and parse time on a large repertoire.

Gate: the stage-2 receipt above names 51d6412: exit 0, 48 passed, 0 failed. 28e4117 changed only the ticket. Review changed no code.

- 2026-10-24 Stage 2 after the reopen (opus-5.5). Test aaf360a adds three tests in `tests/test_pgn.gd`; at that commit the gate gave 48 passed, 3 failed, each failing for the reason the review gave: `comment_before` missing (got null), header values decoded as C escapes (`\n` became a newline, `\t` a tab), and clocks truncated (297534 → 297500, 180050 → 180000, 1 → 0, 3723999 → 3723900). Code afae5ef, in `core/pgn.gd` only: a comment that opens a variation is kept on that variation's first move as `comment_before` (`""` on every other move; documented in the module header), and a variation that closes with no move drops it instead of passing it to the next move. Tag values decode only `\` and `\"`, in one left-to-right regex pass. Clocks are written to the millisecond with trailing zeros dropped (`0:04:57.534`, `0:03:00.05`, `0:04:57.5`). Green: 51 passed, 0 failed. Callers: none outside the tests. Still left out on purpose (no criterion asks for them): the writer skips comments, NAGs and variations, and `0-0` castling with zeros is rejected.

Gate evidence (superseded, before the review's whitespace fix): C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-side\3c329b14-8b90-4f42-9831-e6281840b09d\scratchpad\CORE-006-gate.json

- Proxy decided (opus): defer all five out-of-criteria findings with no follow-up ticket (0-0 castling, empty game from a leading comment, write() on bad input, lone tag backslash, writer without comments/NAGs/variations) — none crashes or loses data, no planned caller hits them (OPEN-003 reads Lichess exports and already reports bad files without saving; HIST-001/002 write legal mainlines), and a stage 2 plus stage 3 cycle would cost more than the defects, as with the CORE-002/003/004 deferrals.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-side\3f72b1a6-c71b-41fd-b7c1-1577e5f7bd1b\scratchpad\CORE-006-gate.json

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5), re-review after the reopen. I checked the two ❌ items and the diff since the review, 28e4117..16f1f9d. I read the whole diff and ran `Pgn.parse`/`Pgn.write` in Godot on the review's inputs and the edge cases below. The session had not moved since the branch was cut, so no rebase was needed.

Criteria:

1. ✅ Was ❌. `test_a_comment_opening_a_variation_is_kept_on_its_first_move`: `({Better is} 1... c5 {Sicilian})` keeps `Better is` as `comment_before` on c5, and its own comment stays `Sicilian`. Every other move has `comment_before == ""`. The module header documents the field. The other parts of the criterion still pass in the first review's tests.
2. ✅ Unchanged since the first review: `test_every_game_of_a_file_is_returned`.
3. ✅ Unchanged since the first review: `test_clk_comments_give_each_move_its_clock_in_milliseconds`. `_clock_ms` was not touched.
4. ✅ Was ❌ in two ways, both fixed:
   - `test_header_backslashes_read_back_unchanged`: the review's `C:\new\test` and `a\tb`, plus `\"`, a trailing `\`, and `\a \b \f \v \' \? \r` all round-trip. Tag values now decode only `\X` → `X` (`core/pgn.gd:22,53`).
   - `test_clocks_read_back_to_the_millisecond`: 297534, 180050, 300000, 297500, 1 and 3723999 ms all round-trip. Clocks are written with up to three decimals, trailing zeros dropped (`core/pgn.gd:160`).
5. ✅ Unchanged since the first review: both error tests are green, and the new `pending` state cannot leak between games. It is set only inside an open variation, and an open variation at a new tag, at a result, or at the end of the text is already an error.

Red-green: I checked it myself. With `core/pgn.gd` from 51d6412 under the new tests, the gate gave 48 passed and 3 failed, for exactly the reasons stage 2 reported: `comment_before` was null, the backslash header dict differed, and clocks came back 297500, 180000 and 0. Green on 16f1f9d: 51 passed, 0 failed.

Test-first: I checked `diff --stat` on every commit since the review:
- 30c8c2f: the ticket only (reopen).
- aaf360a: `tests/test_pgn.gd` and the Stage line (red).
- afae5ef: `core/pgn.gd` only.
- 4bb81e3: the ticket only.
- 16f1f9d (review): `core/pgn.gd`, whitespace only (`:=RegEx` → `:= RegEx`), plus the ticket. No behaviour changed, so it needs no independent review. I reran the gate on it.

All code files are in Primary files.

Examined:
- Callers: a grep finds no use of `core/pgn.gd` or `comment_before` outside `core/pgn.gd` and `tests/test_pgn.gd`. Future consumers:
  - OPEN-003 reads `comment_before` when it merges repertoire comments.
  - HIST-001 writes clocks to the millisecond.
- Edge cases, run in Godot:
  - Two comments opening a variation (`({a} {b} 1... c5)`) join as `a b`.
  - A variation holding only a comment (`({a}) 2. Nf3`) drops it, and Nf3 has `comment_before == ""`.
  - Nested variations: `({a} 1... c5 ({b} 1... d5) 2. c3)` gives c5 `a`, d5 `b` and c3 `""`.
  - A `%clk` inside a comment that opens a variation stays text in `comment_before` and sets no clock.
  - A leading `{top}` still goes to `game.comment`.
  - Clocks of 0, 999, 1000, 59999 and 36000000 ms round-trip.
- Failure paths I ran, both deferred by the proxy (below):
  - `4. 0-0` gives `Game 1, move 4.: illegal move -0`. The tokenizer splits `0-0` into a move number `0` and a move `-0`, so `Board.parse_san` alone would not fix it.
  - A `{lead}` before the first tag makes the second real game's illegal move report as `Game 3`.
- Cross-feature:
  - §9.4 saved games: every millisecond clock now survives.
  - §6.4 repertoire import: annotations that open a variation are kept.
- Standards: the repo documents no coding standards. The only smell, the missing space, was fixed in review.
- Not examined:
  - Real ChessBase or chess.com exports at scale.
  - Whether third-party tools read `%clk` values with two or three decimals (`0:03:00.05`) as intended. The PGN %clk convention allows fractional seconds, and Lichess's "Open in Lichess" (HIST-002) sends moves only.

Gate: `godot --headless -s tests/run.gd` on 16f1f9d, exit 0, 51 passed, 0 failed, log hash `B2069ACC…ACA9A`. The `--no-ff` merge 423b152 has the same tree as 16f1f9d.

Proxy decided lines: one, under ## Comments. It defers five out-of-criteria findings with no follow-up ticket; they are the deferred Disclosure lines below.

Acceptance: passed | gate 51/51 on 16f1f9d (receipt above): the PGN parser with nested variations and `%clk`, as in docs/spec.md:282. Importing a real Lichess study belongs to OPEN-003's manual verification, and saving a real game belongs to HIST-001.

Disclosure: decision | none | stage-2 decision, see ## Comments (API): a comment that opens a variation is stored on the variation's first move as `comment_before` (`""` elsewhere; documented in the core/pgn.gd header). OPEN-003 consumes it.
Disclosure: decision | none | stage-2 decision, see ## Comments: clocks are written to the millisecond with trailing zeros dropped (`0:04:57.534`, `0:03:00.05`, `0:04:57.5`). Whole seconds are unchanged (`0:05:00`), and this file's reader reads 1–3 decimals.
Disclosure: deferred | none | Proxy decided (opus), see ## Comments: `0-0`/`0-0-0` castling is rejected as an illegal move (error, no crash). Godot confirms the tokenizer reads `0` as a move number and `-0` as the move (core/pgn.gd:17-19), so the fix belongs in the pgn.gd tokenizer, not only in Board.parse_san. Lichess and chess.com write `O-O`, and OPEN-003 criterion 5 reports such a file and saves nothing. Trigger: a reported import failure, or the first ticket that reads non-Lichess PGN.
Disclosure: deferred | none | Proxy decided (opus), see ## Comments: a `{}` comment before the first tag pair yields an extra empty game holding that comment, so error messages for that file name a game one too high (confirmed in Godot). OPEN-003 merges the empty game as nothing, and HIST-001 files never start with a comment. Same trigger as above.
Disclosure: deferred | none | Proxy decided (opus), see ## Comments: Pgn.write() script-errors on an invalid FEN header or an illegal uci. Its callers (HIST-001, HIST-002) pass only games built by Game. Fix it with the CORE-002/003/004 outside-input group, in the first ticket that feeds outside input.
Disclosure: deferred | none | Proxy decided (opus), see ## Comments: a lone backslash in a third-party tag value (non-conforming per PGN §7), e.g. `C:\new`, reads as `C:new` (confirmed in Godot). Headers we write round-trip (tested). Fix: narrow `_escape` to `\\([\\"])`, in the first ticket that touches the PGN reader.
Disclosure: deferred | none | Proxy decided (opus), see ## Comments: Pgn.write() does not write comments, NAGs or variations (`shortcut:` at core/pgn.gd:120). No planned ticket exports a tree; HIST-001/002 write the mainline plus %clk.
