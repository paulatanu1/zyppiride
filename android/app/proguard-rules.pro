# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase core
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Auth
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Firestore
-keep class com.google.firestore.** { *; }

# Firebase Cloud Messaging
-keep class com.google.firebase.messaging.** { *; }

# Firebase App Check
-keep class com.google.firebase.appcheck.** { *; }

# Play Integrity
-keep class com.google.android.play.core.integrity.** { *; }

# Kotlin reflection (used by some plugins)
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Geolocator / location plugins
-keep class com.baseflow.geolocator.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Prevent stripping of native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# flutter_image_compress — native JNI bridge; R8 will strip these without keep rules
-keep class vip.mystery0.** { *; }
-keep class com.fluttercandies.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Lottie animations
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

# Suppress warnings for missing classes that are optional at runtime
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
