import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import 'location_models.dart';

/// Free-text location suggestions for the trip-booking / external-trip
/// From/To fields. The backend proxies LocationIQ and never surfaces an
/// error — a missing key or failed lookup just yields an empty list — so
/// this repository mirrors that: any failure here also resolves to an empty
/// list rather than throwing, since suggestions are a pure UX nicety and
/// must never block typing or submission.
class LocationRepository {
  Dio get _dio => DioClient.dio;

  Future<List<LocationSuggestion>> autocomplete(String query) async {
    try {
      final response = await _dio.get(
        ApiConstants.locationsAutocomplete,
        queryParameters: {'q': query},
      );
      final data = response.data;
      if (data is! Map || data['success'] != true) return const [];
      final inner = data['data'];
      final list = inner is Map ? inner['data'] as List? : null;
      if (list == null) return const [];
      return list
          .map((e) => LocationSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
