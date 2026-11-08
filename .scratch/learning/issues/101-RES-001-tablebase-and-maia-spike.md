# RES-001: Tablebase and Maia spike
Stage: done
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - New: docs/research/tablebase.md (the only repo change; downloads and throwaway scripts stay outside the repo)

#### What to build

Answer the facts the learning spec leaves open (spec "Further Notes", §L5, §L12) before anything is built on them, and write the answers to `docs/research/tablebase.md` with sources and the commands used.

#### Acceptance criteria

1. The doc lists every Syzygy file rook and pawn against rook needs, including the smaller endings it can turn into (after captures and promotions), with each file's size and the total, from the official Syzygy file listing.
2. It states how the bundled `engine/stockfish/stockfish.exe` loads them (`setoption name SyzygyPath ...`), showing a relative-path probe with output on this Linux box using the Linux build of Stockfish 19. It measures the base directory for relative paths and recommends the path the app should pass. It cites Windows path-list and directory separator behavior from source, gives Bruno a Windows verification command, and marks that check pending.
3. It answers, with real Stockfish output: can we get win, draw or loss for the side to move in a 5-piece position, and a distance to zeroing (or a usable stand-in) per legal move? If Stockfish can't give a per-move distance, it names the alternative (for example probing the `.rtbz` files ourselves) with its cost, and says which the grader (§L6) should use.
4. It states how to get the tablebase-best move (the perfect opponent, §L8) and how long one probe and one best move take.
5. It reports how Maia-1 (1500 and 1900) plays at least 10 rook-and-pawn-against-rook positions (5 to convert, 5 to hold) against the tablebase: how often its move keeps the result, and whether holds look too easy or converts too hard.
6. It gives the size of the Lichess puzzle and standard game databases, and whether positions for the unit can be picked from them cheaply (they are CC0, ADR 0002).
7. It ends with a short recommendation for CI-005 (which files, from where, with hashes) and LEARN-006 (how to probe).

#### Verification

    Manual: Bruno reads docs/research/tablebase.md.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None: research ticket, no production code.

## Comments

- 2026-11-08 Bruno confirmed the probe design in the foreman chat: the native Fathom helper (LEARN-010) and spec L5's rewrite in `703fe57` stand. This resolves the Needs your call above; the Windows probe and course play-out difficulty checks stay pending Bruno.
- 2026-11-07 Written from `.scratch/learning/spec.md`.

- Proxy decided (opus-5.5 xhigh): proceed on Linux and do not wait for a Windows run. Criterion 2 gets measured with the Linux build of the same Stockfish 19 release (`sf_19`). The Windows-only syntax is cited from the source and stays marked pending until Bruno checks it on Windows. Build lc0 v0.32.1 natively for criterion 5. — Syzygy probing is the same code on both platforms, the ticket is `Review: human` anyway, and the repo has done this before: Windows-only live checks were written up as "pending (Bruno)" rather than holding the work (review-explore spec scenario 1, CLEAN-009). (receipt /tmp/sweatshop-proxy/20261107-223947-RES-001-ce51d3.json)

Criteria check by independent subagent (research ticket: no new tests):
- ✅ 1: docs/research/tablebase.md:5 (file sizes, hashes and closure).
- ✅ 2: docs/research/tablebase.md:41 (Linux probe and pending Windows confirmation); corrected interactive command after review.
- ✅ 3: docs/research/tablebase.md:80 (UCI result and DTZ limitation); clarified the child's DTZ sign after review.
- ✅ 4: docs/research/tablebase.md:93 (best move and timings).
- ✅ 5: docs/research/tablebase.md:99 (ten positions per net and limitations).
- ✅ 6: docs/research/tablebase.md:133 (source sizes and extraction cost).
- ✅ 7: docs/research/tablebase.md:139 (CI-005 and LEARN-006 recommendations).

## Resolution

Research and reproducible source references are in `docs/research/tablebase.md`. Stockfish 19's Linux probe found 20 WDL and 20 DTZ files; the 40 downloaded files matched the Lichess SHA-256 manifest. Maia 1500 and 1900 were measured on ten positions each. Windows confirmation remains pending (Bruno); the recommendation for per-move DTZ also requires review of spec L5's Stockfish-only assumption. Independent criteria review completed and its two corrections were rechecked.

Gate: `godot --headless -s tests/run.gd` — 569 passed, 0 failed, exit 0 on 2026-11-07, tested commit `45ae328d4b2d6e896c285b47514b50f48b948011`.

Gate evidence: /run/media/lage/New Volume/Scratch/RES-001/gate.json

#### Resolution (2026-11-07)
Verdict: Needs your call: reconcile the direct-probe recommendation with L5 before LEARN-006; Windows verification and play-out difficulty acceptance remain pending Bruno.

