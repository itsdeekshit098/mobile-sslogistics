import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/detail_notifier.dart';
import '../data/loan_models.dart';
import 'loan_provider.dart';

class LoanDetailNotifier extends DetailNotifier<LoanDetail> {
  @override
  Future<LoanDetail> fetchDetail(int id) =>
      ref.read(loanRepositoryProvider).fetchLoan(id);

  Future<void> recordPayment({
    required String paymentType,
    required num amount,
    required String paidOn,
    int? installmentId,
    String? paymentMethod,
    String? reference,
    String? notes,
  }) {
    return mutate(() => ref.read(loanRepositoryProvider).recordPayment(
          loanId: recordId,
          paymentType: paymentType,
          amount: amount,
          paidOn: paidOn,
          installmentId: installmentId,
          paymentMethod: paymentMethod,
          reference: reference,
          notes: notes,
        ));
  }

  Future<void> setInstallmentManualStatus({
    required int installmentId,
    required String? manualStatus,
  }) {
    return mutate(() => ref.read(loanRepositoryProvider).setInstallmentManualStatus(
          loanId: recordId,
          installmentId: installmentId,
          manualStatus: manualStatus,
        ));
  }

  Future<void> reversePayment(int paymentId, {String? reason}) {
    return mutate(() => ref.read(loanRepositoryProvider).reversePayment(
          loanId: recordId,
          paymentId: paymentId,
          reason: reason,
        ));
  }

  Future<void> updateLoan(Map<String, dynamic> fields) {
    return mutate(() => ref.read(loanRepositoryProvider).updateLoan(recordId, fields));
  }
}

final loanDetailProvider =
    AsyncNotifierProvider.autoDispose.family<LoanDetailNotifier, LoanDetail, int>(
  LoanDetailNotifier.new,
);
