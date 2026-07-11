import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/api_response.dart';
import 'trip_booking_models.dart';

class TripBookingRepository {
  Dio get _dio => DioClient.dio;

  Future<TripBookingListData> getBookings({
    String? status,
    String? onDate,
    String? fromDate,
    String? toDate,
    String? search,
    bool upcoming = false,
    int page = 1,
    int pageSize = 20,
    bool includeSummary = true,
  }) async {
    final response = await _dio.get(
      ApiConstants.tripBookings,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (includeSummary) 'include_summary': 'true',
        if (upcoming) 'upcoming': 'true',
        'status': ?status,
        // Exact-date match takes precedence over the from/to range — the
        // two are alternative ways to narrow by date, not combined.
        'on_date': ?onDate,
        if (onDate == null) 'from_date': ?fromDate,
        if (onDate == null) 'to_date': ?toDate,
        'search': ?search,
      },
    );

    // API returns { data: { data: [...], total: N, summary?: {...} } }
    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch trip bookings',
    );
    final list = outer['data'] as List;
    final summaryJson = outer['summary'] as Map<String, dynamic>?;
    return TripBookingListData(
      bookings: list
          .map((e) => TripBooking.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: outer['total'] as int? ?? list.length,
      summary: summaryJson != null
          ? TripBookingSummary.fromJson(summaryJson)
          : null,
    );
  }

  Future<TripBooking> createBooking(CreateTripBookingDto dto) async {
    final response = await _dio.post(
      ApiConstants.tripBookings,
      data: dto.toJson(),
    );

    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to create booking',
    );
    return TripBooking.fromJson(data['booking'] as Map<String, dynamic>);
  }

  Future<TripBooking> updateBooking(UpdateTripBookingDto dto) async {
    final response = await _dio.put(
      ApiConstants.tripBookings,
      data: dto.toJson(),
    );

    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to update booking',
    );
    return TripBooking.fromJson(data['booking'] as Map<String, dynamic>);
  }

  /// Cancels a booking — the only status transition the API allows via PUT
  /// (completion happens by creating an external trip with `booking_id`).
  Future<void> cancelBooking(int id) async {
    final response = await _dio.put(
      ApiConstants.tripBookings,
      data: {'id': id, 'status': statusCancelled},
    );

    unwrapResponse<dynamic>(
      response,
      fallbackError: 'Failed to cancel booking',
    );
  }
}
