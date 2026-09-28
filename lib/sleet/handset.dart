import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import 'veil.dart';

class Handset {
  Handset._();

  static String _agent = '';

  static String get agent => _agent.isEmpty ? _fallback() : _agent;

  static Future<void> prime() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        _agent = _android(
          release: info.version.release,
          brand: _title(info.brand),
          model: info.model,
          buildTag: info.display.isNotEmpty ? info.display : info.id,
        );
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        _agent = _ios(info.systemVersion);
      }
    } catch (_) {
      _agent = _fallback();
    }
  }

  static String _android({
    required String release,
    required String brand,
    required String model,
    required String buildTag,
  }) {
    final chrome = _or(openChrome(), _chromeSeed);
    final webkit = _or(openWebkit(), _webkitSeed);
    return '${_or(openProduct(), _productSeed)} '
        '${_or(openLinuxOpen(), _linuxSeed)} $release; $brand $model'
        '${_or(openBuildLabel(), _buildSeed)}$buildTag'
        '${_or(openBuildClose(), _closeSeed)}'
        '${_or(openEngineLabel(), _engineSeed)}$webkit'
        '${_or(openEngineTail(), _tailSeed)}'
        '${_or(openChromeLabel(), _chromeLabelSeed)}$chrome'
        '${_or(openSafariLabel(), _safariSeed)}$webkit';
  }

  static String _ios(String version) {
    final cpu = version.replaceAll('.', '_');
    final webkit = _or(openWebkit(), _webkitSeed);
    final product = _or(openProduct(), _productSeed);
    final engine = _or(openEngineLabel(), _engineSeed);
    final tail = _or(openEngineTail(), _tailSeed);
    return '$product $_iosOpen$cpu$_iosClose$engine$webkit$tail$_iosVersion$version$_iosSafari$webkit';
  }

  static String _fallback() => _android(
        release: '14',
        brand: 'Google',
        model: 'Pixel 8',
        buildTag: 'UP1A.231005.007',
      );

  static String _or(String encoded, String seed) =>
      encoded.isNotEmpty ? encoded : seed;

  static String _title(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String get _productSeed =>
      String.fromCharCodes(const <int>[77, 111, 122, 105, 108, 108, 97, 47, 53, 46, 48]);
  static String get _linuxSeed => String.fromCharCodes(const <int>[
        40, 76, 105, 110, 117, 120, 59, 32, 65, 110, 100, 114, 111, 105, 100,
      ]);
  static String get _buildSeed =>
      String.fromCharCodes(const <int>[32, 66, 117, 105, 108, 100, 47]);
  static String get _closeSeed => String.fromCharCode(41);
  static String get _engineSeed => String.fromCharCodes(const <int>[
        32, 65, 112, 112, 108, 101, 87, 101, 98, 75, 105, 116, 47,
      ]);
  static String get _tailSeed => String.fromCharCodes(const <int>[
        32, 40, 75, 72, 84, 77, 76, 44, 32, 108, 105, 107, 101, 32, 71, 101, 99, 107, 111, 41,
      ]);
  static String get _chromeLabelSeed =>
      String.fromCharCodes(const <int>[32, 67, 104, 114, 111, 109, 101, 47]);
  static String get _safariSeed => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 32, 83, 97, 102, 97, 114, 105, 47,
      ]);
  static String get _chromeSeed => String.fromCharCodes(const <int>[
        49, 52, 57, 46, 48, 46, 55, 53, 51, 56, 46, 49, 52, 54,
      ]);
  static String get _webkitSeed =>
      String.fromCharCodes(const <int>[53, 51, 55, 46, 51, 54]);
  static String get _iosOpen => String.fromCharCodes(const <int>[
        40, 105, 80, 104, 111, 110, 101, 59, 32, 67, 80, 85, 32, 105, 80, 104,
        111, 110, 101, 32, 79, 83, 32,
      ]);
  static String get _iosClose => String.fromCharCodes(const <int>[
        32, 108, 105, 107, 101, 32, 77, 97, 99, 32, 79, 83, 32, 88, 41,
      ]);
  static String get _iosVersion =>
      String.fromCharCodes(const <int>[32, 86, 101, 114, 115, 105, 111, 110, 47]);
  static String get _iosSafari => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 47, 49, 53, 69, 49, 52, 56, 32, 83, 97, 102, 97, 114, 105, 47,
      ]);
}
