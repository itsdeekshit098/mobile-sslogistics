import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/diesel_repository.dart';
import '../../../shared/models/vehicle_model.dart';

final vehicleRepositoryProvider =
    Provider<VehicleRepository>((ref) => VehicleRepository());

/// Full list of vehicles — used for filter dropdown and create form typeahead.
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  return ref.read(vehicleRepositoryProvider).getVehicles();
});
