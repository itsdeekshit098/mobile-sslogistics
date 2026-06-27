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
