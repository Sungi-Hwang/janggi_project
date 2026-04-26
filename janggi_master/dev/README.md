## Dev Workspace

This folder keeps development-only material out of the repository root.

- `engine/`: local engine build helpers such as Windows response files.
- `probes/`: one-off Dart and engine probe scripts that are useful for debugging but should not be part of normal analysis or test runs.
- `probes/stockfish/`: Stockfish-specific probe scripts. These use the `probe_*.dart` naming convention on purpose so they do not look like real test targets.
- `test_tmp/`: ignored local fixtures, captures, scratch exports, and validation outputs used during manual investigation.
- `puzzle_workbench/root_snapshots/`: archived puzzle-generation snapshots that were previously stored in the repository root.
- `puzzle_workbench/reports/`: generated validator reports. The directory is kept for convenience, but report files are ignored by Git.

Runtime app assets and production Flutter code remain outside this folder.
