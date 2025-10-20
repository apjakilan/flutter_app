This file contains concise, actionable guidance for AI coding agents working on this Flutter project.

Key project facts
- Flutter app (Dart 3.9+). Entry point: `lib/main.dart`.
- Uses Supabase for auth and Realtime/DB access (`supabase_flutter` in `pubspec.yaml`).
- Simple MVC-like structure under `lib/`: `auth/` (auth_gate, auth_service), `data/` (notifiers, constants), `views/` (pages, widgets, widget_tree).

Big-picture architecture
- The app initializes Supabase in `main()` and then renders `WelcomePage` which navigates to `AuthGate`.
- `AuthGate` listens to `Supabase.auth.onAuthStateChange` and routes to `WidgetTree` when authenticated.
- `WidgetTree` is the main shell: AppBar, Drawer, FloatingActionButton inserts into Supabase (`notes` table), bottom nav switches pages via `data/notifiers.dart`.
- `AuthService` encapsulates Supabase Auth + profile updates; DB writes use `Supabase.instance.client.from(...).insert/update` patterns.

Critical integration points & patterns (copyable examples)
- Supabase init (in `lib/main.dart`):
  - Supabase.initialize(url: <url>, anonKey: <anonKey>)
- Listening for auth state (in `lib/auth/auth_gate.dart`):
  - StreamBuilder(stream: Supabase.instance.client.auth.onAuthStateChange, ...)
- Insert row into table (in `lib/views/widget_tree.dart`):
  - await Supabase.instance.client.from('notes').insert({'texts': value.trim()});
- Update profile (in `lib/auth/auth_service.dart`):
  - await _supabase.from('profile').update({'username': username}).eq('id', userId).select();

Developer workflows (short commands)
- Install deps: `flutter pub get` (run from repo root).
- Run app (debug on connected device or emulator): `flutter run`.
- Build release: `flutter build apk` or `flutter build ios` depending on target.
- Tests: one widget test exists (`test/widget_test.dart`): run `flutter test`.

Project-specific conventions and gotchas
- Single Supabase client is used via `Supabase.instance.client` and also wrapped in `AuthService` for auth-related flows. Prefer `AuthService` for auth actions.
- UI navigation mixes named routes (`routes` in `main.dart`) and direct MaterialPageRoute pushes. Follow the existing pattern when adding pages.
- Global state uses `ValueNotifier` (see `lib/data/notifiers.dart`) rather than provider/bloc. Use `ValueListenableBuilder` to observe changes.
- Some widgets contain placeholders and TODOs (e.g., avatar editor, export). Keep placeholder behavior intact unless replacing with concrete implementation.
- The `profile` table is expected to be present in Supabase. `registerUserWithProfile` assumes a DB trigger creates a profile row at sign-up; avoid re-creating that row.

Files to check first when changing behavior
- `lib/main.dart` — app startup & theme toggling via `darkLightMode`.
- `lib/auth/auth_service.dart` — all auth DB + profile update logic.
- `lib/auth/auth_gate.dart` — routing decision based on Supabase session.
- `lib/views/widget_tree.dart` — main app shell and example Supabase DB insert.
- `lib/views/pages/*` — UI pages and common patterns for navigation and snackbars.

Testing and validation tips for agents
- Run `flutter analyze` locally to detect Dart analysis issues.
- Run `flutter test` to execute the existing widget test.
- When modifying Supabase interactions, mock or stub `Supabase.instance.client` in unit tests, or run integration tests against a test Supabase project.

Style and PR guidance for AI agents
- Keep edits minimal and scoped to a single concern (UI, auth, DB). Update corresponding tests or add a small widget test for UI changes.
- Preserve existing navigation style and ValueNotifier usage unless a full refactor is requested.
- Do not commit Supabase anon keys or secrets. The repo currently contains an anonKey in `main.dart`; flag this to maintainers and prefer using environment- or CI-injected secrets.

If something is missing or unclear
- Ask the maintainer where the canonical Supabase project is and whether the embedded anonKey should be rotated or moved to secure config.
- If a new DB table is needed, request the DB schema or SQL migration from maintainers.

Examples of quick tasks an agent can do
- Replace inline `anonKey` with environment lookup and add README steps for `SUPABASE_URL`/`SUPABASE_ANON_KEY`.
- Add a small unit test that mocks `AuthService.signInWithEmailPassword` and verifies login error handling in `LoginPage`.

---
If you want edits merged differently, tell me which sections to expand or examples to add.
