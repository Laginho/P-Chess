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
