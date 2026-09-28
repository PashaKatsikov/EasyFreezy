import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import 'book.dart';
import 'ferry.dart';
import 'veil.dart';

class Trace {
  AppsflyerSdk? _sdk;
  var _started = false;

  Map<String, dynamic>? _install;
  Map<String, dynamic>? _deep;
  Map<String, dynamic>? _open;

  final Completer<Map<String, dynamic>> _installDone = Completer<Map<String, dynamic>>();
  final Completer<void> _deepDone = Completer<void>();

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final key = Book.flyerKey;
    if (key.isEmpty) {
      _finishInstall(const <String, dynamic>{});
      _finishDeep();
      return;
    }

    final sdk = AppsflyerSdk(
      AppsFlyerOptions(
        afDevKey: key,
        appId: Book.storeNumericId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: Book.attWaitSeconds.toDouble(),
      ),
    );
    _sdk = sdk;
    sdk.onInstallConversionData(_onInstall);
    sdk.onAppOpenAttribution(_onOpen);
    sdk.onDeepLinking(_onDeep);
    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall(const <String, dynamic>{});
      _finishDeep();
    }
  }

  Future<void> _onInstall(dynamic raw) async {
    final payload = _asMap(raw);
    var chosen = payload;
    if (payload['af_status']?.toString() == 'Organic') {
      await Future<void>.delayed(Duration(seconds: Book.organicWaitSeconds));
      final rescued = await _queryGcd();
      if (rescued != null) chosen = rescued;
    }
    _install = chosen;
    _finishInstall(chosen);
  }

  void _onOpen(dynamic raw) {
    _open = _asMap(raw);
  }

  void _onDeep(DeepLinkResult result) {
    final click = result.deepLink?.clickEvent;
    if (click != null) _deep = Map<String, dynamic>.from(click);
    _finishDeep();
  }

  Future<void> awaitSignals({int? installSeconds}) async {
    await Future.wait<void>(<Future<void>>[
      _installDone.future.timeout(
        Duration(seconds: installSeconds ?? Book.firstWaitSeconds),
        onTimeout: () => <String, dynamic>{},
      ),
      _deepDone.future.timeout(
        Duration(seconds: Book.linkWaitSeconds),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> deviceId() async {
    final sdk = _sdk;
    if (sdk == null) return null;
    try {
      return await sdk.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{...?_install};
    _deep?.forEach((key, value) => body.putIfAbsent(key, () => value));
    _open?.forEach((key, value) => body.putIfAbsent(key, () => value));
    body['af_id'] = await deviceId() ?? '';
    body['bundle_id'] = Book.applicationId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = Book.storeId;
    body['locale'] = locale;
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final project = Book.pushProject;
    if (project.isNotEmpty) body['firebase_project_id'] = project;
    assert(() {
      debugPrint('[EF.TRACE] ${jsonEncode(body)}');
      return true;
    }());
    return body;
  }

  Future<Map<String, dynamic>?> _queryGcd() async {
    try {
      final uid = await deviceId();
      if (uid == null || uid.isEmpty) return null;
      final appRef = Platform.isIOS ? Book.storeNumericId : Book.applicationId;
      final url = openGcdCall(appRef, uid);
      if (url.isEmpty) return null;
      final response = await ferry
          .get(
            Uri.parse(url),
            headers: <String, String>{'authorization': 'Bearer ${Book.flyerKey}'},
          )
          .timeout(Duration(seconds: Book.gcdTimeoutSeconds));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall(Map<String, dynamic> data) {
    if (!_installDone.isCompleted) _installDone.complete(data);
  }

  void _finishDeep() {
    if (!_deepDone.isCompleted) _deepDone.complete();
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is! Map) return <String, dynamic>{};
    return inner.map((k, v) => MapEntry(k.toString(), v));
  }
}
