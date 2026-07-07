import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Central config for Sentry error reporting.
///
/// Mirrors the web app's PII-safe posture (see ui-sslogistics'
/// src/lib/sentry/options.ts): no default PII, and a beforeSend scrubber
/// that strips cookies / auth headers / request bodies before anything
/// leaves the device.
///
/// The DSN lives here as a committed default (a DSN is not a secret on
/// mobile — it's compiled into the app binary either way, exactly like
/// ApiConstants.baseUrl). A `--dart-define=SENTRY_DSN=...` build flag can
/// still override it for CI without editing code, but daily `flutter run`
/// needs no flags.
class SentryConfig {
  static const String dsn = String.fromEnvironment(
    'SENTRY_DSN',
    // sslogistics-mobile project (org sslogistics-t1). Not a secret — it
    // ships in the app binary regardless.
    defaultValue:
        'https://f98fe0b97c18e7249fbf687e676bb6ab@o4511687877459968.ingest.de.sentry.io/4511693346177104',
  );

  /// Debug builds report as `development`, release builds (Play Store /
  /// App Store) as `production` — decided automatically by Flutter's
  /// built-in kReleaseMode, so there's no env value to maintain.
  static String get environment =>
      kReleaseMode ? 'production' : 'development';

  /// When the DSN is empty (e.g. before it's been pasted in, or a build
  /// that intentionally omits it), Sentry.init becomes a silent no-op
  /// instead of erroring.
  static bool get enabled => dsn.isNotEmpty;

  /// Removes anything that could carry PII or secrets from an event right
  /// before it's sent: cookies, auth headers, and request bodies. The
  /// Flutter-side mirror of the web app's `scrubEvent`.
  static FutureOr<SentryEvent?> scrubEvent(SentryEvent event, Hint hint) {
    final req = event.request;
    if (req != null) {
      // headers getter is unmodifiable, so build a filtered copy.
      final safeHeaders = Map<String, String>.of(req.headers)
        ..removeWhere(
          (key, _) => const {
            'authorization',
            'cookie',
            'set-cookie',
          }.contains(key.toLowerCase()),
        );

      // Rebuild the request keeping only non-sensitive metadata —
      // cookies and data (request body) are dropped entirely.
      event.request = SentryRequest(
        url: req.url,
        method: req.method,
        queryString: req.queryString,
        fragment: req.fragment,
        apiTarget: req.apiTarget,
        headers: safeHeaders,
      );
    }
    return event;
  }
}
