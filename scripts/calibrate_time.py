"""Offline Maia time calibration; see BOT-007 and docs/spec.md section 4.3.

Install script-only dependencies with:
    python -m pip install -r scripts/requirements-calibrate.txt

Plan only (no network access):
    python scripts/calibrate_time.py --url <monthly.pgn.zst URL> --max-bytes 2000000000
Only after Bruno approves that download in chat, repeat with --download-approved.
The default sample is a seeded reservoir of up to 10,000 positions. Buckets
need 50 observations; --max-positions, --seed and --min-samples tune these.
No calibrated table is bundled until an approved run produces real data.
"""

import argparse
from dataclasses import dataclass
from bisect import bisect_right
from collections import Counter, defaultdict
from contextlib import contextmanager
import io
import math
from pathlib import Path
import json
import queue
import random
import re
import subprocess
import threading
import time
from urllib.parse import urlparse
from urllib.request import Request, urlopen

import chess
import chess.pgn
import zstandard


CONTROLS = {"60+0": (60, 0, "1+0"), "180+2": (180, 2, "3+2"),
            "300+0": (300, 0, "5+0")}
CLOCK_BINS = [0, 0.15, 0.5, 1]
TOP_P_BINS = [0, 0.3, 0.6, 1]
ROOT = Path(__file__).resolve().parents[1]
MOVE_LINE = re.compile(r"^info string ([a-h][1-8][a-h][1-8][qrbn]?) .*\(P: *([0-9.]+)%\)")


@dataclass(frozen=True)
class Sample:
    fen: str
    control: str
    level: str
    clock_fraction: float
    seconds: float
    start_fen: str
    moves: tuple[str, ...]


class LimitedReader:
    """Never ask the HTTP response for bytes past the approved download cap."""

    def __init__(self, source, max_bytes):
        self.source = source
        self.remaining = max_bytes

    def read(self, size=-1):
        size = self.remaining if size < 0 else min(size, self.remaining)
        if not size:
            return b""
        data = self.source.read(size)
        self.remaining -= len(data)
        return data


@contextmanager
def pgn_stream(source, max_bytes):
    """Decode a bounded compressed prefix in memory, including partial frames."""
    if max_bytes <= 0:
        raise ValueError("max_bytes must be positive")
    limited = LimitedReader(source, max_bytes)
    with zstandard.ZstdDecompressor().stream_reader(
            limited, read_across_frames=True, closefd=False) as reader:
        with io.TextIOWrapper(reader, encoding="utf-8", errors="replace") as text:
            yield text


def extract_samples(pgn):
    """Yield timed moves; ratings belong to the mover, ties round upward.

    A missing clock breaks that player's consecutive interval. First moves
    are untimed in Lichess and the game, so are used only as a baseline.
    """
    while (game := chess.pgn.read_game(pgn)) is not None:
        timing = CONTROLS.get(game.headers.get("TimeControl"))
        if not timing or game.errors or game.headers.get("Variant", "Standard") != "Standard":
            continue
        start, increment, control = timing
        levels = {}
        for side, header in [(chess.WHITE, "WhiteElo"), (chess.BLACK, "BlackElo")]:
            try:
                rating = int(game.headers.get(header, "?"))
            except ValueError:
                continue
            if 1100 <= rating <= 1900:
                levels[side] = f"maia-{((rating + 50) // 100) * 100}"
        board = game.board()
        start_fen = game.headers.get("FEN", board.fen())
        moves = []
        previous = {chess.WHITE: None, chess.BLACK: None}
        for node in game.mainline():
            side = board.turn
            before, after = previous[side], node.clock()
            if side in levels and before is not None and after is not None:
                seconds = before - after + increment
                if seconds >= 0:
                    yield Sample(board.fen(), control, levels[side], before / start, seconds,
                                 start_fen, tuple(moves))
            previous[side] = after
            moves.append(node.move.uci())
            board.push(node.move)


