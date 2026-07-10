import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drivers/data/driver_models.dart';
import '../../drivers/data/driver_repository.dart';

final _activeDriversRepositoryProvider =
    Provider<DriverRepository>((ref) => DriverRepository());

/// Full list of active drivers — used by the diesel create/edit driver
/// picker, mirroring the web's typeahead (createDieselModal.tsx fetches
/// `/api/drivers?pageSize=100` and filters to `is_active`).
final activeDriversProvider = FutureProvider<List<Driver>>((ref) async {
  final data = await ref
      .read(_activeDriversRepositoryProvider)
      .getDrivers(pageSize: 100);
  return data.drivers.where((d) => d.isActive).toList();
});
