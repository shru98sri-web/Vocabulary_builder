# Protect all core Google ML Kit models and sub-features from being stripped out
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