def _fit_rounded_lognormal(seconds):
    """MLE under P(d | t) = max(0, 1 - abs(d - t)), grouped by recorded d."""
    counts = Counter(seconds)
    if not any(counts):
        # All-zero data has its likelihood supremum at zero; keep JSON's median positive.
        return 1e-6, 0.0
    intervals = [(d, n, [math.log(x) if x > 0 else -math.inf
                          for x in (d - 1, d, d + 1)]) for d, n in counts.items()]

    def loss(parameters):
        mu, log_sigma = parameters
        # Numerical search bounds, well beyond the dump's observed clock range.
        if not -20 <= mu <= 20 or not -7 <= log_sigma <= 2:
            return math.inf
        sigma = math.exp(log_sigma)
        mean = math.exp(mu + sigma * sigma / 2)

        def mass(a, b):
            # erfc keeps small tail intervals when both CDFs would round to 1.
            if a > 0:
                return (math.erfc(a / math.sqrt(2)) - math.erfc(b / math.sqrt(2))) / 2
            return (math.erfc(-b / math.sqrt(2)) - math.erfc(-a / math.sqrt(2))) / 2

        total = 0.0
        for d, count, edges in intervals:
            lo, mid, hi = [(edge - mu) / sigma for edge in edges]
            left = mean * mass(lo - sigma, mid - sigma) - (d - 1) * mass(lo, mid)
            right = (d + 1) * mass(mid, hi) - mean * mass(mid - sigma, hi - sigma)
            total -= count * math.log(max(left + right, 1e-300))
        return total

    point = (math.log(sum(seconds) / len(seconds)), math.log(0.8))
    best = loss(point)
    step = 0.5
    while step > 1e-5:
        candidates = [(point[0] + x * step, point[1] + y * step)
                      for x in (-1, 0, 1) for y in (-1, 0, 1) if x or y]
        candidate = min(candidates, key=loss)
        value = loss(candidate)
        if value < best:
            point, best = candidate, value
        else:
            step /= 2
    return math.exp(point[0]), math.exp(point[1])


def build_table(samples, top_probability, min_samples=50):
    """Fit sampled moves to BOT-006's table; sparse buckets use the fallback.

    top_probability(sample) evaluates its pre-move position and history with its Maia level.
    Fit whole-second clock differences without clamping zero observations.
    Bin edges match bot/time_model.gd: lower inclusive, end bins clamped.
    """
    if min_samples < 1:
        raise ValueError("min_samples must be positive")
    groups = defaultdict(list)
    for sample in samples:
        probability = top_probability(sample)
        if not math.isfinite(probability) or not 0 <= probability <= 1:
            raise ValueError("top-move probability must be finite and in [0, 1]")
        clock_bin = bisect_right(CLOCK_BINS[1:-1], sample.clock_fraction)
        top_p_bin = bisect_right(TOP_P_BINS[1:-1], probability)
        groups[sample.control, sample.level, clock_bin, top_p_bin].append(sample.seconds)
    buckets = []
    for (control, level, clock_bin, top_p_bin), seconds in sorted(groups.items()):
        if len(seconds) >= min_samples:
            median, log_sigma = _fit_rounded_lognormal(seconds)
            buckets.append({"control": control, "level": level, "clock_bin": clock_bin,
                            "top_p_bin": top_p_bin, "median": median,
                            "log_sigma": log_sigma})
    return {"clock_bins": CLOCK_BINS, "top_p_bins": TOP_P_BINS, "buckets": buckets}


def sample_positions(samples, limit, seed):
    """Uniform reservoir: memory stays bounded while scanning the entire prefix."""
    rng = random.Random(seed)
    reservoir = []
    for count, sample in enumerate(samples, 1):
        if len(reservoir) < limit:
            reservoir.append(sample)
        elif (index := rng.randrange(count)) < limit:
            reservoir[index] = sample
    # Grouping avoids loading a different Maia net on every sampled position.
    return sorted(reservoir, key=lambda sample: (sample.level, sample.control))


