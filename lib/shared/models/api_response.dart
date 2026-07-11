import 'package:dio/dio.dart';

/// Thrown by [unwrapResponse] when the API envelope reports failure. The
/// message is server-provided (already shown verbatim by callers via
/// `e.toString()`, often after stripping the default "Exception: " prefix),
/// so `toString()` returns the bare message rather than "ApiException: ...".
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Unwraps a `{ success, data, error }` envelope from a raw Dio [Response].
///
/// Relies on [DioClient]'s `validateStatus: status < 500` contract: 4xx
/// responses arrive here as normal `Response` objects rather than throwing,
/// so a non-success envelope becomes an [ApiException] instead of a
/// [DioException]. The central SESSION_INVALID / MAINTENANCE_MODE handling
/// in DioClient's interceptors runs before this — do not add status-code
/// special-casing here, that's handled upstream.
T unwrapResponse<T>(Response response, {String fallbackError = 'Request failed'}) {
  final data = response.data;
  if (data is Map && data['success'] == true) {
    return data['data'] as T;
  }
  final serverError = data is Map ? data['error'] as String? : null;
  throw ApiException(serverError ?? fallbackError, statusCode: response.statusCode);
}

/// Generic wrapper that mirrors the `{ success, data, error, message }` shape
/// returned by every Next.js API route in SS Logistics.
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.message,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromData,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: (json['data'] != null && fromData != null)
          ? fromData(json['data'])
          : null,
      error: json['error'] as String?,
      message: json['message'] as String?,
    );
  }
}
