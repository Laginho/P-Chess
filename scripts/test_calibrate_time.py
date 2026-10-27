from pathlib import Path
from collections import Counter
from dataclasses import replace
import io
import math
import random
import subprocess
import sys
import json

import pytest

from calibrate_time import extract_samples


FIXTURE = Path(__file__).resolve().parents[1] / "tests/fixtures/lichess_sample.pgn"


def test_fixture_extracts_consecutive_clocks_for_each_players_rating():
    with FIXTURE.open(encoding="utf-8") as pgn:
        samples = list(extract_samples(pgn))

    # First moves are untimed. 180 - 179 + 2 = 3 s for White's Nf3;
    # Black's separate clock gives 180 - 178 + 2 = 4 s for Nc6.
    assert [(s.control, s.level, s.seconds) for s in samples] == [
        ("3+2", "maia-1500", 3),
        ("3+2", "maia-1900", 4),
        ("3+2", "maia-1500", 5),
        ("3+2", "maia-1900", 3),
        ("1+0", "maia-1100", 3),
        ("5+0", "maia-1900", 4),
        ("1+0", "maia-1500", 2),
        ("3+2", "maia-1500", 1),
    ]
    assert samples[2].clock_fraction == pytest.approx(179 / 180)
    # Position before White's second move, with both opening moves present.
    assert samples[0].fen == (
        "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"
    )


def test_buckets_match_game_edges_and_omit_sparse_groups():
    from calibrate_time import build_table

    with FIXTURE.open(encoding="utf-8") as pgn:
        example = next(extract_samples(pgn))
    # These now represent rounded differences, not exact think times.
    samples = [replace(example, clock_fraction=0.5, seconds=s) for s in (1, 2, 4)]
    samples += [replace(example, level="maia-1100", seconds=99)]
    table = build_table(samples, lambda sample: 0.6, min_samples=3)
    assert table["clock_bins"] == [0, 0.15, 0.5, 1]
    assert table["top_p_bins"] == [0, 0.3, 0.6, 1]
    assert len(table["buckets"]) == 1
    bucket = table["buckets"][0]
    assert (bucket["control"], bucket["level"], bucket["clock_bin"], bucket["top_p_bin"]) == (
        "3+2", "maia-1500", 2, 2)
    assert 0 < bucket["median"] < 4
    assert math.isfinite(bucket["log_sigma"]) and bucket["log_sigma"] >= 0
    # Increment can lift clocks above their starting time. Both end bins clamp.
    for fraction, top_p, expected in [(1.1, 1, (2, 2)), (0, 0, (0, 0)),
                                       (0.15, 0.3, (1, 1))]:
        table = build_table([replace(example, clock_fraction=fraction, seconds=0)],
                            lambda sample: top_p, min_samples=1)
        bucket = table["buckets"][0]
        assert (bucket["clock_bin"], bucket["top_p_bin"]) == expected
        assert math.isfinite(bucket["median"]) and 0 < bucket["median"] < 0.5
        assert math.isfinite(bucket["log_sigma"]) and bucket["log_sigma"] >= 0
    assert build_table([], lambda sample: 0.6)["buckets"] == []


@pytest.mark.parametrize("median, sigma", [(0.6, 0.5), (4, 0.8)])
def test_fit_recovers_log_normal_from_whole_second_clock_differences(median, sigma):
    from calibrate_time import build_table

    with FIXTURE.open(encoding="utf-8") as pgn:
        example = next(extract_samples(pgn))
    rng = random.Random(37)
    samples = []
    for _ in range(30000):
        elapsed = rng.lognormvariate(math.log(median), sigma)
        # Two whole-second clock readings with an independent uniform phase.
        before = 1000 + rng.random()
        difference = math.floor(before) - math.floor(before - elapsed)
        samples.append(replace(example, seconds=difference))
    bucket, = build_table(samples, lambda sample: 0.4)["buckets"]
    assert bucket["median"] == pytest.approx(median, rel=0.1)
    assert bucket["log_sigma"] == pytest.approx(sigma, rel=0.1)


