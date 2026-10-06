import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'bank.dart';
import 'banners.dart';
import 'chrome.dart';
import 'gfx.dart';
import 'look.dart';
import 'machine.dart';
import 'reels.dart';

class FloorView extends StatefulWidget {
  const FloorView({
    super.key,
    required this.bank,
    required this.bandit,
    required this.onLobby,
    required this.onPrivacy,
    required this.onSupport,
  });

  final Bank bank;
  final Bandit bandit;
  final VoidCallback onLobby;
  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  State<FloorView> createState() => FloorViewState();
}

class FloorViewState extends State<FloorView> with SingleTickerProviderStateMixin {
  late final List<ReelMotor> _motors;
  late final Ticker _ticker;
  Duration? _prev;

  Outcome? _last;
  List<List<bool>> _glow = List.generate(5, (_) => List.filled(4, false));
  late List<List<Kind>> _live;
  bool _busy = false;
  int _spinGen = 0;
  int _landed = 0;
  String _line = 'GOOD LUCK';
  WinGrade _grade = WinGrade.none;
  _Layer _layer = _Layer.none;
  int _brokeDrop = 0;
  int _bonusDump = 0;
  bool _menu = false;

  Bank get _bank => widget.bank;
  Bandit get _bandit => widget.bandit;

  @override
  void initState() {
    super.initState();
    _motors = [
      for (var i = 0; i < 5; i++) ReelMotor(_bandit.strips[i].length, 0),
    ];
    _live = _bandit.strips;
    for (final m in _motors) {
      m.onLand = _onLand;
    }
    _ticker = createTicker(_tick)..start();
    _bank.addListener(_bump);
  }

  void _bump() {
    if (mounted) setState(() {});
  }

  void _tick(Duration elapsed) {
    final dt = _prev == null ? 1 / 60 : (elapsed - _prev!).inMicroseconds / 1e6;
    _prev = elapsed;
    if (!_busy) return;
    var moved = false;
    for (final m in _motors) {
      if (m.tick(dt.clamp(0.0, 0.05))) moved = true;
    }
    if (moved && mounted) setState(() {});
  }

  void _onLand() {
    HapticFeedback.selectionClick();
    _landed++;
    if (_landed >= 5) _settle();
  }

  Future<void> pull() async {
    if (_busy || _layer != _Layer.none) return;
    if (!_bank.canSpin) {
      _brokeDrop = _bank.refill();
      setState(() => _layer = _Layer.broke);
      return;
    }
    _bank.takeStake();
    final out = _bandit.pull(stake: _bank.stake, bonus: _bank.freeTotal > 0);
    _last = out;
    _live = out.strips;
    _glow = List.generate(5, (_) => List.filled(4, false));
    _busy = true;
    _landed = 0;
    final gen = ++_spinGen;
    _line = _bank.freeTotal > 0 ? 'FREE LEFT  ${_bank.freeLeft}' : 'SPINNING';

    for (var i = 0; i < 5; i++) {
      final prev = _motors[i].pos;
      final len = out.strips[i].length;
      _motors[i] = ReelMotor(len, prev % len)
        ..onLand = _onLand
        ..kick(24 + i * 1.6);
    }
    setState(() {});

    for (var i = 0; i < 5; i++) {
      Future<void>.delayed(Duration(milliseconds: 820 + i * 220), () {
        if (!mounted || gen != _spinGen) return;
        _motors[i].aim(out.stops[i]);
      });
    }
  }

  void _settle() {
    final out = _last!;
    _busy = false;
    _glow = out.glow;
    _grade = gradeFor(out.paid, _bank.stake);
    if (out.paid > 0) {
      HapticFeedback.mediumImpact();
      _line = '${_gradeLabel(_grade)}  ${chips(out.paid)}';
    } else if (out.freeAwarded > 0) {
      _line = '+${out.freeAwarded} FREE SPINS';
    } else {
      _line = 'NO WIN';
    }

    final splash = _grade.index >= WinGrade.big.index || out.freeAwarded > 0;
    if (out.paid > 0 && !splash) _bank.credit(out.paid);
    if (out.freeAwarded > 0) _bank.grantFree(out.freeAwarded);

    final bonusOver = _bank.freeTotal > 0 && _bank.freeLeft == 0;
    if (splash) {
      setState(() => _layer = _Layer.win);
      return;
    }
    if (bonusOver) {
      _finishBonus();
      return;
    }
    setState(() {});
    _maybeAuto();
  }

  String _gradeLabel(WinGrade g) => switch (g) {
        WinGrade.epic => 'EPIC WIN',
        WinGrade.mega => 'MEGA WIN',
        WinGrade.big => 'BIG WIN',
        WinGrade.hit => 'WIN',
        WinGrade.none => '',
      };

  void _collectWin() {
    if (_layer != _Layer.win) return;
    final out = _last;
    if (out != null && out.paid > 0) _bank.credit(out.paid);
    setState(() => _layer = _Layer.none);
    if (_bank.freeTotal > 0 && _bank.freeLeft == 0) {
      _finishBonus();
      return;
    }
    _maybeAuto();
  }

  void _finishBonus() {
    _bonusDump = _bank.closeBonus();
    setState(() => _layer = _Layer.bonus);
  }

