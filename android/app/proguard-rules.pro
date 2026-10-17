# TajGo R8/ProGuard rules.
# Conservative keeps for Flutter + Firebase reflection. Runtime verification of
# the shrunk release build is PHONE_REQUIRED.

# Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play services (reflection, model deserialization)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep annotations and generic signatures used by Firestore serialization
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses
-keepattributes SourceFile,LineNumberTable

# Play Integrity / App Check
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.**

# Kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