def test_all_zero_bucket_has_a_finite_subsecond_fit():
    from calibrate_time import build_table

    with FIXTURE.open(encoding="utf-8") as pgn:
        example = next(extract_samples(pgn))
    bucket, = build_table([replace(example, seconds=0)] * 100,
                          lambda sample: 0.4)["buckets"]
    assert math.isfinite(bucket["median"]) and 0 < bucket["median"] < 0.5
    assert bucket["median"] != 0.05
    assert math.isfinite(bucket["log_sigma"]) and bucket["log_sigma"] >= 0


def test_fixture_extraction_from_a_capped_zstandard_stream():
    import zstandard
    from calibrate_time import pgn_stream

    compressed = zstandard.ZstdCompressor().compress(FIXTURE.read_bytes())
    source = io.BytesIO(compressed + b"must not be read")
    with pgn_stream(source, len(compressed)) as pgn:
        assert len(list(extract_samples(pgn))) == 8
    assert source.tell() == len(compressed)

    # A cap can cut a zstd frame and a PGN game. Earlier data stays usable.
    compressor = zstandard.ZstdCompressor().compressobj()
    prefix = compressor.compress(FIXTURE.read_bytes())
    prefix += compressor.flush(zstandard.COMPRESSOBJ_FLUSH_BLOCK)
    tail = compressor.compress(FIXTURE.read_bytes()) + compressor.flush()
    prefix += tail[:-10]
    source = io.BytesIO(prefix + b"must not be read")
    with pgn_stream(source, len(prefix)) as pgn:
        assert list(extract_samples(pgn))
    assert source.tell() == len(prefix)


