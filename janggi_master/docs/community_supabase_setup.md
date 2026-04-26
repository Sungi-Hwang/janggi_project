# Problem Community Supabase Setup

## Required project settings

- Create a Supabase project.
- Enable Google in **Authentication > Providers**.
- Use Android package name `com.nightsynclabs.janggihansu`.
- Apply `supabase/migrations/20260426000000_community_puzzles.sql`.

## Flutter build defines

Run the app with the Supabase project values:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID
```

`GOOGLE_IOS_CLIENT_ID` is optional and only needed for an iOS Google client.

If these values are not supplied, the app still opens normally and the
`문제 공유소` screen shows a setup-required state.
