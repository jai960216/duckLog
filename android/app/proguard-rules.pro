# ============================================================================
# ProGuard / R8 rules for duckLog (Flutter release build)
# ============================================================================

# ---------- Flutter engine ----------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-dontwarn io.flutter.embedding.**

# ---------- Firebase Core ----------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ---------- Firebase Crashlytics ----------
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }

# ---------- Firebase Messaging ----------
-keep class com.google.firebase.messaging.** { *; }

# ---------- Firebase Analytics ----------
-keep class com.google.firebase.analytics.** { *; }

# ---------- Google Sign-In / Play Services Auth ----------
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.signin.** { *; }
-dontwarn com.google.android.gms.**

# ---------- Kakao SDK ----------
-keep class com.kakao.sdk.** { *; }
-dontwarn com.kakao.sdk.**

# ---------- In-App Purchase (Google Play Billing) ----------
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ---------- OkHttp (used by Supabase, Kakao, etc.) ----------
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ---------- Hive (local storage) ----------
-keep class io.hive.** { *; }
-dontwarn io.hive.**

# ---------- General: Annotations ----------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# ---------- General: Serializable ----------
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ---------- Suppress common warnings ----------
-dontwarn javax.annotation.**
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn sun.misc.**
