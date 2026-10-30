# HIST-005: Delete a game, and the PracticeTarget header
Stage: to-implement
Blocked by: HIST-004
Review: agent
Difficulty: normal

- Primary files:
  - core/history.gd (`delete`)
  - core/pgn.gd (`finished_game`: `PracticeTarget`)
  - ui/history_screen.gd, ui/history_screen.tscn
  - tests/test_history.gd
  - tests/test_pgn.gd
  - tests/test_review.gd (test-only: the exact-header assertion, if a target is set there)
  - docs/spec.md (§15.7)

#### What to build

Each history card gets Delete, with confirmation (§15.7). Deleting removes the game everywhere, so the stats and practice counts always match the history. For that, games played with a target line record it in a `PracticeTarget` header.

#### Acceptance criteria

1. A game played with a target line (§6.3) saves its id in a `PracticeTarget` header; other games have none.
2. Delete asks for confirmation; Cancel changes nothing.
3. Confirming removes the PGN, its analysis file and its repertoire snapshot, and the card leaves the list.
4. It takes the game off the stats of its (level, control), read back from the PGN headers: one win, draw or loss, and a flag win or loss when the reason is time. Your side is the player named "You" (UI-018 switches this to `HumanColor`).
5. It takes one off the practice count of the game's `PracticeTarget`; a game without that header leaves the practice counts as they are.
6. Counts never go below zero; a failed delete reports an error and leaves the stats untouched.

#### Verification

    Manual: note a level's W/D/L, delete one game, check it dropped by one.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_pgn.gd`: a target id gives a `PracticeTarget` header (red: none).
- `tests/test_history.gd`: deleting a won-on-time game removes its files and one win and one flag win; deleting a targeted game removes one practice count; an untargeted legacy game leaves them; nothing goes below zero (red: no delete).

## Comments

- 2026-10-30 Written from spec §15.7.