Reviewed the complete diff `6b92979...b54e74b` (commits `a99b2b8`, `45ae328`, `b54e74b`) against all seven criteria. Research integrated into `sweatshop/learning/2026-11-07-2234` by merge `538f99f`; no production code, test or research-document repair was needed.

##### Standards

0 findings. Only the declared primary file `docs/research/tablebase.md` and tracker metadata changed. Downloads, native builds and experiment scripts stayed on the external HDD. The explicit research exemption permits no red-green test commits; there is no production behavior to test. Terminology and dependency recommendations conform to CONTEXT.md and ADR 0002. No applicable code smells.

Reviewed `Proxy decided (opus-5.5 xhigh): proceed on Linux and do not wait for a Windows run.` against its authentic receipt `/tmp/sweatshop-proxy/20261107-223947-RES-001-ce51d3.json`. Its Linux substitution and criterion 2 amendment are disclosed below; no additional proxy decisions were made during review.

##### Spec

0 confirmed findings; all numbered research criteria are met:

- ✅ 1: Independently verified all 40 downloaded files against the document, fresh Lichess byte-count and SHA-256 manifests: 47,896,448 bytes, no mismatches. The material closure includes captures and all promotions.
- ✅ 2: Reproduced the Linux relative-path probe with Stockfish 19: 20 WDL/20 DTZ files from the parent working directory, 0/0 after moving into the executable directory. Verified Windows `;` and Unix `:` list delimiters in the tagged source. The absolute-path recommendation and pending Windows command are present.
- ✅ 3: Reproduced all 18 root moves and representative scores +20000/0/-20000; direct probing confirmed root WDL +2/DTZ +1 and the capture child's WDL -2/DTZ -4. Stockfish source confirms internal root DTZ ranks are collapsed into displayed scores. Fathom is a concrete alternative with integration costs, subject to the L5 decision.
- ✅ 4: Best-move procedure and separate timing measurements are documented; recheck returned `bestmove a1h1`. Cold startup and future Windows adapter latency are explicitly outside the measurements.
- ✅ 5: Recomputed all ten positions per net from the recorded experiment: five convert/five hold each; 1500 kept 70/70 and 88/89, 1900 kept 81/81 and 53/55. These results cannot establish human difficulty; the document says so explicitly.
- ✅ 6: Lichess database source, CC0 provenance, compressed sizes and extraction costs are documented. Appropriate content yield and scan time are explicitly unmeasured.
- ✅ 7: CI-005 has a complete pinned file list/source; LEARN-006 has an explicit WDL/root-DTZ/best-move probe recommendation and failure requirements.

Affected callers and interactions examined: existing UCI path lookup, engine startup, policy requests and move sampling (`engine/uci.gd`, `bot/maia_player.gd`, `bot/move_picker.gd`); CI-005 packaging, LEARN-004 content, LEARN-006 grading, and L5/L6/L8/L12. Failure paths considered: missing tables, ambiguous UCI/root-probe success, DTZ signs and immediate zeroing, promotion material, halfmove/repetition state and Maia sampling limitations. No runtime API changed. Not examined live: Windows execution/backend behavior, future native adapter packaging and real course difficulty with Bruno.

Gate: reused the unchanged-code receipt `/run/media/lage/New Volume/Scratch/RES-001/gate.json`, tested commit `45ae328d4b2d6e896c285b47514b50f48b948011`: `godot --headless -s tests/run.gd`, 569 passed, 0 failed, exit 0. Verified log SHA-256 and exit marker; only tracker metadata changed afterward. Standards and Spec were reviewed independently by subagents, then all evidence and verdicts were checked by the closing reviewer.

Acceptance: pending | Bruno's Windows probe, approval of the downstream probe design and course-position difficulty checks; see docs/research/tablebase.md and the open destinations below.
Disclosure: decision | none | Criterion 2 uses the Linux build of the same Stockfish 19 release under the recorded proxy decision and receipt above; Windows evidence is not claimed.
Disclosure: pending | release | .scratch/learning/issues/104-CI-005-bundle-the-tablebase-files.md — Bruno must run the documented probe against the bundled Windows executable and tables before release.
Disclosure: pending | integration | .scratch/learning/issues/110-LEARN-006-grading-and-feedback.md — reconcile L5, the Stockfish-only criterion and fake-UCI seam with the direct native probe before implementing/integrating LEARN-006; this research merge does not approve that contract change.
Disclosure: pending | release | .scratch/learning/issues/108-LEARN-004-rook-endgames-content.md and .scratch/learning/issues/111-LEARN-007-play-outs.md — Bruno must assess actual course play-outs; the random-position Maia experiment does not establish hold/convert difficulty.

Standards: 0 findings. Spec: 0 findings. The human decisions and product checks above remain explicit delivery conditions.
