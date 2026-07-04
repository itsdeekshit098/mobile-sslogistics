import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../network/dio_client.dart';

/// Connects to GET /api/notifications/stream (a plain SSE endpoint, not a
/// browser EventSource — Dio has no native SSE client) and parses the
/// "event: ...\ndata: ...\n\n" frames by hand.
///
/// Reconnects with a short delay on drop/error, mirroring EventSource's own
/// auto-reconnect behavior on web. Each (re)connection calls [onReconnect]
/// so the caller can refetch GET /api/notifications to catch up on
/// anything missed while disconnected.
class NotificationStreamService {
  StreamSubscription<List<int>>? _subscription;
  bool _stopped = false;
  Timer? _reconnectTimer;

  void connect({
    required void Function(Map<String, dynamic> json) onNotification,
    required void Function() onReconnect,
  }) {
    _stopped = false;
    _connectOnce(onNotification: onNotification, onReconnect: onReconnect);
  }

  Future<void> _connectOnce({
    required void Function(Map<String, dynamic> json) onNotification,
    required void Function() onReconnect,
  }) async {
    if (_stopped) return;

    try {
      final response = await DioClient.dio.get<ResponseBody>(
        ApiConstants.notificationsStream,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      onReconnect();

      final buffer = StringBuffer();
      _subscription = response.data!.stream.listen(
        (chunk) {
          buffer.write(utf8.decode(chunk, allowMalformed: true));
          _drainBuffer(buffer, onNotification);
        },
        onDone: () => _scheduleReconnect(onNotification, onReconnect),
        onError: (_) => _scheduleReconnect(onNotification, onReconnect),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect(onNotification, onReconnect);
    }
  }

  void _drainBuffer(
    StringBuffer buffer,
    void Function(Map<String, dynamic> json) onNotification,
  ) {
    final content = buffer.toString();
    final frames = content.split('\n\n');
    // The last element may be an incomplete frame — keep it in the buffer.
    buffer
      ..clear()
      ..write(frames.removeLast());

    for (final frame in frames) {
      _handleFrame(frame, onNotification);
    }
  }

  void _handleFrame(
    String frame,
    void Function(Map<String, dynamic> json) onNotification,
  ) {
    String? eventName;
    String? data;

    for (final line in frame.split('\n')) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data = line.substring(5).trim();
      }
      // Lines starting with ":" are heartbeat comments — ignored.
    }

    if (eventName == 'notification' && data != null && data.isNotEmpty) {
      try {
        onNotification(jsonDecode(data) as Map<String, dynamic>);
      } catch (_) {
        // Malformed frame — ignore and keep the connection alive.
      }
    }
  }

  void _scheduleReconnect(
    void Function(Map<String, dynamic> json) onNotification,
    void Function() onReconnect,
  ) {
    if (_stopped) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connectOnce(onNotification: onNotification, onReconnect: onReconnect);
    });
  }

  void close() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
  }
}
