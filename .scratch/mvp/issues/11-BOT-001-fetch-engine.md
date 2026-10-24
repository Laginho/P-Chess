# BOT-001: Engine fetch script
Stage: done
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - New: scripts/fetch-engine.ps1
  - docs/THIRD_PARTY.md (Lc0 and Maia entries)

#### What to build

`scripts/fetch-engine.ps1` downloads the pinned Lc0 build and the nine Maia nets into `engine/` and checks their SHA-256 hashes (§3.1). CI's release job uses the same script. Review is `human` because the script downloads executables.

#### Acceptance criteria

1. Runs in Windows PowerShell 5.1: no `&&`, `||`, ternary, `??` or `?.`.
2. Downloads the Lc0 v0.32.1 CPU dnnl Windows zip from its official GitHub release and extracts it to `engine/lc0/`, and downloads `maia-1100.pb.gz` … `maia-1900.pb.gz` from the official Maia release to `engine/weights/`.
3. Every file's SHA-256 is checked against a hash pinned in the script; on a mismatch the file is deleted and the script exits non-zero.
4. Files already present with the right hash are not downloaded again.
5. A `-Root <dir>` parameter sets the target folder (default: the repo root).
6. The pinned SHA-256 hashes are taken from the official GitHub release downloads, recorded with the release tags, asset names and URLs in the verification evidence (Bruno's decision, 2026-10-24; he has no local copies). The Lc0 zip hash matches GitHub's published release-asset digest; the Maia v1.0 release publishes no digests, so its nine hashes are computed from the official downloads.
7. `docs/THIRD_PARTY.md` names Lc0 and Maia, their GPL-3 licence and the exact upstream tags.

#### Verification

    powershell -NoProfile -File scripts/fetch-engine.ps1 -Root <empty temp dir>   # downloads, exit 0
    powershell -NoProfile -File scripts/fetch-engine.ps1 -Root <same dir>          # skips every file, exit 0
    Tamper one byte of a downloaded net, run again: exit non-zero.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: the script is checked by the three runs above, recorded in the ticket.

## Comments

- 2026-10-24 Proxy decided (gpt-6-astra high, fallback): Proceed with stage 2 using hashes computed from official upstream downloads; preserve comparison with Bruno's copies as an explicit human integration gate. Missing local reference files do not prevent implementing and testing the downloader, but upstream hashes cannot establish equivalence with unavailable copies. Criterion 6 incorporates this decision; Primary files and `Review: human` are unchanged.
- Bruno-copy comparison: pending — reference copies unavailable in this worktree and `D:/Desktop/Projects/P-Chess/engine/`. The earlier night-run report (`docs/relatorios/2026-10-24-sweatshop-night-core.tex`) also records missing engine files.
- Pre-implementation verification: the ticket's first PowerShell command fails because `scripts/fetch-engine.ps1` does not exist (exit -196608). Log: `C:/Users/Lage/AppData/Local/Temp/P-Chess-BOT-001-evidence-20261024/red-missing-script.txt`. The ticket explicitly exempts GDScript tests; verification uses its public command-line seam. No existing function is changed. Future callers are manual setup and CI-003's release job; inspected `docs/spec.md` §§3.1/12 and CI-003. Relevant boundaries: empty target, paths with spaces, valid cached assets, corrupt cached/downloaded assets, missing extracted files and download failure.

Disclosure: decision | integration | Criterion 6 and the proxy decision above: Bruno must compare his reference copies or explicitly accept the recorded official upstream artifacts as the baseline before integration.

#### Stage 2 verification (2026-10-24)

- Implemented only the two Primary files. No persistent test files are added, as this ticket specifies command-line verification instead of a GDScript test seam.
- Windows PowerShell 5.1.19041.6456 parses and executes the script. The initial default-parameter expression failed when `-Root` was omitted; computing the default inside the script body fixes it. The final clean default-root run from a different working directory downloaded all ten assets, extracted all ten ZIP entries, and exited 0. `-Root` also passed with an absolute and relative path containing spaces.
- Repeat run: exit 0, no `Downloading:` lines, and all 20 installed files retained their modification timestamps. This run passed inside the network-restricted sandbox.
- Flip one byte of `maia-1100.pb.gz`: exit 1, SHA-256 mismatch reported, corrupt file deleted. Additional checks independently corrupted the cached ZIP and extracted `lc0.exe`: each exited 1 and deleted the affected file. A following run restored the missing executable from the verified ZIP without downloading.
- At the HTTP boundary, an external wrapper supplied a corrupt response, then an interrupted response after writing partial bytes: each exited 1 and removed the output. The wrapper initially failed to propagate its child script's exit status; adding `exit $LASTEXITCODE` fixed the external harness, with no production change.
- Ten separately downloaded official reference assets match the final installed assets byte for byte by SHA-256. The ZIP hash also matches GitHub's release-asset `digest`; Maia v1.0 publishes no digests, so those nine hashes are computed values.
- Logs and external HTTP wrapper: `C:/Users/Lage/AppData/Local/Temp/P-Chess-BOT-001-evidence-20261024/` (`red-missing-script.txt`, `red-default-root.txt`, `green-download.txt`, `green-default-root-download.txt`, `green-repeat.txt`, `green-relative-root.txt`, `green-tamper-net.txt`, `green-tamper-*.txt`, `green-restore-exe.txt`, `green-bad-response.txt`, `green-interrupted-response.txt`, `official-assets.json`). Downloads under this checkout's ignored `engine/` are the newly fetched upstream artifacts, not Bruno's unavailable historical copies.

Provenance: [Lc0 v0.32.1](https://github.com/LeelaChessZero/lc0/releases/tag/v0.32.1), asset URL prefix `https://github.com/LeelaChessZero/lc0/releases/download/v0.32.1/`; [Maia v1.0](https://github.com/CSSLab/maia-chess/releases/tag/v1.0), asset URL prefix `https://github.com/CSSLab/maia-chess/releases/download/v1.0/`. Append the asset name below to its release's prefix. The script also pins hashes for every extracted ZIP entry, preserving upstream bytes and bundled licence notices.

| Official release asset | Computed SHA-256 |
|---|---|
| lc0-v0.32.1-windows-cpu-dnnl.zip | b9cfcfbd3dabffbfd452f6e8e087c22273721bef48eba19640b6d92006c142f5 |
| maia-1100.pb.gz | e1cf1cd0c96b8a4fa6a275f4b9fd54ed1ffebf9fe44641b9fceded310e9619c4 |
| maia-1200.pb.gz | ead4ba953f233ae732999ebc1e2b675378148527ebcfad2f0acbc5e4c224d98e |
| maia-1300.pb.gz | 36195f87bf4761834baa0bf87472b18509a7261a9d7d6f1a8443261369a733f2 |
| maia-1400.pb.gz | d5353ea6766356dad2d28920c6692f37a5f30963767f1a3105d33b4d0af011e8 |
| maia-1500.pb.gz | 35ab6f20421d59e1df3b17c5a5016947af4c6761368ef84044a9a9c7619a9a00 |
| maia-1600.pb.gz | d2c9e5948581acf4b9fc0b1e720c5dc0fe64ce80cfc4a239d3f8a42e1176c876 |
| maia-1700.pb.gz | d277eacd792d340a30abb464dc65127254e65cac57abca17facc469889b96478 |
| maia-1800.pb.gz | 0031ad7c4256b1fd09fbebd28418d644d68b26cd2a45df4967ccf5c7ec9c4965 |
| maia-1900.pb.gz | e2f565f42d7cd9f122557e6dc4eb84e5bbaedceda1d404dc485d3611c7c97a12 |

Acceptance: pending | Command-line behavior passes the checks above; comparison with Bruno's historical copies remains an integration condition under criterion 6.

#### Stage 2 handoff (2026-10-24)

- Production commit: `01e0eb601e2b90657d48e12d9506611251a836a6`. The bound gate `godot --headless -s tests/run.gd` passed: **81 passed, 0 failed**, exit 0. Only the expected malformed-theme fixture warnings were emitted; no `ERROR`, `SCRIPT ERROR` or `FAIL` lines occurred in the successful gate's stderr.
- The first sandboxed gate could not write Godot's `user://` runner fixtures and stalled. Its process tree was stopped and logs preserved as `gate-sandbox.stdout` / `gate-sandbox.stderr` in the evidence directory. The same command then passed with access to Godot's user-data directory; no source changes were needed.
- Final diff is limited to the two Primary files and this ticket; `git diff --check` passed. Downloaded engine assets remain ignored. No test-only commit is required by this ticket's explicit verification exemption.
- Human review must retain the criterion-6 integration condition. This handoff does not confirm equivalence with Bruno's unavailable historical copies.

Gate evidence: C:/Users/Lage/AppData/Local/Temp/P-Chess-BOT-001-evidence-20261024/gate.json

#### Resolution (2026-10-24)
Verdict: Needs your call: Criterion 6 requires Bruno to confirm the historical-copy comparison or explicitly accept the recorded official upstream artifacts before integration.

- Reviewed `7c904638a6d9b023d4d75446fb08f960965a2101...422758cb8d26930ed1d2e120b8e7f54ac26f486a`, including every commit's file separation. The implementation is limited to the two Primary files; the remaining changes are this ticket's metadata. The ticket explicitly exempts persistent GDScript tests in favor of command-line red/green verification. No production or test changes were authored during review.

##### Standards

- No findings. The implementation follows the documented scope, uses small named checksum/download functions, and documents usage and provenance. No baseline code smell warrants a finding. The independent Standards reviewer inspected PowerShell 5.1 parsing, the failure logs, and the successful gate receipt.

##### Spec

- No implementation defects or unasked scope creep. Criteria 1-5 and 7 pass: Windows PowerShell 5.1 compatibility; the exact official Lc0 and Maia asset versions and installation paths; pinned checksums with deletion and nonzero exit on mismatch; cache reuse; default/custom roots; and attribution. The independent Spec reviewer hashed all 20 installed files against their pins and confirmed that the archive's ten entries exactly match the extracted-file manifest.
- Criterion 6's provenance and stage-2 handoff requirements pass; its explicit human integration condition is pending. Bruno's historical copies remain unavailable at `D:/Desktop/Projects/P-Chess/engine/`. The fresh downloads in this lane are not historical reference copies. No confirmation of equivalence or explicit acceptance of the replacement baseline has been received.
- Independently checked the [official Lc0 release-asset digest](https://github.com/LeelaChessZero/lc0/releases/expanded_assets/v0.32.1): it matches the pinned ZIP SHA-256. The [Maia v1.0 asset listing](https://github.com/CSSLab/maia-chess/releases/expanded_assets/v1.0) names all nine networks and publishes no digests. Exact-tag licence texts match the attributions. Maia checksum provenance also relies on the recorded stage-2 official-download evidence.

##### Verification and review coverage

- Revalidated the existing gate receipt: exit 0, matching log SHA-256, tested production commit `01e0eb601e2b90657d48e12d9506611251a836a6` is an ancestor of HEAD, and only this ticket changed afterward. Gate result remains **81 passed, 0 failed**. Reused this evidence because production is unchanged.
- Independently parsed and ran the cached installation in Windows PowerShell **5.1.19041.6456**: exit 0, zero downloads, all 20 installed files retained their sizes and modification timestamps. `git diff --check` passed.
- Red/green evidence reviewed: the pre-implementation invocation fails because the script is missing; the implemented script passes clean installation and repeated cached execution. Corrupt net, ZIP and executable runs fail and delete the affected file; missing executable restoration succeeds offline. Reviewed the external HTTP wrapper and its correction to propagate the child exit status; corrupt and interrupted responses fail and remove their output.
- Callers and interactions examined: manual setup, `docs/spec.md` sections 3.1/12, and CI-003's planned release invocation and licence packaging. Failure/boundary paths examined: empty target; default root independent of working directory; absolute/relative roots with spaces; valid cache; corrupt cached/downloaded assets; interrupted transfer; and missing extracted files. Live UCI/gameplay and clean-machine release acceptance are outside this ticket and were not run. Historical-copy equivalence remains unverified.
- The existing stage-2 `Proxy decided (gpt-6-astra high, fallback)` contract change was explicitly reviewed: it permits implementation/review with upstream hashes while reserving baseline acceptance to Bruno. That integration condition is preserved.

- 2026-10-24 Proxy escalated (gpt-6-astra high, fallback): Criterion 6 explicitly requires Bruno's decision before integration; the proxy cannot waive it. Upstream hashes and passing tests do not establish equivalence with unavailable historical copies, and a bare ticket ID is not explicit baseline acceptance. Record this review as blocked on `BOT-001`; do not merge, close, or add a ledger entry.
- Human question: Do you explicitly accept the official Lc0 v0.32.1 and Maia v1.0 artifacts, with the hashes recorded above, as the baseline for integration (recommended), or should integration wait for comparison with your historical copies?

Acceptance: pending | Implementation review passes with 0 Standards findings and 0 Spec defects; criterion 6's human integration condition remains unresolved. Reviewed commit: `422758cb8d26930ed1d2e120b8e7f54ac26f486a`.

Disclosure: pending | integration | Criterion 6 and this Resolution: Bruno must explicitly accept the recorded upstream baseline or confirm comparison with his historical copies. The implementation stays on `BOT-001`; no session merge or completion ledger entry is made.

- 2026-10-24 Bruno decided (human, relayed to the foreman): "Aceito os arquivos oficiais do GitHub como referência dos hashes; não tenho cópias locais. Registre isso no BOT-001 no lugar do critério 6." Folded into criterion 6 in place of the comparison with his copies. This answers the Needs-your-call verdict above and the integration condition of the proxy decision and Disclosures; no code changed. Stage restored to `to-review` for re-review.

Disclosure: decision | integration | Resolved 2026-10-24: Bruno accepted the official GitHub release artifacts as the hash baseline (criterion 6).

#### Resolution (2026-10-24, re-review)
Verdict: Approve

- Re-review of the diff since the previous pass, `422758c...d0b0787` (rebased `64ffe7c`): ticket metadata only. Production is unchanged since the tested commit `01e0eb6` (`git diff --stat 01e0eb6 BOT-001 -- . ':!.scratch'` is empty after the rebase onto the session). The previous pass had no ❌ items; its only open point was criterion 6's human condition, now rewritten from Bruno's decision.
- Merged into the session as `83b8d00` (`--no-ff`); the rebase onto the session was clean. No production or test changes were authored during review.

##### Standards

- No findings. The re-review diff touches only this ticket. The Standards sub-agent flagged the `#### Resolution` heading placement as breaking the `## Comments` convention; dismissed: the ticket-flow loop mandates appending a `#### Resolution (YYYY-MM-DD)` block to the ticket.

##### Spec

- Criterion 6 as rewritten passes: the script builds its URLs from the official `LeelaChessZero/lc0` `v0.32.1` and `CSSLab/maia-chess` `v1.0` release download prefixes with the exact asset names; all ten pinned asset hashes equal the provenance table above; tags, asset names, URLs and hashes are recorded in the verification evidence; the Lc0 ZIP hash matches GitHub's published release-asset digest (checked independently in the previous pass); `docs/THIRD_PARTY.md` states the Maia hashes are computed because v1.0 publishes no digests. No conflict with the other criteria.
- Criteria 1-5 and 7: pass, carried from the previous pass; the code they were verified against is unchanged.
- `Proxy decided (gpt-6-astra high, fallback)` (stage 2): implement with hashes from official upstream downloads, keep the historical-copy comparison as a human integration gate. That gate is now closed by Bruno's decision (`Bruno decided`, relayed through the foreman, `d0b0787`), folded into criterion 6. The earlier `Proxy escalated` line and the "Bruno-copy comparison: pending" note are history, superseded by that decision.

##### Verification and review coverage

- Gate receipt `C:/Users/Lage/AppData/Local/Temp/P-Chess-BOT-001-evidence-20261024/gate.json`: exit 0, code `01e0eb6`, log reports **81 passed, 0 failed**. Reused: no production changed during rebase or review. This session could not recompute the log's SHA-256 (sandbox blocks the temp directory); the previous pass verified it.
- Examined: the criterion-6 rewrite against the script, `docs/THIRD_PARTY.md` and the recorded evidence; Comments and Disclosures for contradictions. Not re-examined: callers, failure paths and cross-feature interactions, unchanged since the previous pass recorded them. Live UCI/gameplay and clean-machine release remain outside this ticket (BOT-002, CI-003).

Acceptance: passed | Command-line runs under "Stage 2 verification" (clean download, cached repeat, tamper, interrupted/corrupt response, default/relative roots), the gate receipt above, and Bruno's acceptance of the upstream hash baseline (criterion 6).

Disclosure: decision | none | Criterion 6 rewritten from Bruno's decision (2026-10-24, `d0b0787`): the official GitHub release artifacts are the hash baseline; this resolves the stage-2 proxy decision's integration condition and the previous pass's Needs-your-call.
