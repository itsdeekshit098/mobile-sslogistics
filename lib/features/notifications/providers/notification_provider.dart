import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/notification_stream_service.dart';
import '../data/notification_repository.dart';
import '../data/notification_models.dart';

/// UI state for the notifications list + bell badge.
class NotificationListState {
  final List<NotificationItem> items;
  final int total;
  final int unreadCount;

  const NotificationListState({
    required this.items,
    required this.total,
    required this.unreadCount,
  });

  const NotificationListState.initial()
      : items = const [],
        total = 0,
        unreadCount = 0;
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

final notificationListProvider =
    AsyncNotifierProvider<NotificationListNotifier, NotificationListState>(
  NotificationListNotifier.new,
);

class NotificationListNotifier extends AsyncNotifier<NotificationListState> {
  final NotificationStreamService _stream = NotificationStreamService();

  @override
  Future<NotificationListState> build() async {
    ref.onDispose(_stream.close);

    _stream.connect(
      onNotification: (json) {
        final item = NotificationItem.fromJson(json);
        final cur = state.valueOrNull ?? const NotificationListState.initial();
        state = AsyncData(
          NotificationListState(
            items: [item, ...cur.items],
            total: cur.total + 1,
            unreadCount: cur.unreadCount + 1,
          ),
        );
      },
      // Re-fetch on every (re)connection to catch up on anything missed
      // while disconnected, mirroring the web hook's EventSource onopen.
      onReconnect: () {
        refresh();
      },
    );

    return _fetch();
  }

  Future<NotificationListState> _fetch() async {
    final data =
        await ref.read(notificationRepositoryProvider).getNotifications();
    return NotificationListState(
      items: data.items,
      total: data.total,
      unreadCount: data.unreadCount,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> markRead(int id) async {
    final cur = state.valueOrNull;
    if (cur == null) return;

    final alreadyRead = cur.items.any((n) => n.id == id && n.isRead);
    if (alreadyRead) return;

    state = AsyncData(
      NotificationListState(
        items: cur.items
            .map((n) => n.id == id
                ? n.copyWith(readAt: DateTime.now().toIso8601String())
                : n)
            .toList(),
        total: cur.total,
        unreadCount: cur.unreadCount > 0 ? cur.unreadCount - 1 : 0,
      ),
    );

    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
    } catch (_) {
      // Best-effort — next refresh reconciles.
    }
  }

  Future<void> markAllRead() async {
    final cur = state.valueOrNull;
    if (cur == null) return;

    state = AsyncData(
      NotificationListState(
        items: cur.items
            .map((n) => n.copyWith(
                readAt: n.readAt ?? DateTime.now().toIso8601String()))
            .toList(),
        total: cur.total,
        unreadCount: 0,
      ),
    );

    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } catch (_) {
      // Best-effort — next refresh reconciles.
    }
  }
}
