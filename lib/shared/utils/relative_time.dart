import 'package:intl/intl.dart';

final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

/// Formats [dt] as "Just now" / "Xm ago" / "Xh ago" / "Xd ago", falling back
/// to an absolute date+time beyond a week — used anywhere a timestamp needs
/// a human-scannable age (activity log, sessions).
String relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return _dateTimeFmt.format(dt);
}
