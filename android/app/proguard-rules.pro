# === Flutter default keep rules ===
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# === TensorFlow Lite (Prevent class stripping) ===
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

# === Google Play Core (for split APKs / deferred components) ===
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# === Optional: Suppress common harmless warnings ===
-dontwarn org.tensorflow.**
-dontwarn java.nio.file.*
-dontwarn com.google.protobuf.**

# === Keep annotations and metadata (helps avoid reflection issues) ===
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
