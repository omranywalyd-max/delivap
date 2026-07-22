# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**
-dontwarn com.google.errorprone.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Maps
-keep class com.google.maps.** { *; }
-dontwarn com.google.maps.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Socket.IO
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# Lottie
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

# HTTP
-keep class org.apache.** { *; }
-dontwarn org.apache.**

# JSON
-keep class com.fasterxml.** { *; }
-dontwarn com.fasterxml.**

# Keep generic signatures
-keepattributes Signature
-keepattributes *Annotation*

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep model classes used by Gson/Json
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp / Okio
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Keep serializable classes
-keepattributes EnclosingMethod
-keep class ** implements java.io.Serializable { *; }

# Keep source info for crash reporting
-keepattributes SourceFile,LineNumberTable

# Customer app native activities
-keep class com.deliv.customer.** { *; }
-keep class com.deliv.customer.DriverArrivalActivity { *; }
-keep class com.deliv.customer.MainActivity { *; }
