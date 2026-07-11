# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter run                      # launch on connected device/emulator
flutter analyze                  # static analysis (flutter_lints + riverpod_lint)
flutter test                     # run tests
flutter test test/widget_test.dart   # run a single test file
dart run build_runner build --delete-conflicting-outputs   # riverpod_generator codegen
```

## What this app is

Flutter client for the SS Logistics platform. It has **no backend of its own** — all data comes from the Next.js API in `../ui-sslogistics` (see root `../CLAUDE.md` for the shared contract). `ApiConstants.baseUrl` (`lib/core/constants/api_constants.dart`) resolves in this order: an explicit `--dart-define=API_BASE_URL=...` always wins; otherwise release builds (`kReleaseMode`) default to the production URL automatically; otherwise debug/profile builds use `http://10.0.2.2:3000` on the Android emulator / `http://localhost:3000` on the iOS simulator. No manual swap is needed before release — `scripts/build_release.sh` only needs `API_BASE_URL` set if you're intentionally pointing a release build at a non-default backend (e.g. staging).

Stack: Riverpod (state), GoRouter (navigation), Dio (HTTP).

## Architecture

Feature-first layout under `lib/`:

- `core/` — cross-cutting infrastructure: `network/dio_client.dart`, `router/app_router.dart`, `constants/`, `storage/`.
- `features/<name>/` — each feature has `data/` (repository making Dio calls), `providers/` (Riverpod), `screens/`, `widgets/`.
- `shared/` — models (`AppUser`, `Vehicle`, …) and reusable widgets (`ErrorState`, `AppDrawer`).

### Networking & sessions (the part that's easy to break)

- `DioClient` (singleton, initialized in `main()`) uses a `PersistCookieJar` — the Supabase auth **cookies are the session**; there are no bearer tokens. `validateStatus` accepts anything `< 500`, so 4xx responses arrive as normal `Response` objects: repositories must check `response.statusCode == 200 && data['success'] == true` and throw `Exception(data['error'])` otherwise.
- The cookie jar is backed by `SecureCookieStorage` (`lib/core/network/secure_cookie_storage.dart`), which persists cookies in `flutter_secure_storage` (Keystore/Keychain) rather than plain files — the session is the only credential this app holds. `DioClient.init()` also does a best-effort one-time delete of the old plaintext `.cookies/` directory from pre-migration installs (signs the user out once on upgrade).
- **Single-login handling**: the backend revokes all other sessions on any login. A Dio `onResponse` interceptor detects `401` + `code: "SESSION_INVALID"` and fires `DioClient.onSessionInvalidated`, which `AuthNotifier` (`features/auth/providers/auth_provider.dart`) wires to: clear cookies/local user, set auth state to null (GoRouter's redirect then sends the user to `/login`), and set `forcedLogoutMessageProvider` so the login screen shows a "signed in on another device" banner. Don't add per-screen 401 handling — this central path covers it.
- The root widget (`app.dart`) observes app lifecycle and calls `authProvider.notifier.verifySession()` on resume (throttled 15s) so a session revoked while the app was backgrounded is detected immediately.
- Logout POSTs to `/api/auth/signout` (`ApiConstants.logout`) then clears local state; the endpoint path matters — `/api/auth/logout` does not exist on the backend.

### Navigation & auth gating

`app_router.dart` builds a `GoRouter` whose `redirect` reads `authProvider`: unauthenticated → `/login`, authenticated on `/login` → `/dashboard`. Auth state changes propagate through a `refreshListenable` bridge. New protected screens just need a route; no per-screen guards.

### Error tracking (Sentry)

- Initialized in `main()` via `SentryFlutter.init(appRunner: …)` — one call installs `FlutterError.onError`, `PlatformDispatcher.onError` (unhandled async), and native crash handlers. All options live in `lib/core/config/sentry_config.dart`.
- **PII-safe**, mirroring the web app: `sendDefaultPii = false` plus `SentryConfig.scrubEvent` strips cookies, `Authorization`/`Cookie` headers, and request bodies. User context (`setSentryUser` in `lib/core/observability/sentry_provider_observer.dart`) is **id + role only**, never email — set/cleared in `AuthNotifier` (build/login/logout/forced-logout).
- **Config**: DSN is a committed default in `sentry_config.dart` (a DSN isn't secret on mobile — it ships in the binary, same as `ApiConstants.baseUrl`); overridable via `--dart-define=SENTRY_DSN=…`. `environment` is auto-derived from `kReleaseMode` (`development` in debug, `production` in release) — no flags needed for `flutter run`. Uses a **separate Sentry project** (`sslogistics-mobile`) from the web app, same org.
- **Coverage**: `SentryProviderObserver` on the root `ProviderScope` auto-captures any failing Riverpod provider; `_dio.addSentry()` (last interceptor in `DioClient.init`) captures 5xx + HTTP breadcrumbs; `SentryNavigatorObserver` on the GoRouter records navigation. The two SSE services log reconnect failures as **breadcrumbs** (not captures) because they retry every 3s — capturing would flood Sentry while offline.

### Dashboard tiles

`features/dashboard/widgets/dashboard_tile.dart` holds the `allTiles` list. A tile is only tappable when `isMobileReady: true` and its `allowedRoles` includes the user's role (`admin | staff | driver`); otherwise it renders greyed out with a "Mobile Soon"/"Coming Soon" badge. When you finish building a feature's screens, flip its tile's `isMobileReady`.

### Theming helpers (`lib/core/theme/`)

`theme_extensions.dart` (`context.isDark`, `context.colors`), `app_spacing.dart` (`AppSpacing`), and `app_text_styles.dart` (`AppTextStyles`) exist to stop new code from re-typing `Theme.of(context).brightness == Brightness.dark` and one-off `TextStyle`s. **Use them in any file you're already touching or writing from scratch — do not do a retroactive sweep of existing screens just to adopt them.** Most existing screens still inline their own dark-mode checks/styles; that's expected debt, not a bug to fix opportunistically.

### Release signing

`android/key.properties` holds the upload keystore path + passwords in plaintext and is required by `android/app/build.gradle.kts` for release signing. It's gitignored (`.gitignore`, `android/.gitignore`) and must never be committed — this folder isn't a git repo today, but treat the ignore rule as load-bearing if that ever changes. Rotate the keystore password out-of-band if it's ever exposed; there's no code-level mitigation for a leaked signing key.
