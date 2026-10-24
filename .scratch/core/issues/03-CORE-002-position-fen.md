# CORE-002: Position and FEN
Stage: done
Blocked by: CORE-001
Review: agent
Difficulty: normal

- Primary files:
  - New: core/board.gd
  - New: tests/test_fen.gd

#### What to build

`core/board.gd` holds a chess position and reads and writes FEN. It also gives the position key (FEN without the halfmove and fullmove counters) that repetition (§7) and the opening book (§6.2) match on.

#### Acceptance criteria

1. Parsing then printing FEN returns the same string for the start position, Kiwipete and CPW perft positions 3–6 (FENs in CORE-003).
2. All six FEN fields are kept: placement, side to move, castling rights, en-passant square, halfmove clock, fullmove number.
3. Invalid FEN (wrong rank count, unknown piece letter, bad side to move, bad castling field) returns an error value; it never crashes.
4. The position key is the FEN without its last two fields; two positions that differ only in move counters have the same key.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_fen.gd`: round-trip of the six FENs, the invalid cases and the position key. Red because `core/board.gd` does not exist.

## Comments

- 2026-10-24 Stage 2: red on 8ccc45f (`test_fen.gd` fails to load, `core/board.gd` missing; 8 passed, 1 failed), green on 443b1bf (12 passed, 0 failed, exit 0). API for CORE-003 on: `Board.from_fen(fen)` returns the board or `null` (no `push_error`, so bad input never counts as a script error), `to_fen()`, `position_key()`, `piece_at("e4")`, public `side_to_move` / `castling` / `en_passant` / `halfmove_clock` / `fullmove_number`, and `squares` (64, a1 = 0, FEN letter or ""). No callers yet: the file is new. Beyond criterion 3 the parser also rejects a castling field out of `KQkq` order or repeated, an en-passant square on the wrong rank for the side to move, a negative halfmove clock, fullmove 0, and anything but exactly six fields. It does not check king count or piece legality; that is movegen's ground (CORE-003).

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\4e9483fb-7d4c-4415-8015-5b70d1a1fc01\scratchpad\CORE-002-gate.json

- 2026-10-24 Stage 3: a probe found that a halfmove or fullmove field beyond int64 (`99999999999999999999`) is accepted. `String.to_int()` logs `Cannot represent ... as a 64-bit signed integer` twice (core/board.gd:54, :60) and the value clamps to 9223372036854775807. Nothing crashes, and criterion 3 does not cover counters.
- Proxy decided (opus): defer the int64-overflow counter path in Board.from_fen with no follow-up ticket — it is outside criterion 3, nothing crashes or loses data, and no planned feature sends outside FENs to from_fen, so the stage-2 and stage-3 cycle plus a gate rerun would cost more than the defect.

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents and found nothing to fix. My own read of the whole diff and a probe of edge inputs found one minor defect outside the criteria (counter overflow), which the proxy deferred.

Criteria:

1. ✅ `test_round_trip_returns_the_same_fen` parses and prints the start position, Kiwipete and positions 3–6. Its six strings match CORE-003 character by character.
2. ✅ `from_fen` stores all six fields: `squares` (64 entries, a1 = 0), `side_to_move`, `castling`, `en_passant`, `halfmove_clock` and `fullmove_number`. `test_keeps_all_six_fields` reads each one back from a FEN with non-default values (`b Kq e3 7 42`).
3. ✅ Each invalid case returns `null` before anything is indexed. `test_invalid_fen_returns_null` covers 7 and 9 ranks, ranks of 7 and 9 squares, an unknown letter, side `x` and `W`, and castling `KQxq`, `KKkq` and `-K`. My probe also returned `null`, with no error logged, for a trailing newline or space, empty castling and en-passant fields, a non-ASCII letter, and the digit `0`.
4. ✅ `to_fen()` is `position_key()` plus the two counters, so the key is the FEN minus its last two fields by construction. `test_position_key_drops_the_move_counters` shows that `0 1` and `8 5` give the same key and that the side to move changes it.

Test-first: I checked `diff --stat` on every commit:
- 8ccc45f: `tests/test_fen.gd` and the Stage line only (red).
- 443b1bf: `core/board.gd` only (production).
- c85637a: the ticket only.
- ee7a582: the `--no-ff` merge into the session.

Both files are inside Primary files.

Examined:
- Callers: none. `core/board.gd` is new, and its first caller will be CORE-003, which also has it as a Primary file.
- Failure paths: every branch of `from_fen` that returns `null`, and empty fields from doubled spaces (the `field != ""` check in `_valid_castling`, and the length check on en passant).
- Edge inputs that are lenient but harmless: a counter of `+5` reads as 5, and a rank of `44` reads as `8`. Output is built from the board, not from the input text, so `to_fen()` and `position_key()` stay canonical.
- Cross-feature, a note for CORE-003: `piece_at()` does no bounds check. A square outside `a1`–`h8` indexes out of range and logs a script error, which the runner turns into a test failure.
- Cross-feature: `from_fen` deliberately avoids `push_error`, because the runner's `ErrorLog` fails any test during which Godot logs an error. The counter-overflow path is the one exception (see Disclosure).
- Not examined: the Linux CI run, and performance (CORE-003's perft will measure it).

Red-green, from stage 2 and checked here: red at 8ccc45f, because `core/board.gd` is not in that tree (`git ls-tree`) and `test_fen.gd` fails to load. Green at 443b1bf.

Gate: the stage-2 receipt above (443b1bf, exit 0) still holds, because only this ticket and the ledger changed after it. I reran `godot --headless -s tests/run.gd` in review on c85637a, the same production tree: 12 passed, 0 failed.

Proxy decided lines: one, the counter-overflow deferral under Comments.

Acceptance: passed | gate 12/12 on 443b1bf (receipt above), rerun in review on c85637a 12/12, plus my edge-input probe described under criterion 3

Disclosure: deferred | none | Proxy decided (opus), see ## Comments: Board.from_fen with a halfmove or fullmove field beyond int64 (19+ digits) returns a board instead of null. String.to_int() logs "Cannot represent ... as a 64-bit signed integer" twice (core/board.gd:54, :60) and clamps the value to 9223372036854775807. Nothing crashes, and the case is outside criterion 3. No spec section or ticket feeds outside FENs to from_fen, so only a hand-typed counter reaches it. The fix, a length or range guard on fields[4] and fields[5], belongs to the first ticket that adds outside FEN input.
