import 'package:flutter/material.dart';

import 'look.dart';

class Sky extends StatelessWidget {
  const Sky({super.key, required this.art, this.child});

  final String art;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(art, fit: BoxFit.cover, filterQuality: FilterQuality.high),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33050814), Color(0x00050814), Color(0x99050814)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}

class NeonPill extends StatelessWidget {
  const NeonPill({
    super.key,
    required this.label,
    required this.onTap,
    this.color = Ice.cyan,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(color, Colors.white, 0.18)!,
                color,
                Color.lerp(color, Colors.black, 0.35)!,
              ],
            ),
            border: Border.all(color: Colors.white24, width: 1.2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 16, spreadRadius: 1),
            ],
          ),
          child: Text(label, style: russo(height * 0.42, Ice.voidBg, ls: 1.2)),
        ),
      ),
    );
  }
}

class GhostBtn extends StatelessWidget {
  const GhostBtn({super.key, required this.label, required this.onTap, this.color = Ice.cyan});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Ice.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(label, style: barlow(14, color, w: FontWeight.w700, ls: 0.8)),
      ),
    );
  }
}

class ChipMeter extends StatelessWidget {
  const ChipMeter({super.key, required this.tag, required this.value, this.accent = Ice.gold, this.onTap});

  final String tag;
  final String value;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Ice.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tag, style: barlow(10, accent, w: FontWeight.w700, ls: 1.2)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, maxLines: 1, style: russo(15, Ice.cream, ls: 0.3)),
          ),
        ],
      ),
    );
    return onTap == null ? body : GestureDetector(onTap: onTap, child: body);
  }
}
