import 'dart:typed_data';

import 'package:easy_freezy/sleet/pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'test-secret-not-the-real-one';
  final body = <String, dynamic>{'af_status': 'Non-organic', 'n': 1};

  test('seal returns the unique envelope shape', () {
    final env = Pack.seal(body, secret);
    expect(env.keys.toSet(), <String>{'h', 'u', 'j', 'x'});
    expect(env['h'], 13);
    expect((env['u'] as String).length, 32); // 16-byte nonce as hex
    expect((env['x'] as String).length, 16); // truncated HMAC tag
    expect(env['j'], isNot(contains('='))); // base64url, no padding
  });

  test('empty secret yields no envelope', () {
    expect(Pack.seal(body, ''), isEmpty);
  });

  test('sealWithNonce is deterministic', () {
    final nonce =
        Uint8List.fromList(List<int>.generate(16, (i) => (i * 7) & 0xFF));
    final a = Pack.sealWithNonce(body, secret, nonce);
    final b = Pack.sealWithNonce(body, secret, nonce);
    expect(a, equals(b));
  });
}
