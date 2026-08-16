import 'package:intl/intl.dart';

/// Shared money and date formatting for the finance modules (loans, private
/// fundings, client receivables).
///
/// Every other feature declares its own module-private `_moneyFmt` / `_dateFmt`
/// at the top of a card file. That was fine for one or two features; the three
/// finance modules add six more forms, three detail screens and three list
/// screens that all have to agree on how a rupee figure reads, so they share
/// these instead. Wording matches the web's `loansPage.utils.ts` so a number
/// looks identical on the phone and on the dashboard.

final _rupeeFmt = NumberFormat('#,##0', 'en_IN');
final _rupeePreciseFmt = NumberFormat('#,##0.00', 'en_IN');
final _apiDateFmt = DateFormat('yyyy-MM-dd');
final _displayDateFmt = DateFormat('dd MMM yyyy');
final _shortDateFmt = DateFormat('dd MMM');
final _monthYearFmt = DateFormat('MMMM yyyy');

/// `₹1,23,456` — whole rupees, Indian digit grouping. The default for amounts
/// people say out loud.
String formatRupees(num? value) {
  if (value == null) return '—';
  return '₹${_rupeeFmt.format(value)}';
}

/// `₹1,234.56` — keeps paise. Used for accrued interest, where rounding to the
/// rupee would hide the daily movement the figure exists to show.
String formatRupeesPrecise(num? value) {
  if (value == null) return '—';
  return '₹${_rupeePreciseFmt.format(value)}';
}

/// Wire format for `date` columns.
String formatApiDate(DateTime date) => _apiDateFmt.format(date);

/// `12 Aug 2026` from a `YYYY-MM-DD` string.
///
/// Parsed with [DateTime.parse], which reads a bare date as local midnight —
/// so a date-only value can never slide to the previous day the way
/// `toLocal()` on a UTC timestamp would.
String formatDisplayDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return _displayDateFmt.format(parsed);
}

/// `12 Aug` — for chips and dense rows where the year is implied.
String formatShortDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return _shortDateFmt.format(parsed);
}

/// `August 2026` from `YYYY-MM-DD` or `YYYY-MM`.
String formatMonthYear(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  final normalized = isoDate.length == 7 ? '$isoDate-01' : isoDate;
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return isoDate;
  return _monthYearFmt.format(parsed);
}

/// Today as `YYYY-MM-DD`, matching how the API compares date-only columns.
String todayApiDate() => _apiDateFmt.format(DateTime.now());

/// Whole days from today to [isoDate]; negative once the date has passed.
/// Both sides are floored to midnight so a due date isn't "0 days away" in the
/// morning and "-1" the same evening.
int daysFromToday(String isoDate) {
  final target = DateTime.tryParse(isoDate);
  if (target == null) return 0;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(target.year, target.month, target.day);
  return due.difference(today).inDays;
}

/// `today` / `tomorrow` / `in 3 days` / `5 days ago` — the urgency line under
/// a due date.
String relativeDueLabel(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  final days = daysFromToday(isoDate);
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days == -1) return 'yesterday';
  return days > 0 ? 'in $days days' : '${days.abs()} days ago';
}

/// First day of the month containing [date], as `YYYY-MM-DD`.
String monthStart(DateTime date) => _apiDateFmt.format(DateTime(date.year, date.month, 1));

/// Last day of the month containing [date], as `YYYY-MM-DD`.
/// Day 0 of the next month is the last day of this one, which also gets
/// February and leap years right without a special case.
String monthEnd(DateTime date) => _apiDateFmt.format(DateTime(date.year, date.month + 1, 0));

/// Shifts a `YYYY-MM-DD` month start by [delta] months.
String shiftMonth(String isoMonthStart, int delta) {
  final parsed = DateTime.tryParse(isoMonthStart) ?? DateTime.now();
  return _apiDateFmt.format(DateTime(parsed.year, parsed.month + delta, 1));
}
