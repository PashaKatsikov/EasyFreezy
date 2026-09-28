import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'book.dart';
import 'slip.dart';

const String _prefix = 'n6w_';

class Shelf {
  Shelf({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _route = '${_prefix}lane';
  static const String _url = '${_prefix}pl';
  static const String _until = '${_prefix}pl_at';
  static const String _snooze = '${_prefix}ask_at';
  static const String _granted = '${_prefix}ask_ok';
  static const String _blocked = '${_prefix}ask_no';
  static const String _pending = '${_prefix}hold';
  static const String _seen = '${_prefix}seen';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> prime() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Mark get mark => Mark.read(_prefs.getString(_route));

  Future<void> saveMark(Mark value) => _prefs.setString(_route, value.token);

  Future<String?> cachedUrl() => _secure.read(key: _url);

  Future<void> rememberUrl(String url, int? expiresUnix) async {
    await _secure.write(key: _url, value: url);
    final until = expiresUnix ?? _now() + Book.cacheSeconds;
    await _prefs.setInt(_until, until);
  }

  bool get cacheStale {
    final until = _prefs.getInt(_until);
    if (until == null) return true;
    return _now() >= until;
  }

  bool get permissionGranted => _prefs.getBool(_granted) ?? false;

  Future<void> markGranted(bool value) => _prefs.setBool(_granted, value);

  bool get permissionBlocked => _prefs.getBool(_blocked) ?? false;

  Future<void> markBlocked() => _prefs.setBool(_blocked, true);

  Future<void> snoozeUntil(int unixSeconds) =>
      _prefs.setInt(_snooze, unixSeconds);

  bool get shouldAsk {
    if (permissionGranted || permissionBlocked) return false;
    final until = _prefs.getInt(_snooze);
    if (until == null) return true;
    return _now() >= until;
  }

  Future<void> stashPending(String? url) async {
    if (url == null || url.isEmpty) {
      await _secure.delete(key: _pending);
    } else {
      await _secure.write(key: _pending, value: url);
    }
  }

  Future<String?> takePending() async {
    final url = await _secure.read(key: _pending);
    if (url != null) await _secure.delete(key: _pending);
    return url;
  }

  bool alreadyOpened(String id) => _prefs.getString(_seen) == id;

  Future<void> rememberOpened(String id) => _prefs.setString(_seen, id);

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
