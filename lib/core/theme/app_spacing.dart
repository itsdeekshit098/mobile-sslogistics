/// Standard spacing scale for new/touched widgets. Existing screens use
/// ad-hoc `EdgeInsets`/`SizedBox` values; this isn't a retroactive sweep —
/// adopt it going forward rather than rewriting spacing app-wide.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}
