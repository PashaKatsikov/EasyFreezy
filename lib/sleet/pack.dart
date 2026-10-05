import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Veil envelope packer for the attribution relay.
///
/// The clean attribution body is sealed into an opaque envelope that only the
/// edge relay (which shares [secret]) can open:
///
///   keystream = sha256(secret + nonce + counterBE32) blocks
///   enc       = raw XOR keystream
///   payload   = base64url(enc) without padding
///   tag       = hmacSha256(secret, nonce + enc).hex()[:16]
///   envelope  = { _schema: _rev, _nonce: nonceHex, _payload: payload, _tag: tag }
///
/// Field names and schema revision are unique to this app (see the deploy
/// registry). SHA-256 / HMAC are implemented here to avoid a shared crypto
/// dependency fingerprint.
abstract final class Pack {
  // Per-app wire contract — must match the relay's FIELD_*/SCHEMA_REV.
  static const String _schema = 'h';
  static const String _nonce = 'u';
  static const String _payload = 'j';
  static const String _tag = 'x';
  static const int _rev = 13;

  static final Random _rng = Random.secure();

  /// Seals [body] into the envelope map. Returns an empty map when [secret]
  /// is blank (caller treats that as a non-recoverable configuration miss).
  static Map<String, dynamic> seal(Map<String, dynamic> body, String secret) {
    if (secret.isEmpty) return const <String, dynamic>{};
    final nonce = Uint8List(16);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = _rng.nextInt(256);
    }
    return sealWithNonce(body, secret, nonce);
  }

  /// Deterministic variant used by tests / cross-language verification.
  static Map<String, dynamic> sealWithNonce(
    Map<String, dynamic> body,
    String secret,
    Uint8List nonce,
  ) {
    if (secret.isEmpty) return const <String, dynamic>{};
    final key = Uint8List.fromList(utf8.encode(secret));
    final raw = Uint8List.fromList(utf8.encode(jsonEncode(body)));
    final enc = Uint8List(raw.length);
    final stream = _keystream(key, nonce, raw.length);
    for (var i = 0; i < raw.length; i++) {
      enc[i] = raw[i] ^ stream[i];
    }
    final nonceEnc = Uint8List(nonce.length + enc.length)
      ..setRange(0, nonce.length, nonce)
      ..setRange(nonce.length, nonce.length + enc.length, enc);
    final tag = _hex(_hmacSha256(key, nonceEnc)).substring(0, 16);
    return <String, dynamic>{
      _schema: _rev,
      _nonce: _hex(nonce),
      _payload: base64Url.encode(enc).replaceAll('=', ''),
      _tag: tag,
    };
  }

  static Uint8List _keystream(Uint8List secret, Uint8List nonce, int length) {
    final out = Uint8List(length);
    var filled = 0;
    var counter = 0;
    while (filled < length) {
      final block = Uint8List(secret.length + nonce.length + 4)
        ..setRange(0, secret.length, secret)
        ..setRange(secret.length, secret.length + nonce.length, nonce);
      final base = secret.length + nonce.length;
      block[base] = (counter >> 24) & 0xFF;
      block[base + 1] = (counter >> 16) & 0xFF;
      block[base + 2] = (counter >> 8) & 0xFF;
      block[base + 3] = counter & 0xFF;
      final digest = _sha256(block);
      final take = (length - filled) < 32 ? (length - filled) : 32;
      out.setRange(filled, filled + take, digest);
      filled += take;
      counter++;
    }
    return out;
  }

  // ── SHA-256 ────────────────────────────────────────────────────────────
  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) =>
      ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

  static Uint8List _sha256(Uint8List message) {
    final h = <int>[
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];
    final bitLen = message.length * 8;
    final padLen = ((message.length + 8) ~/ 64 + 1) * 64;
    final data = Uint8List(padLen)..setRange(0, message.length, message);
    data[message.length] = 0x80;
    for (var i = 0; i < 8; i++) {
      data[padLen - 1 - i] = (bitLen >> (8 * i)) & 0xFF;
    }
    final w = Int32List(64);
    for (var chunk = 0; chunk < padLen; chunk += 64) {
      for (var i = 0; i < 16; i++) {
        final j = chunk + i * 4;
        w[i] = (data[j] << 24) |
            (data[j + 1] << 16) |
            (data[j + 2] << 8) |
            data[j + 3];
      }
      for (var i = 16; i < 64; i++) {
        final x = w[i - 15] & 0xFFFFFFFF;
        final y = w[i - 2] & 0xFFFFFFFF;
        final s0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);
        final s1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }
      var a = h[0], b = h[1], c = h[2], d = h[3];
      var e = h[4], f = h[5], g = h[6], hh = h[7];
      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final t1 = (hh + s1 + ch + _k[i] + (w[i] & 0xFFFFFFFF)) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final t2 = (s0 + maj) & 0xFFFFFFFF;
        hh = g;
        g = f;
        f = e;
        e = (d + t1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xFFFFFFFF;
      }
      h[0] = (h[0] + a) & 0xFFFFFFFF;
      h[1] = (h[1] + b) & 0xFFFFFFFF;
      h[2] = (h[2] + c) & 0xFFFFFFFF;
      h[3] = (h[3] + d) & 0xFFFFFFFF;
      h[4] = (h[4] + e) & 0xFFFFFFFF;
      h[5] = (h[5] + f) & 0xFFFFFFFF;
      h[6] = (h[6] + g) & 0xFFFFFFFF;
      h[7] = (h[7] + hh) & 0xFFFFFFFF;
    }
    final out = Uint8List(32);
    for (var i = 0; i < 8; i++) {
      out[i * 4] = (h[i] >> 24) & 0xFF;
      out[i * 4 + 1] = (h[i] >> 16) & 0xFF;
      out[i * 4 + 2] = (h[i] >> 8) & 0xFF;
      out[i * 4 + 3] = h[i] & 0xFF;
    }
    return out;
  }

  static Uint8List _hmacSha256(Uint8List key, Uint8List message) {
    var block = key;
    if (block.length > 64) block = _sha256(block);
    final padded = Uint8List(64)..setRange(0, block.length, block);
    final inner = Uint8List(64 + message.length);
    final outer = Uint8List(64 + 32);
    for (var i = 0; i < 64; i++) {
      inner[i] = padded[i] ^ 0x36;
      outer[i] = padded[i] ^ 0x5c;
    }
    inner.setRange(64, 64 + message.length, message);
    outer.setRange(64, 64 + 32, _sha256(inner));
    return _sha256(outer);
  }

  static const String _hexAlphabet = '0123456789abcdef';

  static String _hex(Uint8List bytes) {
    final buf = StringBuffer();
    for (final b in bytes) {
      buf.write(_hexAlphabet[(b >> 4) & 0xF]);
      buf.write(_hexAlphabet[b & 0xF]);
    }
    return buf.toString();
  }
}
