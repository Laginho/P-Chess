# CI-004: Fetch and ship Stockfish 19
Stage: done
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

- Proxy decided (opus-5.5 xhigh): Accept with one change: set CI-004 to `to-implement` and resume from `recovery/20261030-1847/CI-004` by cherry-picking only 423f2ed (drop aa2f15c entirely), then redo the manual check and run the gate once with the installed Godot - the code is done and the only problems were the environment and the stale ticket text. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-190030-CI-004-9cf28d.json)
- 2026-10-30 Resume, don't restart. This ticket's `Stage:` on the session branch is the real state. `recovery/20261030-1847/CI-004` is only code to reuse. Its copy of this ticket (`Stage: implementing`, "Stage remains implementing") is old evidence, not the state, and does not trigger the "interrupted implementing" rule. Steps: (1) cut the ticket branch from the session and `git cherry-pick 423f2ed` only, never aa2f15c; (2) do the Verification's manual step again: delete `engine/stockfish`, run `scripts/fetch-engine.ps1` twice, pipe `uci` into the exe, and record the new output here (criterion 5); (3) run the gate once. Resolve Godot in this order: `where.exe godot`; if that finds nothing, call `C:\Users\bruno\AppData\Local\Programs\Godot\godot.cmd` directly (the binary REV-001 passed 274/0 with in this sandbox); never download Godot. Attempt 1's gate does not count: it used a different binary, was killed and exited -1. If no installed Godot runs, or Godot can't create folders under `user://`, stop only your own child processes, write an environment note here and stop. That is not a code problem, so don't run the gate a second time. No Godot tests are owed (§15.11).

- 2026-10-30 Verification: stockfish directory absent before first fetch; first run downloaded and verified the archive, executable and licence. Second run completed without downloads. Gate: 274 passed, 0 failed; exit 0.

```text
Stockfish 19 by the Stockfish developers (see AUTHORS file)
id name Stockfish 19
id author the Stockfish developers (see AUTHORS file)

option name Debug Log File type string default <empty>
option name NumaPolicy type string default auto
option name Threads type spin default 1 min 1 max 1024
option name Hash type spin default 16 min 1 max 33554432
option name Clear Hash type button
option name Ponder type check default false
option name MultiPV type spin default 1 min 1 max 256
option name Skill Level type spin default 20 min 0 max 20
option name Move Overhead type spin default 10 min 0 max 5000
option name nodestime type spin default 0 min 0 max 10000
option name UCI_Chess960 type check default false
option name UCI_LimitStrength type check default false
option name UCI_Elo type spin default 1320 min 1320 max 3190
option name UCI_ShowWDL type check default false
option name SyzygyPath type string default <empty>
option name SyzygyProbeDepth type spin default 1 min 1 max 100
option name Syzygy50MoveRule type check default true
option name SyzygyProbeLimit type spin default 7 min 0 max 7
option name EvalFile type string default nn-1a298aa575a0.nnue
uciok
```

Gate evidence: C:\Users\bruno\AppData\Local\Temp\ci-004-gate-20261030.json

#### Resolution (2026-10-30)

Verdict: Approve

