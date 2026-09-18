import 'package:flutter/material.dart';

import 'bank.dart';
import 'look.dart';
import 'machine.dart';

class DebugRack extends StatelessWidget {
  const DebugRack({
    super.key,
    required this.bank,
    required this.onBoot,
    required this.onLobby,
    required this.onTable,
    required this.onPrivacy,
    required this.onSupport,
    required this.onDaily,
    required this.onPay,
    required this.onSpin,
    required this.onClose,
  });

  final Bank bank;
  final VoidCallback onBoot;
  final VoidCallback onLobby;
  final VoidCallback onTable;
  final VoidCallback onPrivacy;
  final VoidCallback onSupport;
  final VoidCallback onDaily;
  final VoidCallback onPay;
  final void Function(ForcePull force) onSpin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF00B1522),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('TEST RACK', style: russo(22, Ice.cyan)),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Ice.cream),
                  ),
                ],
              ),
              Text('debug only  •  rotate the phone on Boot to check landscape',
                  style: barlow(13, Ice.dim)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    _sec('SCREENS'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _b('Boot (rotate OK)', onBoot),
                      _b('Lobby', onLobby),
                      _b('Table', onTable),
                      _b('Daily', onDaily),
                      _b('Paytable', onPay),
                      _b('Privacy', onPrivacy),
                      _b('Support', onSupport),
                    ]),
                    _sec('SPINS'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _b('Natural', () => onSpin(ForcePull.off)),
                      _b('Dead', () => onSpin(ForcePull.dead)),
                      _b('Big win', () => onSpin(ForcePull.big)),
                      _b('Mega win', () => onSpin(ForcePull.mega)),
                      _b('Scatters', () => onSpin(ForcePull.scatters)),
                    ]),
                    _sec('BANK'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _b('+50,000', () => bank.inject(50000)),
                      _b('Bankrupt', () => bank.inject(-bank.chips)),
                      _b('Reset save', () => bank.wipe()),
                    ]),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: bank,
                      builder: (context, _) => Text(
                        'chips ${chips(bank.chips)}   stake ${chips(bank.stake)}   free ${bank.freeLeft}/${bank.freeTotal}',
                        style: barlow(14, Ice.cream),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        child: Text(t, style: barlow(13, Ice.gold, w: FontWeight.w700, ls: 1.4)),
      );

  Widget _b(String t, VoidCallback tap) => FilledButton(
        onPressed: tap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF173044),
          foregroundColor: Ice.cream,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text(t, style: barlow(14, Ice.cream, w: FontWeight.w700)),
      );
}
