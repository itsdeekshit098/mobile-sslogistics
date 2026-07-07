import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicles/data/vehicle_repository.dart';
import '../../../shared/models/vehicle_model.dart';

final vehicleRepositoryProvider =
    Provider<VehicleRepository>((ref) => VehicleRepository());

/// Full list of vehicles — used for filter dropdown and create form typeahead.
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final data = await ref
      .read(vehicleRepositoryProvider)
      .getVehicles(pageSize: 1000);
  return data.vehicles
      .map((v) => Vehicle(
            id: v.id,
            plateNumber: v.vehicleNumber,
            expectedKml: v.expectedKml,
            tankCapacity: v.tankCapacity,
            model: v.model,
          ))
      .toList();
});
