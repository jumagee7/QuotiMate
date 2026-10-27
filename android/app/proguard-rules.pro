# Keep ML Kit Text Recognition classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**

# flutter_local_notifications — keep all BroadcastReceivers and Services so
# ProGuard/R8 does not strip them in release builds. Without these rules the
# ScheduledNotificationReceiver is removed and NO scheduled notifications fire
# when the app is in the background or killed.
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }

