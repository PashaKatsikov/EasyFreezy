import 'dart:async';

import 'package:flutter/material.dart';

import 'bank.dart';
import 'chrome.dart';
import 'gfx.dart';
import 'look.dart';

class LobbyView extends StatefulWidget {
  const LobbyView({
    super.key,
    required this.bank,
    required this.onPlay,
    required this.onDaily,
    required this.onPay,
    required this.onPrivacy,
    required this.onSupport,
  });

  final Bank bank;
  final VoidCallback onPlay;
  final VoidCallback onDaily;
  final VoidCallback onPay;
  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  State<LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<LobbyView> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.bank.addListener(_bump);
    _tick = Timer.periodic(const Duration(milliseconds: 90), (_) {
      widget.bank.tickJack(1 + DateTime.now().millisecond % 4);
    });
  }

  void _bump() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.bank.removeListener(_bump);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bank;
    return Sky(
      art: Gfx.alley,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  ChipMeter(tag: 'CHIPS', value: chipsShort(b.chips), accent: Ice.gold),
                  const Spacer(),
                  ChipMeter(tag: 'JACKPOT', value: chipsShort(b.jackpot), accent: Ice.magenta),
                ],
              ),
              const Spacer(flex: 2),
              Flexible(
                flex: 9,
                child: Image.asset(Gfx.wordmark, fit: BoxFit.contain, filterQuality: FilterQuality.high),
              ),
              const Spacer(),
              NeonPill(label: 'PLAY', onTap: widget.onPlay, color: Ice.cyan, height: 58),
              const SizedBox(height: 12),
              NeonPill(
                label: b.dailyReady ? 'DAILY BONUS' : 'BONUS CLAIMED',
                onTap: b.dailyReady ? widget.onDaily : null,
                color: Ice.pink,
                height: 50,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GhostBtn(label: 'PAYTABLE', onTap: widget.onPay),
                  GhostBtn(label: 'SUPPORT', onTap: widget.onSupport, color: Ice.magenta),
                  GhostBtn(label: 'PRIVACY', onTap: widget.onPrivacy, color: Ice.gold),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '18+  SIMULATED GAMBLING  •  NO REAL MONEY',
                style: barlow(12, Ice.dim, ls: 1.1),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
