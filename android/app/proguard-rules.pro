# Play Core (Deferred Components / Split APKs) - Required for Flutter R8
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Supabase / GoTrue / Realtime
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp (used by many packages)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Retrofit (if used)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Exceptions

# Just Audio
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Audio Service
-keep class com.ryanheise.audioservice.** { *; }

# Image Picker
-keep class androidx.core.content.FileProvider { *; }

# Sign in with Apple
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }

# Google Sign In
-keep class com.google.android.gms.auth.** { *; }

# Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# URL Launcher
-keep class androidx.browser.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Device Info Plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Package Info Plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# App Links
-keep class com.llfbandit.app_links.** { *; }

# Timezone
-keep class com.baseflow.flutter_native_timezone.** { *; }

# Keep Parcelables
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# R8 full mode compatibility
-dontwarn java.lang.invoke.StringConcatFactory
