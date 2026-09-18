import 'package:flutter/material.dart';

class Ice {
  Ice._();

  static const voidBg = Color(0xFF050814);
  static const cyan = Color(0xFF22E3FF);
  static const magenta = Color(0xFFFF2BD6);
  static const pink = Color(0xFFFF3BA0);
  static const gold = Color(0xFFFFD24A);
  static const cream = Color(0xFFF4FBFF);
  static const dim = Color(0xFF8FB4C8);
  static const panel = Color(0xE6101828);
}

String chips(int n) {
  final neg = n < 0;
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

TextStyle russo(double size, Color color, {double ls = 0.6, bool glow = false}) => TextStyle(
      fontFamily: 'Russo',
      fontSize: size,
      color: color,
      letterSpacing: ls,
      height: 1.1,
      decoration: TextDecoration.none,
      shadows: glow
          ? [Shadow(color: color.withValues(alpha: 0.55), blurRadius: size * 0.4)]
          : null,
    );

TextStyle barlow(
  double size,
  Color color, {
  FontWeight w = FontWeight.w600,
  double ls = 0.4,
}) =>
    TextStyle(
      fontFamily: 'Barlow',
      fontSize: size,
      fontWeight: w,
      color: color,
      letterSpacing: ls,
      height: 1.1,
      decoration: TextDecoration.none,
    );

String chipsShort(int n) {
  if (n.abs() >= 1000000) {
    final v = n / 1000000;
    final s = v >= 100 ? v.round().toString() : v.toStringAsFixed(v >= 10 ? 1 : 2);
    return '${s}M';
  }
  return chips(n);
}
