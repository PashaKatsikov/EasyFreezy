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

  static String get endpoint => openEndpoint();
  static String get relaySecret => openRelaySecret();
  static String get flyerKey => openFlyerKey();
  static String get pushProject => openPushProject();

  static String get storeId {
    if (storeNumericId.isNotEmpty) return 'id$storeNumericId';
    return marketId;
  }

  static bool get ready =>
      endpoint.isNotEmpty &&
      relaySecret.isNotEmpty &&
      flyerKey.isNotEmpty &&
      pushProject.isNotEmpty;
}
