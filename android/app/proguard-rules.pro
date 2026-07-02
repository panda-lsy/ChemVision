# vivo BlueLM 端侧 LLM SDK
# 通过反射访问 LlmConfig / LlmManager 的字段和方法，必须保留类名、字段名、方法名。
-keep class com.vivo.llmsdk.** { *; }
-dontwarn com.vivo.llmsdk.**

# JNI 原生层对应的包名/类名符号
-keepclasseswithmembernames class * {
    native <methods>;
}
