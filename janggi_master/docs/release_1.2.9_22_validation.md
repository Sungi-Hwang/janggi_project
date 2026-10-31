# 1.2.9 (22) native API crash repair — 2026-10-31

## Source and preservation

- Original checkout: `D:\Project\janggi-master\janggi_master`.
- Original Git HEAD: `cfb2fd7b43519368b5132b128fa30577cb88b90f`.
- The original uncommitted changes were the production version bump to
  `1.2.8+21` and Billing plugin upgrade (`in_app_purchase` 3.3.0,
  `in_app_purchase_android` 0.5.0). They are preserved in snapshot commit
  `dfdfca504ae8b6bdb6e5ee6118b5c1605b0b3236` in the independent checkout.
- The original branch, uncommitted patch, and untracked plan directory were
  left unchanged. The before/after patch SHA-256 values match.
- Source fix commit: `76f8b7878bfa601a1613045676e32f97fa922f1a`.
- Branch: `codex/fix-native-api-state-ownership-local`.
- StoryCanon was not modified.

## Repair

`ThreadPool::start_thinking` moves the `StateListPtr` into `setupStates`.
Consequently `g_states` can be null when the other C API entry point performs
its first lazy initialization. Both the command and analyze initialization
paths now allocate a fresh state list before using `back()`.

The native regression runs each scenario in a separate process so a native
crash is a test failure rather than a failure of the entire test runner.

## Fresh verification

- Windows native baseline: 3 failed, 1 passed.
- Windows fixed native library: 4 passed, 0 failed, 50 iterations per scenario
  (200 scenario iterations total).
- Windows debugger confirmed SIGSEGV in the baseline `stockfish_analyze`.
- Android API 35 x86_64 emulator, 4096-byte pages:
  - Engine extracted from the saved production 1.2.8 AAB: exit 139 / SIGSEGV
    for `position startpos -> go depth 1 -> first analyze`.
  - Engine extracted from the new 1.2.9 AAB: the same driver exits 0.
  - Baseline trace resolves offset `0xa9098` to `stockfish_analyze`.
- `flutter analyze`: no issues.
- `flutter test --reporter expanded`: 57 passed, 1 skipped, 0 failed.
  The skipped imported-game corpus test is gated by `RUN_KJA_VERIFY=1`.
- `flutter build appbundle --release`: exit 0; 318.3 seconds.
- Bundletool validation: exit 0.
- JAR signature verification: `jar verified`; upload certificate matches
  the saved production AAB. Standard self-signed upload-key trust/timestamp
  warnings remain.
- All 8 arm64-v8a/x86_64 native libraries in both the AAB and generated test
  APK pass 16KB ELF alignment. The uncompressed APK libraries also pass ZIP
  offset alignment; bundle configuration is `PAGE_ALIGNMENT_16K`.
- DataStore resolves to 1.2.0. The saved 1.2.8 AAB also passes all 8 alignment
  checks, including both `libdatastore_shared_counter.so` binaries.
- A test APK generated from the AAB installs successfully; the app process
  remains running with `com.nightsynclabs.janggihansu/.MainActivity` resumed.
  This APK uses the existing debug key; the upload AAB uses the release key.

## Upload artifact

- `build/app/outputs/bundle/release/app-release.aab`
- Package: `com.nightsynclabs.janggihansu`
- Version: `1.2.9`, versionCode `22`
- SHA-256: `DD42D7F31C17886BB164F14C91CC0F17AD7C7046BA11315824EFCA9026DBF3CD`
- Production runtime settings were recovered unambiguously from the saved
  production AAB and passed using a local, untracked defines file. No values
  or signing passwords are stored in this report or committed source.

## Remaining limits and deployment status

- A real crash in the saved production engine is reproduced and repaired.
  Its observed symbol is `stockfish_analyze`; the exact relationship to the
  separately reported `Position::attackers_to` production signature remains
  unconfirmed without the full current Play Console trace.
- A 16KB runtime image is not installed, so runtime testing used a 4KB
  emulator. Static 16KB ELF/ZIP checks passed; 16KB runtime behavior is not
  claimed as tested.
- Play Console showed the August 30 release, code 21 (1.2.8), as available on
  Google Play. Chrome connection 3 disappeared (`Browser is not available: 3`).
  This did not establish login expiry or account permission denial.
- The Chrome app launch request reported `Computer Use app approval timed
  out`. The user reopened Chrome; the same extension identity reappeared as
  connection 6, with the original signed-in Google session still valid.
- Production release draft 14 was created. AAB selection through the browser
  file chooser failed because the ChatGPT extension does not have **Allow
  access to file URLs** enabled. No AAB upload completed.
- A normal Windows file-picker fallback was attempted. Before selecting the
  Chrome window, Computer Use stopped for the turn because it could not
  determine the current browser URL with sufficient confidence to enforce
  policy. No further computer input was attempted after that stop.
- No release was submitted; no new Play review or rollout is in progress.
- An initial GitHub push was rejected by automatic approval review because
  explicit source-upload authorization was missing. The user subsequently
  explicitly approved pushing this correction branch to
  `Sungi-Hwang/janggi_project`. A remote absence check precedes the single
  authorized retry; its final result is reported separately.
- Android verification is complete and the temporary emulator has exited.
  Builds and tests are finished. There is no active AAB upload. A later Play
  upload/submission still needs this PC or another authorized upload host;
  this is not yet a state where only Google review remains.
