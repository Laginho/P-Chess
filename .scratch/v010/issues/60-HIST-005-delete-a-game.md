# HIST-005: Delete a game, and the PracticeTarget header
Stage: blocked
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

- 2026-10-31 Attempt 1 stopped to ask (its commits are on branch `recovery/asked/20261031-005421/HIST-005`): O **HIST-005 está bloqueado** na branch `HIST-005-delete-a-game`, com a implementação anterior preservada e o bloqueio registrado no commit `c7b3e60`. /  / A revisão exige testes determinísticos para falhas durante a remoção final e a gravação das estatísticas. As operações atuais não oferecem um ponto de injeção para essas falhas, e o proxy do fluxo estava inacessível. /  / Você autoriza adicionar um pequeno ponto de injeção de falhas em `core/history.gd`, usado pelos testes de `tests/test_history.gd`? Se preferir, pode indicar outra forma determinística de provocar essas falhas. /  / A skill [ticket-flow](C:/Users/bruno/.agents/skills/ticket-flow/SKILL.md) determina que, se o proxy falhar, a etapa deve registrar `blocked` e, em uma sessão acompanhada, apresentar a falha e consultar a pessoa.

- 2026-10-31 Proxy decided (opus-5.5 xhigh): No new production seam. Stage 2 provokes the failures from the filesystem, the way `tests/test_history.gd:411` already does. The reason: no contract change, it follows the repo's existing pattern, and only `tests/test_history.gd` (a Primary file) changes. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-005424-HIST-005-fd6cb1.json)
  > Decision: No new production seam. Stage 2 provokes the failures from the filesystem, the way `tests/test_history.gd:411` already does. The reason: no contract change, it follows the repo's existing pattern, and only `tests/test_history.gd` (a Primary file) changes.
  > 
  > **How to make each failure point fail** (`core/history.gd` at `c7b3e60`)
  > 
  > 1. **Final file removal** (`DirAccess.remove_absolute(item + ".deleting")` fails after the rename worked). Planting a directory or holding a Windows lock both fail one step too early, at the rename. Instead, call `FileAccess.set_read_only_attribute(analysis, true)` on the **analysis file**, which is the last entry in `paths`. On Windows the rename of a read-only file succeeds and the unlink fails. The PGN and snapshot `.deleting` files are already gone by then, so `_restore_deleted_files` runs both of its branches: it rewrites those two from their saved buffers and renames the analysis file back. Notes for the test:
  >    - `assert_eq(FileAccess.set_read_only_attribute(analysis, true), OK)`, so a platform without the attribute fails loudly instead of passing green.
  >    - The analysis file lives in the shared `user://analysis` folder, outside the test root. Cleanup must call `set_read_only_attribute(analysis, false)` before removing it.
  > 2. **Saving the temp stats file** (`_results.save(temp_path)`). Before calling `delete`, plant an empty directory at `<root>/stats.cfg.deleting`, the same pattern as line 411. The real `stats.cfg` on disk is never touched, so "unchanged after reload" can be checked directly with `History.new(folder)`.
  > 3. **Replacing `stats.cfg`** (`rename_absolute(temp, stats_path)`). This failure goes into the same `if status != OK` rollback block as point 2. Point 2's test, plus red proof against a mutation of that block, covers the branch. Don't plant a directory at `stats.cfg` for this: it destroys the file on disk, so the reload check becomes impossible. Record in the ticket that point 2 covers this branch.
  > 
  > **Assertions for each test (from the stage 3 review):**
  > - `delete` returns `false` and `history.error` is not empty.
  > - Result, flag and practice counts are unchanged, both in memory and after `History.new(folder)`.
  > - The PGN, snapshot and analysis file are back with their original contents.
  > - No `.deleting` file is left behind.
  > 
  > The tests go in their own test-only commit. Prove them red against the pre-fix code (`239c38e^` / `1ce2381^`) or a focused mutation, then green on the current implementation. After that, update the gate evidence.
  > 
  > **Fallback, already authorized so the stage doesn't block again:** if the red run shows the read-only attribute does not make `remove_absolute` fail on this Godot 4.7, add the smallest possible seam. Route only that final removal through one instance method (`func _remove(path: String) -> Error`) and override it in a test-local subclass inside `tests/test_history.gd`. Nothing else becomes injectable, and it stays within the Primary files.
  > 
  > **Contract impact:** none. Criteria 1–6 and the Primary files stay as they are, and nothing changes for integration or release.
  > 
  > **Next for the caller:** record this under `## Comments`, set `Stage:` back to `implementing`, and rerun stage 2 on `recovery/asked/20261031-005421/HIST-005`. That branch is where `c7b3e60` lives; `HIST-005-delete-a-game`, the branch named in the question, isn't in the repository.
  > 
  > I didn't run anything, so I haven't confirmed that a read-only file makes the delete fail on Godot 4.7; stage 2's red run will settle that. The read-only trick only works on Windows (and maybe macOS, not Linux); the gate runs on Windows.

- 2026-10-31 Stage stopped (incomplete handoff): Invalid committed handoff: A parameter cannot be found that matches parameter name 'Raw'. See C:\Users\bruno\Desktop\Pastinha\Programas\Projects\P-Chess\.artifacts-build\lanes\v010\.scratch\run-log\HIST-005-implement-20261031-005749.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
