# zrNotes

A minimalist note app where every note is a free canvas of draggable sections.
One Flutter codebase for Android, iOS, Windows and Web, with Supabase for
sign-in, storage and sync.

## Commands

```bash
flutter pub get
flutter analyze                 # must stay clean
flutter test                    # on Linux needs: libgtk-3-dev libx11-dev libxi-dev
flutter run -d chrome --dart-define=DEMO=true   # sample data, no sign-in
flutter run -d windows
flutter build apk --release --split-per-abi
flutter build windows --release
dart run flutter_launcher_icons # after changing assets/icon*.png
```

Pinned to Flutter 3.50.0 (stable). CI pins the same version.

## Things that will trip you up

- **Import Material from `package:material_ui/material_ui.dart`**, never
  `package:flutter/material.dart`. On Flutter 3.50 the old import is deprecated
  and is a *separate* set of classes. Packages that still use it (flutter_quill)
  cannot see the app theme, so `lib/theme/legacy_theme.dart` builds a matching
  legacy theme and `MaterialApp.builder` wraps the app with it. If a
  third-party widget shows up purple, that bridge is missing a colour.
- **`window_manager` 0.7 and `tray_manager` 0.9 use the new nativeapi API**
  (`WindowManager.instance.getCurrent()`, `TrayIcon.create()`). Old tutorials
  do not apply. All of it lives in `lib/platform/desktop.dart` and is a no-op
  off Windows.
- `appflowy_editor` does not compile on Flutter 3.50. The editor is
  `flutter_quill`; tables are a custom embed (`lib/ui/table_embed.dart`).
- `desktop_drop` must stay below 0.9 (conflicts with `file_picker`).
- Markdown round-trips lose colour and font size, so a section is only
  converted back from Markdown when its Markdown text was actually edited.

## Layout

```
lib/
  main.dart            app start, providers, AuthGate
  config.dart          Supabase URL/key (--dart-define overridable), DEMO flag
  models.dart          Folder, Note, Section (+ fromRow/toRow)
  data/                repository.dart (Supabase), demo_repository.dart, markdown.dart
  state/               notes_store.dart (data + saving), settings.dart (every option)
  theme/               vibes.dart (the six vibes), legacy_theme.dart
  platform/desktop.dart  Windows tray, close-to-tray, compact mode
  ui/                  home_shell, nav, note_page, canvas_view, section_card,
                       overview_view, mindmap_view, settings_page, wizard, auth_page
supabase/migrations/   SQL already applied to the hosted project
tool/                  icon source (icon.html) and renderer
```

## Architecture

- **State** is `provider` + `ChangeNotifier`: `NotesStore` and `AppSettings`.
  Edits are optimistic; typing and dragging are debounced per row (700 ms)
  and flushed before refresh and sign-out.
- **Data**: tables `folders`, `notes` (subnotes are notes with
  `parent_note_id`), `sections` (position, size, colour, Quill Delta JSON in
  `content`), `user_settings` (one JSON blob). Every table has RLS limiting
  rows to `auth.uid()`. Images go to the public `note-images` bucket under
  `<user id>/<uuid>.<ext>`.
- **Schema changes**: add a new file in `supabase/migrations/` and apply the
  same SQL to the hosted project. Never edit an applied migration.
- **Vibes**: a vibe is a `VibeSpec` (fonts, palettes, radius, borders, tab
  style, shadow, canvas pattern, motion). `buildTheme` turns it into a
  `ThemeData` plus the `VibeTheme` extension. Widgets read `VibeTheme.of(context)`
  and must not hard-code colours, radii or durations. Layout is the same in
  every vibe; only the look changes.
- **Default vibe** is the brand: ink `#16181D` on paper with highlighter
  yellow-green `#E4EE5B`, index-tab section headers, hard offset shadows,
  matching the app icon (stacked notes with "zr").
- **Canvas**: `InteractiveViewer` over a 6000×4200 scene. Scroll pans,
  Ctrl+scroll and pinch zoom. Sections drag by their tab. Below 45% zoom
  sections collapse to title + summary.
- **Settings**: every option is a field on `AppSettings`, saved locally and
  synced to `user_settings`. A new option needs: the field, `toJson`/`fromJson`,
  and a control in `settings_page.dart`. Presets live in the same file.

## Conventions

- Keep the UI minimal: no new permanent chrome without a setting to hide it.
- Respect `reduceMotion`: use `v.duration` / `Appear`, not fixed durations.
- Tap targets use `v.minTap` so the "large targets" option works.
- Comments explain why, briefly. No commented-out code.

## CI

`.github/workflows/build-apk.yml` (analyze, test, signed APK) and
`build-windows.yml` (zip + Inno Setup installer) run on pull requests, pushes
to `main` and manually. `deploy-web.yml` builds the web app on the same
triggers and publishes it to GitHub Pages from `main`. Android signing uses the secrets
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`; without them the APK is debug-signed.

## Not built yet

Mermaid diagram rendering, Android/iOS home-screen widgets, offline cache,
Google sign-in on Windows (needs a deep-link handler), iOS build in CI.
