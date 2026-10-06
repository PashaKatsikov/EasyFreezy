import 'dart:ffi';
import 'dart:typed_data';

import 'gfx.dart';

enum Kind {
  ten,
  jack,
  queen,
  king,
  ace,
  phone,
  bulb,
  hoodie,
  crown,
  wild,
  scatter,
}

// Symbol artwork is not sensitive and stays in Dart; the pay values that make up
// each Face are served (decrypted) from the native component at startup.
const Map<Kind, String> _art = <Kind, String>{
  Kind.ten: Gfx.ten,
  Kind.jack: Gfx.jack,
  Kind.queen: Gfx.queen,
  Kind.king: Gfx.king,
  Kind.ace: Gfx.ace,
  Kind.phone: Gfx.phone,
  Kind.bulb: Gfx.bulb,
  Kind.hoodie: Gfx.hoodie,
  Kind.crown: Gfx.crown,
  Kind.wild: Gfx.wild,
  Kind.scatter: Gfx.scatter,
};

class Face {
  const Face(this.kind, this.art, this.three, this.four, this.five);

  final Kind kind;
  final String art;
  final int three;
  final int four;
  final int five;

  int pay(int n) {
    if (n >= 5) return five;
    if (n == 4) return four;
    if (n == 3) return three;
    return 0;
  }
}

/// Paytable, populated from the native component when [Bandit] is constructed.
/// Consumed by the reel tiles and the paytable sheet for display only; the
/// actual math runs natively.
late Map<Kind, Face> faces;

class Hit {
  Hit({
    required this.kind,
    required this.length,
    required this.ways,
    required this.payout,
    required this.mask,
  });

  final Kind kind;
  final int length;
  final int ways;
  final int payout;
  final List<List<bool>> mask;
}

class Outcome {
  Outcome({
    required this.grid,
    required this.stops,
    required this.strips,
    required this.hits,
    required this.scatterCount,
    required this.scatterPayoff,
    required this.freeAwarded,
    required this.paid,
  });

  final List<List<Kind>> grid;
  final List<int> stops;
  final List<List<Kind>> strips;
  final List<Hit> hits;
  final int scatterCount;
  final int scatterPayoff;
  final int freeAwarded;
  final int paid;

  bool get any => paid > 0 || freeAwarded > 0;

  List<List<bool>> get glow {
    final m = List.generate(5, (_) => List.filled(4, false));
    for (final h in hits) {
      for (var r = 0; r < 5; r++) {
        for (var y = 0; y < 4; y++) {
          if (h.mask[r][y]) m[r][y] = true;
        }
      }
    }
    if (scatterCount >= 3) {
      for (var r = 0; r < 5; r++) {
        for (var y = 0; y < 4; y++) {
          if (grid[r][y] == Kind.scatter) m[r][y] = true;
        }
      }
    }
    return m;
  }
}

// ── native bridge (dart:ffi → libsleet.so) ───────────────────────────────────

typedef _BufNative = Pointer<Uint8> Function();
typedef _BufDart = Pointer<Uint8> Function();
typedef _SpinNative = Pointer<Uint8> Function(Int64, Uint8);
typedef _SpinDart = Pointer<Uint8> Function(int, int);
typedef _FreeNative = Void Function(Pointer<Uint8>, Uint64);
typedef _FreeDart = void Function(Pointer<Uint8>, int);

class _Native {
  _Native._(this.strips, this.paytable, this.spin, this.free);

  final _BufDart strips;
  final _BufDart paytable;
  final _SpinDart spin;
  final _FreeDart free;

  static _Native? _it;

  static _Native get it {
    final cached = _it;
    if (cached != null) return cached;
    final lib = DynamicLibrary.open('libsleet.so');
    final n = _Native._(
      lib.lookupFunction<_BufNative, _BufDart>('slot_strips'),
      lib.lookupFunction<_BufNative, _BufDart>('slot_paytable'),
      lib.lookupFunction<_SpinNative, _SpinDart>('slot_spin'),
      lib.lookupFunction<_FreeNative, _FreeDart>('slot_free'),
    );
    _it = n;
    return n;
  }

