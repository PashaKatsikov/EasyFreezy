import 'package:flutter_test/flutter_test.dart';

import 'package:easy_freezy/look.dart';
import 'package:easy_freezy/machine.dart';

void main() {
  test('chip formatter groups thousands', () {
    expect(chips(0), '0');
    expect(chips(25000), '25,000');
    expect(chips(8450000), '8,450,000');
  });

  test('three crowns from the left pay', () {
    final strips = [
      [Kind.crown, Kind.ten, Kind.jack, Kind.queen],
      [Kind.crown, Kind.ten, Kind.jack, Kind.queen],
      [Kind.crown, Kind.ten, Kind.jack, Kind.queen],
      [Kind.ten, Kind.jack, Kind.queen, Kind.king],
      [Kind.ten, Kind.jack, Kind.queen, Kind.king],
    ];
    final out = Bandit.read(strips, [0, 0, 0, 0, 0], 100, false);
    expect(out.hits.any((h) => h.kind == Kind.crown && h.length == 3), isTrue);
    expect(out.paid, greaterThan(0));
  });

  test('forced dead grid never pays', () {
    final strips = [
      [Kind.ten, Kind.jack, Kind.queen, Kind.king],
      [Kind.ace, Kind.phone, Kind.bulb, Kind.hoodie],
      [Kind.ten, Kind.jack, Kind.queen, Kind.king],
      [Kind.ace, Kind.phone, Kind.bulb, Kind.hoodie],
      [Kind.ten, Kind.jack, Kind.queen, Kind.king],
    ];
    final out = Bandit.read(strips, [0, 0, 0, 0, 0], 500, false);
    expect(out.paid, 0);
    expect(out.freeAwarded, 0);
    expect(out.hits, isEmpty);
  });

  test('three scatters award free spins', () {
    final strips = [
      [Kind.scatter, Kind.ten, Kind.jack, Kind.queen],
      [Kind.scatter, Kind.ten, Kind.jack, Kind.queen],
      [Kind.scatter, Kind.ten, Kind.jack, Kind.queen],
      [Kind.ten, Kind.jack, Kind.queen, Kind.king],
      [Kind.ten, Kind.jack, Kind.queen, Kind.king],
    ];
    final out = Bandit.read(strips, [0, 0, 0, 0, 0], 100, false);
    expect(out.scatterCount, 3);
    expect(out.freeAwarded, 8);
  });
}
