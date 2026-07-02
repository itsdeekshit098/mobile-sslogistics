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

Flutter client for the SS Logistics platform. It has **no backend of its own** — all data comes from the Next.js API in `../ui-sslogistics` (see root `../CLAUDE.md` for the shared contract). `ApiConstants.baseUrl` (`lib/core/constants/api_constants.dart`) points at `http://10.0.2.2:3000` on Android emulator / `localhost:3000` on iOS simulator; swap to the production URL before release.

Stack: Riverpod (state), GoRouter (navigation), Dio (HTTP).

## Architecture

Feature-first layout under `lib/`:

- `core/` — cross-cutting infrastructure: `network/dio_client.dart`, `router/app_router.dart`, `constants/`, `storage/`.
- `features/<name>/` — each feature has `data/` (repository making Dio calls), `providers/` (Riverpod), `screens/`, `widgets/`.
- `shared/` — models (`AppUser`, `Vehicle`, …) and reusable widgets (`ErrorState`, `AppDrawer`).

### Networking & sessions (the part that's easy to break)

- `DioClient` (singleton, initialized in `main()`) uses a `PersistCookieJar` — the Supabase auth **cookies are the session**; there are no bearer tokens. `validateStatus` accepts anything `< 500`, so 4xx responses arrive as normal `Response` objects: repositories must check `response.statusCode == 200 && data['success'] == true` and throw `Exception(data['error'])` otherwise.
- **Single-login handling**: the backend revokes all other sessions on any login. A Dio `onResponse` interceptor detects `401` + `code: "SESSION_INVALID"` and fires `DioClient.onSessionInvalidated`, which `AuthNotifier` (`features/auth/providers/auth_provider.dart`) wires to: clear cookies/local user, set auth state to null (GoRouter's redirect then sends the user to `/login`), and set `forcedLogoutMessageProvider` so the login screen shows a "signed in on another device" banner. Don't add per-screen 401 handling — this central path covers it.
- The root widget (`app.dart`) observes app lifecycle and calls `authProvider.notifier.verifySession()` on resume (throttled 15s) so a session revoked while the app was backgrounded is detected immediately.
- Logout POSTs to `/api/auth/signout` (`ApiConstants.logout`) then clears local state; the endpoint path matters — `/api/auth/logout` does not exist on the backend.

### Navigation & auth gating

`app_router.dart` builds a `GoRouter` whose `redirect` reads `authProvider`: unauthenticated → `/login`, authenticated on `/login` → `/dashboard`. Auth state changes propagate through a `refreshListenable` bridge. New protected screens just need a route; no per-screen guards.

### Dashboard tiles

`features/dashboard/widgets/dashboard_tile.dart` holds the `allTiles` list. A tile is only tappable when `isMobileReady: true` and its `allowedRoles` includes the user's role (`admin | staff | driver`); otherwise it renders greyed out with a "Mobile Soon"/"Coming Soon" badge. When you finish building a feature's screens, flip its tile's `isMobileReady`.