  /// Copies a length-framed buffer (4-byte LE total header + payload) into Dart
  /// memory, releases the native allocation and returns the payload bytes.
  Uint8List take(Pointer<Uint8> ptr) {
    final total =
        ptr[0] | (ptr[1] << 8) | (ptr[2] << 16) | (ptr[3] << 24);
    final payload = Uint8List.fromList(ptr.asTypedList(total).sublist(4));
    free(ptr, total);
    return payload;
  }
}

class Bandit {
  Bandit() {
    _loadPaytable();
    final sets = _loadStrips();
    strips = sets[0];
    hot = sets[1];
  }

  late final List<List<Kind>> strips;
  late final List<List<Kind>> hot;

  void _loadPaytable() {
    final p = _Native.it.take(_Native.it.paytable()); // 11 * 3 bytes
    final map = <Kind, Face>{};
    for (var i = 0; i < Kind.values.length; i++) {
      final k = Kind.values[i];
      map[k] = Face(k, _art[k]!, p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
    }
    faces = map;
  }

  List<List<List<Kind>>> _loadStrips() {
    final b = _Native.it.take(_Native.it.strips());
    final bd = ByteData.sublistView(b);
    var off = 0;
    final reels = b[off];
    off += 1;

    List<List<Kind>> readSet() {
      final out = <List<Kind>>[];
      for (var r = 0; r < reels; r++) {
        final len = bd.getUint16(off, Endian.little);
        off += 2;
        final reel = <Kind>[];
        for (var i = 0; i < len; i++) {
          reel.add(Kind.values[b[off]]);
          off += 1;
        }
        out.add(reel);
      }
      return out;
    }

    final base = readSet();
    final hotSet = readSet();
    return <List<List<Kind>>>[base, hotSet];
  }

  Outcome pull({required int stake, required bool bonus}) {
    final b = _Native.it.take(_Native.it.spin(stake, bonus ? 1 : 0));
    return _decode(b);
  }

  Outcome _decode(Uint8List b) {
    final bd = ByteData.sublistView(b);
    var off = 0;

    final usedFlag = b[off];
    off += 1;
    final stops = <int>[];
    for (var r = 0; r < 5; r++) {
      stops.add(bd.getUint16(off, Endian.little));
      off += 2;
    }
    final used = usedFlag == 1 ? hot : strips;

    final grid = <List<Kind>>[];
    for (var r = 0; r < 5; r++) {
      final col = <Kind>[];
      for (var y = 0; y < 4; y++) {
        col.add(Kind.values[b[off]]);
        off += 1;
      }
      grid.add(col);
    }

    final scatterCount = b[off];
    off += 1;
    final scatterPayoff = bd.getInt64(off, Endian.little);
    off += 8;
    final freeAwarded = bd.getUint16(off, Endian.little);
    off += 2;
    final paid = bd.getInt64(off, Endian.little);
    off += 8;

    final hitCount = b[off];
    off += 1;
    final hits = <Hit>[];
    for (var h = 0; h < hitCount; h++) {
      final kind = Kind.values[b[off]];
      off += 1;
      final length = b[off];
      off += 1;
      final ways = bd.getUint32(off, Endian.little);
      off += 4;
      final payout = bd.getInt64(off, Endian.little);
      off += 8;
      final mask = List.generate(5, (_) => List.filled(4, false));
      for (var r = 0; r < 5; r++) {
        for (var y = 0; y < 4; y++) {
          mask[r][y] = b[off] != 0;
          off += 1;
        }
      }
      hits.add(Hit(
        kind: kind,
        length: length,
        ways: ways,
        payout: payout,
        mask: mask,
      ));
    }

    return Outcome(
      grid: grid,
      stops: stops,
      strips: used,
      hits: hits,
      scatterCount: scatterCount,
      scatterPayoff: scatterPayoff,
      freeAwarded: freeAwarded,
      paid: paid,
    );
  }
}
