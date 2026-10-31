# UI-016: The home screen
Stage: done
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

Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-ui016-review-gate.json

#### Resolution (2026-10-31)
Verdict: Approve

- Standards: no findings. Reviewed all 13 changed files and the 15 implementation/handoff commits against `AGENTS.md`, tracker conventions, Primary files and the test/production commit split. The History test changes only replace Setup navigation with Home navigation; `ticket-flow/stage2.md` explicitly permits this test-only Primary-file extension.
- Spec: no findings in criteria 1-7. Independent axes `/root/standards` and `/root/spec` examined `261147ad27f79283cc27ef402488f4d48388299a...a2ff75cd926a8081759c0b5254ae350aec1ee419`. The review correction `15f29246130857f5e92362d430e4ecc572062a24` changes three stale comments and tracker metadata only; no production behavior was authored during review.
- Criterion 1: PASS — Home is visible on launch and Custom game starts hidden (`test_launch_opens_home`).
- Criterion 2: PASS — all three time controls start through the shared game path; defaults are Maia 1500/random/Free, and saved level, colour choice, opening mode and catalog selection are reused (`test_quick_play_uses_defaults`, `test_custom_catalog_mode_is_reused_after_restart`).
- Criterion 3: PASS — the Home selector lists Maia levels, loads the saved level, saves changes and synchronizes after Custom game.
- Criterion 4: PASS — Custom game, History, Settings and Quit are wired; Custom game and History return to Home. Profile remains UI-019 as specified. History navigation assertions and the Settings-after-focus regression pass.
- Criterion 5: PASS — a successful Custom game records the chosen level, original colour choice, opening mode and selection in the settings file; an independent Settings/Main instance reloads them (`test_custom_choices_survive_restart_and_new_game_returns_home`, catalog restart test).
- Criterion 6: PASS — game-over New game and review New game route to Home; `_show_home` clears clocks and resets both match scores via `_show_setup`. `test_session.gd`, `test_review.gd` and `test_home.gd` cover the changed navigation and reset.
- Criterion 7: PASS — engine startup failure, missing nets and engine-stopped paths expose the Home message; quick-play buttons are disabled (`test_missing_engine_disables_quick_play`).
- Red/green proof: inspected the separate test-only and production-only commits. Stage 2 records the initial Home/default/custom/focus failures, catalog mutation failure and corrupt-settings regression/fix above; those historical red runs were not repeated during review. Existing assertions outside replaced navigation remain intact.
- Gate: `godot --headless -s tests/run.gd`, run once successfully on `15f29246130857f5e92362d430e4ecc572062a24`: 373 PASS lines, 373 passed, 0 failed, no SKIP lines, ExitCode: 0. Log: `C:\Users\bruno\AppData\Local\Temp\p-chess-ui016-review-gate.log`; receipt above. Its SHA256 matches the log. An earlier sandbox attempt exited before launching Godot because the installed Godot directory was absent from PATH; the successful run used the installation bound in `AGENTS.md`.
- Coverage: inspected Home scenes/signals, Custom game and persisted colour choice, level changes, Free/Catalog/My repertoire startup, catalog/repertoire load errors, corrupt settings load, rematch preservation, game-over/review/history callers, match-score reset, focus recovery and engine startup/stopped failure paths. All changed files and these connected callers were examined; the complete gate ran live.
- Limits: rendered Home at 800x600, physical keyboard/focus and interactive real-engine quick play/restart acceptance remain manual. The existing Acceptance and release Disclosure stay pending; headless success does not establish those product checks.
- Integration: rebased onto `sweatshop/v010/2026-10-30-2302` (already up to date) and merged without squash as `38655e5632a02d64cbde219013ea82c054b517a1`. Tested production is unchanged through the merge and closure. The session driver owns publication.
