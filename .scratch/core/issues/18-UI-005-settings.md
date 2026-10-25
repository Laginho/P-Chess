# UI-005: Settings store and screen
Stage: implementing
Blocked by: UI-004
Review: agent
Difficulty: normal

- Primary files:
  - New: core/settings.gd
  - New: ui/settings.tscn, ui/settings.gd
  - ui/main.gd, ui/board_view.gd, bot/maia_player.gd (read their settings)
  - New: tests/test_settings.gd

#### What to build

Settings live in `user://settings.cfg` and are edited on a settings screen (§10). This ticket covers the settings whose features already exist; UI-006, UI-007, OPEN-002 and OPEN-004 add their own rows.

#### Acceptance criteria

1. Settings are stored with `ConfigFile` in `user://settings.cfg`; a missing file gives the §10 defaults.
2. The screen edits: legal-move dots (on), animation length (120 ms, 0 allowed), board / pieces / sounds themes (brown, cburnett, the UI-003 default), volume (100%), threshold `τ` (2%), temperature `T` (1.0), panic intensity (medium), auto-claim threefold (on).
3. Each change takes effect without a restart.
4. Values persist across a restart.
5. An out-of-range or corrupt value falls back to its default; it never crashes.

#### Verification

    Manual: change each setting, restart, check it stuck.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_settings.gd`: defaults with no file, save and reload, a corrupt value falling back. Red because `core/settings.gd` does not exist.

## Comments

- Stage 2, harness fix: after 298b272 every assert of `test_a_corrupt_file_gives_the_defaults` held, but ConfigFile logs its own parse error for a corrupt file and the runner counts any logged error as a failure. The test now turns `Engine.print_error_messages` off around that one load. Red again by mutation: a store that sets volume 0 on a failed load fails it (`expected 100, got 0`), with three other tests.
- Stage 2, handoff. Cycles: f499917 red (`Preload file "res://core/settings.gd" does not exist`), 298b272 green except for the harness issue above, 8fff240 harness fix, 4ddb143 the screen and the wiring. Gate: 113 passed, 0 failed (107 before, plus 6 new).
- Interface: `core/settings.gd` is `Settings.new(path := "user://settings.cfg")`, `get_value(key)`, `set_value(key, value) -> bool` (saves at once, emits `changed(key, value)`, refuses out-of-range values), `valid(key, value)` static. Keys: `legal_dots`, `animation_ms`, `board_theme`, `piece_theme`, `sound_theme`, `volume`, `tau`, `temperature`, `panic`, `auto_claim`, in one `[settings]` section.
- My own judgement, no proxy: the ranges, which the spec does not give, are animation 0–1000 ms, volume 0–100%, `τ` 0–20%, `T` 0.1–3.0. A theme only has to be a non-empty name; the loaders already fall back on one that is missing. The BOT-003 note (a `T` above `T_max`, or `τ` below `τ_min`, makes panic steadier, not wilder) stays possible with these ranges; I did not narrow them to rule it out.
- Panic was never wired: Maia did not see its clock. For the panic setting to take effect, `MaiaPlayer.think(game, time_left, start_time)` now takes Maia's clock in ms and applies `MovePicker.panic`; without a start time (the old one-argument call in `test_maia_player.gd`) there is no panic, so those tests are unchanged. Its test sits in `tests/test_settings.gd`, because `tests/test_maia_player.gd` is not in Primary files.
- The screen opens from a Settings button in the top-right corner, over the setup screen or a game. While it is open it takes every key, so Esc closes it instead of resigning. Checked headless with a scratch script that drives `ui/main.tscn`: the 10 rows show, every edit reaches the board, the sounds, Maia and the game at once, and a new store reads them back. The theme lists come from `ThemeLoader.list_themes`; this lane has no `themes/` folder, so here each list holds only the current name.
- Not done: the manual check (change each setting, restart the app, see that it stuck) needs a person at the window.

> Gate evidence: C:/Users/Lage/AppData/Local/Temp/claude/D--Desktop-Projects-P-Chess--artifacts-build-lanes-core/012c181d-09e9-456d-a9ce-26fd17372943/scratchpad/UI-005-review-gate.json
>
> #### Resolution (2026-10-24)
>
> Verdict: Approve
>
> Stage 3 (opus-5.5). The Standards and Spec reviews ran as separate sub-agents, and neither found anything. I read the whole diff and the code around it, and found one regression they missed (below). I fixed it in review.
>
> Examined: every caller of `MaiaPlayer.think`. `main._next_turn` passes Maia's `clock.left` and the control's start time, both in ms as `MovePicker.panic` expects. The three one-argument calls in `tests/test_maia_player.gd` leave `start_time` at 0, so they get no panic and behave as before. `_apply` runs once per key in `_ready`, after `board_view.game` exists, and again on every `changed`. Auto-claim reaches the game in progress, and `_start` reads it for the next game. A theme setter given a missing name falls back with a warning (ThemeLoader) and does not crash. In `valid()`, `and` short-circuits, so a string in a numeric key never reaches a comparison. NaN and INF fail the bounds, and int/float mismatches are converted. The screen's SpinBoxes clamp after snapping to the step, so the screen cannot produce a value the store would refuse. The screen is a later child of Main, so its `_unhandled_key_input` sees keys first and takes all of them while it is open. Esc closes it, and F11, Space and F wait. I rendered the running app (not headless) at 1280×800 and 800×600 to check the layout. Not examined: the manual restart check, and the real theme lists (this lane has no `themes/` folder).
>
> Criteria:
>
> 1. ✅ `core/settings.gd` reads and writes `user://settings.cfg` (the default path of main's `Settings.new()`) through ConfigFile. A failed load leaves `DEFAULTS` in place (`test_a_missing_file_gives_the_spec_defaults`).
> 2. ✅ `ui/settings.gd` has ten rows, with the criterion's defaults, which agree with §10: dots on, 120 ms (spin minimum 0), brown, cburnett, sfx (SoundPlayer's default theme from UI-003), volume 100, τ 2% (stored as 0.02, shown ×100), T 1.0, panic medium, auto-claim on. A screenshot of the open panel shows all ten.
> 3. ✅ Every accepted `set_value` emits `changed`. `main._apply` sends each key to what reads it: board_view (dots, slide length, themes), sound_player, the master bus volume, Maia (τ, T and panic, read at its next `think`) and the current game (auto-claim). Panic needed Maia's clock, which `think` now receives (Comments).
> 4. ✅ `set_value` saves the whole section on every change, and a new store reads it back (`test_a_change_is_saved_and_read_back_by_a_new_store`).
> 5. ✅ An out-of-range value, a wrong type, an unknown choice or an empty theme name reads as that key's default, and the other keys keep their values (`test_a_bad_value_in_the_file_falls_back_to_its_default_and_keeps_the_rest`). A corrupt file gives every default, and the next save replaces it (`test_a_corrupt_file_gives_the_defaults`). `set_value` refuses bad values (`test_an_out_of_range_change_is_refused`).
>
> Finding (regression), fixed in review in 0023d1c. The Settings button was anchored at the window's top-right corner (x W−96…W−4, y 4…35). There it covered the top half of the top clock's digits, and it stayed visible in F11 focus mode, where §8.7 and UI-004 criterion 6 allow only the board and the clocks. A screenshot of the running app showed both. The fix moves the button to the left edge of the side panel, beside the top clock, and adds the settings screen to `_set_focus`'s list. Screenshots after the fix, at 1280×800 and at 800×600 with the widest clock text ("0:09.9"): no overlap, and focus mode shows only the board and the clocks.
>
> Review fix 0023d1c: written by stage 3 (opus-5.5). Independent reviewer: a separate Haiku sub-agent, which examined `git show 0023d1c` together with `ui/main.gd`, `ui/main.tscn`, `ui/settings.*` and `ui/clock.tscn`. Its first verdict was Issues, on two points:
> - (a) The button overlaps the clock label's rectangle. True of the rectangle, but the digits are right-aligned, and at 800×600 there is a ~45 px gap.
> - (b) F11 is ignored while the panel is open. That is stage 2's modal design from 4ddb143, which the fix does not change.
> Shown that measurement and that history, it changed its verdict to Approve.
>
> Rules: the test-only commits f499917 and 8fff240 (with ticket metadata) alternate with the production-only commits 298b272 and 4ddb143, and 279b6dc touches only the ticket. The review fix 0023d1c touches `ui/main.gd`, `ui/settings.gd`, `ui/settings.tscn` and the ticket. Only Primary files changed (`ui/board_view.gd` needed no change). The branch already sat on the session tip d4bd359, so no rebase was needed. Merged as 0fb6137.
>
> Red-green: stage 2's red f499917 failed with `Preload file "res://core/settings.gd" does not exist`. The harness fix 8fff240 was proved red again by mutation (Comments). Green on 4ddb143: `113 passed, 0 failed`. I also ran a mutation check in review, in a throwaway worktree on 0023d1c, with three mutations: the bounds check removed from `valid()`, `config.save` removed, and panic never applied in `think`. Result: `108 passed, 5 failed`, and every mutant was caught by at least one test (bounds: the out-of-range and bad-file tests; save: the reload and corrupt-file tests; panic: the Maia test). The review fix has no test of its own: layout and focus mode are manual checks, as in UI-004.
>
> Gate: rerun on 0023d1c after the fix: exit 0, `113 passed, 0 failed`, and the live Lc0 tests ran (receipt in the `Gate evidence:` line above; it replaces stage 2's receipt for 4ddb143). The merge 0fb6137 has the same tree as 0023d1c.
>
> Not findings (no criterion and no regression), noted only:
> - `_spin`'s parameter `scale` shadows `Control.scale`. This only produces an editor warning; the behaviour is correct.
> - `set_value` ignores the error from `config.save`. If `user://` is read-only, a change applies for the session but is not kept, and nothing says so.
> - `user://test_settings.cfg` stays behind after the suite: each test deletes it at the start, never at the end.
> - UI-004's pending check "claim a threefold" can now be done: turn auto-claim off in Settings.
>
> `Proxy decided` lines: none.
>
> Acceptance: pending | nobody has yet changed each setting, restarted the app and checked that it stuck. Evidence so far: gate 113/113 on 0023d1c, a mutation check (108/5), stage 2's scripted headless run of `ui/main.tscn` (Comments), and screenshots of the running app in review (setup, game, open panel, focus mode, 800×600).
> Disclosure: decision | none | stage 2's own judgement, without a proxy (## Comments): the ranges, which the spec leaves open, are animation 0–1000 ms, volume 0–100%, τ 0–20% and T 0.1–3.0, and a theme name only has to be non-empty.
> Disclosure: decision | none | `MaiaPlayer.think(game, time_left := 0, start_time := 0)` now takes Maia's clock in ms so that panic can apply; the old one-argument calls keep their behaviour (## Comments).
> Disclosure: pending | release | the manual Verification check (change each setting, restart, see it stuck) has not been run by a person (Acceptance above).
> Disclosure: pending | release | the Board, Pieces and Sounds lists come from `ThemeLoader.list_themes`, and this lane has no `themes/` folder, so here each list holds only the current name. Check in the full repo that every bundled set is listed.

#### Reopen (2026-10-24, session PR #8 review)

Reviewer: independent review of session PR #8 by gpt-6.1-sol xhigh (verdict "do not merge"), relayed by the supervisor foreman. Its gate run was green, 113/0/0; no test covers the case.

5. ❌ `Settings.valid` (`core/settings.gd:71`) accepts any non-empty theme name. A saved `sound_theme="deleted-or-misspelled"` loads unchanged and every sound goes silent, instead of falling back to the default `sfx`; the nine default sounds are available but none loads. The same holds for a board or pieces theme whose folder is gone.

What is left: a saved theme whose folder does not exist falls back to its default (`sfx` for sounds, and the §10 defaults for board and pieces); add a test that loads a saved theme that no longer exists and checks the fallback and that the default sounds load. The lane now has `themes/` (boards, pieces, sounds); make sure the tests do not pass only because a folder is missing or present in this checkout. Every other criterion verdict above stands.

Note for stage 2: the block quoted above is the previous review's record, kept for history; the live fields are the ones below it. Write the new receipt as `Gate evidence: <path>` at the very start of its own line, with no list dash and nothing after the path: the installed driver misses a `- Gate evidence:` line (fix pending in Agent-Skills#4).

Verdict: Reopen — criterion 5: a saved theme that no longer exists is kept, and the sounds go silent instead of falling back to sfx
