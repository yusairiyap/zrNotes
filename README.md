# zrNotes

Minimalist notes on a free canvas. Each note is a page where sections can be
dropped anywhere, dragged, coloured and zoomed, with folders, subnotes, a mind
map, Markdown editing and six "vibes" that change the whole feel of the app.

Built with Flutter (Android, iOS, Windows, Web) and Supabase.

## Try it

```bash
flutter pub get
flutter run -d chrome --dart-define=DEMO=true   # sample notes, no account
flutter run -d windows                          # real sign-in and sync
```

Builds for Windows (`.zip` and installer `.exe`) and Android (`.apk`) are
attached to each run under the repository's **Actions** tab.

The web version is published from `main` to
`https://yusairiyap.github.io/zrNotes/`. Every pull request also gets a
preview at `https://yusairiyap.github.io/zrNotes/pr-<number>/`, linked in a
comment on the pull request and removed when it closes.

This needs Settings → Pages → Source set to **Deploy from a branch**, branch
`gh-pages`, folder `/ (root)`, and `https://yusairiyap.github.io/zrNotes/**`
added to Supabase under Authentication → URL Configuration → Redirect URLs.

## Setup that needs your accounts

**Google sign-in.** Create an OAuth client in Google Cloud Console, then in
the Supabase dashboard open Authentication → Providers → Google and paste the
client id and secret. Add `dev.zr.zrnotes://login-callback` under
Authentication → URL Configuration → Redirect URLs. Email sign-in works
without any of this.

**Signed Android builds.** Create a keystore once:

```bash
keytool -genkey -v -keystore zrnotes.jks -keyalg RSA -keysize 2048 -validity 10000 -alias zrnotes
base64 -w0 zrnotes.jks
```

and add these repository secrets: `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
Without them the APK is signed with the debug key, which installs fine but
cannot be updated by a properly signed build later.

## More

See [CLAUDE.md](CLAUDE.md) for the architecture and conventions.
