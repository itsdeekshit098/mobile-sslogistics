import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/app_user.dart';

class AuthRepository {
  Dio get _dio => DioClient.dio;

  /// POST /api/auth/login → returns logged-in user on success
  Future<AppUser> login(String email, String password) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );

    final data = response.data;

    if (response.statusCode == 200 && data is Map && data['success'] == true) {
      // Login succeeded; cookie is now stored by the cookie jar.
      // Fetch the session to get the full user object.
      return getSession();
    }

    if (data is Map) {
      throw Exception(
        data['error'] ?? data['message'] ?? 'Login failed',
      );
    } else {
      throw Exception('Login failed. Status: ${response.statusCode}, Response: ${data.toString().substring(0, data.toString().length > 50 ? 50 : data.toString().length)}...');
    }
  }

  /// GET /api/auth/session → returns current user or throws
  Future<AppUser> getSession() async {
    final response = await _dio.get(ApiConstants.session);
    final data = response.data;

    if (response.statusCode == 200 && data is Map && data['success'] == true) {
      final user = AppUser.fromJson(
        data['data'] as Map<String, dynamic>,
      );
      await SecureStorage.saveUser(user.toJson());
      return user;
    }

    throw Exception('Not authenticated');
  }

  /// POST /api/auth/logout + clear local cookies
  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } catch (_) {
      // Even if the server call fails, clear local state
    }
    await clearLocalSession();
  }

  /// Clears local session state only, without calling the server.
  /// Used when the server has already invalidated the session itself
  /// (e.g. the account was signed in elsewhere), so there's nothing to
  /// revoke remotely.
  Future<void> clearLocalSession() async {
    await DioClient.clearCookies();
    await SecureStorage.clearUser();
  }
}
