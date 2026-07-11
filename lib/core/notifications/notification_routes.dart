/// Maps a notification's `type` (+ its metadata) to a route that actually
/// exists in this app's GoRouter. Notifications are created server-side
/// with a `link_path` meant for the *web* admin dashboard (e.g.
/// `/admin/diesel-records?...`) — that path doesn't exist on mobile, so
/// mobile navigation must derive its own destination from `type`/metadata
/// instead of reusing the web-only link_path.
String? mobileRouteForNotification(String type, [Map<String, dynamic>? data]) {
  switch (type) {
    case 'diesel_record_created':
      final vehicleId = data?['vehicle_id'];
      if (vehicleId != null) {
        return '/diesel-records?vehicle_id=$vehicleId';
      }
      return '/diesel-records';
    case 'vehicle_created':
    case 'vehicle_updated':
    case 'vehicle_deleted':
      return '/vehicles';
    case 'document_expiring':
      return '/vehicles';
    case 'trip_booking_reminder':
      return '/trip-bookings';
    default:
      // Unrecognized/future notification types still land somewhere useful
      // instead of a dead tap.
      return '/notifications';
  }
}
