-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

-keep class com.appsflyer.** { *; }
-dontwarn com.appsflyer.**

-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.play.core.**

-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
