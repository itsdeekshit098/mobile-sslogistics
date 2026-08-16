import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/detail_notifier.dart';
import '../data/funding_models.dart';
import 'funding_provider.dart';

class FundingDetailNotifier extends DetailNotifier<FundingDetail> {
  @override
  Future<FundingDetail> fetchDetail(int id) =>
      ref.read(fundingRepositoryProvider).fetchFunding(id);

  Future<void> recordEntry({
    required String entryType,
    required num amount,
    required String entryDate,
    String? paymentMethod,
    String? reference,
    String? description,
  }) {
    return mutate(() => ref.read(fundingRepositoryProvider).recordEntry(
          fundingId: recordId,
          entryType: entryType,
          amount: amount,
          entryDate: entryDate,
          paymentMethod: paymentMethod,
          reference: reference,
          description: description,
        ));
  }

  Future<void> reverseEntry(int entryId, {String? reason}) {
    return mutate(() => ref.read(fundingRepositoryProvider).reverseEntry(
          fundingId: recordId,
          entryId: entryId,
          reason: reason,
        ));
  }

  Future<void> changeRate({
    required String effectiveFrom,
    num? roi,
    String? roiBasis,
    num? fixedInterestAmount,
    String? note,
  }) {
    return mutate(() => ref.read(fundingRepositoryProvider).changeRate(
          fundingId: recordId,
          effectiveFrom: effectiveFrom,
          roi: roi,
          roiBasis: roiBasis,
          fixedInterestAmount: fixedInterestAmount,
          note: note,
        ));
  }

  Future<void> settle() {
    return mutate(() => ref.read(fundingRepositoryProvider).settleFunding(recordId));
  }

  Future<void> updateFunding(Map<String, dynamic> fields) {
    return mutate(() => ref.read(fundingRepositoryProvider).updateFunding(recordId, fields));
  }
}

final fundingDetailProvider =
    AsyncNotifierProvider.autoDispose.family<FundingDetailNotifier, FundingDetail, int>(
  FundingDetailNotifier.new,
);