- Standards: 0 documented violations and 0 relevant heuristic smells. An independent reviewer checked Windows PowerShell 5.1 compatibility, Primary-files scope, commit separation and the existing download/validation conventions.
- Spec: 0 findings from a second independent reviewer. Criteria 1-5 passed; no production behavior was authored during stage 3.
- Coverage: reviewed all 6 changed files in `c748352b902402f47da000ab1d206b1ab0798c60...0fe9ddf9ee570770bda0d7f8e6ad1c3292603fb4`, including all 3 Markdown files OCR excluded as `unsupported_ext`. OCR coverage: 3/3 reviewable files; complete Git coverage: 6/6, none skipped, 100%.
- Criterion 1: passed. The pinned official universal archive's SHA-256 matches the [published release-asset digest](https://github.com/official-stockfish/Stockfish/releases/expanded_assets/sf_19). Local archive, executable and licence hashes match the script. An external fixture executed the actual script AST blocks with a mocked transfer of the verified archive: corrupt ZIP, exe and licence each fail with the shared SHA-256 message, delete the corrupt file, and recover on the next run.
- Criterion 2: passed. A full Windows PowerShell 5.1 rerun of `scripts/fetch-engine.ps1` exited 0 without downloads. The fixture also checked a fresh Stockfish installation, cached rerun and restoration of a missing exe from the cached ZIP. The stage-2 fresh network download remains the recorded transfer evidence; review's fixture did not download over the network.
- Criterion 3: passed. The workflow calls the same fetch script with the package root. Executing its exact package-validation/archiving block produced a fixture ZIP containing both Stockfish files. Removing either file rejected the package before archiving. All 8 multiline workflow PowerShell blocks parsed under Windows PowerShell 5.1. Fixture application and other engine files were placeholders; this was not a Godot export or a tagged Actions release.
- Criterion 4: passed. `docs/THIRD_PARTY.md` identifies the official release, exact `sf_19` source tag, GPLv3 and unmodified distribution. The real extracted `Copying.txt` is present and hash-verified, and the workflow includes the notices in the package and release notes.
- Criterion 5: passed. Review independently piped `uci` and `quit` into the installed executable: `id name Stockfish 19`, `uciok`, exit 0. Stage 2's full output remains above.
- Examined callers and failure paths: default-root local fetch, release fetch with `-Root`, Lc0/Maia validation and cache behavior, Stockfish archive/file integrity, missing entries/files, failure cleanup and archive disposal, Git ignores, package validation and compression, and the executable path expected by the generic UCI bridge. Full Stockfish game analysis remains [REV-002](53-REV-002-analysis-engine-and-files.md); no gameplay, clean-machine release acceptance or tagged workflow execution was performed here.
- Red/green evidence: the ticket explicitly requires no new Godot tests. Production and metadata are separated in `f2d4694` and `0fe9ddf`. Review's corruption and missing-package-file fixtures exercise the production blocks rather than a copied implementation. Fixture script and output: `C:\Users\bruno\AppData\Local\Temp\P-Chess-CI-004-review-20261030-190958\verify.ps1` and `verification.log` (exit 0).
- Verification: reused the bound gate on production commit `f2d4694543b903ef229a297be7ef97aa8fdc102d`: 274 passed, 0 failed, 0 skips, exit 0. Verified the receipt, log SHA-256 and unchanged production using `Assert-GateEvidence` after merging. Log: `C:\Users\bruno\AppData\Local\Temp\ci-004-gate-20261030.log`. The gate was not repeated in review.
- Proxy decision reviewed: the existing `Proxy decided (opus-5.5 xhigh): Accept with one change` record matches receipt `C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-190030-CI-004-9cf28d.json`. The committed implementation reuses only the production change, preserves the resumed ticket state, records fresh manual output, and supplies the new green gate. This resolved an environment/state recovery; no product criterion changed or known defect was deferred.
- Integration: rebased onto `sweatshop/analysis/2026-10-30-1831` (already current), then merged without squash as `181777e`. `Review: human` is carried to the driver's eventual session PR; this stage does not push or open a separate PR.

Acceptance: passed | Local fetch/cache verification, Stockfish UCI handshake and package integrity checks above; external fixture evidence is linked in this Resolution.
Disclosure: decision | none | [Recovery decision above](#comments), checked against its proxy receipt, was fulfilled without changing the contract.
Disclosure: pending | release | [Product QA in spec section 15.1](../../../docs/spec.md#151-release-and-tickets) remains Bruno's release acceptance. The future tagged workflow and clean-machine Stockfish package have not been exercised; local fixture checks establish packaging behavior, not that release acceptance. Game analysis remains the open [REV-002](53-REV-002-analysis-engine-and-files.md) deliverable.
