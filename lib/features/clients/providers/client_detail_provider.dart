import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/detail_notifier.dart';
import '../data/client_models.dart';
import 'client_provider.dart';

/// Profile, balance, contacts and deployments — everything about a client
/// except the statement, which paginates on its own (see
/// [ClientEntriesNotifier]) because a long-running account grows without
/// limit and must never be loaded whole.
class ClientDetailNotifier extends DetailNotifier<ClientDetail> {
  @override
  Future<ClientDetail> fetchDetail(int id) =>
      ref.read(clientRepositoryProvider).fetchClient(id);

  Future<void> updateClient(Map<String, dynamic> fields) {
    return mutate(() => ref.read(clientRepositoryProvider).updateClient(recordId, fields));
  }

  Future<void> addOrUpdateContact({
    int? id,
    required String name,
    String? role,
    String? designation,
    String? phone,
    String? altPhone,
    String? email,
    bool isPrimary = false,
  }) {
    return mutate(() => ref.read(clientRepositoryProvider).addOrUpdateContact(
          clientId: recordId,
          id: id,
          name: name,
          role: role,
          designation: designation,
          phone: phone,
          altPhone: altPhone,
          email: email,
          isPrimary: isPrimary,
        ));
  }

  Future<void> deleteContact(int contactId) {
    return mutate(
        () => ref.read(clientRepositoryProvider).deleteContact(clientId: recordId, contactId: contactId));
  }

  Future<void> addOrUpdateDeployment({
    int? id,
    int? vehicleId,
    required int quantity,
    String? vehicleType,
    int? seatingCapacity,
    String? truckType,
    String? containerLength,
    String? axleType,
    String? containerBodyType,
    num? monthlyRate,
    String? startDate,
    String? endDate,
  }) {
    return mutate(() => ref.read(clientRepositoryProvider).addOrUpdateDeployment(
          clientId: recordId,
          id: id,
          vehicleId: vehicleId,
          quantity: quantity,
          vehicleType: vehicleType,
          seatingCapacity: seatingCapacity,
          truckType: truckType,
          containerLength: containerLength,
          axleType: axleType,
          containerBodyType: containerBodyType,
          monthlyRate: monthlyRate,
          startDate: startDate,
          endDate: endDate,
        ));
  }

  Future<void> deleteDeployment(int deploymentId) {
    return mutate(() =>
        ref.read(clientRepositoryProvider).deleteDeployment(clientId: recordId, deploymentId: deploymentId));
  }
}

final clientDetailProvider =
    AsyncNotifierProvider.autoDispose.family<ClientDetailNotifier, ClientDetail, int>(
  ClientDetailNotifier.new,
);
