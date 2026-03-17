# ═══════════════════════════════════════════════
#  flutter_local_notifications — ОБЯЗАТЕЛЬНО
# ═══════════════════════════════════════════════
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Broadcast receivers для scheduled notifications
-keep public class * extends android.content.BroadcastReceiver

# AndroidX notifications
-keep class androidx.core.app.** { *; }

# AlarmManager
-keep class android.app.AlarmManager { *; }
-keep class android.app.PendingIntent { *; }

# ═══════════════════════════════════════════════
#  Play Core (Flutter embedding)
# ═══════════════════════════════════════════════
-dontwarn com.google.android.play.core.**

# ═══════════════════════════════════════════════
#  Общие правила
# ═══════════════════════════════════════════════
-keepattributes *Annotation*
-keep class * implements java.io.Serializable { *; }
