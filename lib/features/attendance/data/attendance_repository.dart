import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import 'attendance_models.dart';

class AttendanceRepository {
  Dio get _dio => DioClient.dio;

  /// One day, every driver. With no [date] the server answers for today (IST).
  Future<AttendanceDay> getDay({String? date}) async {
    final response = await _dio.get(
      ApiConstants.driverAttendance,
      queryParameters: {'date': ?date},
    );
    return AttendanceDay.fromJson(
      unwrapResponse<Map<String, dynamic>>(response, fallbackError: 'Failed to load attendance'),
    );
  }

  /// The month register ([month] is YYYY-MM) with per-driver totals.
  Future<AttendanceMonth> getMonth(String month) async {
    final response = await _dio.get(
      ApiConstants.driverAttendance,
      queryParameters: {'month': month},
    );
    return AttendanceMonth.fromJson(
      unwrapResponse<Map<String, dynamic>>(response, fallbackError: 'Failed to load the register'),
    );
  }

  /// Downloads the month's wages export (CSV) to a temp file and returns its
  /// path. Admin-only on the server.
  Future<String> downloadMonthExport(String month) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/driver_attendance_$month.csv';
    final response = await _dio.download(
      ApiConstants.driverAttendanceExport,
      savePath,
      queryParameters: {'month': month},
    );
    // 4xx arrives as a normal response here, with the error body written to
    // the file — never hand that to the user as if it were the export.
    if ((response.statusCode ?? 500) < 300) return savePath;
    throw const ApiException('Failed to download the export');
  }

  /// Saves only the drivers that changed, and returns the day as now stored.
  /// An empty mark clears that driver's attendance for the date.
  Future<AttendanceDay> saveDay(String date, Map<int, AttendanceMark> changes) async {
    final response = await _dio.put(
      ApiConstants.driverAttendance,
      data: {
        'date': date,
        'entries': [
          for (final entry in changes.entries) {'driver_id': entry.key, ...entry.value.toJson()},
        ],
      },
    );
    return AttendanceDay.fromJson(
      unwrapResponse<Map<String, dynamic>>(response, fallbackError: 'Failed to save attendance'),
    );
  }
}
