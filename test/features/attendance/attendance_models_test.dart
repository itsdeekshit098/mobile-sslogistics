import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sslogistics/features/attendance/data/attendance_models.dart';

void main() {
  group('AttendanceMark', () {
    test('the tick marks all three shifts and clears them again', () {
      final full = AttendanceMark.empty.toggleFullDay();
      expect(full.shifts, ['A', 'B', 'C']);
      expect(full.isFullDay, isTrue);
      expect(full.toggleFullDay(), AttendanceMark.empty);
    });

    test('a part day becomes a full day on the tick', () {
      const partial = AttendanceMark(shifts: ['B']);
      expect(partial.isPartial, isTrue);
      expect(partial.toggleFullDay(), AttendanceMark.fullDay);
    });

    test('toggling shifts keeps A, B, C order', () {
      final mark = AttendanceMark.empty.toggleShift('C').toggleShift('A');
      expect(mark.shifts, ['A', 'C']);
      expect(mark.toggleShift('A').shifts, ['C']);
    });

    test('picking a shift clears absent or leave', () {
      final mark = AttendanceMark.absent.toggleShift('B');
      expect(mark.status, isNull);
      expect(mark.shifts, ['B']);
    });

    test('labels', () {
      expect(AttendanceMark.empty.label, 'Not marked');
      expect(AttendanceMark.fullDay.label, 'Full day');
      expect(const AttendanceMark(shifts: ['A']).label, 'Shift A');
      expect(const AttendanceMark(shifts: ['A', 'C']).label, 'Shifts A + C');
      expect(AttendanceMark.absent.label, 'Absent');
      expect(AttendanceMark.leave.label, 'On leave');
    });

    test('fromJson normalises order and drops unknown shifts', () {
      final mark = AttendanceMark.fromJson({
        'shifts': ['C', 'X', 'A'],
        'status': null,
      });
      expect(mark.shifts, ['A', 'C']);
      expect(mark, const AttendanceMark(shifts: ['A', 'C']));
    });
  });

  group('date-only helpers', () {
    test('stepping days crosses month and year ends', () {
      expect(addDaysTo('2026-10-31', 1), '2026-11-01');
      expect(addDaysTo('2027-01-01', -1), '2026-12-31');
    });

    test('stepping months crosses a year end', () {
      expect(addMonthsTo('2026-12', 1), '2027-01');
      expect(addMonthsTo('2026-01', -1), '2025-12');
    });

    test('datesInMonth handles month length and leap years', () {
      expect(datesInMonth('2026-10').length, 31);
      expect(datesInMonth('2026-02').length, 28);
      expect(datesInMonth('2028-02').last, '2028-02-29');
    });

    test('labels', () {
      expect(formatDayLabel('2026-10-11'), 'Sun, 11 Oct');
      expect(formatMonthLabel('2026-10'), 'October 2026');
    });
  });
}
