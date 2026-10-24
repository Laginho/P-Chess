# OPEN-002: Book weight in Catalog mode
Stage: to-implement
Blocked by: BOT-003, HIST-001, OPEN-001
Review: agent
Difficulty: hard

- Primary files:
  - bot/book.gd
  - bot/maia_player.gd
  - core/history.gd (practice counts, Opening header)
  - core/settings.gd, ui/settings.tscn, ui/settings.gd (book intensity)
  - New: tests/test_book.gd

#### What to build

In Catalog mode Maia leans toward the checked lines and drifts off them as the game deepens (§6.2, §6.3). The weights feed the move picker before its cut (BOT-003).

#### Acceptance criteria

1. The book is indexed by position key, so a transposition into a checked line counts.
2. For each legal move `m` that keeps the game on a checked line, `w(m) = 1 + (B − 1) · f(d)`, where `d` is the game's current ply number; every other move has `w = 1`.
3. `f(d) = 1` for `d ≤ 6`, falls linearly to 0 at `d = 16` (`f(11) = 0.5`), and is 0 after.
4. `B = B_target` when `m` follows the target line, else `B_other`. Book intensity weak / medium / strong gives `(B_target, B_other)` = (5, 2), (20, 5), (100, 15); default medium, stored as a setting.
5. The target line is picked at game start: among the checked lines (in My repertoire mode, the lines for Maia's side), the one with the lowest practice count; ties are broken by the RNG.
6. At game end the target line's practice count goes up by one; counts persist under `user://`.
7. Once the game has left every checked line, every weight is 1.
8. A saved game's `Opening` header names the deepest catalog line whose position the game reached (in every mode).
9. Integration with the picker: a line move that Maia rates at 0.5% is sampled at least once in 1,000 seeded games' first Maia move under strong intensity, and never under Free mode.

#### Verification

    Manual: check one line, play five games as white; Maia follows it early and leaves it later.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_book.gd`: weights at plies 4, 11 and 18; a transposition; target-line choice with counts and a seeded tie; weights after leaving the book; the Opening header name; the picker integration of criterion 9. Red because the book weight does not exist.

## Comments
