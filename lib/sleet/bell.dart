import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'ferry.dart';
import 'shelf.dart';

const String kChipChannelId = 'ef_chip_notes';
const String kChipChannelName = 'Chip alerts';
const String _icon = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _remoteBg(RemoteMessage message) async {}

class Bell {
  Bell(this._shelf);

  final Shelf _shelf;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  String? _token;
  var _ready = false;
  var _launchRead = false;
  var _localReady = false;

  void Function(String url)? onIncoming;
  void Function(String token)? onToken;

  String? get token => _token;

  Future<void> boot() async {
    if (_ready) return;
    final messaging = await _ensureMessaging();
    if (messaging == null) return; // Firebase unavailable; retry on next call.
    try {
      FirebaseMessaging.onBackgroundMessage(_remoteBg);
      FirebaseMessaging.onMessage.listen(_foreground);
      FirebaseMessaging.onMessageOpenedApp.listen(_warm);
      messaging.onTokenRefresh.listen((next) {
        _token = next;
        onToken?.call(next);
      });
      _ready = true;
      // Token fetch must never hang the flow (e.g. a first launch with no
      // network). Bound it; onTokenRefresh delivers it later once online.
      try {
        _token = await messaging
            .getToken()
            .timeout(const Duration(seconds: 12), onTimeout: () => null);
        debugPrint('[EF.FIRE] boot token=${_token == null ? 'null' : 'ok(${_token!.length})'}');
      } catch (e) {
        debugPrint('[EF.FIRE] getToken failed: $e');
      }
    } catch (_) {}
  }

  // Minimal, fast path to a usable messaging instance: ensures Firebase is up
  // and local notifications are wired, without waiting on the FCM token. Safe to
  // call repeatedly (idempotent) and used by both boot() and ask().
  Future<FirebaseMessaging?> _ensureMessaging() async {
    final existing = _messaging;
    if (existing != null) return existing;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;
      await _setupLocal();
      debugPrint('[EF.FIRE] messaging ready '
          '(project=${Firebase.app().options.projectId})');
      return messaging;
    } catch (e, st) {
      debugPrint('[EF.FIRE] ensureMessaging FAILED: $e');
      debugPrint('$st');
      return null;
    }
  }

  Future<void> _setupLocal() async {
    if (_localReady) return;
    const android = AndroidInitializationSettings(_icon);
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final url = _urlFromPayload(response.payload);
        if (url != null) onIncoming?.call(url);
      },
    );
    if (Platform.isAndroid) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChipChannelId,
          kChipChannelName,
          description: 'Bonus drops and promo notes',
          importance: Importance.high,
        ),
      );
    }
    _localReady = true;
  }

  Future<bool> ask() async {
    // The system permission dialog must not depend on the FCM token, so go
    // through the lightweight ensure path rather than the full boot().
    final messaging = await _ensureMessaging();
    if (messaging == null) {
      debugPrint('[EF.FIRE] ask: messaging unavailable, no dialog');
      return false;
    }
    // Kick off the full listener/token setup in the background so pushes work
    // once permission is granted, but don't let it delay the dialog.
    if (!_ready) unawaited(boot());

    // Android 13+: fire the concrete POST_NOTIFICATIONS OS dialog directly via
    // the local-notifications plugin (most reliable), then reconcile with FCM.
    bool? androidGrant;
    if (Platform.isAndroid) {
      try {
        final android = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        androidGrant = await android?.requestNotificationsPermission();
        debugPrint('[EF.FIRE] ask: android POST_NOTIFICATIONS granted=$androidGrant');
      } catch (e) {
        debugPrint('[EF.FIRE] ask: android request failed: $e');
      }
    }

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    debugPrint('[EF.FIRE] ask: fcm status=$status androidGrant=$androidGrant');
    final granted = androidGrant ??
        (status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional);
    await _shelf.markGranted(granted);
    if (!granted && status == AuthorizationStatus.denied) {
      await _shelf.markBlocked();
    }
    return granted;
  }

  Future<String?> coldOpen({required Duration within}) async {
    if (_launchRead) return null;
    _launchRead = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final initial = await FirebaseMessaging.instance.getInitialMessage().timeout(within);
      final fromFcm = _urlFromData(initial?.data);
      if (fromFcm != null && initial != null) {
        final id = _tapId(initial, fromFcm);
        if (_shelf.alreadyOpened(id)) return null;
        await _shelf.rememberOpened(id);
        return fromFcm;
      }
    } catch (_) {}

    try {
      await _setupLocal();
      final details = await _local.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        return _urlFromPayload(details?.notificationResponse?.payload);
      }
    } catch (_) {}
    return null;
  }

  static String? _urlFromData(Map<String, dynamic>? data) {
    final raw = data?['url'];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

  static String? _urlFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return _urlFromData(decoded);
    } catch (_) {}
    return null;
  }

  static String _tapId(RemoteMessage message, String url) {
    final messageId = message.messageId;
    if (messageId != null && messageId.isNotEmpty) return messageId;
    final sent = message.sentTime?.millisecondsSinceEpoch ?? 0;
    return '$sent:${url.hashCode}';
  }

  Future<void> _foreground(RemoteMessage message) async {
    final note = message.notification;
    if (note == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final imageUrl = note.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _fetch(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kChipChannelId,
          kChipChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _icon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }
    details ??= const AndroidNotificationDetails(
      kChipChannelId,
      kChipChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _icon,
    );
    await _local.show(
      id: note.hashCode,
      title: note.title,
      body: note.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  void _warm(RemoteMessage message) {
    final url = message.data['url'];
    if (url is String && url.isNotEmpty) onIncoming?.call(url);
  }

  Future<Uint8List?> _fetch(String url) async {
    try {
      final response = await ferry.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
}
