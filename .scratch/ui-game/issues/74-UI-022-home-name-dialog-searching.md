# UI-022: Home, name dialog and searching screen to the design
Stage: implementing
Blocked by: UI-021
Review: agent
Difficulty: normal

- Primary files:
  - ui/home.gd, ui/home.tscn
  - ui/name_dialog.gd, ui/name_dialog.tscn
  - ui/searching.gd, ui/searching.tscn
  - tests/test_home.gd
  - tests/test_session.gd, tests/test_settings.gd (test-only: node paths that move)

#### What to build

Restyle Home, the first-launch name dialog and the searching screen to `docs/design/v0.1.0/png/Main.png`, `NameDialog.png` and `Searching.png` (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. Home matches `Main.png`: the board at the start position on the left; the "P-Chess" title; the "Quick play" label with the Maia level selector; the 2Ã—2 grid of large buttons (1+0, 3+2 and 5+0 in green with their icons, Custom in the raised style); History, Profile, Settings and Quit at the bottom with their icons. Behaviour is unchanged (UI-016, UI-018, UI-019).
2. The name dialog matches `NameDialog.png` over a dimmed Home but keeps the spec's behaviour: prefilled with "You", only OK, blank names refused (Â§15.8).
3. The searching screen matches `Searching.png`: the board, and a side card with the spinner, "Starting your game", the live status line and the time-control and level chips. The status follows Â§15.8 ("Pausing analysisâ€¦", "Loading Maia 1500â€¦", "Preparing gameâ€¦"), not the canvas's sample text.
4. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the three boards.

#### Verification

    Manual: screenshot tool for Main, NameDialog and Searching at 1280Ã—800 and 800Ã—600; launch with no `player_name`, then quick-play once.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_home.gd`: Home has the four large buttons and the four bottom buttons, each with its icon, and the level selector reads "Maia <level>" (red where today's Home differs).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`.
