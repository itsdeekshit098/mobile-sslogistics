import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_models.dart';
import '../data/sessions_repository.dart';

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) => SessionsRepository());

class SessionsState {
  final List<SessionUser> users;
  final int total;
  final int page;
  final int perPage;

  const SessionsState({
    required this.users,
    required this.total,
    this.page = 1,
    this.perPage = 20,
  });

  int get totalPages => total == 0 ? 1 : (total / perPage).ceil();
}

/// autoDispose so a switched-user login doesn't briefly show the previous
/// user's cached session list.
final sessionsProvider =
    AsyncNotifierProvider.autoDispose<SessionsNotifier, SessionsState>(SessionsNotifier.new);

class SessionsNotifier extends AutoDisposeAsyncNotifier<SessionsState> {
  bool _disposed = false;

  @override
  Future<SessionsState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<SessionsState> _fetch({int page = 1, int perPage = 20}) async {
    final data = await ref.read(sessionsRepositoryProvider).fetchUsers(page: page, perPage: perPage);
    return SessionsState(users: data.users, total: data.total, page: data.page, perPage: data.perPage);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(page: current?.page ?? 1, perPage: current?.perPage ?? 20),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> changePage(int page) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _fetch(page: page, perPage: current.perPage));
    if (_disposed) return;
    state = result;
  }

  Future<void> changePageSize(int perPage) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _fetch(page: 1, perPage: perPage));
    if (_disposed) return;
    state = result;
  }

  Future<void> banUser(String userId) async {
    await ref.read(sessionsRepositoryProvider).banUser(userId);
    await refresh();
  }

  Future<void> unbanUser(String userId) async {
    await ref.read(sessionsRepositoryProvider).unbanUser(userId);
    await refresh();
  }

  Future<void> revokeSessions(String userId) async {
    await ref.read(sessionsRepositoryProvider).revokeSessions(userId);
    await refresh();
  }

  Future<bool> resetPassword({required String userId, required String newPassword}) async {
    final revoked = await ref
        .read(sessionsRepositoryProvider)
        .resetPassword(userId: userId, newPassword: newPassword);
    await refresh();
    return revoked;
  }
}
