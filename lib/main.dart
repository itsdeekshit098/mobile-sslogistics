import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/config/sentry_config.dart';
import 'core/network/dio_client.dart';
import 'core/notifications/push_service.dart';
import 'core/observability/sentry_provider_observer.dart';
import 'app.dart';

Future<void> main() async {
  // SentryFlutter.init wraps app startup so a single call installs
  // FlutterError.onError, PlatformDispatcher.onError (unhandled async
  // errors), and the native crash handlers — the actual app boots inside
  // appRunner. See SentryConfig for the PII-safe options.
  await SentryFlutter.init(
    (options) {
      options.dsn = SentryConfig.enabled ? SentryConfig.dsn : '';
      options.environment = SentryConfig.environment;
      // Never let Sentry auto-attach IP/user data; we opt in minimally via
      // setSentryUser (id + role only).
      options.sendDefaultPii = false;
      // Full performance tracing in debug, sampled to 10% in release to
      // keep quota/cost sane on real traffic.
      options.tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
      // Strip cookies / auth headers / request bodies before sending.
      options.beforeSend = SentryConfig.scrubEvent;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      await DioClient.init();
      await PushService.init();
      runApp(
        const ProviderScope(
          // One observer auto-captures every failing provider.
          observers: [SentryProviderObserver()],
          child: SSLogisticsApp(),
        ),
      );
    },
  );
}
