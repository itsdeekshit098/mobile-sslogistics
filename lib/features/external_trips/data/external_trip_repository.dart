import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/api_response.dart';
import 'external_trip_models.dart';

class ExternalTripRepository {
  Dio get _dio => DioClient.dio;

  Future<ExternalTripListData> getTrips({
    String? fromDate,
    String? toDate,
    int? vehicleId,
    String? tripType,
    int page = 1,
    int pageSize = 20,
    bool includeSummary = true,
  }) async {
    final response = await _dio.get(
      ApiConstants.externalTrips,
      queryParameters: {
        'page': page,
        // Unlike diesel-records this endpoint uses snake_case paging params.
        'page_size': pageSize,
        if (!includeSummary) 'include_summary': 'false',
        'from_date': ?fromDate,
        'to_date': ?toDate,
        'vehicle_id': ?vehicleId,
        'trip_type': ?tripType,
      },
    );

    // API returns { data: { data: [...], total: N, summary?: {...} } }
    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch external trips',
    );
    final list = outer['data'] as List;
    final summaryJson = outer['summary'] as Map<String, dynamic>?;
    return ExternalTripListData(
      trips: list
          .map((e) => ExternalTrip.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: outer['total'] as int? ?? list.length,
      summary:
          summaryJson != null ? ExternalTripSummary.fromJson(summaryJson) : null,
    );
  }

  Future<void> createTrip(CreateExternalTripDto dto) async {
    final response = await _dio.post(
      ApiConstants.externalTrips,
      data: dto.toJson(),
    );

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to create trip');
  }

  Future<void> updateTrip(UpdateExternalTripDto dto) async {
    final response = await _dio.put(
      ApiConstants.externalTrips,
      data: dto.toJson(),
    );

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update trip');
  }

  Future<void> deleteTrip(int id) async {
    final response = await _dio.delete(
      ApiConstants.externalTrips,
      queryParameters: {'id': id},
    );

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete trip');
  }

  Future<List<Driver>> getDrivers() async {
    final response = await _dio.get(
      ApiConstants.drivers,
      queryParameters: {'pageSize': 100},
    );

    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch drivers',
    );
    final list = outer['data'] as List;
    return list
        .map((e) => Driver.fromJson(e as Map<String, dynamic>))
        .where((d) => d.isActive)
        .toList();
  }
}
