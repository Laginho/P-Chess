"""Offline Maia time calibration; see BOT-007 and docs/spec.md section 4.3.

Install script-only dependencies with:
    python -m pip install -r scripts/requirements-calibrate.txt
"""

from dataclasses import dataclass
from bisect import bisect_right
from collections import defaultdict
import math
import statistics

import chess
import chess.pgn


CONTROLS = {"60+0": (60, 0, "1+0"), "180+2": (180, 2, "3+2"),
            "300+0": (300, 0, "5+0")}
CLOCK_BINS = [0, 0.15, 0.5, 1]
TOP_P_BINS = [0, 0.3, 0.6, 1]


@dataclass(frozen=True)
class Sample:
    fen: str
    control: str
    level: str
    clock_fraction: float
    seconds: float


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
        previous = {chess.WHITE: None, chess.BLACK: None}
        for node in game.mainline():
            side = board.turn
            before, after = previous[side], node.clock()
            if side in levels and before is not None and after is not None:
                seconds = before - after + increment
                if seconds >= 0:
                    yield Sample(board.fen(), control, levels[side], before / start, seconds)
            previous[side] = after
            board.push(node.move)


def build_table(samples, top_probability, min_samples=50):
    """Fit sampled moves to BOT-006's table; sparse buckets use the fallback.

    top_probability(sample) evaluates its pre-move FEN with its Maia level.
    Zero-second premoves use the game's 0.05 s floor before taking logarithms.
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
        groups[sample.control, sample.level, clock_bin, top_p_bin].append(
            max(0.05, sample.seconds))
    buckets = []
    for (control, level, clock_bin, top_p_bin), seconds in sorted(groups.items()):
        if len(seconds) >= min_samples:
            buckets.append({"control": control, "level": level, "clock_bin": clock_bin,
                            "top_p_bin": top_p_bin, "median": statistics.median(seconds),
                            "log_sigma": statistics.pstdev(math.log(s) for s in seconds)})
    return {"clock_bins": CLOCK_BINS, "top_p_bins": TOP_P_BINS, "buckets": buckets}
