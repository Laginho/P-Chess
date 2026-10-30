# CI-004: Fetch and ship Stockfish 19
Stage: blocked
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - scripts/fetch-engine.ps1
  - .github/workflows/release.yml
  - .gitignore (only if `engine/stockfish/` is not ignored already)
  - docs/THIRD_PARTY.md
  - docs/spec.md (§3.1, §15.3)

#### What to build

The analysis engine arrives the same way Lc0 does (§15.3): `fetch-engine.ps1` downloads the pinned Stockfish 19 Windows build, verifies it and places it under `engine/stockfish/`, and every release zip ships it with its licence.

#### Acceptance criteria

1. `fetch-engine.ps1` downloads the official Stockfish 19 Windows x86-64 build (the one that picks its CPU path at runtime, NNUE embedded) from a pinned release URL, and verifies the SHA-256 of the archive and of the installed exe, as it does for Lc0. A mismatch deletes the file and fails, with the same message shape.
2. It installs `engine/stockfish/stockfish.exe` and Stockfish's `Copying.txt` beside it; a second run with everything present downloads nothing.
3. The release zip contains both files; the release workflow needs no change beyond what that takes.
4. `docs/THIRD_PARTY.md` gains a Stockfish section: the release, the `sf_19` source tag link, GPLv3, shipped unmodified.
5. Running the installed exe with `uci` answers `uciok` naming Stockfish 19 (record the output under `## Comments`).

#### Verification

    Manual: delete engine/stockfish, run scripts/fetch-engine.ps1 twice, then echo uci into the exe.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None in the Godot suite: CI has no Stockfish (§15.11). The script's own hash check and the manual run are the evidence.

## Comments

- 2026-10-30 Written from spec §15.3. `Review: human` because it changes what a release ships.

- 2026-10-30 Attempt 1 failed: exit 0. Log tail: O CI-004 foi implementado na branch `ci-004`, mas **ainda não está pronto para revisão**: permanece em `implementing` porque o gate não produziu recibo verde. /  / O script instalou o Stockfish 19 e sua licença; a segunda execução não baixou arquivos. O executável respondeu `id name Stockfish 19` e `uciok`. A saída foi registrada no [ticket](</C:/Users/bruno/Desktop/Pastinha/Programas/Projects/P-Chess/.artifacts-build/lanes/analysis/.scratch/analysis/issues/51-CI-004-stockfish-fetch-and-release.md>). /  / O gate encontrou falhas de acesso a `user://` no sandbox e processos filhos começaram a se multiplicar após timeouts. A saída parcial indicou 198 testes aprovados e 72 falhos; interrompi os processos dessa execução, que terminou com código `-1`. Pela regra fornecida, o gate só pode ser repetido após mudança de código. /  / Commits registrados: `423f2ed` para a implementação e `aa2f15c` para a evidência da tentativa. A árvore de trabalho está limpa. /  /

- 2026-10-30 Attempt 2 failed: exit 0; blocked after two attempts. Log tail: O CI-004 tem uma implementação anterior interrompida em **`implementing`**. Pela regra da skill `ticket-flow`, essa etapa deve ser relatada sem retomá-la às cegas. /  / A branch `ci-004` não aparece entre as referências locais ou remotas, mas os commits `423f2ed` e `aa2f15c` ainda estão acessíveis. O último registra que o Stockfish 19 respondeu `uciok` e que a segunda execução do script não baixou arquivos. O gate foi interrompido após falhas de acesso a `user://` e não produziu recibo verde; portanto, o ticket ainda não está pronto para revisão. /  / A cópia na branch da sessão continua em `to-implement`, mas está desatualizada em relação a esses commits. Não alterei arquivos nem executei o gate.
