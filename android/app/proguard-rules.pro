# Add project specific ProGuard rules here.
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Keep line numbers for debugging stack traces (optional)
#-keepattributes SourceFile,LineNumberTable
#-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google ML Kit rules
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-keepnames class com.google.mlkit.** { *; }

# Play Core rules (for app update, asset delivery, deferred components)
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.assetpacks.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Flutter deferred component rules
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Provider / ViewModel rules (if needed)
-keep class ** extends androidx.lifecycle.ViewModel { *; }
-keep class ** extends android.arch.lifecycle.ViewModel { *; }
-keep class kotlin.Metadata { *; }

# HTTP / Base64 warnings
-dontwarn org.apache.commons.codec.binary.Base64

# Missing rules from R8
-dontwarn com.google.android.gms.common.annotation.NoNullnessRewrite
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
