import 'package:flutter/material.dart';

import '../look.dart';

class IcePill extends StatelessWidget {
  const IcePill({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.filled = true,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: land ? 42 : 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: filled
              ? const LinearGradient(colors: <Color>[Ice.cyan, Ice.magenta])
              : null,
          color: filled ? null : const Color(0xCC071018),
          border: Border.all(color: Ice.cyan.withValues(alpha: 0.85), width: 1.4),
          boxShadow: filled
              ? const <BoxShadow>[BoxShadow(color: Color(0x6622E3FF), blurRadius: 12)]
              : null,
        ),
        child: Text(label, style: russo(land ? 16 : 18, filled ? Ice.voidBg : Ice.cream, ls: 1.1)),
      ),
    );
  }
}