def test_cli_plans_then_calibrates_offline_fixture_with_local_uci_process(tmp_path, monkeypatch, capsys):
    import calibrate_time as calibration

    def forbidden_network(*args, **kwargs):
        pytest.fail("A plan must not open the network")

    monkeypatch.setattr(calibration, "urlopen", forbidden_network)
    args = ["--url", "https://example.invalid/month.pgn.zst", "--max-bytes", "2000000000"]
    assert calibration.main(args) == 0
    assert "2,000,000,000" in capsys.readouterr().out

    import zstandard
    compressed = zstandard.ZstdCompressor().compress(FIXTURE.read_bytes())

    class Response(io.BytesIO):
        status = 206
        headers = {"Content-Range": f"bytes 0-{len(compressed) - 1}/9999999"}
        consumed = 0

        def read(self, size=-1):
            result = super().read(size)
            self.consumed += len(result)
            return result

    response = Response(compressed + b"past the permitted prefix")

    def fixture_response(request, timeout):
        assert request.get_header("Range") == f"bytes=0-{len(compressed) - 1}"
        assert request.full_url == "https://example.invalid/month.pgn.zst"
        return response

    monkeypatch.setattr(calibration, "urlopen", fixture_response)
    weights = tmp_path / "Maia weights"
    weights.mkdir()
    for rating in range(1100, 1901, 100):
        (weights / f"maia-{rating}.pb.gz").touch()
    engine = tmp_path / "lc0.exe"
    engine.touch()
    transcript = tmp_path / "uci.txt"
    fake = tmp_path / "fake_lc0.py"
    fake.write_text('''
import sys
from pathlib import Path
import chess
board = chess.Board()
for line in sys.stdin:
    command = line.strip()
    with Path(sys.argv[1]).open('a', encoding='utf-8') as log:
        log.write(command + '\\n')
    if command == 'uci':
        print('uciok', flush=True)
    elif command == 'isready':
        print('readyok', flush=True)
    elif command.startswith('position fen '):
        fen, _, moves = command[len('position fen '):].partition(' moves ')
        board = chess.Board(fen)
        for move in moves.split():
            board.push_uci(move)
    elif command == 'go nodes 1':
        move = next(iter(board.legal_moves)).uci()
        print('info string a1a8  (1) N: 1 (P: 99.00%)', flush=True)
        print(f'info string {move}  (1) N: 1 (P: 40.00%)', flush=True)
        print(f'bestmove {move}', flush=True)
    elif command == 'quit':
        break
''', encoding="utf-8")
    real_popen = subprocess.Popen

    def fake_lc0(command, **kwargs):
        assert command == [str(engine)]
        return real_popen([sys.executable, "-u", str(fake), str(transcript)], **kwargs)

    monkeypatch.setattr(calibration.subprocess, "Popen", fake_lc0)
    output = tmp_path / "data/time_model.json"
    args = ["--url", "https://example.invalid/month.pgn.zst", "--max-bytes", str(len(compressed)),
            "--engine", str(engine), "--weights", str(weights), "--output", str(output),
            "--min-samples", "1", "--per-stratum", "1000"]
    # The approved flag here executes only local fixture I/O: no download occurs.
    assert calibration.main(args + ["--download-approved"]) == 0
    assert response.consumed == len(compressed)
    table = json.loads(output.read_text(encoding="utf-8"))
    assert len(table["buckets"]) == 5
    assert all(b["clock_bin"] == 2 and b["top_p_bin"] == 1 for b in table["buckets"])
    assert 2 < next(b["median"] for b in table["buckets"]
                    if b["control"] == "3+2" and b["level"] == "maia-1500") < 4
    commands = transcript.read_text(encoding="utf-8").splitlines()
    assert commands[:2] == ["uci", "setoption name VerboseMoveStats value true"]
    nets = [command.rsplit("maia-", 1)[1] for command in commands
            if command.startswith("setoption name WeightsFile value ")]
    assert nets == ["1100.pb.gz", "1500.pb.gz", "1900.pb.gz"]
    assert commands.count("isready") == 3
    assert commands.count("go nodes 1") == 8
    assert not any("PolicyTemperature" in command for command in commands)
    assert commands[-1] == "quit"


@pytest.mark.parametrize("scenario", ["opening", "missing_clocks", "custom_start", "no_moves"])
def test_policy_uses_initial_position_and_all_preceding_moves(tmp_path, monkeypatch, scenario):
    import calibrate_time as calibration

    start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    with FIXTURE.open(encoding="utf-8") as pgn:
        samples = list(extract_samples(pgn))
    sample = samples[0]
    moves = "e2e4 e7e5"
    legal_move = "g1f3"
    if scenario == "missing_clocks":
        sample = samples[6]
        moves = "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6"
        legal_move = "f3g1"
    elif scenario == "custom_start":
        start = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
        pgn = io.StringIO(f'''[SetUp "1"]
[FEN "{start}"]
[WhiteElo "1500"]
[BlackElo "1500"]
[TimeControl "180+2"]
[Result "*"]

1... e5 {{[%clk 0:03:00]}} 2. Nf3 {{[%clk 0:03:00]}} Nc6 {{[%clk 0:02:58]}} *
''')
        sample = next(extract_samples(pgn))
        moves = "e7e5 g1f3"
        legal_move = "b8c6"
    elif scenario == "no_moves":
        start = sample.fen
        moves = ""
        sample = replace(sample, start_fen=start, moves=())

    expected = f"position fen {start}" + (f" moves {moves}" if moves else "")
    fake = tmp_path / "history_policy.py"
    fake.write_text('''
import sys
position = ''
for line in sys.stdin:
    command = line.strip()
    if command == 'uci':
        print('uciok', flush=True)
    elif command == 'isready':
        print('readyok', flush=True)
    elif command.startswith('position '):
        position = command
    elif command == 'go nodes 1':
        probability = '46.94' if position == sys.argv[1] else '27.34'
        print(f'info string {sys.argv[2]}  (1) N: 1 (P: {probability}%)', flush=True)
        print(f'bestmove {sys.argv[2]}', flush=True)
    elif command == 'quit':
        break
''', encoding="utf-8")
    (tmp_path / f"{sample.level}.pb.gz").touch()
    real_popen = subprocess.Popen
    monkeypatch.setattr(calibration.subprocess, "Popen", lambda command, **kwargs:
                        real_popen([sys.executable, "-u", str(fake), expected, legal_move], **kwargs))
    with calibration.lc0_policy(tmp_path / "lc0.exe", tmp_path) as policy:
        assert policy(sample) == pytest.approx(0.4694)


