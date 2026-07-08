import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App name/version/build metadata read once from the platform. Used to
/// show the current version (e.g. in the nav drawer) and by the
/// force-update check (features/system/providers/app_version_provider.dart).
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});
