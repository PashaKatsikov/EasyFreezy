import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'bank.dart';
import 'chrome.dart';
import 'look.dart';
import 'machine.dart';

enum WinGrade { none, hit, big, mega, epic }

WinGrade gradeFor(int paid, int stake) {
  if (paid <= 0) return WinGrade.none;
  final x = paid / stake;
  if (x >= 50) return WinGrade.epic;
  if (x >= 20) return WinGrade.mega;
  if (x >= 8) return WinGrade.big;
  return WinGrade.hit;
}

class WinSplash extends StatefulWidget {
  const WinSplash({
    super.key,
    required this.paid,
    required this.grade,
    required this.free,
    required this.onCollect,
  });

  final int paid;
  final WinGrade grade;
  final int free;
  final VoidCallback onCollect;

  @override
  State<WinSplash> createState() => _WinSplashState();
}

class _WinSplashState extends State<WinSplash> {
  int _shown = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    final target = widget.paid;
    if (target <= 0) return;
    final steps = 28;
    var i = 0;
    _t = Timer.periodic(const Duration(milliseconds: 32), (t) {
      i++;
      final u = (i / steps).clamp(0.0, 1.0);
      final eased = 1 - pow(1 - u, 3).toDouble();
      setState(() => _shown = (target * eased).round());
      if (u >= 1) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.paid <= 0 && widget.free > 0
        ? 'FREE SPINS'
        : switch (widget.grade) {
            WinGrade.epic => 'EPIC WIN!',
            WinGrade.mega => 'MEGA WIN!',
            WinGrade.big => 'BIG WIN!',
            WinGrade.hit => 'YOU WIN',
            WinGrade.none => 'FREE SPINS',
          };
    final color = switch (widget.grade) {
      WinGrade.epic => Ice.gold,
      WinGrade.mega => Ice.magenta,
      WinGrade.big => Ice.cyan,
      _ => Ice.cream,
    };

    return GestureDetector(
      onTap: widget.onCollect,
      child: ColoredBox(
        color: const Color(0xCC050814),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
          Text(title, style: russo(42, color, ls: 1.4, glow: true), textAlign: TextAlign.center),
                if (widget.paid > 0) ...[
                  const SizedBox(height: 8),
                  Text(chips(_shown), style: russo(48, Ice.cream, ls: 1)),
                ],
                if (widget.free > 0) ...[
                  const SizedBox(height: 10),
                  Text('+${widget.free} FREE SPINS', style: russo(22, Ice.cyan)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: 220,
                  child: NeonPill(label: 'COLLECT', onTap: widget.onCollect, color: Ice.pink),
                ),
                const SizedBox(height: 8),
                Text('TAP ANYWHERE', style: barlow(13, Ice.dim, ls: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DailyBoard extends StatelessWidget {
  const DailyBoard({super.key, required this.bank, required this.onClose});

  final Bank bank;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ready = bank.dailyReady;
    final mark = bank.dailyIndex;
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xCC050814),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xF0121A2A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Ice.magenta.withValues(alpha: 0.7), width: 1.4),
                boxShadow: const [BoxShadow(color: Ice.magenta, blurRadius: 24, spreadRadius: -4)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DAILY BONUS', style: russo(28, Ice.magenta, ls: 1.2)),
                  const SizedBox(height: 6),
                  Text('Come back every day. Miss a day and the streak resets.',
                      style: barlow(14, Ice.dim), textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < 7; i++)
                        _DayCell(
                          day: i + 1,
                          pay: Bank.daily[i],
                          now: i == mark,
                          done: !ready && i == mark,
                          locked: i > mark,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  NeonPill(
                    label: ready ? 'CLAIM' : 'COME BACK TOMORROW',
                    onTap: ready
                        ? () {
                            bank.claimDaily();
                            onClose();
                          }
                        : onClose,
                    color: Ice.gold,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.pay,
    required this.now,
    required this.done,
    required this.locked,
  });

  final int day;
  final int pay;
  final bool now;
  final bool done;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = done
        ? Ice.cyan
        : now
            ? Ice.gold
            : Ice.dim;
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1422),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c, width: now ? 1.6 : 1),
      ),
      child: Column(
        children: [
          Text('DAY $day', style: barlow(12, c, w: FontWeight.w700, ls: 1)),
          Text(chips(pay), style: russo(14, Ice.cream)),
        ],
      ),
    );
  }
}

class PaySheet extends StatelessWidget {
  const PaySheet({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xCC050814),
        child: Center(
          child: GestureDetector(
            onTap: () {},
              child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              height: MediaQuery.sizeOf(context).height * 0.72,
              decoration: BoxDecoration(
                color: const Color(0xF0121A2A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Ice.cyan.withValues(alpha: 0.65)),
              ),
              child: Column(
                children: [
                  Text('PAYTABLE', style: russo(26, Ice.cyan)),
                  const SizedBox(height: 4),
                  Text('5 reels • 4 rows • 1024 ways  •  left to right',
                      style: barlow(13, Ice.dim), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Scatter anywhere: 3 = 8 free spins, 4 = 12, 5 = 20.',
                      style: barlow(13, Ice.magenta), textAlign: TextAlign.center),
                  Text('Wild substitutes every symbol except Scatter.',
                      style: barlow(13, Ice.gold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final k in Kind.values)
                          if (k != Kind.scatter) _PayRow(face: faces[k]!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  NeonPill(label: 'CLOSE', onTap: onClose, height: 46),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.face});

  final Face face;

  static String _x(int t) => t % 10 == 0 ? '${t ~/ 10}' : '${t / 10}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Image.asset(face.art, width: 40, height: 40, filterQuality: FilterQuality.high),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '3x ${_x(face.three)}    4x ${_x(face.four)}    5x ${_x(face.five)}',
              style: barlow(16, Ice.cream),
            ),
          ),
        ],
      ),
    );
  }
}

class BrokeSheet extends StatelessWidget {
  const BrokeSheet({super.key, required this.drop, required this.onClose});

  final int drop;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xCC050814),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(drop > 0 ? 'BANK DROP' : 'ICE COLD', style: russo(32, Ice.cyan)),
                const SizedBox(height: 8),
                Text(
                  drop > 0
                      ? 'House chips in. +${chips(drop)}'
                      : 'Daily drop is spent. Grab the daily bonus or come back later.',
                  style: barlow(16, Ice.cream),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(width: 200, child: NeonPill(label: 'OK', onTap: onClose)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BonusPaid extends StatelessWidget {
  const BonusPaid({super.key, required this.amount, required this.onClose});

  final int amount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xCC050814),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('FREE SPINS PAID', style: russo(28, Ice.gold)),
              const SizedBox(height: 8),
              Text(chips(amount), style: russo(44, Ice.cream)),
              const SizedBox(height: 18),
              SizedBox(width: 220, child: NeonPill(label: 'COLLECT', onTap: onClose, color: Ice.gold)),
            ],
          ),
        ),
      ),
    );
  }
}
