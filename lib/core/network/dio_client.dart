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

    // Global error handler for friendly connection error messages
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
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
