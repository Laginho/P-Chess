# UI-018: Your name, and the HumanColor header
Stage: to-implement
Blocked by: HIST-005, UI-016
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/name_dialog.gd
  - New: ui/name_dialog.tscn
  - core/settings.gd (`player_name`)
  - core/pgn.gd (`finished_game`)
  - core/history.gd (your side from `HumanColor`)
  - ui/history_screen.gd
  - ui/review.gd (the players shown)
  - ui/main.gd
  - tests/test_pgn.gd
  - tests/test_history.gd
  - tests/test_review.gd (test-only: exact-header assertions)
  - tests/test_settings.gd
  - docs/spec.md (§9.4, §15.8)

#### What to build

The player has a name (§15.8). It is asked once, written into new games, and shown everywhere "You" showed. New PGNs also record which colour you played, since a name like "Maia 1500" could match the opponent's.

#### Acceptance criteria

1. On first launch a modal over Home asks "What should I call you?", prefilled with "You", with only OK; an empty name is not accepted.
2. The name is stored in the `player_name` setting and survives a restart; the dialog never shows again once set.
3. New PGNs write the name in your player header and a `HumanColor` header (`w` or `b`).
4. Stats, thumbnails and Delete read your side from `HumanColor`; for PGNs without it, your side is the player named "You".
5. Old PGNs keep "You" in the file but show the current name in the history and the review.

#### Verification

    Manual: delete settings.cfg, launch, name yourself, play, check History shows the name.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_pgn.gd`: `finished_game` writes the name and `HumanColor` (red: "You", no header).
- `tests/test_history.gd`: a game where you are named "Maia 1500" as Black counts for you from `HumanColor`; a legacy game falls back to "You"; Delete uses the same side (red).
- `tests/test_settings.gd`: `player_name` default "You", empty rejected.

## Comments

- 2026-10-30 Written from spec §15.8 and the design brief (screen 2).
