# CORE-005: SAN in and out
Stage: blocked
Blocked by: CORE-003
Review: agent
Difficulty: normal

- Primary files:
  - core/board.gd (SAN)
  - New: tests/test_san.gd

#### What to build

Moves in Standard Algebraic Notation, both ways. The move list, the PGN files, the openings TSVs and repertoire import all speak SAN.

#### Acceptance criteria

1. Moves print as SAN: piece letter, `x` on captures, `=Q`/`=R`/`=B`/`=N` on promotion, `O-O`/`O-O-O`, `+` for check, `#` for mate.
2. Disambiguation uses the file when that is enough, else the rank, else both (tested with three queens that can reach one square).
3. SAN parses back to the move; trailing `+`, `#`, `!` and `?` are accepted; illegal or ambiguous SAN returns an error.
4. For every legal move at depth 1 from the six perft positions, parsing the printed SAN gives back the same move.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_san.gd`: the cases above and the round-trip. Red because there is no SAN code.

## Comments

- 2026-10-24 Stage stopped (incomplete handoff): Invalid committed handoff: CORE-005: code changed after gate (core/board.gd, tests/test_san.gd); reuse evidence only for identical code. See D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\core\.scratch\run-log\CORE-005-implement-20261024-030601.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
