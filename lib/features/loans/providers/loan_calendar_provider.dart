import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/money_format.dart';
import '../data/loan_models.dart';
import 'loan_provider.dart';

/// Fetches the EMI calendar for the month containing [monthStart] (any
/// `YYYY-MM-DD` in that month works — only year/month are used).
/// `.autoDispose` + `.family` means each month the user navigates to gets its
/// own cached fetch, so paging back to a month already seen doesn't re-hit
/// the network.
final loanCalendarProvider =
    FutureProvider.autoDispose.family<LoanCalendar, String>((ref, monthStart) {
  final parsed = DateTime.tryParse(monthStart) ?? DateTime.now();
  final from = monthStart;
  final to = monthEnd(parsed);
  return ref.read(loanRepositoryProvider).fetchCalendar(from: from, to: to);
});
