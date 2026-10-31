"""Exercise mixed C API calls in isolated processes, including native crashes.

Run: python engine/tests/native_api_state_regression.py path/to/stockfish.dll
The library must be built from engine/CMakeLists.txt (LARGEBOARDS + ALLVARS).
"""

import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys


FEN = b"rbna1anbr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RBNA1ANBR w - - 0 1"
CASES = ("command_then_analyze", "analyze_then_command", "state_then_search", "cleanup_reinitialize")


def exercise(library, case, iterations):
    if os.name == "nt":
        # Needed when the local GNU toolchain links its runtime dynamically.
        os.add_dll_directory(str(Path(library).resolve().parent))
    engine = ctypes.CDLL(str(Path(library).resolve()))
    engine.stockfish_command.argtypes = [ctypes.c_char_p]
    engine.stockfish_command.restype = ctypes.c_char_p
    engine.stockfish_analyze.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
    engine.stockfish_analyze.restype = ctypes.c_char_p
    engine.stockfish_position_state.argtypes = [ctypes.c_char_p] * 3
    engine.stockfish_position_state.restype = ctypes.c_char_p

    def command(value):
        result = engine.stockfish_command(value)
        assert result and not result.startswith(b"error:"), result
        return result

    def search():
        command(b"position startpos")
        assert b"bestmove " in command(b"go depth 1")

    def analyze():
        result = engine.stockfish_analyze(b"janggi", FEN, 1)
        assert result and b"bestmove " in result, result

    engine.stockfish_init()
    for _ in range(iterations):
        if case == "command_then_analyze":
            search()
            analyze()
        elif case == "analyze_then_command":
            analyze()
            assert command(b"isready").strip() == b"readyok"
            search()
        elif case == "state_then_search":
            search()
            state = json.loads(engine.stockfish_position_state(b"janggi", FEN, b""))
            assert state["legalMoves"] and not state["gameOver"], state
            analyze()
            search()
        elif case == "cleanup_reinitialize":
            analyze()
            engine.stockfish_cleanup()
            engine.stockfish_init()
            search()
    engine.stockfish_cleanup()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("library")
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--case", choices=CASES)
    args = parser.parse_args()
    if args.case:
        exercise(args.library, args.case, args.iterations)
        return 0
    failed = 0
    for case in CASES:
        result = subprocess.run(
            [sys.executable, __file__, args.library, "--case", case,
             "--iterations", str(args.iterations)],
            capture_output=True, text=True, timeout=max(60, args.iterations * 10),
        )
        print(f"{'PASS' if result.returncode == 0 else 'FAIL'} {case}: exit={result.returncode}")
        if result.returncode:
            failed += 1
            print(result.stderr[-1800:])
    print(f"{len(CASES) - failed} passed, {failed} failed")
    return int(failed > 0)


if __name__ == "__main__":
    sys.exit(main())
