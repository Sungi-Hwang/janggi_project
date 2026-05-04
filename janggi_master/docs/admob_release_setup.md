# AdMob release setup

Debug builds may use Google's sample ad IDs, but release builds must use this
app's production AdMob IDs.

## Required values

- `ADMOB_APP_ID`: Android app ID, format `ca-app-pub-...~...`
- `ADMOB_ANDROID_BANNER_ID`: Android banner ad unit ID, format `ca-app-pub-.../...`
- `ADMOB_ANDROID_INTERSTITIAL_ID`: Android interstitial ad unit ID, format `ca-app-pub-.../...`

## Current Android production values

These values are already wired into the Android release build:

```text
ADMOB_APP_ID=ca-app-pub-5593224479644015~7853283941
ADMOB_ANDROID_BANNER_ID=ca-app-pub-5593224479644015/3813684745
ADMOB_ANDROID_INTERSTITIAL_ID=ca-app-pub-5593224479644015/6990601711
```

Debug builds keep using Google's sample ad units by default. To force production
ad units in a debug build, pass
`--dart-define=ADMOB_USE_PRODUCTION_ADS_IN_DEBUG=true`.

## Release build example

The default Android release build now uses the production IDs above:

```powershell
flutter build appbundle --release
```

You can still override them at build time:

```powershell
flutter build appbundle --release `
  --dart-define=ADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY `
  --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB `
  --dart-define=ADMOB_ANDROID_INTERSTITIAL_ID=ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII
```

`ADMOB_APP_ID` may also be supplied through an `ADMOB_APP_ID` environment
variable for local Gradle builds, but using `--dart-define` keeps the Flutter
release command self-contained. The banner and interstitial IDs must be passed
as `--dart-define` values because they are read by Flutter code at runtime.

If any release value is missing or still uses Google's sample publisher ID
`ca-app-pub-3940256099942544`, the Android release build fails intentionally.
