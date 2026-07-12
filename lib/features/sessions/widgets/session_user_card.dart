import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/relative_time.dart';
import '../data/session_models.dart';

class SessionUserCard extends StatefulWidget {
  final SessionUser user;
  final bool isSelf;
  final VoidCallback onActions;

  const SessionUserCard({
    super.key,
    required this.user,
    required this.isSelf,
    required this.onActions,
  });

  @override
  State<SessionUserCard> createState() => _SessionUserCardState();
}

class _SessionUserCardState extends State<SessionUserCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.user;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.tileSessionsIcon.withValues(alpha: 0.16)
                            : AppColors.tileSessionsBg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          color: AppColors.tileSessionsIcon,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (widget.isSelf) ...[
                                const SizedBox(width: 6),
                                _Badge(label: 'You', color: AppColors.primary),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _Badge(label: user.role.toUpperCase(), color: AppColors.textMuted),
                              if (user.isBanned) _Badge(label: 'Banned', color: AppColors.error),
                              _Badge(
                                label: '${user.sessions.length} session${user.sessions.length == 1 ? '' : 's'}',
                                color: AppColors.tileSessionsIcon,
                              ),
                            ],
                          ),
                          if (user.lastSignInAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Last sign-in ${relativeTime(user.lastSignInAt!)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                      onPressed: widget.onActions,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
            if (user.sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No active sessions',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Column(
                  children: user.sessions.map((s) => _SessionRow(session: s)).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final UserSession session;
  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.smartphone, size: 15, color: secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.device ?? 'Unknown device',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${session.ip ?? 'Unknown IP'} · active ${session.lastActiveAt != null ? relativeTime(session.lastActiveAt!) : 'unknown'}',
                  style: TextStyle(fontSize: 11.5, color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
