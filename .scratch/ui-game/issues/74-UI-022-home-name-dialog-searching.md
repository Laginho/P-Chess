# UI-022: Home, name dialog and searching screen to the design
Stage: to-review
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


- 2026-10-31 Stage 2: Home, first-launch dialog and Searching restyled. Focused tests were committed red before production changes: icons (8 failures), missing-engine layout (1), Profile Settings access (1), theme propagation (6), and restoring layout after the warning hides (1).
- Final gate on `83e6b3a`: `godot --headless -s tests/run.gd`, exit 0, 418 reported passed including 6 Lc0 SKIPs (412 executed).
- Final captures: `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-verified-d17186cb-4643-4aac-98eb-709fc243232a/` contains Main, NameDialog and Searching at 1280x800 and 800x600; each used a separate data directory. The 800x600 missing-engine state was also checked at `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-missing-fixed-053ee4dc-f676-43d8-a359-ca9fb5bab399/missing.png`.
- Before captures: `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-before-eaa0e393-ab2c-4de1-abe9-900c41460eb8/`. The before NameDialog files are not valid evidence of the dialog because that batch reused the preceding capture's player-name data.

### Foundation review UI-021

The shared `ui/theme/p_chess.tres` FontVariation resources use string `wght` keys (for example lines 112-116). In Godot 4.7, `TextServer.font_get_variation_coordinates()` returns `{}` for that resource; a duplicated variation using numeric OpenType tag `2003265652` returns `{2003265652: 800}`. The selected weights are therefore not applied and the headings and buttons render lighter than the canvas. Probe: `C:/Users/bruno/AppData/Local/Temp/ui022-fontaxes.gd`. This shared theme is outside UI-022's Primary files and must be corrected before integration.

### Visual review UI-022

The native `AcceptDialog` retains its own button height and window layout (the canvas OK button is taller); the level selector lacks the canvas robot icon, and the Searching card uses the shared Godot button/card styles and a rotating fixed arc rather than the canvas's animated arc and exact header/footer decorations. These are observable differences from the references, retained with the existing native dialog and shared theme controls; review against the canvas is still required. One earlier Main capture omitted the board for a frame; a repeat and the final captures rendered it.

Acceptance: pending | Human visual comparison and first-launch/quick-play with an installed Lc0 remain; the screenshots use isolated fixture data and the real engine executable is absent.
Disclosure: pending | integration | [Foundation review UI-021](#foundation-review-ui-021) - fix shared font-variation axes before visual acceptance.
Disclosure: pending | integration | [Visual review UI-022](#visual-review-ui-022) - assess and resolve the listed canvas differences.
Disclosure: pending | release | [UI-022 acceptance](#comments) - perform first-launch and a real quick-play with Lc0 installed.
Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui022-last-gate.json
