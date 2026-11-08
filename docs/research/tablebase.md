# RES-001: Syzygy and Maia spike

Research on 2026-11-07, on the Linux machine. This is an experiment, not an implementation. The Windows check below is **pending Bruno**. Sources: the [Lichess Syzygy file listing](https://tablebase.lichess.ovh/tables/standard/), its [byte counts](https://tablebase.lichess.ovh/tables/standard/bytes.tsv) and [SHA-256 manifest](https://tablebase.lichess.ovh/tables/standard/sha256); [Stockfish 19 source](https://github.com/official-stockfish/Stockfish/blob/sf_19/src/syzygy/tbprobe.cpp); [Lichess database](https://database.lichess.org/).

## Files and dependency closure

Start with `KRPvKR`: either rook or the pawn can be captured; the pawn can promote to Q, R, B or N, with or without capturing the opposing rook. Apply captures repeatedly to those configurations. Colours can be swapped; Syzygy uses one canonical material name for either orientation. K vs K is an immediate draw and has no file. Even the tiny `KBvK` and `KNvK` pairs are included in this conservative complete closure. Both WDL (`.rtbw`) and DTZ (`.rtbz`) files are needed for the proposed direct probe. These are **40 files, 47,896,448 bytes (45.68 MiB)**. Sizes and hashes below are from the Lichess manifests, then checked against all downloaded files with `sha256sum -c`.

| Material | WDL bytes | DTZ bytes | WDL SHA-256 | DTZ SHA-256 |
| --- | ---: | ---: | --- | --- |
| KBvK | 80 | 80 | `bc0d8ab3560de9038460f0e8f61e3b7efd3e3d0327d19ae0387c0da7ddeb244d` | `6246c8a5c643eec9d4758d55ed843e31cc28a9b82a6f630c1c950d8b7755975b` |
| KNvK | 80 | 80 | `9d3518b12df3d2006441df758bce31e961346e70a11920aaad75c647003bb6e7` | `0e49a0f2810a131c32fc14872e83044aa9810ce2c86df071851512077291fc25` |
| KPvK | 7,824 | 4,176 | `02fd2bdcd92821c869458f019f63524def1c9e7a2862ca8d2b16dc7712b16183` | `ad01af2076183c90ccee662ca6c5d74da3222ff1fee47c01b5d4e56ed01938de` |
| KQRvK | 4,560 | 44,112 | `b018ece9cc195618981b027268f9cca929a1ed4c0bdd739874b7846640ef479a` | `9766d3e684582297943583e1981154609655034cea2aa78a5494cc01c8c6bcee` |
| KQRvKR | 279,824 | 3,421,968 | `13477ef681468dfb19d09ab8dbeb08d259f9db57a6e5e2c7cdb902880fc2166b` | `6ed2eba7b9d5b7813a30751a0e1dd3561e499c1ffe76b5de98ea7ad5b006fdbd` |
| KQvK | 272 | 5,392 | `517667dff787162dbb1ed9d5d6484d30ee854e686ee0675c08d99ecf045d2d50` | `71ea9444fa5bd42897d781a0c356975ea6f23e0f65a4254e470897031c161c8c` |
| KQvKR | 20,496 | 309,008 | `8cdbe3c8e098037875de5854c656f8afeadb8327c85b5b7b1cac81719afd3e2c` | `0c15a2aaa3bdef39da4c26932006b5d38b55b8e3ad13e8a44815d63f84738618` |
| KRBvK | 2,832 | 261,776 | `9e6eced11a37cad71b4fc1a4f62a15e191e58883b51ce8c4c45f341051c6ae8e` | `e3bb6fbd54a57a154136ecee763a8e9862d8ab3f57b2f55387df70bdbff1b140` |
| KRBvKR | 2,035,280 | 575,440 | `6343cff1ca9d4026aed57ede37ebd29004d11c9d8ec932351b04b4e8018ce8b9` | `e6ee6691bde20eceedd44b26adab5b3328d9ca758153693775b65d3a51ae11cb` |
| KRNvK | 2,320 | 295,632 | `4f96cab9fc0005f2679eacb92cec32edf9c932db7bb29b5dc7659be0012d6c35` | `150b85874a78474a38d0f36f1ab39d387f524a1c2092ad92d3d0945d96c17d16` |
| KRNvKR | 1,491,856 | 287,632 | `163432941d6f625c093c7291d2045453f712435e906e9d91d371105da96f97c4` | `4183e43f92e4ea0126028acc59b991b36dabdf944d53a61e9e7367374aebbe06` |
| KRPvK | 5,136 | 12,944 | `6bc2aa9db5ee7fcc287e6c3b006ab6cfc2be4dff4ae7ca4a524a78520eea61db` | `5c89c9ef70c144bb2d6d823a41668ccf2f79b486b6bc128ff01aadb5485c06a9` |
| KRPvKR | 16,378,576 | 13,725,456 | `1100e6deaee14ca9a56b69441208462c02ef45b3f56daa3d75f687eb5cf12319` | `184ce33fa4dcfa931f7a3b9955662e166287ec203224ae9681d527d3b8cd9c6f` |
| KRRvK | 1,936 | 53,520 | `4c05ec32e6e43b690d235307de75432a3ceecdbc3d2659d8101ed15b48b8445d` | `e68314e00bf9f16122005a06f7d42bc0f6c682f30e8ca50532ba44444f3b96ce` |
| KRRvKR | 334,224 | 7,700,816 | `7897a69c7ad337adc93aa39c9d22dcf1a5e215908437b36d92db5e4bebf9217e` | `dd0fe4d32ccbfc390e8d4468fa5a31484e26abdb45d712cdfe1b8b5fe0a05c14` |
| KRvK | 208 | 7,632 | `386fbde73308e49a4207836922c68b30b664e83c5a37f7fa37305a15cd16f2f1` | `cab59f42e75c2a25da3939231850a79fa838593fff5c28d7772da92062ed965a` |
| KRvKB | 32,912 | 9,936 | `69b247cb390ffcd729cf5fe5c40f8a24803190bf67b108b8f05b8b08b26a6a72` | `4fa644478a516e1425b22a740ddefc4d54e51298250b8208d26073df3638630b` |
| KRvKN | 100,048 | 93,200 | `a8cde902b010bf6c8763c97d19b5430b422e74db9cb8e9d5e67fa07373c13c5b` | `c0df57d0b066cdd7be5bdf9b14745f6ead1fd8e9fba2b77fe0f3cb56ebef7ae0` |
| KRvKP | 179,408 | 193,424 | `3968c2bfced3a5ecfbb54166ec13d4e7b70f3b03c495af4ae87cad2ec75a0749` | `6d4b1389832854119df815ff89ed2cb0786e8887f000009f0db3484457f7f6ff` |
| KRvKR | 12,944 | 3,408 | `797081b5b3fbac20c4baa5453d68bdae1425b63895f5c9a5ac5c68ea63a97712` | `c23fa5a0209204b847232ed49e079c099cf603b43d6ace9e27257793b1839850` |

The mirror URLs are `https://tablebase.lichess.ovh/tables/standard/3-4-5-wdl/<name>.rtbw` and `.../3-4-5-dtz/<name>.rtbz`. Example commands (replace `<name>` for each row):

```sh
curl -fLO https://tablebase.lichess.ovh/tables/standard/3-4-5-wdl/KRPvKR.rtbw
curl -fLO https://tablebase.lichess.ovh/tables/standard/3-4-5-dtz/KRPvKR.rtbz
curl -fsSL https://tablebase.lichess.ovh/tables/standard/sha256 -o sha256
sha256sum -c <(grep -E ' (KRPvKR)\.rtb[zw]$' sha256)
```

## Stockfish loading and real output

Stockfish 19 Linux release `stockfish-linux-x86-64-universal.tar.gz` SHA-256 `9defc0d4e55d49c65a6d042f3e571a39fcea499ade6dbe741b53b8c65e03611f`; the Windows archive pinned in `scripts/fetch-engine.ps1` has SHA-256 `3c8bf1f9ea66a09350a40df4f632288285ac206d99f33ab5842c408fc30b48a7`. Downloaded from [sf_19](https://github.com/official-stockfish/Stockfish/releases/tag/sf_19). With the current directory containing `tables/` and the binary under `stockfish/`, send:

```text
uci
setoption name SyzygyPath value tables
isready
position fen 8/8/8/4k3/8/4K3/4P3/R6r w - - 0 1
go depth 1
```

Actual Linux output (abridged):

```text
info string Found 20 WDL and 20 DTZ tablebase files (up to 5-man).
readyok
info depth 1 ... score cp 20000 ... tbhits 18 ... pv a1h1 ...
bestmove a1h1
```

Moving the working directory into `stockfish/` with the same `SyzygyPath value tables` instead reported `Found 0 WDL and 0 DTZ ...`. Thus the relative path is relative to the **process working directory**, not the executable. Build and pass an absolute, UTF-8 path to the extracted data directory in the app. Stockfish's [file-opening code](https://github.com/official-stockfish/Stockfish/blob/sf_19/src/syzygy/tbprobe.cpp) appends names to paths using `std::filesystem`; its documented directory-list delimiter is `;` on Windows, `:` on Unix. Its Windows example uses backslashes; the app should use one absolute path, avoiding list delimiters. Forward-slash Windows behavior has not been measured here.

**Pending (Bruno):** from the release root, after placing all files under `engine/tablebase`, start the shipped exe and enter the UCI commands interactively. Wait for `bestmove` before entering `quit`; check that `Found 20 WDL and 20 DTZ` and `bestmove a1h1` appear:

```powershell
.\engine\stockfish\stockfish.exe
```

```text
uci
setoption name SyzygyPath value engine\tablebase
isready
position fen 8/8/8/4k3/8/4K3/4P3/R6r w - - 0 1
go depth 1
```

After `bestmove`, enter `quit`.

### WDL, distance and a perfect move

For that FEN, `setoption name MultiPV value 18`, followed by the position and `go depth 1`, gave all 18 legal moves. Representative real lines, truncated at the first PV move:

```text
info depth 1 ... multipv 1 score cp 20000 ... tbhits 18 ... pv a1h1
info depth 1 ... multipv 2 score cp 0 ... tbhits 18 ... pv a1a5
info depth 1 ... multipv 8 score cp -20000 ... tbhits 18 ... pv a1a3
bestmove a1h1 ponder e5d5
```

For this position these are respectively win, draw and loss for White, the side to move. An independent direct probe returned root WDL `+2`, DTZ `+1`; the first move is an immediate capture, so its zeroing distance is 1 ply, even though the resulting position's DTZ is -4 for Black (magnitude 4). Side-to-move signs reverse after a move. `MultiPV` output is **not a general exact-WDL API**: it is UCI search output and can be absent, incomplete, or a normal evaluation if a root table is missing or search is interrupted; `tbhits` alone does not prove all root moves were tablebase-ranked. Stockfish reports scores, not each move's DTZ. [Its root code](https://github.com/official-stockfish/Stockfish/blob/sf_19/src/syzygy/tbprobe.cpp) calculates DTZ and ranks moves internally, then maps many ranks to the same displayed score. A centipawn difference or PV length is not DTZ.

Stockfish's root tablebase ranking and `bestmove` can produce a perfect move with a complete set, successful root probe and 50-move/repetition handling. There is no explicit UCI success flag identifying that exact root probe; fail closed when completeness or interpretation is uncertain, never silently substitute an engine evaluation. Direct root probing offers an explicit result and avoids that ambiguity. Respect terminal positions, legal moves, side-to-move, the halfmove clock, repetition/history and the distinction between unconditional wins/losses and cursed wins/blessed losses. DTZ is plies to the next pawn move or capture, not distance to mate; Syzygy DTZ can be rounded by one ply, and comparison margins must account for that and immediate zeroing moves.

Warm timings on this machine (Intel Core i5-9300H, single sample position, cache warm, not a latency guarantee): 25 Stockfish UCI `go depth 1` calls, already started, median **2.85 ms**, range **2.73–3.00 ms**; this includes command/pipe round trip and returns the best move. The independent Python Syzygy reader took a median **0.063 ms** each for WDL or DTZ over 200 warm root calls. This is a different implementation and excludes process startup; it is not a measurement of a future Windows adapter.

A direct native probe such as [Fathom](https://github.com/jdart1/Fathom) (MIT) can read WDL/DTZ and expose root move results. Cost: native Windows build/packaging, Godot binding or a separate helper protocol, legality and state/50-move tests, licensing notice, and lifecycle/error handling. The Python reader used for this experiment is GPL and is not a proposed bundled dependency. Recommend this route for **LEARN-006** if the DTZ-margin requirement remains: compare the actual and best move with the probe's root-move semantics, rather than guessing DTZ from Stockfish's score. This would change spec L5's assumption that the real probe is only bundled Stockfish; resolve that design change in human review before implementation. Relaxing the margin to WDL-only would be a product change, not an equivalent result.

## Maia experiment

Lc0 v0.32.1, native Linux Eigen backend, Maia-1 1500 and 1900 official nets (hashes below), `go nodes 1` and `VerboseMoveStats`, matching the app's one-node policy interface. The Windows build uses DNNL; its numerical differences and Windows timings were not measured. A local throwaway Python script used python-chess 1.11.2 to read the downloaded Syzygy tables. The script built legal random KRPKR positions with seed `20261107`, rejecting checks and immediate captures, with five losing positions for the defending Maia (user converts) and five drawn positions for the attacking Maia (user holds). This is a convenience sample, not selected course content or a representative human-game sample. Each model played one sampled trajectory per position against a tablebase WDL-preserving opponent, at most 60 plies, stopping on material change, terminal game or promotion. The opponent chose maximal WDL and used child DTZ as a tie-break; it did not implement full halfmove/repetition-aware DTZ ranking, so it is **not a validated 50-move-perfect opponent**. The experiment compared theoretical five-valued WDL at each move, rather than adjudicating the 50-move rule.

Maia moves were sampled from the reported policy with the app's default 2% cutoff and temperature 1, with no book weights or time pressure. Each row shows Maia's first sampled UCI move and the number of its sampled moves which retained its own WDL, over that entire trajectory. The two models used successive draws from the same seeded RNG; they were not paired samples.

| # | User goal | Starting FEN (Maia to move) | Maia 1500 first; kept | Maia 1900 first; kept |
| --- | --- | --- | --- | --- |
| 1 | convert | `K7/8/4R3/8/2P5/8/2k5/1r6 b - - 0 1` | `b1b4`; 15/15 | `c2c3`; 12/12 |
| 2 | convert | `8/5r2/P7/7R/8/8/8/1K2k3 b - - 0 1` | `f7a7`; 5/5 | `f7a7`; 18/18 |
| 3 | convert | `8/8/8/3R2P1/8/8/4K3/5rk1 b - - 0 1` | `g1g2`; 4/4 | `f1f2`; 9/9 |
| 4 | convert | `8/8/2R5/1P1k2r1/8/1K6/8/8 b - - 0 1` | `g5g3`; 29/29 | `g5g3`; 21/21 |
| 5 | convert | `1k6/7K/8/8/2R5/6P1/8/4r3 b - - 0 1` | `e1e3`; 17/17 | `e1g1`; 21/21 |
| 6 | hold | `8/7k/8/R7/5K2/5P2/8/5r2 w - - 0 1` | `a5g5`; 27/27 | `f4e4`; 8/9 |
| 7 | hold | `8/4k3/8/8/6K1/6P1/3R4/1r6 w - - 0 1` | `d2e2`; 19/20 | `d2h2`; 30/30 |
| 8 | hold | `1k6/5r2/P7/8/2K5/8/R7/8 w - - 0 1` | `c4b5`; 19/19 | `c4b5`; 3/4 |
| 9 | hold | `2K5/8/2R5/8/6P1/4k3/7r/8 w - - 0 1` | `c8d8`; 18/18 | `g4g5`; 7/7 |
| 10 | hold | `8/2k5/5R2/7P/r7/8/8/5K2 w - - 0 1` | `h5h6`; 5/5 | `h5h6`; 5/5 |

Across convert positions, 1500 retained loss on **70/70** moves and 1900 on **81/81**. That is mathematically uninformative about defending quality: a position already lost under optimal play cannot become worse than loss. It does **not** show converts are easy or hard. On the drawn hold positions, 1500 retained the current WDL on **88/89** sampled moves; 1900 on **53/55**. There was one draw-to-loss move at 1500 and two at 1900; later moves can preserve an already lost result, so those aggregate ratios do not measure the probability of holding an entire game. Maia can hand the defending player a win, but these few artificial positions cannot establish that holds are too easy. Likewise, a tablebase-perfect opponent is not a human converting player; test actual course positions and human play-outs before tuning difficulty. One hold line promoted while preserving a draw, so promotion alone is not a general game-result test.

Commands used (large assets and build remain outside the repo):

```sh
git clone --depth 1 --branch v0.32.1 --recurse-submodules --shallow-submodules https://github.com/LeelaChessZero/lc0.git lc0-src
meson setup lc0-build lc0-src -Dgtest=false -Dispc=false -Dplain_cuda=false -Donnx=false
ninja -C lc0-build -j 4
# For each net start: lc0-build/lc0 --weights=<absolute-net-path> --backend=eigen
# Send uci, setoption name VerboseMoveStats value true, isready,
# then position fen <FEN> and go nodes 1 for each Maia turn.
```

Nets downloaded from [Maia v1.0](https://github.com/CSSLab/maia-chess/releases/tag/v1.0): `maia-1500.pb.gz` SHA-256 `35ab6f20421d59e1df3b17c5a5016947af4c6761368ef84044a9a9c7619a9a00`; `maia-1900.pb.gz` SHA-256 `e2f565f42d7cd9f122557e6dc4eb84e5bbaedceda1d404dc485d3611c7c97a12`. Each matches `scripts/fetch-engine.ps1`.

## Position sources

The [Lichess database](https://database.lichess.org/) states that its exports are CC0. On 2026-11-07 the puzzle export had **6,193,530 puzzles**, updated 2026-11-03; a HEAD request to `https://database.lichess.org/lichess_db_puzzle.csv.zst` reported **309,751,173 compressed bytes** (about 295 MiB). It is CSV with FEN, moves, ratings and themes. The FEN is *before* the opponent's first move, so apply that move before filtering the position the solver sees. Stream decompression and filter for exactly two kings, two rooks and one pawn; this is inexpensive in storage, though an exact hit count and scan time were not measured. Puzzles are selected for tactical solutions and are not a representative endgame pool.

The standard game archive lists **8,315,708,510 games, 166 monthly files, 2.63 TB compressed**; October 2026 alone is **31 GB, 95,395,628 games**. Streaming a month or a partial download avoids storing the whole archive, but parsing PGNs and replaying games to identify the five-piece material costs substantially more compute than filtering puzzle FENs. Lichess says decompressed games average roughly 7.1 times their compressed size and supports streaming. Availability of enough appropriate positions was not measured; check and curate them before committing to either source.

## Recommendations

- **CI-005:** Fetch and pin both file types for every material row above, from Lichess's named WDL/DTZ directories, validating each against the listed SHA-256 before bundling. Fail on a missing or mismatched file. Keep downloads outside the repository and add notices; verify the actual Windows path and startup before release.
- **LEARN-006:** Use one explicit probe boundary returning WDL and root-move DTZ, plus best move and a clear failure. Evaluate Fathom integration as described above; do not infer exact DTZ from UCI scores. Include 50-move/repetition and promotion/zeroing cases in its real-adapter verification. This recommendation requires the L5 design assumption to be reconciled in human review.
