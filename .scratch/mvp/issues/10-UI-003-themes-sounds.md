# UI-003: Themes and sounds
Stage: implementing
Blocked by: UI-001
Review: human
Difficulty: normal

- Primary files:
  - New: ui/theme_loader.gd
  - New: ui/sound_player.gd
  - ui/board_view.gd
  - ui/main.gd
  - New: themes/boards/brown/theme.json
  - New: themes/sounds/sfx/, nes/, piano/, futuristic/ (.ogg files)
  - docs/THIRD_PARTY.md
  - New: tests/test_themes.gd, tests/fixtures/themes/

#### What to build

Board, piece and sound themes as folders (§8.6), built in under `res://themes/` or the user's own under `user://themes/`, plus sounds for the game events (§8.5). Review is `human` because Bruno picks the default sound set by ear.

#### Acceptance criteria

1. The loader lists the themes of each kind (boards, pieces, sounds) from `res://themes/<kind>/` and `user://themes/<kind>/`.
2. A board theme is a `theme.json` with two colours or a texture; a malformed one falls back to brown with a warning.
3. A piece set must have all twelve files `wK.svg` … `bP.svg`; an incomplete set is not listed.
4. A sound set has one `.ogg` per event: move, capture, castle, check, promote, premove, low time, game start, game end. A missing file means that event is silent; it never crashes.
5. In a two-human game, move, capture, castle, check, promote, game start and game end play their sounds. (Premove and low time are wired by UI-007 and CLOCK-001.)
6. The bundled sound sets are exactly `sfx`, `nes`, `piano` and `futuristic` from Lichess; Lichess's `standard` set is not in the repo.
7. `docs/THIRD_PARTY.md` credits the Lichess sound sets (AGPL) with a source link.
8. The default sound set is the one Bruno names at review; until then, `sfx`.

#### Verification

    Manual: Bruno listens to the four sets and names the default.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_themes.gd`: the loader on fixture folders: a valid board, a malformed board, a complete and an incomplete piece set, a sound set with one file missing. Red because `ui/theme_loader.gd` does not exist.

## Comments
