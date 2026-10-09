import 'veil.dart';

abstract final class Book {
  static const String applicationId = 'com.easyfreezy.app';
  static const String marketId = 'com.easyfreezy.app';
  static const String displayName = 'Easy Freezy';
  static const String storeNumericId = '';

  static const int snoozeSeconds = 259190;
  static const int organicWaitSeconds = 9;
  static const int postTimeoutSeconds = 22;
  static const int firstWaitSeconds = 27;
  static const int returnWaitSeconds = 9;
  static const int linkWaitSeconds = 8;
  static const int coldTapSeconds = 2;
  static const int dialTimeoutSeconds = 8;
  static const int dropQuietMs = 1050;
  static const int loopRetries = 4;
  static const int cacheSeconds = 561600;
  static const int attWaitSeconds = 14;
  static const int gcdTimeoutSeconds = 13;

  static String get flyerKey => openFlyerKey();
  static String get pushProject => openPushProject();

  static String get storeId {
    if (storeNumericId.isNotEmpty) return 'id$storeNumericId';
    return marketId;
  }

  // The endpoint URL is deliberately not reachable from Dart — it lives
  // encrypted in the Rust table and is resolved per call inside net.rs. The
  // readiness gate checks the secrets Dart still needs for AppsFlyer
  // bootstrap and the gray-layer string table. The config body itself is
  // plain JSON; the partner answers with plain JSON too.
  static bool get ready =>
      flyerKey.isNotEmpty && pushProject.isNotEmpty;
}
