import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_remoteBg);
      await _setupLocal();
      _token = await _messaging!.getToken();
      _messaging!.onTokenRefresh.listen((next) {
        _token = next;
        onToken?.call(next);
      });
      FirebaseMessaging.onMessage.listen(_foreground);
      FirebaseMessaging.onMessageOpenedApp.listen(_warm);
      _ready = true;
    } catch (_) {}
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
    final messaging = _messaging;
    if (messaging == null) return false;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    final granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _shelf.markGranted(granted);
    if (status == AuthorizationStatus.denied) await _shelf.markBlocked();
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