def test_reservoir_keeps_a_bounded_seeded_sample_from_the_whole_prefix():
    from calibrate_time import sample_positions

    with FIXTURE.open(encoding="utf-8") as pgn:
        samples = list(extract_samples(pgn))
    result = sample_positions(iter(samples), 3, seed=7)
    assert len(result) == 6  # Three 3+2/1500, plus the three other strata.
    assert result == sample_positions(iter(samples), 3, seed=7)
    # A reservoir is not merely the first N positions: later games can enter.
    assert any(sample not in samples[:3] for sample in result)
    assert all(sample in samples for sample in result)
    assert len(sample_positions(iter(samples), 100, seed=7)) == 8
    assert sample_positions(iter([]), 3, seed=7) == []


def test_reservoir_limits_each_control_level_and_clock_stratum():
    from calibrate_time import sample_positions

    with FIXTURE.open(encoding="utf-8") as pgn:
        example = next(extract_samples(pgn))
    samples = []
    expected = {}
    for control in ("1+0", "3+2", "5+0"):
        for rating in range(1100, 1901, 100):
            for clock_bin, fraction in enumerate((0.0, 0.15, 0.5)):
                count = 2 if clock_bin == 2 else 20
                level = f"maia-{rating}"
                expected[control, level, fraction] = min(count, 5)
                samples.extend(replace(example, control=control, level=level,
                                       clock_fraction=fraction, seconds=i) for i in range(count))
    result = sample_positions(iter(samples), 5, seed=7)
    assert Counter((s.control, s.level, s.clock_fraction) for s in result) == expected
    assert result == sample_positions(iter(samples), 5, seed=7)
    assert result != sample_positions(iter(samples), 5, seed=8)
    assert any(s.seconds >= 5 for s in result)
    assert all(s in samples for s in result)


def test_uci_stop_while_bucketing_leaves_the_previous_table_untouched(tmp_path, monkeypatch):
    # External engine failures are visible; they must not replace an existing table.
    import calibrate_time as calibration
    import zstandard

    class Response(io.BytesIO):
        status = 200  # Servers may ignore Range; the local byte cap still applies.

    compressed = zstandard.ZstdCompressor().compress(FIXTURE.read_bytes())
    monkeypatch.setattr(calibration, "urlopen", lambda *a, **kw: Response(compressed))
    engine = tmp_path / "lc0.exe"
    engine.touch()
    for rating in range(1100, 1901, 100):
        (tmp_path / f"maia-{rating}.pb.gz").touch()
    real_popen = subprocess.Popen
    monkeypatch.setattr(calibration.subprocess, "Popen",
                        lambda command, **kwargs: real_popen([sys.executable, "-c", "pass"], **kwargs))
    output = tmp_path / "time_model.json"
    output.write_text("previous table", encoding="utf-8")
    with pytest.raises(SystemExit) as stopped:
        calibration.main(["--url", "https://example.invalid/month.pgn.zst", "--max-bytes",
                          str(len(compressed)), "--engine", str(engine), "--weights", str(tmp_path),
                          "--output", str(output), "--download-approved"])
    assert stopped.value.code == 1
    assert output.read_text(encoding="utf-8") == "previous table"
