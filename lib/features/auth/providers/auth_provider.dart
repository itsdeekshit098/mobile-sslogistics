import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/notifications/push_service.dart';
import '../../../shared/models/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

/// Set when the app force-logs-out a still-logged-in user because their
/// session was invalidated server-side (e.g. they signed in elsewhere).
/// The login screen reads and clears this to show an explanatory banner
/// instead of silently landing back on /login.
final forcedLogoutMessageProvider = StateProvider<String?>((ref) => null);

/// Holds the current [AppUser], or null if not authenticated.
/// On first build, tries to restore the session from persisted cookies.
final authProvider =
    AsyncNotifierProvider<AuthNotifier, AppUser?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    DioClient.onSessionInvalidated = _handleSessionInvalidated;
    try {
      final user = await ref.read(authRepositoryProvider).getSession();
      // Restoring an already-valid session on cold start — the token
      // registration attempted inside PushService.init() may have run
      // before cookies were confirmed valid, so retry here too.
      await PushService.registerCurrentToken();
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(authRepositoryProvider).login(email, password);
    });

    if (state.hasValue && state.value != null) {
      // The initial registration attempt in PushService.init() may have
      // run (and silently failed) before this login completed — retry now
      // that the session cookie is valid.
      await PushService.registerCurrentToken();
    }
  }

  Future<void> logout() async {
    // Unregister while the session cookie is still valid — a forced
    // logout (session revoked elsewhere) can't do this since the session
    // is already dead by the time it's detected.
    await PushService.unregister();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  DateTime? _lastVerifiedAt;

  /// Re-checks the session against the server. Called when the app returns
  /// to the foreground so a session revoked elsewhere (single-login
  /// enforcement) is detected right away, not only on the next user action.
  /// Throttled so rapid app switching doesn't spam the endpoint.
  Future<void> verifySession() async {
    if (state.valueOrNull == null) return;
    final now = DateTime.now();
    if (_lastVerifiedAt != null &&
        now.difference(_lastVerifiedAt!) < const Duration(seconds: 15)) {
      return;
    }
    _lastVerifiedAt = now;
    try {
      await ref.read(authRepositoryProvider).getSession();
    } catch (_) {
      // A revoked session is force-logged-out by the SESSION_INVALID
      // interceptor; other failures (e.g. offline) must not log the user out.
    }
  }

  /// Called by [DioClient] whenever a request comes back with a
  /// SESSION_INVALID error. Only acts if we currently believe the user is
  /// logged in — a never-logged-in / already-logged-out app also gets 401s
  /// on its startup session check, and that's not "logged out elsewhere".
  void _handleSessionInvalidated() {
    if (state.valueOrNull == null) return;
    ref.read(authRepositoryProvider).clearLocalSession();
    state = const AsyncData(null);
    ref.read(forcedLogoutMessageProvider.notifier).state =
        "You've been logged out because your account was signed in on another device.";
  }
}
