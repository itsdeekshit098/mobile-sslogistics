import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import 'session_models.dart';

class SessionsRepository {
  Dio get _dio => DioClient.dio;

  Future<SessionsPage> fetchUsers({int page = 1, int perPage = 20}) async {
    final response = await _dio.get(
      ApiConstants.adminSessions,
      queryParameters: {'page': page, 'perPage': perPage},
    );

    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch sessions',
    );
    final list = outer['users'] as List;
    final users = list.map((e) => SessionUser.fromJson(e as Map<String, dynamic>)).toList();
    return SessionsPage(
      users: users,
      total: outer['total'] as int? ?? users.length,
      page: outer['page'] as int? ?? page,
      perPage: outer['perPage'] as int? ?? perPage,
    );
  }

  Future<void> _setBan(String userId, bool ban) async {
    final response = await _dio.put(
      ApiConstants.adminSessions,
      data: {'userId': userId, 'action': ban ? 'ban' : 'unban'},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update user');
  }

  Future<void> banUser(String userId) => _setBan(userId, true);
  Future<void> unbanUser(String userId) => _setBan(userId, false);

  Future<void> revokeSessions(String userId) async {
    final response = await _dio.delete(
      ApiConstants.adminSessions,
      queryParameters: {'userId': userId},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to revoke sessions');
  }

  /// Returns whether the reset also revoked the user's active sessions.
  Future<bool> resetPassword({required String userId, required String newPassword}) async {
    final response = await _dio.patch(
      ApiConstants.adminSessions,
      data: {'userId': userId, 'newPassword': newPassword},
    );
    final data = unwrapResponse<Map<String, dynamic>?>(
      response,
      fallbackError: 'Failed to reset password',
    );
    return data?['sessionsRevoked'] as bool? ?? true;
  }
}