@contextmanager
def lc0_policy(engine, weights, timeout=30):
    """Yield a callable returning legal root-move top P, as engine/uci.gd does."""
    process = subprocess.Popen([str(engine)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, text=True, encoding="utf-8",
                               bufsize=1, cwd=ROOT)
    replies = queue.Queue()

    def read_output():
        try:
            for line in process.stdout:
                replies.put(line.rstrip())
        finally:
            replies.put(None)

    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()

    def send(command):
        process.stdin.write(command + "\n")
        process.stdin.flush()

    def receive_until(prefix):
        deadline = time.monotonic() + timeout
        while True:
            try:
                line = replies.get(timeout=max(0, deadline - time.monotonic()))
            except queue.Empty as error:
                raise RuntimeError(f"Lc0 timed out waiting for {prefix}") from error
            if line is None:
                raise RuntimeError(f"Lc0 stopped while waiting for {prefix}")
            yield line
            if line.startswith(prefix):
                return

    level = None

    def top_probability(sample):
        nonlocal level
        if sample.level != level:
            net = weights / f"{sample.level}.pb.gz"
            if not net.is_file():
                raise FileNotFoundError(f"Missing Maia net: {net}")
            send("ucinewgame")
            send(f"setoption name WeightsFile value {net}")
            send("isready")
            list(receive_until("readyok"))
            level = sample.level
        # Maia uses historical boards: match the game's initial FEN plus all prior moves.
        position = f"position fen {sample.start_fen}"
        if sample.moves:
            position += " moves " + " ".join(sample.moves)
        send(position)
        send("go nodes 1")
        board = chess.Board(sample.fen)
        probabilities = []
        for line in receive_until("bestmove"):
            match = MOVE_LINE.match(line)
            if match:
                try:
                    board.parse_uci(match[1])  # Also normalizes Lc0's king-takes-rook castling.
                except ValueError:
                    continue
                probabilities.append(float(match[2]) / 100)
        if not probabilities:
            raise RuntimeError(f"Lc0 returned no legal root policy for {sample.fen}")
        return max(probabilities)

    try:
        send("uci")
        list(receive_until("uciok"))
        send("setoption name VerboseMoveStats value true")
        # No PolicyTemperature override: coupled to engine/uci.gd start(), BOT-008,
        # and BOT-007's proxy decision (Lc0 v0.32.1 default 1.359 in both).
        yield top_probability
    finally:
        if process.poll() is None:
            try:
                send("quit")
                process.wait(timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                process.kill()
                process.wait()
        reader.join(timeout=5)
        process.stdin.close()
        process.stdout.close()


def positive_int(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", required=True, help="monthly Lichess .pgn.zst dump URL")
    parser.add_argument("--max-bytes", required=True, type=positive_int,
                        help="maximum compressed download bytes")
    parser.add_argument("--download-approved", action="store_true",
                        help="only use after Bruno approves this download in chat")
    parser.add_argument("--max-positions", type=positive_int, default=10000)
    parser.add_argument("--min-samples", type=positive_int, default=50)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--engine", type=Path, default=ROOT / "engine/lc0/lc0.exe")
    parser.add_argument("--weights", type=Path, default=ROOT / "engine/weights")
    parser.add_argument("--output", type=Path, default=ROOT / "data/time_model.json")
    args = parser.parse_args(argv)
    url = urlparse(args.url)
    if url.scheme not in {"http", "https"} or not url.netloc or not url.path.endswith(".pgn.zst"):
        parser.error("--url must be an HTTP(S) .pgn.zst URL")
    print(f"Planned download: at most {args.max_bytes:,} compressed bytes "
          f"({args.max_bytes / 1024**3:.3f} GiB) from {args.url}", flush=True)
    if not args.download_approved:
        print("Plan only. After Bruno approves in chat, repeat with --download-approved.")
        return 0
    try:
        engine, weights = args.engine.resolve(), args.weights.resolve()
        if not engine.is_file() or any(
                not (weights / f"maia-{level}.pb.gz").is_file()
                for level in range(1100, 1901, 100)):
            raise FileNotFoundError("Install Lc0 and all nine Maia nets with scripts/fetch-engine.ps1")
        request = Request(args.url, headers={"Range": f"bytes=0-{args.max_bytes - 1}",
                                            "Accept-Encoding": "identity"})
        with urlopen(request, timeout=60) as response:
            if response.status == 206 and not response.headers.get("Content-Range", "").startswith("bytes 0-"):
                raise ValueError("Server did not return the start of the dump")
            with pgn_stream(response, args.max_bytes) as pgn:
                samples = sample_positions(extract_samples(pgn), args.max_positions, args.seed)
        print(f"Evaluating {len(samples):,} sampled positions with Maia", flush=True)
        with lc0_policy(engine, weights) as top_probability:
            table = build_table(samples, top_probability, args.min_samples)
        # Replace only after successful extraction, engine evaluation and serialization.
        output = json.dumps(table, indent=2, allow_nan=False) + "\n"
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_suffix(args.output.suffix + ".tmp")
        temporary.write_text(output, encoding="utf-8")
        temporary.replace(args.output)
        print(f"Wrote {len(table['buckets'])} buckets to {args.output}; "
              f"buckets below {args.min_samples} samples use the game's formula.")
        return 0
    except (OSError, ValueError, RuntimeError, zstandard.ZstdError) as error:
        parser.exit(1, f"Calibration failed: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
