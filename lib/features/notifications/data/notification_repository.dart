import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/api_response.dart';
import 'notification_models.dart';

class NotificationRepository {
  Dio get _dio => DioClient.dio;

  Future<NotificationListData> getNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      ApiConstants.notifications,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );

    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch notifications',
    );
    final list = outer['data'] as List;
    return NotificationListData(
      items: list
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: outer['total'] as int? ?? list.length,
      unreadCount: outer['unreadCount'] as int? ?? 0,
    );
  }

  Future<void> markRead(int id) async {
    final response = await _dio.put(
      ApiConstants.notificationsMarkRead,
      data: {'id': id},
    );

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to mark notification read');
  }

  Future<void> markAllRead() async {
    final response = await _dio.put(ApiConstants.notificationsMarkAllRead);

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to mark notifications read');
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    final response = await _dio.post(
      ApiConstants.notificationsRegisterDevice,
      data: {'token': token, 'platform': platform},
    );

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to register device');
  }

  Future<void> unregisterDevice(String token) async {
    final response = await _dio.delete(
      ApiConstants.notificationsRegisterDevice,
      queryParameters: {'token': token},
    );

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to unregister device');
  }
}
