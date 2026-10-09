// Gray-layer bridge to the native Rust component (`libsleet.so`).
//
// Two surfaces live here:
//
//  * String table — relay secret, AppsFlyer/GCD, push project, UA fragments,
//    WebView JS injections, relay screen copy. Ciphertext lives in Rust
//    (rust/src/table.rs, generated from tool/sleet/plain.dart); this file
//    only reveals a given id on demand.
//
//  * `postConfig` — browser-fingerprinted HTTP POST (wreq + Chrome134) to
//    the config endpoint. The URL, method, header names and MIME all stay in
//    the encrypted table and are decrypted inside Rust on every call, so
//    nothing about the request shape is visible from Dart.
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _RevealNative = Pointer<Uint8> Function(Int32);
typedef _RevealDart = Pointer<Uint8> Function(int);
typedef _FreeNative = Void Function(Pointer<Uint8>);
typedef _FreeDart = void Function(Pointer<Uint8>);
typedef _PostNative = Pointer<Uint8> Function(Pointer<Uint8>, Uint32, Uint32);
typedef _PostDart = Pointer<Uint8> Function(Pointer<Uint8>, int, int);

// FFI ids — must stay in sync with the DATA order in rust/src/table.rs.
//
// Ids 23..26 (httpMethod, headerAccept, headerContentType, mimeJson) are
// native-only: they're consumed inside Rust (rust/src/net.rs) when the HTTP
// transport fires, and are deliberately NOT exposed through veil.dart so the
// URL/method/header surface never materialises in plaintext on the Dart side.
// Keeping `_idEndpoint` out of this list for the same reason: the real URL
// is resolved per call inside net.rs via DATA[ID_ENDPOINT].
const int _idRelaySecret = 1;
const int _idGcd = 2;
const int _idFlyerKey = 3;
const int _idPushProject = 4;
const int _idProduct = 5;
const int _idLinuxOpen = 6;
const int _idBuildLabel = 7;
const int _idBuildClose = 8;
const int _idEngineLabel = 9;
const int _idEngineTail = 10;
const int _idChromeLabel = 11;
const int _idSafariLabel = 12;
const int _idChrome = 13;
const int _idWebkit = 14;
const int _idSafeArea = 15;
const int _idKeyboard = 16;
const int _idAutoplay = 17;
const int _idHook = 18;
const int _idInviteTitle = 19;
const int _idInviteBody = 20;
const int _idGapTitle = 21;
const int _idGapBody = 22;

// Cache slots cover ids 0..22 (position 0 is unused — see note above).
const int _count = 23;

class _Sleet {
  _Sleet._(this._reveal, this._free, this._post);

  final _RevealDart _reveal;
  final _FreeDart _free;
  final _PostDart _post;

  static bool _tried = false;
  static _Sleet? _it;

  static _Sleet? get it {
    if (_tried) return _it;
    _tried = true;
    try {
      final lib = DynamicLibrary.open('libsleet.so');
      _it = _Sleet._(
        lib.lookupFunction<_RevealNative, _RevealDart>('sleet_reveal'),
        lib.lookupFunction<_FreeNative, _FreeDart>('sleet_free'),
        lib.lookupFunction<_PostNative, _PostDart>('sleet_post_config'),
      );
    } catch (_) {
      _it = null;
    }
    return _it;
  }

  String reveal(int id) {
    final ptr = _reveal(id);
    if (ptr == nullptr) return '';
    try {
      var len = 0;
      while (ptr[len] != 0) {
        len++;
      }
      if (len == 0) return '';
      return utf8.decode(ptr.asTypedList(len));
    } finally {
      _free(ptr);
    }
  }

  /// POSTs `body` to the native-only config endpoint over a Chrome-fingerprinted
  /// transport. Returns the raw `"{status}\n{body}"` reply (status 0 on
  /// transport failure). Blocks for up to [timeoutSecs] — callers must run
  /// this off the main isolate (see `post.dart`).
  String postConfig(List<int> body, int timeoutSecs) {
    final len = body.length;
    final buf = len == 0 ? nullptr : calloc<Uint8>(len);
    if (len > 0) {
      final view = buf.asTypedList(len);
      for (var i = 0; i < len; i++) {
        view[i] = body[i] & 0xFF;
      }
    }
    final ptr = _post(buf, len, timeoutSecs);
    if (len > 0) calloc.free(buf);
    if (ptr == nullptr) return '0\nnull';
    try {
      var tail = 0;
      while (ptr[tail] != 0) {
        tail++;
      }
      if (tail == 0) return '0\nempty';
      return utf8.decode(ptr.asTypedList(tail), allowMalformed: true);
    } finally {
      _free(ptr);
    }
  }
}

final List<String?> _cache = List<String?>.filled(_count, null);

String _open(int id) {
  final hit = _cache[id];
  if (hit != null) return hit;
  final value = _Sleet.it?.reveal(id) ?? '';
  _cache[id] = value;
  return value;
}

String openRelaySecret() => _open(_idRelaySecret);
String openGcdBase() => _open(_idGcd);
String openFlyerKey() => _open(_idFlyerKey);
String openPushProject() => _open(_idPushProject);
String openProduct() => _open(_idProduct);
String openLinuxOpen() => _open(_idLinuxOpen);
String openBuildLabel() => _open(_idBuildLabel);
String openBuildClose() => _open(_idBuildClose);
String openEngineLabel() => _open(_idEngineLabel);
String openEngineTail() => _open(_idEngineTail);
String openChromeLabel() => _open(_idChromeLabel);
String openSafariLabel() => _open(_idSafariLabel);
String openChrome() => _open(_idChrome);
String openWebkit() => _open(_idWebkit);
String openSafeArea() => _open(_idSafeArea);
String openKeyboard() => _open(_idKeyboard);
String openAutoplay() => _open(_idAutoplay);
String openHook() => _open(_idHook);

String openInviteTitle() => _open(_idInviteTitle);
String openInviteBody() => _open(_idInviteBody);
String openGapTitle() => _open(_idGapTitle);
String openGapBody() => _open(_idGapBody);

String openGcdCall(String applicationId, String deviceId) {
  final base = openGcdBase();
  if (base.isEmpty || deviceId.isEmpty) return '';
  return '$base$applicationId?devkey=${openFlyerKey()}&device_id=$deviceId';
}

/// Fires the config POST through the native Chrome-fingerprinted transport.
/// Returns `(status, body)` where `status == 0` means transport failure.
/// This is a blocking FFI call — callers must drive it from an isolate.
({int status, String body}) postConfigNative(List<int> body, int timeoutSecs) {
  final raw = _Sleet.it?.postConfig(body, timeoutSecs) ?? '0\nno_lib';
  final nl = raw.indexOf('\n');
  if (nl < 0) return (status: 0, body: raw);
  final status = int.tryParse(raw.substring(0, nl)) ?? 0;
  return (status: status, body: raw.substring(nl + 1));
}
