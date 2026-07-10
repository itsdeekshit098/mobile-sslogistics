import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_models.dart';
import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

class SettingsState {
  final MaintenanceSettings maintenance;
  final AppVersionSettings appVersion;

  const SettingsState({required this.maintenance, required this.appVersion});
}

final settingsProvider =
    AsyncNotifierProvider.autoDispose<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends AutoDisposeAsyncNotifier<SettingsState> {
  bool _disposed = false;

  @override
  Future<SettingsState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<SettingsState> _fetch() async {
    final repo = ref.read(settingsRepositoryProvider);
    final results = await Future.wait([repo.getMaintenance(), repo.getAppVersion()]);
    return SettingsState(
      maintenance: results[0] as MaintenanceSettings,
      appVersion: results[1] as AppVersionSettings,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_fetch);
    if (_disposed) return;
    state = result;
  }

  Future<void> saveMaintenance({required bool maintenanceMode, String? message}) async {
    await ref
        .read(settingsRepositoryProvider)
        .updateMaintenance(maintenanceMode: maintenanceMode, message: message);
    await refresh();
  }

  Future<void> saveAppVersion({int? minAndroidVersionCode, String? message}) async {
    await ref
        .read(settingsRepositoryProvider)
        .updateAppVersion(minAndroidVersionCode: minAndroidVersionCode, message: message);
    await refresh();
  }
}