  void _maybeAuto() {
    if (!_bank.auto || _layer != _Layer.none || _busy) return;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _bank.auto && !_busy && _layer == _Layer.none) pull();
    });
  }

  void showDaily() => setState(() => _layer = _Layer.daily);
  void showPay() => setState(() => _layer = _Layer.pay);

  @override
  void dispose() {
    _ticker.dispose();
    _bank.removeListener(_bump);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _bank;

    return Sky(
      art: Gfx.brick,
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _Hud(
                  bank: b,
                  onBack: widget.onLobby,
                  onMenu: () => setState(() => _menu = !_menu),
                ),
                Expanded(child: Center(child: _Board(
                  motors: _motors,
                  strips: _live,
                  glow: _glow,
                ))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_line, style: russo(18, Ice.gold), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 6),
                _Controls(
                  bank: b,
                  busy: _busy,
                  onMinus: () => b.bumpStake(-1),
                  onPlus: () => b.bumpStake(1),
                  onSpin: () => pull(),
                  onAuto: () {
                    b.auto = !b.auto;
                    setState(() {});
                    if (b.auto) pull();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (_menu) _Menu(
            onClose: () => setState(() => _menu = false),
            onPay: () {
              setState(() {
                _menu = false;
                _layer = _Layer.pay;
              });
            },
            onDaily: () {
              setState(() {
                _menu = false;
                _layer = _Layer.daily;
              });
            },
            onPrivacy: widget.onPrivacy,
            onSupport: widget.onSupport,
          ),
          if (_layer == _Layer.win && _last != null)
            WinSplash(
              paid: _last!.paid,
              grade: _grade,
              free: _last!.freeAwarded,
              onCollect: _collectWin,
            ),
          if (_layer == _Layer.daily)
            DailyBoard(bank: b, onClose: () => setState(() => _layer = _Layer.none)),
          if (_layer == _Layer.pay)
            PaySheet(onClose: () => setState(() => _layer = _Layer.none)),
          if (_layer == _Layer.broke)
            BrokeSheet(
              drop: _brokeDrop,
              onClose: () => setState(() => _layer = _Layer.none),
            ),
          if (_layer == _Layer.bonus)
            BonusPaid(
              amount: _bonusDump,
              onClose: () {
                setState(() => _layer = _Layer.none);
                _maybeAuto();
              },
            ),
        ],
      ),
    );
  }
}

enum _Layer { none, win, daily, pay, broke, bonus }

class _Hud extends StatelessWidget {
  const _Hud({required this.bank, required this.onBack, required this.onMenu});

  final Bank bank;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Row(
        children: [
          GhostBtn(label: 'BACK', onTap: onBack),
          const SizedBox(width: 6),
          Expanded(child: ChipMeter(tag: 'CHIPS', value: chipsShort(bank.chips))),
          const SizedBox(width: 6),
          Expanded(
            child: ChipMeter(
              tag: bank.freeTotal > 0 ? 'FREE ${bank.freeLeft}' : 'JACKPOT',
              value: bank.freeTotal > 0 ? chipsShort(bank.freeBucket) : chipsShort(bank.jackpot),
              accent: Ice.magenta,
            ),
          ),
          const SizedBox(width: 6),
          GhostBtn(label: 'MENU', onTap: onMenu, color: Ice.gold),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.motors, required this.strips, required this.glow});

  final List<ReelMotor> motors;
  final List<List<Kind>> strips;
  final List<List<bool>> glow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: AspectRatio(
        aspectRatio: 588 / 526,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(Gfx.frame, fit: BoxFit.fill, filterQuality: FilterQuality.high),
              ),
              Positioned(
                left: w * 0.042,
                right: w * 0.042,
                top: h * 0.052,
                bottom: h * 0.048,
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++) ...[
                      if (i > 0) SizedBox(width: w * 0.01),
                      Expanded(
                        child: ReelColumn(
                          strip: strips[i],
                          head: motors[i].pos % strips[i].length,
                          glow: glow[i],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.bank,
    required this.busy,
    required this.onMinus,
    required this.onPlus,
    required this.onSpin,
    required this.onAuto,
  });

  final Bank bank;
  final bool busy;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onSpin;
  final VoidCallback onAuto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 443 / 132,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(Gfx.stake, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                  ),
                  Center(child: Text(chips(bank.stake), style: russo(22, Ice.cream))),
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(flex: 22, child: GestureDetector(onTap: busy ? null : onMinus)),
                        const Spacer(flex: 56),
                        Expanded(flex: 22, child: GestureDetector(onTap: busy ? null : onPlus)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: busy ? null : onSpin,
            onLongPress: onAuto,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: busy ? 0.55 : 1,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: bank.auto ? 0.94 : 1,
                    child: Image.asset(Gfx.spin, width: 108, height: 102, filterQuality: FilterQuality.high),
                  ),
                ),
                Text(bank.auto ? 'AUTO ON' : 'HOLD: AUTO', style: barlow(11, bank.auto ? Ice.magenta : Ice.dim, ls: 0.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.onClose,
    required this.onPay,
    required this.onDaily,
    required this.onPrivacy,
    required this.onSupport,
  });

  final VoidCallback onClose;
  final VoidCallback onPay;
  final VoidCallback onDaily;
  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0x99050814),
        child: Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 210,
              margin: const EdgeInsets.fromLTRB(0, 64, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Ice.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Ice.cyan.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('PAYTABLE', onPay),
                  _row('DAILY BONUS', onDaily),
                  _row('SUPPORT', onSupport),
                  _row('PRIVACY', onPrivacy),
                  _row('CLOSE', onClose),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String t, VoidCallback tap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GhostBtn(label: t, onTap: tap),
      );
}
