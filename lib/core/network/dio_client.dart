import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';

/// Singleton Dio client with persistent cookie jar.
/// Call [DioClient.init] once in main() before the app starts.
class DioClient {
  static Dio? _dio;
  static PersistCookieJar? _cookieJar;

  /// Invoked whenever the backend reports the current session no longer
  /// exists (e.g. it was revoked because the account signed in elsewhere).
  /// Set by [AuthNotifier] so it can force a logout + login-screen redirect
  /// instead of every screen just showing a dead-end "error + retry" state.
  static void Function()? onSessionInvalidated;

  /// Invoked whenever any request comes back blocked by maintenance mode.
  /// This is a fallback alongside the maintenance SSE stream — it catches
  /// the case where a user acts (taps something) before the stream has
  /// pushed the change, or if the stream connection itself is blocked by a
  /// restrictive network. Set by [MaintenanceNotifier].
  static void Function(String? message)? onMaintenanceDetected;

  static Future<void> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();

    _cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${appDocDir.path}/.cookies/'),
    );

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
        // Treat any non-5xx status as a valid response; we check success flag manually
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio!.interceptors.add(CookieManager(_cookieJar!));

    // Detect a session revoked server-side (e.g. by a login elsewhere) so
    // callers don't have to special-case this in every repository.
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final data = response.data;
          if (response.statusCode == 401 &&
              data is Map &&
              data['code'] == 'SESSION_INVALID') {
            onSessionInvalidated?.call();
          }
          return handler.next(response);
        },
      ),
    );

    // Global error handler for friendly connection error messages
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          // 503s exceed validateStatus's `< 500` threshold, so they surface
          // here as an error rather than through onResponse above.
          final data = e.response?.data;
          if (e.response?.statusCode == 503 &&
              data is Map &&
              data['code'] == 'MAINTENANCE_MODE') {
            onMaintenanceDetected?.call(data['error'] as String?);
          }
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.unknown) {
            return handler.reject(
              NetworkException(
                requestOptions: e.requestOptions,
                customMessage: 'No internet connection. Please check your network.',
              ),
            );
          }
          return handler.next(e);
        },
      ),
    );
  }

  static Dio get dio {
    assert(_dio != null, 'DioClient.init() must be called before accessing dio');
    return _dio!;
  }

  /// Deletes all stored cookies (call on logout).
  static Future<void> clearCookies() async {
    await _cookieJar?.deleteAll();
  }
}

class NetworkException extends DioException {
  final String customMessage;

  NetworkException({
    required super.requestOptions,
    required this.customMessage,
  });

  @override
  String toString() => customMessage;
}
