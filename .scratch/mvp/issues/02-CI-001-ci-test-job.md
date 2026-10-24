# CI-001: CI test job
Stage: to-review
Blocked by: CORE-001
Review: human
Difficulty: normal

- Primary files:
  - New: .github/workflows/ci.yml

#### What to build

Every push runs the test suite on GitHub Actions (§12), so a red test shows on the branch before review: Ubuntu runner, Godot 4.7 headless, the same command as the local gate.

#### Acceptance criteria

1. The workflow runs on every push to any branch.
2. The job runs on `ubuntu-latest`, downloads a pinned Godot 4.7 Linux build from its official release URL, and runs `godot --headless -s tests/run.gd`.
3. The job fails when the runner exits non-zero.
4. The job does not need `engine/` (lc0 is not on the runner); tests that need lc0 skip themselves there.

#### Verification

    gh run watch   # on the pushed ticket branch: one green run, linked in the ticket
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: a workflow file has no unit test. The evidence is the link to the green run on the ticket branch.

## Comments

- 2026-10-24 Stage 2: CORE-001 is done on the session base. No unit-test commit is required by this ticket; verification is the pushed workflow run plus the local gate. The existing tests use explicit script paths and do not require lc0 or an import cache.

- 2026-10-24 Stage 2 handoff on `ci-001`:
  - Implementation: `.github/workflows/ci.yml` runs on every push without branch/path filters, on `ubuntu-latest`, with read-only repository permission and a 15-minute timeout. It downloads the official pinned Godot 4.7.2 Linux x86_64 archive, verifies SHA-256, installs `godot`, and runs exactly `godot --headless -s tests/run.gd`.
  - Scope and failure paths: only the new workflow and this ticket changed. No GDScript function changed. The workflow invokes the existing test runner directly; it has no exit-code masking or `continue-on-error`. The existing runner tests exercise failing assertions, unloadable scripts and runtime errors through child Godot processes. No engine download or import step is needed; the fresh Linux checkout passed without `engine/`.
  - Test exemption: the ticket explicitly requires no new GDScript unit test. The workflow did not exist on the session base; its integration proof is the real Actions run, rather than an artificial YAML unit test.
  - Commits: `9260bec` starts implementation (metadata only), `9c938b4` adds the workflow, and `3e56a02` updates checkout to the official v7.0.1 release after the first green run reported checkout v4's deprecated Node 20 runtime. The final run uses Node 24 without that warning.
  - Final GitHub Actions proof: [green push run 40110593945](https://github.com/Laginho/P-Chess/actions/runs/40110593945), commit `3e56a0260009f05b8814cd8d91e6bc7d3c96063b`, Ubuntu, Godot `4.7.2.stable.official.ed1daf0bf`, checksum OK, **78 passed, 0 failed**. `gh run watch 40110593945 --exit-status` exited 0.
  - Local gate on the same final implementation commit: **78 passed, 0 failed**, exit 0. Receipt and hashed log are recorded below. `git diff --check` passed; final diff and per-commit scope were inspected.
  - Stage 3 remains pending; no merge or PR was performed during implementation.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\P-Chess-CI-001\final-gate.json

Acceptance: passed | [final Linux push run](https://github.com/Laginho/P-Chess/actions/runs/40110593945) and the local gate both passed 78/78 on `3e56a02`.
