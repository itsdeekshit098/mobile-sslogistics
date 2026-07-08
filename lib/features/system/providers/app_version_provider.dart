import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/package_info_provider.dart';
import '../data/app_version_service.dart';

class AppVersionCheckState {
  final bool updateRequired;
  final String? message;

  const AppVersionCheckState({this.updateRequired = false, this.message});
}

/// Checked once at startup and again on every app resume (see app.dart) —
/// there's no persistent connection like the maintenance SSE stream because
/// this must also work for a user who isn't logged in yet.
final appVersionProvider =
    NotifierProvider<AppVersionNotifier, AppVersionCheckState>(
        AppVersionNotifier.new);

class AppVersionNotifier extends Notifier<AppVersionCheckState> {
  final _service = AppVersionService();

  @override
  AppVersionCheckState build() => const AppVersionCheckState();

  Future<void> check() async {
    // Only Android is gated today — the app ships an iOS bundle id but no
    // App Store force-update flow has been built yet.
    if (!Platform.isAndroid) return;

    try {
      final config = await _service.fetch();
      if (config.minAndroidVersionCode == null) return;

      final packageInfo = await ref.read(packageInfoProvider.future);
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber);
      if (currentBuildNumber == null) return;

      if (currentBuildNumber < config.minAndroidVersionCode!) {
        state = AppVersionCheckState(
          updateRequired: true,
          message: config.message,
        );
      }
    } catch (_) {
      // Fail open: an unreachable version-check endpoint must never block
      // app usage, unlike an actual confirmed outdated build.
    }
  }
}
