import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/maintenance_status.dart';

/// Opens a long-lived Server-Sent Events connection to our own Next.js API
/// (not directly to Supabase — no extra credentials shipped in the app) so
/// the app finds out maintenance mode changed within ~1s instead of only on
/// its next API call. Auto-reconnects with a short delay whenever the
/// connection drops (network blip, backgrounded app, serverless timeout).
class MaintenanceStreamService {
  StreamSubscription<List<int>>? _subscription;
  bool _disposed = false;

  void Function(MaintenanceStatus status)? onStatus;

  void start() {
    _disposed = false;
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      final response = await DioClient.dio.get<ResponseBody>(
        ApiConstants.maintenanceStream,
        options: Options(responseType: ResponseType.stream),
      );

      var buffer = '';
      _subscription = response.data!.stream.listen(
        (chunk) {
          buffer += utf8.decode(chunk, allowMalformed: true);
          final events = buffer.split('\n\n');
          buffer = events.removeLast(); // keep any incomplete trailing event
          for (final block in events) {
            _handleEventBlock(block);
          }
        },
        onDone: _scheduleReconnect,
        onError: (Object e) {
          _breadcrumb('maintenance stream error', e);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      // Breadcrumb, not captureException: reconnects every 3s, so capturing
      // each failure would flood Sentry while offline.
      _breadcrumb('maintenance stream connect failed', e);
      _scheduleReconnect();
    }
  }

  void _breadcrumb(String message, Object error) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: 'sse',
      level: SentryLevel.warning,
      data: {'error': error.toString()},
    ));
  }

  void _handleEventBlock(String block) {
    final dataLine = block.split('\n').firstWhere(
          (line) => line.startsWith('data: '),
          orElse: () => '',
        );
    if (dataLine.isEmpty) return; // e.g. a ": ping" heartbeat comment

    try {
      final json = jsonDecode(dataLine.substring('data: '.length));
      onStatus?.call(MaintenanceStatus.fromJson(json as Map<String, dynamic>));
    } catch (_) {
      // Ignore malformed events.
    }
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    if (_disposed) return;
    Future.delayed(const Duration(seconds: 3), _connect);
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
  }
}
