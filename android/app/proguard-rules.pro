# Keep standard Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep SQLite3 and Drift (native SQLite interface)
-keep class com.sqlite3.** { *; }
-keep class org.sqlite.** { *; }
-keep class drift.** { *; }

# Keep Google Sign-In and Google APIs
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.googleapis.** { *; }
-keep class io.flutter.plugins.google_sign_in.** { *; }

# Keep WorkManager (background tasks)
-keep class dev.flutter.plugins.workmanager.** { *; }
-keep class androidx.work.** { *; }

# Suppress warnings from Google Play Core classes referenced by Flutter but not used
-dontwarn com.google.android.play.core.**

