import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/json_parse.dart';

/// The three shifts of a day, in order.
const List<String> kShifts = ['A', 'B', 'C'];

/// What one driver did on one day.
///
/// Shifts and [status] are mutually exclusive: a driver either worked some of
/// A/B/C, or was `ABSENT` / on `LEAVE` for the whole day. Neither means the
/// day has not been marked.
@immutable
class AttendanceMark {
  final List<String> shifts;
  final String? status;

  const AttendanceMark({this.shifts = const [], this.status});

  static const empty = AttendanceMark();
  static const fullDay = AttendanceMark(shifts: kShifts);
  static const absent = AttendanceMark(status: 'ABSENT');
  static const leave = AttendanceMark(status: 'LEAVE');

  factory AttendanceMark.fromJson(Map<String, dynamic> json) {
    final raw = (json['shifts'] as List? ?? const []).map((e) => e.toString()).toSet();
    return AttendanceMark(
      shifts: kShifts.where(raw.contains).toList(),
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'shifts': shifts, 'status': status};

  bool get isMarked => shifts.isNotEmpty || status != null;
  bool get isFullDay => shifts.length == kShifts.length;
  bool get isPartial => shifts.isNotEmpty && !isFullDay;
  bool get isAbsent => status == 'ABSENT';
  bool get isLeave => status == 'LEAVE';
  bool get isOff => status != null;

  bool has(String shift) => shifts.contains(shift);

  /// Adds or removes one shift; picking a shift always clears absent/leave.
  AttendanceMark toggleShift(String shift) {
    final on = has(shift);
    return AttendanceMark(
      shifts: kShifts.where((s) => s == shift ? !on : has(s)).toList(),
    );
  }

  /// The tick: marks all three shifts, or clears them if already a full day.
  AttendanceMark toggleFullDay() => isFullDay ? empty : fullDay;

  String get label {
    if (isAbsent) return 'Absent';
    if (isLeave) return 'On leave';
    if (isFullDay) return 'Full day';
    if (shifts.length > 1) return 'Shifts ${shifts.join(' + ')}';
    if (shifts.length == 1) return 'Shift ${shifts.first}';
    return 'Not marked';
  }

  @override
  bool operator ==(Object other) =>
      other is AttendanceMark && other.status == status && listEquals(other.shifts, shifts);

  @override
  int get hashCode => Object.hash(status, shifts.join());
}

class AttendanceDayDriver {
  final int driverId;
  final String name;
  final String? place;
  final bool isActive;
  final AttendanceMark mark;

  /// The day before, for "as yesterday". Null when that day was not marked.
  final AttendanceMark? previous;

  const AttendanceDayDriver({
    required this.driverId,
    required this.name,
    required this.place,
    required this.isActive,
    required this.mark,
    required this.previous,
  });

  factory AttendanceDayDriver.fromJson(Map<String, dynamic> json) {
    final previous = json['previous'];
    return AttendanceDayDriver(
      driverId: parseIdOr0(json['driver_id']),
      name: json['name'] as String? ?? '',
      place: json['place'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      mark: AttendanceMark.fromJson(json),
      previous: previous is Map<String, dynamic> ? AttendanceMark.fromJson(previous) : null,
    );
  }
}

class AttendanceDay {
  /// YYYY-MM-DD
  final String date;

  /// Today in IST as the server sees it — the app never computes this itself.
  final String today;

  /// Whether the signed-in role may change this date.
  final bool editable;
  final List<AttendanceDayDriver> drivers;

  const AttendanceDay({
    required this.date,
    required this.today,
    required this.editable,
    required this.drivers,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
        date: json['date'] as String,
        today: json['today'] as String,
        editable: json['editable'] as bool? ?? false,
        drivers: (json['drivers'] as List? ?? const [])
            .map((e) => AttendanceDayDriver.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isToday => date == today;
}

class AttendanceTotals {
  final int shifts;

  /// Days with at least one shift.
  final int daysPresent;
  final int fullDays;
  final int absent;
  final int leave;

  const AttendanceTotals({
    required this.shifts,
    required this.daysPresent,
    required this.fullDays,
    required this.absent,
    required this.leave,
  });

  factory AttendanceTotals.fromJson(Map<String, dynamic> json) => AttendanceTotals(
        shifts: parseIdOr0(json['shifts']),
        daysPresent: parseIdOr0(json['days_present']),
        fullDays: parseIdOr0(json['full_days']),
        absent: parseIdOr0(json['absent']),
        leave: parseIdOr0(json['leave']),
      );
}

class AttendanceMonthDriver {
  final int driverId;
  final String name;
  final String? place;
  final bool isActive;

  /// Marked days only, keyed by YYYY-MM-DD.
  final Map<String, AttendanceMark> days;

  /// Counted by the server; the app only displays them.
  final AttendanceTotals totals;

  const AttendanceMonthDriver({
    required this.driverId,
    required this.name,
    required this.place,
    required this.isActive,
    required this.days,
    required this.totals,
  });

  factory AttendanceMonthDriver.fromJson(Map<String, dynamic> json) => AttendanceMonthDriver(
        driverId: parseIdOr0(json['driver_id']),
        name: json['name'] as String? ?? '',
        place: json['place'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        days: (json['days'] as Map<String, dynamic>? ?? const {}).map(
          (date, mark) => MapEntry(date, AttendanceMark.fromJson(mark as Map<String, dynamic>)),
        ),
        totals: AttendanceTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? const {}),
      );
}

class AttendanceMonth {
  /// YYYY-MM
  final String month;
  final String today;
  final List<AttendanceMonthDriver> drivers;

  const AttendanceMonth({required this.month, required this.today, required this.drivers});

  factory AttendanceMonth.fromJson(Map<String, dynamic> json) => AttendanceMonth(
        month: json['month'] as String,
        today: json['today'] as String,
        drivers: (json['drivers'] as List? ?? const [])
            .map((e) => AttendanceMonthDriver.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Whether a driver's name or place contains [query] (already lower-cased).
bool matchesDriverSearch(String query, String name, String? place) =>
    query.isEmpty ||
    name.toLowerCase().contains(query) ||
    (place ?? '').toLowerCase().contains(query);

// ── Date-only helpers ───────────────────────────────────────────────────────
// Dates travel as YYYY-MM-DD strings and are only ever parsed as UTC, so a
// phone's timezone can never shift one onto the neighbouring day.

DateTime parseDateOnly(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

String formatDateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String addDaysTo(String date, int days) =>
    formatDateOnly(parseDateOnly(date).add(Duration(days: days)));

String addMonthsTo(String month, int months) {
  final parts = month.split('-').map(int.parse).toList();
  return formatDateOnly(DateTime.utc(parts[0], parts[1] + months, 1)).substring(0, 7);
}

/// Every date in a YYYY-MM month, in order.
List<String> datesInMonth(String month) {
  final parts = month.split('-').map(int.parse).toList();
  final count = DateTime.utc(parts[0], parts[1] + 1, 0).day;
  return [for (var d = 1; d <= count; d++) '$month-${d.toString().padLeft(2, '0')}'];
}

/// "Sun, 11 Oct"
String formatDayLabel(String date) => DateFormat('EEE, d MMM').format(parseDateOnly(date));

/// "October 2026"
String formatMonthLabel(String month) => DateFormat('MMMM yyyy').format(parseDateOnly('$month-01'));
