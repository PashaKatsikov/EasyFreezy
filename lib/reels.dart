import 'dart:math';

import 'package:flutter/material.dart';

import 'look.dart';
import 'machine.dart';

class ReelMotor {
  ReelMotor(this.len, this.pos);

  final int len;
  double pos;
  double vel = 0;
  bool spinning = false;
  int? landAt;
  double? halt;
  VoidCallback? onLand;
  bool _shot = false;

  void kick(double speed) {
    spinning = true;
    halt = null;
    landAt = null;
    _shot = false;
    vel = speed;
  }

  void aim(int index) {
    landAt = index;
    const minTravel = 5.0;
    var t = pos + minTravel;
    var delta = index - (t % len);
    if (delta < -0.01) delta += len;
    t += delta;
    if (t < pos + minTravel - 0.01) t += len;
    halt = t;
  }

  bool tick(double dt) {
    if (!spinning) return false;
    if (halt == null) {
      pos += vel * dt;
      return true;
    }
    final remain = halt! - pos;
    if (remain <= 0.04) {
      pos = (landAt ?? 0).toDouble();
      spinning = false;
      vel = 0;
      if (!_shot) {
        _shot = true;
        onLand?.call();
      }
      return true;
    }
    vel = max(2.8, remain / 0.42);
    pos += vel * dt;
    if (pos > halt!) pos = halt!;
    return true;
  }
}

class ReelColumn extends StatelessWidget {
  const ReelColumn({
    super.key,
    required this.strip,
    required this.head,
    required this.glow,
  });

  final List<Kind> strip;
  final double head;
  final List<bool> glow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cell = box.maxHeight / 4;
      final i0 = head.floor();
      final frac = head - i0;
      final len = strip.length;
      return ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var k = -1; k <= 4; k++)
              Positioned(
                top: (k - frac) * cell,
                left: 0,
                right: 0,
                height: cell,
                child: _Tile(
                  kind: strip[(i0 + k) % len],
                  lit: k >= 0 && k < 4 && glow[k],
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.kind, required this.lit});

  final Kind kind;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final special = kind == Kind.wild || kind == Kind.scatter;
    return AnimatedScale(
      scale: lit ? 1.08 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: lit
              ? [
                  BoxShadow(
                    color: (kind == Kind.scatter ? Ice.magenta : Ice.cyan).withValues(alpha: 0.85),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : special
                  ? [BoxShadow(color: Ice.gold.withValues(alpha: 0.25), blurRadius: 8)]
                  : null,
        ),
        child: Image.asset(
          faces[kind]!.art,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
