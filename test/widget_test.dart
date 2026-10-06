import 'package:flutter_test/flutter_test.dart';

import 'package:easy_freezy/look.dart';
import 'package:easy_freezy/machine.dart';

// The slot math (strips, RNG, paytable, payout evaluation) now lives in the
// native Rust component (rust/src/slot.rs) and is covered by `cargo test` there,
// since it cannot run on the host without libsleet.so. These tests only cover
// pure-Dart helpers.
void main() {
  test('chip formatter groups thousands', () {
    expect(chips(0), '0');
    expect(chips(25000), '25,000');
    expect(chips(8450000), '8,450,000');
  });

  test('Face.pay picks the right tier by match length', () {
    const f = Face(Kind.crown, '', 15, 40, 100);
    expect(f.pay(2), 0);
    expect(f.pay(3), 15);
    expect(f.pay(4), 40);
    expect(f.pay(5), 100);
    expect(f.pay(6), 100); // 5+ caps at the five-of-a-kind tier
  });

  test('Kind enum order matches the native symbol ids', () {
    // slot.rs encodes wild=9, scatter=10; Dart decodes via Kind.values[id].
    expect(Kind.values.length, 11);
    expect(Kind.wild.index, 9);
    expect(Kind.scatter.index, 10);
  });
}
