import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/notification_stream_service.dart';
import '../../auth/providers/auth_provider.dart';
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
  // Feeds the dashboard bell badge and keeps an SSE connection open, so this
  // provider stays app-scoped (not autoDispose) to avoid tearing the stream
  // down and reconnecting every time the user navigates away from a screen
  // that watches it. Instead it's gated on auth: build() re-runs on
  // login/logout/forced-logout (ref.watch(authProvider) below), which closes
  // the old stream via ref.onDispose and either returns empty state (no
  // user) or opens a fresh stream + fetch (new user) — fixing both the
  // post-logout reconnect-forever leak and stale cross-user data.
  @override
  Future<NotificationListState> build() async {
    final user = ref.watch(authProvider.select((s) => s.valueOrNull));
    if (user == null) {
      return const NotificationListState.initial();
    }

    final stream = NotificationStreamService();
    ref.onDispose(stream.close);

    stream.connect(
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

    return _fetchWithRetry();
  }

  /// The very first fetch can race the auth session settling right after
  /// login (cookie not yet propagated), causing a spurious error. Retry
  /// once after a short delay before surfacing it to the UI.
  Future<NotificationListState> _fetchWithRetry() async {
    try {
      return await _fetch();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 800));
      return _fetch();
    }
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
