# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# قواعد تعتيم عامة
-verbose
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontskipnonpubliclibraryclassmembers
-dontpreverify
-allowaccessmodification
-repackageclasses ''

# تعتيم أسماء المتغيرات والدوال
-obfuscationdictionary proguard-dict.txt
-classobfuscationdictionary proguard-dict.txt
-packageobfuscationdictionary proguard-dict.txt

# إخفاء المعلومات الحساسة
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Security classes
-keep class com.example.secure_app.security.** { *; }
-keep class com.example.secure_app.MainActivity { *; }
-keep class com.example.secure_app.SecurityModule { *; }
-keep class com.example.secure_app.RootDetectionModule { *; }

# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Security detection
-keep class com.scottyab.rootbeer.** { *; }
-keep class com.noshufou.android.su.** { *; }
-keep class eu.chainfire.** { *; }

# SSL Pinning
-keep class com.datatheorem.android.trustkit.** { *; }
-keep class okhttp3.CertificatePinner { *; }
-keep class okhttp3.ConnectionSpec { *; }

# Secure Storage
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }

# Encryption
-keep class javax.crypto.** { *; }
-keep class javax.crypto.spec.** { *; }
-keep class java.security.** { *; }

# Biometric
-keep class androidx.biometric.** { *; }

# تعزيز الأمان
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-keepattributes *Annotation*,EnclosingMethod,Signature
-keepattributes SourceFile,LineNumberTable

# منع الهندسة العكسية
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# حماية ضد التصحيح
-keep class android.os.Debug { *; }
-assumenosideeffects class android.os.Debug {
    public static boolean isDebuggerConnected();
    public static void waitForDebugger();
}

# إخفاء المسارات الحساسة
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# تعتيم إضافي
-adaptclassstrings
-adaptresourcefilenames
-adaptresourcefilecontents

# إخفاء الاستثناءات
-keepattributes Exceptions
-keep public class * extends java.lang.Exception

# حماية الـ Reflection
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# حماية الأكواد الحساسة
-keep class com.example.secure_app.core.security.** { *; }
-keep class com.example.secure_app.core.encryption.** { *; }

# إزالة التعليقات والـ metadata غير الضرورية
-dontnote
-dontwarn