import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../shared/models/app_user.dart';

/// Auto-reports any Riverpod provider that fails — either by throwing in
/// its build() or by a Future/Stream emitting an error. Because every
/// feature's data flows through an AsyncNotifier/Provider, this one
/// observer covers all of them (diesel, vehicles, auth, …) without adding
/// a Sentry call to each provider.
///
/// Registered once on the root ProviderScope in main.dart.
class SentryProviderObserver extends ProviderObserver {
  const SentryProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        // Which provider failed — helps triage without exposing state.
        scope.setContexts('provider', {
          'name': provider.name ?? provider.runtimeType.toString(),
        });
      },
    );
  }
}

/// Attaches safe (non-PII) user context to future Sentry events:
/// id + role only — never email or display name. Mirrors the web app's
/// src/lib/sentry/setUser.ts so the no-PII rule lives in one place.
///
/// Pass null to clear it (on logout / forced logout).
void setSentryUser(AppUser? user) {
  Sentry.configureScope((scope) {
    scope.setUser(
      user == null
          ? null
          : SentryUser(id: user.id, data: {'role': user.role}),
    );
  });
}
