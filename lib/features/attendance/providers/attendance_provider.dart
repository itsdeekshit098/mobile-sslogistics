import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';

final attendanceRepositoryProvider =
    Provider<AttendanceRepository>((ref) => AttendanceRepository());

/// The day on screen plus the working copy of its marks.
///
/// [day] stays exactly as the server last returned it, so the difference
/// between it and [marks] is what a save has to send.
class AttendanceDayState {
  final AttendanceDay day;
  final Map<int, AttendanceMark> marks;

  /// A different date is being fetched; the current one stays visible.
  final bool loading;
  final bool saving;

  const AttendanceDayState({
    required this.day,
    required this.marks,
    this.loading = false,
    this.saving = false,
  });

  factory AttendanceDayState.fromDay(AttendanceDay day) => AttendanceDayState(
        day: day,
        marks: {for (final d in day.drivers) d.driverId: d.mark},
      );

  AttendanceDayState copyWith({
    Map<int, AttendanceMark>? marks,
    bool? loading,
    bool? saving,
  }) =>
      AttendanceDayState(
        day: day,
        marks: marks ?? this.marks,
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
      );

  AttendanceMark markOf(int driverId) => marks[driverId] ?? AttendanceMark.empty;

  /// Drivers whose mark differs from what the server has.
  Map<int, AttendanceMark> get changes => {
        for (final d in day.drivers)
          if (markOf(d.driverId) != d.mark) d.driverId: markOf(d.driverId),
      };

  bool get canEdit => day.editable && !saving && !loading;

  int get total => day.drivers.length;
  int get unmarked => day.drivers.where((d) => !markOf(d.driverId).isMarked).length;
  int get off => day.drivers.where((d) => markOf(d.driverId).isOff).length;
  int onShift(String shift) => day.drivers.where((d) => markOf(d.driverId).has(shift)).length;

  /// Unmarked drivers that have something to copy from the day before.
  int get copyableFromYesterday => day.drivers
      .where((d) => !markOf(d.driverId).isMarked && (d.previous?.isMarked ?? false))
      .length;
}

/// autoDispose so a switched-user login never shows the previous user's day.
final attendanceDayProvider =
    AsyncNotifierProvider.autoDispose<AttendanceDayNotifier, AttendanceDayState>(
  AttendanceDayNotifier.new,
);

class AttendanceDayNotifier extends AutoDisposeAsyncNotifier<AttendanceDayState> {
  // This riverpod version has no `ref.mounted`; a save or date change can
  // resolve after the screen is gone, and writing `state` then throws.
  bool _disposed = false;

  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  @override
  Future<AttendanceDayState> build() async {
    ref.onDispose(() => _disposed = true);
    return AttendanceDayState.fromDay(await _repo.getDay());
  }

  /// Loads another date, keeping the current one on screen meanwhile.
  /// Rethrows so the screen can show the server's message.
  Future<void> goToDate(String date) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(loading: true));
    try {
      final day = await _repo.getDay(date: date);
      if (_disposed) return;
      state = AsyncData(AttendanceDayState.fromDay(day));
    } catch (_) {
      if (!_disposed) state = AsyncData(current);
      rethrow;
    }
  }

  void setMark(int driverId, AttendanceMark mark) {
    final current = state.valueOrNull;
    if (current == null || !current.canEdit) return;
    state = AsyncData(current.copyWith(marks: {...current.marks, driverId: mark}));
  }

  /// Applies a mark to every driver still unmarked. [pick] may skip a driver
  /// by returning null.
  void fillUnmarked(AttendanceMark? Function(AttendanceDayDriver driver) pick) {
    final current = state.valueOrNull;
    if (current == null || !current.canEdit) return;
    final next = {...current.marks};
    for (final driver in current.day.drivers) {
      if (current.markOf(driver.driverId).isMarked) continue;
      final mark = pick(driver);
      if (mark != null) next[driver.driverId] = mark;
    }
    state = AsyncData(current.copyWith(marks: next));
  }

  void discard() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(AttendanceDayState.fromDay(current.day));
  }

  /// Sends the changed drivers. Rethrows so the screen can show the server's
  /// message; the unsaved marks stay in place when it fails.
  Future<void> save() async {
    final current = state.valueOrNull;
    if (current == null || current.changes.isEmpty) return;
    state = AsyncData(current.copyWith(saving: true));
    try {
      final day = await _repo.saveDay(current.day.date, current.changes);
      if (_disposed) return;
      state = AsyncData(AttendanceDayState.fromDay(day));
      // The register's totals are counted server-side from these rows.
      ref.invalidate(attendanceMonthProvider);
    } catch (_) {
      if (!_disposed) state = AsyncData(current);
      rethrow;
    }
  }
}

/// The month register, keyed by YYYY-MM.
final attendanceMonthProvider = FutureProvider.autoDispose.family<AttendanceMonth, String>(
  (ref, month) => ref.read(attendanceRepositoryProvider).getMonth(month),
);
