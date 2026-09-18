import 'dart:math';

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

const faces = <Kind, Face>{
  Kind.ten: Face(Kind.ten, Gfx.ten, 2, 6, 16),
  Kind.jack: Face(Kind.jack, Gfx.jack, 2, 6, 16),
  Kind.queen: Face(Kind.queen, Gfx.queen, 3, 8, 20),
  Kind.king: Face(Kind.king, Gfx.king, 3, 8, 20),
  Kind.ace: Face(Kind.ace, Gfx.ace, 4, 10, 25),
  Kind.phone: Face(Kind.phone, Gfx.phone, 5, 14, 35),
  Kind.bulb: Face(Kind.bulb, Gfx.bulb, 6, 18, 45),
  Kind.hoodie: Face(Kind.hoodie, Gfx.hoodie, 8, 25, 60),
  Kind.crown: Face(Kind.crown, Gfx.crown, 15, 40, 100),
  Kind.wild: Face(Kind.wild, Gfx.wild, 20, 60, 200),
  Kind.scatter: Face(Kind.scatter, Gfx.scatter, 0, 0, 0),
};

const scatterPay = <int, int>{3: 20, 4: 80, 5: 250};
const scatterFree = <int, int>{3: 8, 4: 12, 5: 20};

enum ForcePull { off, dead, big, mega, scatters }

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

class Bandit {
  Bandit([Random? rng]) : rng = rng ?? Random();

  final Random rng;
  ForcePull force = ForcePull.off;

  late final strips = <List<Kind>>[
    _weave(0, wilds: 1, scatters: 1),
    _weave(1, wilds: 2, scatters: 1),
    _weave(2, wilds: 2, scatters: 2),
    _weave(3, wilds: 2, scatters: 1),
    _weave(4, wilds: 1, scatters: 1),
  ];

  late final hot = <List<Kind>>[
    _weave(10, wilds: 3, scatters: 1, lean: true),
    _weave(11, wilds: 4, scatters: 1, lean: true),
    _weave(12, wilds: 4, scatters: 2, lean: true),
    _weave(13, wilds: 4, scatters: 1, lean: true),
    _weave(14, wilds: 3, scatters: 1, lean: true),
  ];

  List<Kind> _weave(int seed, {required int wilds, required int scatters, bool lean = false}) {
    final bag = <Kind>[
      ...List.filled(lean ? 3 : 5, Kind.ten),
      ...List.filled(lean ? 3 : 5, Kind.jack),
      ...List.filled(lean ? 3 : 4, Kind.queen),
      ...List.filled(lean ? 3 : 4, Kind.king),
      ...List.filled(3, Kind.ace),
      ...List.filled(3, Kind.phone),
      ...List.filled(2, Kind.bulb),
      ...List.filled(lean ? 3 : 2, Kind.hoodie),
      ...List.filled(lean ? 3 : 2, Kind.crown),
      ...List.filled(wilds, Kind.wild),
      ...List.filled(scatters, Kind.scatter),
    ];
    bag.shuffle(Random(seed * 97 + 13));
    return bag;
  }

  Outcome pull({required int stake, required bool bonus}) {
    final used = bonus ? hot : strips;
    late final List<List<Kind>> src;
    late final List<int> stops;
    switch (force) {
      case ForcePull.off:
        src = used;
        stops = [for (final s in used) rng.nextInt(s.length)];
      case ForcePull.dead:
        // Reel 0 and reel 1 use disjoint symbol sets (no wild, no scatter),
        // so no kind can ever chain past length 1 from the leftmost reel.
        // What sits on reels 2-4 is irrelevant to the payout once that's true.
        src = [
          [Kind.ten, Kind.jack, Kind.queen, Kind.king],
          [Kind.ace, Kind.phone, Kind.bulb, Kind.hoodie],
          [Kind.ten, Kind.jack, Kind.queen, Kind.king],
          [Kind.ace, Kind.phone, Kind.bulb, Kind.hoodie],
          [Kind.ten, Kind.jack, Kind.queen, Kind.king],
        ];
        stops = [0, 0, 0, 0, 0];
      case ForcePull.big:
        src = [
          for (var i = 0; i < 5; i++) [Kind.crown, Kind.ten, Kind.jack, Kind.queen],
        ];
        stops = [0, 0, 0, 0, 0];
      case ForcePull.mega:
        src = [for (var i = 0; i < 5; i++) List.filled(4, Kind.crown)];
        stops = [0, 0, 0, 0, 0];
      case ForcePull.scatters:
        src = [
          [Kind.scatter, Kind.ten, Kind.jack, Kind.queen],
          [Kind.scatter, Kind.ten, Kind.jack, Kind.queen],
          [Kind.scatter, Kind.ten, Kind.jack, Kind.queen],
          [Kind.ten, Kind.jack, Kind.queen, Kind.king],
          [Kind.ten, Kind.jack, Kind.queen, Kind.king],
        ];
        stops = [0, 0, 0, 0, 0];
    }
    force = ForcePull.off;
    return read(src, stops, stake, bonus);
  }

  static Outcome read(List<List<Kind>> used, List<int> stops, int stake, bool bonus) {
    final grid = <List<Kind>>[
      for (var r = 0; r < 5; r++)
        [for (var y = 0; y < 4; y++) used[r][(stops[r] + y) % used[r].length]],
    ];

    final hits = <Hit>[];
    for (final kind in Kind.values) {
      if (kind == Kind.scatter) continue;
      final mask = List.generate(5, (_) => List.filled(4, false));
      var length = 0;
      var ways = 1;
      for (var r = 0; r < 5; r++) {
        var n = 0;
        for (var y = 0; y < 4; y++) {
          final cell = grid[r][y];
          final ok = kind == Kind.wild ? cell == Kind.wild : cell == kind || cell == Kind.wild;
          if (ok) {
            n++;
            mask[r][y] = true;
          }
        }
        if (n == 0) break;
        ways *= n;
        length++;
      }
      final unit = faces[kind]!.pay(length);
      if (unit > 0) {
        hits.add(Hit(
          kind: kind,
          length: length,
          ways: ways,
          payout: stake * unit * ways ~/ 10,
          mask: mask,
        ));
      }
    }

    var scatters = 0;
    for (final col in grid) {
      for (final c in col) {
        if (c == Kind.scatter) scatters++;
      }
    }
    final sPay = stake * (scatterPay[scatters] ?? 0) ~/ 10;
    var free = scatterFree[scatters] ?? 0;
    if (bonus && free > 0) free = 5;

    final paid = hits.fold<int>(0, (a, h) => a + h.payout) + sPay;
    return Outcome(
      grid: grid,
      stops: stops,
      strips: used,
      hits: hits,
      scatterCount: scatters,
      scatterPayoff: sPay,
      freeAwarded: free,
      paid: paid,
    );
  }
}
