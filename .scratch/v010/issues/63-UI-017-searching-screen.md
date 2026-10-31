# UI-017: The searching screen
Stage: done
Blocked by: HIST-006, UI-016
Review: agent
Difficulty: normal
Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui017-final-gate.json
Acceptance: pending | Manual real-engine batch/startup and rendered-screen checks in Manual acceptance below.
Disclosure: pending | release | [UI-017 manual acceptance](63-UI-017-searching-screen.md#manual-acceptance): interactive Maia/Stockfish startup and physical input/layout remain to be checked.

- Primary files:
  - New: ui/searching.gd
  - New: ui/searching.tscn
  - ui/main.gd (`_start`; replaces the `Starting` overlay)
  - ui/main.tscn
  - engine/uci.gd (a signal when the net's `readyok` arrives, if none exists)
  - tests/test_session.gd
  - tests/test_book.gd (test-only: searching status and asynchronous startup)
  - tests/test_badges.gd, tests/test_clock_input_order.gd, tests/test_history.gd, tests/test_home.gd, tests/test_premove.gd, tests/test_repertoire.gd, tests/test_review.gd (test-only: follow the asynchronous startup replacing immediate game creation)
  - docs/spec.md (§15.8)

#### What to build

Between the click and the game, a screen like chess.com's "searching for opponent" shows for at least 0.5 s (§15.8). Its message follows the real work.

#### Acceptance criteria

1. Every game start (quick play, Custom game, rematch) shows the searching screen with the time control and the Maia level.
2. Its status line follows the actual steps, in order, skipping those with nothing to do: "Pausing analysis…" while the queue pauses, "Loading Maia 1500…" until the net's `readyok`, "Preparing game…" while the catalog and the opening selection load.
3. It stays at least 0.5 s, and longer when the work takes longer; the game and its clock start only when it closes.
4. An error during start (missing repertoire, bad selection, engine stopped) closes it and shows the error where it shows today.

#### Verification

    Manual: quick-play with a batch running; read the three messages.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: a start with a fake slow net shows "Loading Maia …" until readyok; a fast start still lasts 0.5 s; the clock does not run while it shows; with the queue running the first line is "Pausing analysis…" (red: no screen).

## Comments

- 2026-10-30 Written from spec §15.8 and the design brief (screen 3).

- 2026-10-31 Stage stopped (incomplete handoff): Stage left uncommitted work; saved for recovery. See C:\Users\bruno\Desktop\Pastinha\Programas\Projects\P-Chess\.artifacts-build\lanes\v010\.scratch\run-log\UI-017-implement-20261031-015246.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.

- 2026-10-31 Foreman diagnosis (run 3): no code, contract or environment defect. Terra high started well (`6b28a10`, a red test for searching before Maia is ready), then ended its turn after 2 minutes with uncommitted work and a progress report: the same early stop it made on REV-005 (run 2) and HIST-004 (this run). Its report is useful: with the screen waiting for `readyok`, the new test passed but 14 existing tests failed because they expect the game to start immediately; those tests must follow the new flow. Its work is kept: branch `recovery/20261031-0155/UI-017` (`6b28a10`) and `stash@{0}` (uncommitted screen + `readyok` wait). Reuse the test if useful; start clean otherwise. Next: the rest of this run moves to the sol lineup (authorized fallback after the foreman's one diagnosis-and-restart was spent on HIST-004). Finish every criterion and the gate before ending the turn.

- 2026-10-31 Retry: inspected recovery/20261031-0155/UI-017 and stash@{0}; both preserved. Rebuilt the recovered tracer test with isolated storage and explicit readyok completion. Callers traced: Home quick play, Custom game, game-over/review rematch and Space; all reach `_start`. Startup boundaries include pending catalog, failed repertoire/selection, engine stop, repeated starts and old finished-game clocks.


## Resolution (stage 2, 2026-10-31)

- Implemented the full-window Searching scene with the time control, Maia level and actual startup status. All start routes share `_start`: pause active analysis, wait for the selected net's `level_ready`/`readyok`, prepare the catalog/repertoire/selection, then close after at least 500 ms and create the game and clock. Repeated starts and game hotkeys are ignored during searching. The previous finished clock is stopped.
- Startup errors close searching and retain the existing Home/Custom game error paths. A regression test exposed an engine-stop race during analysis pause; `79814e8` resumes the queue on both early failure exits. Engine stop during catalog loading hides searching immediately; later catalog completion cannot create a game.
- Recovery branch `recovery/20261031-0155/UI-017` and `stash@{0}` were inspected and preserved. Their production changes were reused and completed; no recovery work was dropped.
- Red/green: `5bb2682` introduced the tracer test before production (`a8b85cf`). The original flow failed screen visibility and no-clock-before-readiness assertions (`%TEMP%/ui017-red.log`, ExitCode: 1). The analysis-stop race failed in `47b8a29` (`%TEMP%/ui017-searching-red.log`) before the fix. A temporary production mutant removing the 500 ms minimum failed all three start routes (`%TEMP%/ui017-minimum-mutant.log`, ExitCode: 1); original bytes were restored afterward. Session, badges and repertoire focused runs passed after harness corrections; the complete final gate below includes all seven new searching tests.
- Harness corrections: PowerShell's input encoding replaced two Unicode expectations with question marks; the test-only correction preserves the literal UI text. Custom-game tests now use isolated persisted preferences, instead of creating a shared `res://tests/fixtures/no_session_settings.cfg`; that test-created file was removed. All legacy assertions on retained behavior are unchanged, except the explicitly retired `main.starting` assertion now observes `main.searching`.
- The first complete gate reported 376 passed / 4 failed: two review-rematch tests and the Custom-game/repertoire test still assumed immediate startup, and the delayed-catalog test awaited startup before releasing its held worker. This last fixture also blocked shutdown after the suite printed its totals, so only that identified Godot process was terminated (recorded ExitCode: -1; no receipt). `21f6a79` corrects those waits. The final gate is a new run after these committed test changes.
- Final gate: `godot --headless -s tests/run.gd` on `21f6a79ab64d6b0584b119584265ada2a94befd6`: **380 passed, 0 failed**, 380 PASS lines, 0 SKIP lines, ExitCode: 0. Log: `C:\Users\bruno\AppData\Local\Temp\ui017-final-gate.log`; SHA256: `9277A60FA2670091CDD520460706A9F20911CFC1A9A2F2C91DB0C667292DC835`. The receipt names this tested commit; only this tracker handoff changes afterward. Live UCI tests ran successfully; this does not establish the interactive product checks below.

### Updated legacy tests

These test-only changes follow the asynchronous startup required by criteria 1 and 3, as permitted by ticket-flow stage 2's replaced-behavior rule. Existing test seams and behavioral assertions are retained. The changed test methods are listed by file; fake bridges now emit readiness and fixture helpers await startup before replacing clocks or playing moves.

- `tests/test_badges.gd`: `test_real_games_show_badges_only_in_review_in_every_mode_and_keep_book_when_checking_is_off`, `test_rematch_checks_actual_black_moves_and_no_continuation_is_explicit`, `test_game_snapshots_repertoire_and_uses_live_check_preference_at_review`, `test_expected_moves_are_visible_in_review_without_hovering_over_a_clipped_badge`, `test_required_repertoire_load_failure_prevents_new_game_and_retry_uses_repaired_study`, `test_enabling_checking_during_catalog_load_rejects_bad_repertoire_and_allows_repaired_retry`.
- `tests/test_book.gd`: `test_main_uses_named_selection_counts_once_rematches_and_recognizes_free_openings`, `test_main_reports_corrupt_practice_in_catalog_and_free_without_duplicate_saves`, `test_cold_main_and_picker_share_one_loader_and_wait_responsively_before_start`, `test_main_joins_a_picker_load_without_applying_its_old_selection_and_rejects_a_bad_save_name`, `test_loader_startup_failure_reports_an_error_without_a_game_and_allows_retry`.
- `tests/test_clock_input_order.gd`: `test_a_mating_drop_at_zero_loses_on_time_before_the_move_is_played`, `test_a_drop_crossing_ten_seconds_warns_once_before_the_increment`, `test_a_mating_drop_with_one_millisecond_left_still_plays`, `test_input_before_start_and_untimed_first_moves_remain_available`, `test_a_mating_reply_arriving_at_zero_loses_on_time_before_the_move_is_played`, `test_a_mating_reply_with_one_millisecond_left_still_plays_once`, `test_a_reply_after_a_processed_flag_is_ignored_without_a_repeated_result`.
- `tests/test_history.gd`: `test_main_recovers_corrupt_stats_once_and_reports_them_in_the_review`, `test_main_saves_mate_once_with_final_increment_and_resets_history_on_rematch`, `test_main_saves_a_clock_flag_once_and_keeps_move_time_snapshots`, `test_main_saves_a_claimed_draw_once`, `test_main_records_first_and_later_premoves_after_exactly_one_charge`, `test_main_waits_for_the_last_snapshot_when_move_accounting_emits_a_flag`, `test_main_reports_failed_game_and_stats_writes_in_the_result_ui`.
- `tests/test_home.gd`: `test_quick_play_uses_defaults`, `test_custom_choices_survive_restart_and_new_game_returns_home`, `test_custom_catalog_mode_is_reused_after_restart`.
- `tests/test_premove.gd`: `test_main_queues_human_moves_and_executes_one_per_maia_reply`, `test_right_click_cancels_the_queue_and_right_drag_still_draws`, `test_black_premoves_include_first_move_cost_and_later_increment`, `test_a_premove_that_flags_is_not_played_and_discards_the_whole_queue`, `test_maia_checkmate_clears_premoves_and_rematch_keeps_no_ghosts`, `test_a_hold_survives_maias_reply_and_drops_as_a_normally_timed_move`, `test_a_reply_and_due_premove_preserve_an_unfinished_drag`, `test_a_due_premove_moving_the_held_live_piece_ends_the_hold`, `test_an_invalid_remaining_ghost_cancels_the_hold_without_a_stale_drop`, `test_premove_setting_persists_and_screen_changes_apply_immediately`.
- `tests/test_repertoire.gd`: `test_main_uses_repertoire_for_maia_catalog_for_history_and_preserves_rematches_and_modes`, `test_failed_repertoire_load_does_not_start_clock_or_policy_and_can_retry`.
- `tests/test_review.gd`: `test_summary_waits_for_analysis_and_shows_accuracy_and_counts`, `test_graph_click_navigates_and_tracks_orientation`, `test_review_tooltips_explain_accuracy_and_class_thresholds`, `test_fixture_updates_counts_before_final_accuracy`, `test_checkmate_opens_review_with_result_and_both_sides_moves`, `test_review_opens_for_no_move_resignation_flag_and_claimed_draw`, `test_export_buttons_send_finished_pgn_and_lichess_url`, `test_space_with_review_focused_rematches_and_replaces_the_previous_game`, `test_review_returns_to_setup_and_starts_a_fresh_game`, `test_review_steps_through_game_with_arrow_keys`, `test_clicking_a_move_shows_its_position`, `test_eval_bar_tracks_current_position_and_board_orientation`, `test_analysis_landing_shows_class_icon_and_best_move_on_board`, `test_open_review_starts_max_analysis_and_tracks_progress`, `test_review_places_move_list_beside_board`, `test_review_reuses_current_analysis_and_reanalyses_stale_file`, `test_review_fits_an_800_by_600_window`, `test_review_help_popups_fit_minimum_window`.
- `tests/test_session.gd`: `test_game_over_panel_actions`, `test_a_new_reply_plays_before_an_old_games_wait_finishes`, `test_an_old_policy_after_rematch_is_dropped_before_a_wait_is_scheduled`, `test_a_main_rematch_after_a_flag_closes_the_open_promotion_picker`, `test_a_main_rematch_after_a_flag_drops_the_held_piece`, `test_a_main_rematch_kills_the_old_snap_back`, `test_two_rematches_drop_a_stale_white_move_legal_in_the_current_game`, `test_resign_button_shares_the_two_second_window_with_escape`, `test_resign_button_disabled_in_setup_and_after_engine_stops`, `test_settings_blocks_focused_resign_button_from_space`, `test_draw_offer_accepted_on_reply_without_playing_it`, `test_declined_offer_reenables_only_after_ten_human_moves`, `test_draw_offer_does_not_pass_through_settings_and_resets_on_rematch`, `test_match_score_follows_players_and_resets`, `test_match_score_respects_focus_mode`.

### Manual acceptance

- With real Stockfish batch analysis active, launch Quick play and observe the pause, selected Maia loading and preparation status in order; confirm no clock or playable new game before the screen closes. Repeat Custom game and both game-over/review rematch routes.
- Check the searching screen at 800x600 and the normal window size, using physical mouse/keyboard. Confirm readable, centered time control/level/status, the minimum 0.5 s duration on a warm start, responsive waiting on a cold start, and no duplicate game from repeated input.
- Stop Maia during startup and try a missing repertoire or saved opening selection; confirm searching closes, the existing error is visible and analysis resumes. Confirm a valid retry succeeds after fixing the repertoire/selection.

Stage 2 ends at `to-review`; no stage-3 review, integration or ledger closure was performed here.

#### Resolution (2026-10-31)
Verdict: Approve

- Reviewed the complete 16-file diff from session base `5c5f9a795eaf173d8a334781e2867a6f6f9d5cd5` to ticket handoff `0141e2b04a068c6484375ac947631eb48ea3182b`, plus connected callers and failure paths. Independent Standards and Spec reviewers agreed with the stage-3 review; no production repair was needed.
- Standards: 0 documented violations and 0 actionable complexity findings. All changed files are within Primary files. Inspected all 12 commits: tests and production remain separate; the legacy-test changes retain their behavioral assertions while waiting for the new asynchronous startup.
- Spec: 0 findings. Criterion 1 passes: Quick play, Custom game and rematch share `_start` and show the selected time control and Maia level. Criterion 2 passes: active analysis cancellation precedes the selected net's `readyok`, followed by catalog/repertoire/selection preparation. Criterion 3 passes: the screen remains for at least 500 ms and until startup completes; the previous clock stops and the new game/clock are created only after it closes. Criterion 4 passes: repertoire, selection, catalog and engine failures close searching and preserve existing error and retry paths.
- Coverage: Home and Custom game; game-over, Review and Space rematches; repeated starts and game hotkeys; analysis pause/resume and cancellation racing with engine failure; UCI callback serialization; old clocks and late policy replies; cold/delayed catalog loading and late completion after engine failure; repertoire snapshots/checking; saved selection failure and repaired retry; history, badges, premoves and review callers. Every changed scene, script, test and documentation file was examined. Rendered layout, physical mouse/keyboard and interactive Maia/Stockfish batch acceptance were not performed; the Manual acceptance section remains the release checklist.
- Red/green evidence reviewed: tracer red before `a8b85cf`; analysis-stop race red before `79814e8`; minimum-duration mutant red on Quick play, Custom game and rematch. Existing gate log and receipt were inspected and validated with `Assert-GateEvidence`: tested commit `21f6a79ab64d6b0584b119584265ada2a94befd6`, **380 passed, 0 failed**, 380 PASS lines, 0 actual SKIP lines, ExitCode: 0. Live UCI tests passed, including level switching and missing-net failure. The log SHA256 matches `9277A60FA2670091CDD520460706A9F20911CFC1A9A2F2C91DB0C667292DC835`.
- Integration: `ui-017` was already based on the current session; rebase made no changes. Merged without squash into `sweatshop/v010/2026-10-30-2302` as `f196729eb8cc54c084167364a14be5ba01365a34`. Gate evidence remains valid after merge; reused the green receipt because the tested code is identical. This closure changes only the ticket and feature ledger. No PR or push is part of this session-stage handoff.

Acceptance: pending | [Manual acceptance](#manual-acceptance): interactive real-engine batch/startup, rendered layout and physical input remain unchecked.
Disclosure: pending | release | [Manual acceptance](#manual-acceptance): these product checks remain release conditions after session integration.
