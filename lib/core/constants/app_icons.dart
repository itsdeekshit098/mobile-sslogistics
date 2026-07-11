import 'package:flutter/material.dart';

/// Centralised icon map matching the web app's Lucide icon names.
/// Using Material Icons as a stable drop-in — swap to a Lucide package
/// whenever a Dart 3.x-compatible version is available.
class AppIcons {
  // Navigation / layout
  static const layoutDashboard = Icons.dashboard_outlined;
  static const menu = Icons.menu;
  static const bell = Icons.notifications_none_outlined;
  static const arrowRight = Icons.arrow_forward;
  static const arrowLeft = Icons.arrow_back;
  static const chevronLeft = Icons.chevron_left;
  static const chevronRight = Icons.chevron_right;
  static const x = Icons.close;
  static const lock = Icons.lock_outline;
  static const logOut = Icons.logout;

  // Entities
  static const truck = Icons.local_shipping_outlined;
  static const users = Icons.people_outline;
  static const building2 = Icons.business_outlined;
  static const fuel = Icons.local_gas_station_outlined;
  static const wrench = Icons.build_outlined;
  static const userCog = Icons.manage_accounts_outlined;
  static const navigation = Icons.directions_outlined;
  static const fileText = Icons.description_outlined;
  static const barChart3 = Icons.bar_chart_outlined;
  static const activity = Icons.timeline;
  static const shieldCheck = Icons.verified_user_outlined;
  static const shield = Icons.security_outlined;
  static const user = Icons.person_outline;
  static const inbox = Icons.inbox_outlined;
  static const badge = Icons.badge_outlined;

  // Actions
  static const plus = Icons.add;
  static const pencil = Icons.edit_outlined;
  static const trash2 = Icons.delete_outline;
  static const refreshCw = Icons.refresh;
  static const checkCircle = Icons.check_circle_outline;

  // Status / alerts
  static const alertCircle = Icons.error_outline;
  static const alertTriangle = Icons.warning_amber_outlined;

  // Form / visibility
  static const eye = Icons.visibility_outlined;
  static const eyeOff = Icons.visibility_off_outlined;
  static const calendar = Icons.calendar_today_outlined;
  static const clock = Icons.access_time;

  // Metrics
  static const gauge = Icons.speed;
  static const droplets = Icons.water_drop_outlined;
  static const indianRupee = Icons.currency_rupee;
  static const mapPin = Icons.place_outlined;
  static const trendingUp = Icons.trending_up;

  // Admin (sessions / settings / activity log)
  static const settings = Icons.settings_outlined;
  static const smartphone = Icons.smartphone_outlined;
  static const ban = Icons.block_outlined;
  static const key = Icons.vpn_key_outlined;
  static const uploadCloud = Icons.cloud_upload_outlined;
}
