# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase Cloud Messaging (push notifications)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Sentry crash reporting
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Flutter's deferred-components support references Play Core split-install
# APIs that this app doesn't depend on (no Play Feature Delivery in use).
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
