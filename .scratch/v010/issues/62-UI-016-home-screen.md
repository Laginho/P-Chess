# UI-016: The home screen
Stage: reviewing
Blocked by: HIST-004
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/home.gd
  - New: ui/home.tscn
  - ui/main.gd
  - ui/main.tscn
  - ui/setup.gd, ui/setup.tscn (becomes Custom game, with a way back; its History button moves to Home)
  - ui/game_over.gd (`_new_game`)
  - ui/review.gd (New game)
  - core/settings.gd (the last game's settings)
  - New: tests/test_home.gd
  - tests/test_session.gd, tests/test_review.gd, tests/test_clock_input_order.gd, tests/test_badges.gd, tests/test_book.gd, tests/test_repertoire.gd (test-only: tests that expect the setup screen at launch or after New game)
  - docs/spec.md (§9.1, §15.8)

#### What to build

The app opens on a home screen (§15.8): three quick-play buttons, a level selector, and the ways to everything else. Today's setup screen becomes "Custom game".

#### Acceptance criteria

1. The app opens on Home.
2. Quick-play buttons 1+0, 3+2 and 5+0 start a game at once with your last level, colour choice and opening mode; the first time, Maia 1500, random colour and Free.
3. A small level selector beside them shows and changes the level, for example "Maia 1500".
4. Buttons: Custom game (the setup screen), History, Settings and Quit. Profile is added by UI-019.
5. Starting a game from Custom game also becomes the "last" settings quick play reuses; they survive a restart.
6. New game, from the game-over panel or the review, returns to Home; returning Home resets the match score (UI-014).
7. The engine-missing message shows on Home, and quick play is disabled while it shows.

#### Verification

    Manual: launch, quick-play 3+2, resign, New game, check Home; restart and quick-play reuses the level.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_home.gd`: launch shows Home; first quick play uses 1500/random/Free; after a custom game, quick play reuses its level, colour and opening mode; New game lands on Home and resets the score (red: no Home).
- The listed test files: setup-at-launch or New-game-opens-setup assertions go through Custom game or expect Home (test-only).

## Comments

- 2026-10-30 Written from spec §15.8 and the design brief (screen 1). Decided while slicing: New game returns to Home, since setup is now one of Home's options.

- 2026-10-31 Stage 2: implemented Home, quick play and persistent custom choices; wired History, Settings, Quit, Custom game, New game and engine errors. The initial Home, default quick play, custom return and focus-mode tests were red before their respective changes. The catalog reuse test was also checked against a mutation forcing Free (failed as intended). Updated replaced navigation assertions in `test_session.gd`, `test_review.gd` and `test_history_screen.gd`; the latter follows the History button moved from Setup to Home. The first full gate found a corrupt-settings regression (370 passed, 1 failed); the existing corrupt-file test passed after the fix. The final gate on `2e9e8fa` passed 373 tests, 0 failed, exit 0; log: `C:\Users\bruno\AppData\Local\Temp\p-chess-ui016-gate.log`.

- During test development a fixture wrote eight simulated games and wins to the default local history. The eight matching PGNs and corresponding statistics were restored after backup to `C:\Users\bruno\AppData\Local\Temp\p-chess-ui016-history-backup`; the test now uses isolated history storage.

- 2026-10-31 Stage 3: Standards and Spec reviews found no implementation defects in criteria 1-7. Corrected only stale comments describing the launch screen, game hotkeys and settings storage. The History test navigation replacement is permitted by the test-only Primary-file exception in `ticket-flow/stage2.md`.

Acceptance: pending | Launch, quick-play 3+2, resign, choose New game, restart and verify the last level; inspect Home and keyboard navigation at the minimum window size. Headless tests do not establish manual UI or real-engine acceptance.

Disclosure: pending | release | Manual Home layout, keyboard navigation and real-engine quick-play acceptance remain outstanding (verification above).

Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-ui016-gate.json
