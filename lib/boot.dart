import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'gfx.dart';
import 'look.dart';

class BootView extends StatefulWidget {
  const BootView({
    super.key,
    required this.onReady,
    required this.progress,
    required this.launchReady,
  });

  final VoidCallback onReady;

  /// Progress of the real pre-launch loading stages (0..1), fed by the app as
  /// milestones complete. Mapped onto the 0..85% portion of the bar so the fill
  /// tracks actual loading for every launch type (first run, native, webview).
  final double progress;

  /// Set by the app once the landing target (native game or webview) has been
  /// resolved and launch is imminent. Only then does the bar run to 100%.
  final bool launchReady;

  @override
  State<BootView> createState() => _BootViewState();
}

class _BootViewState extends State<BootView> with SingleTickerProviderStateMixin {
  // The bar eases up to this point while loading stages complete; the final
  // stretch to 100% only runs once the launch target is resolved.
  static const double _hold = 0.85;

  late final AnimationController _bar;
  bool _fired = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _bar = AnimationController(vsync: this, value: 0);
    _drive();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warm());
    if (widget.launchReady) _finish();
  }

  @override
  void didUpdateWidget(BootView old) {
    super.didUpdateWidget(old);
    if (widget.progress != old.progress) _drive();
    if (widget.launchReady && !old.launchReady) _finish();
  }

  // Eases the bar toward the latest loading milestone (never backwards), so the
  // visible fill stays in step with the stages reported by the app.
  void _drive() {
    if (_finishing) return;
    final target = _hold * widget.progress.clamp(0.0, 1.0);
    if (target <= _bar.value) return;
    _bar.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
    );
  }

  // Best-effort decode of the game art. This never gates the progress bar, so a
  // cold start that goes straight into the webview is not slowed down by it.
  Future<void> _warm() async {
    for (final asset in Gfx.all) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (_) {}
    }
  }

  // Runs the bar from wherever it is to 100%, lets the user actually see the
  // full bar for a beat, then hands off to the app.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await _bar.animateTo(
      1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || _fired) return;
    _fired = true;
    widget.onReady();
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    return ColoredBox(
      color: Ice.voidBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            land ? Gfx.alley : Gfx.brick,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: land
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66050814), Color(0x1A050814), Color(0xB3050814)],
                      stops: [0, 0.4, 1],
                    )
                  : const RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [Color(0x00050814), Color(0xAA050814)],
                    ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _bar,
              builder: (context, _) => _body(land, _bar.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(bool land, double t) {
    final logo = Image.asset(Gfx.wordmark, filterQuality: FilterQuality.high);
    final bar = _Meter(t: t);
    if (land) {
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: logo,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
              margin: const EdgeInsets.only(right: 28),
              decoration: BoxDecoration(
                color: const Color(0x99050814),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Ice.cyan.withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('STOP. THINK. FREEZE.', style: barlow(18, Ice.cyan, w: FontWeight.w700, ls: 2)),
                  const SizedBox(height: 18),
                  bar,
                  const SizedBox(height: 10),
                  Text('${(t * 100).floor()}%', style: russo(22, Ice.cream)),
                  const SizedBox(height: 8),
                  _status(t, 14),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        const Spacer(flex: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: logo,
        ),
        const Spacer(flex: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: bar,
        ),
        const SizedBox(height: 12),
        _status(t, 15),
        const SizedBox(height: 8),
        Text('${(t * 100).floor()}%', style: russo(20, Ice.cream)),
        const Spacer(flex: 2),
      ],
    );
  }

  // Loading status line: animated "Loading" with cycling dots while work is in
  // flight, "READY" once the bar is full. Shown in both orientations.
  Widget _status(double t, double size) {
    final style = barlow(size, Ice.dim, ls: 1.6);
    return t < 1
        ? _LoadingDots(style: style)
        : Text('READY', style: style, textAlign: TextAlign.center);
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.t});

  final double t;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xCC071018),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Ice.cyan.withValues(alpha: 0.7), width: 1.4),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Align(
          alignment: Alignment.centerLeft,
          // widthFactor fills the track horizontally by fraction, heightFactor
          // keeps the fill at full track height (the old SizedBox collapsed to 0).
          child: FractionallySizedBox(
            widthFactor: t.clamp(0.0, 1.0),
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(18)),
                gradient: LinearGradient(colors: [Ice.cyan, Ice.magenta]),
                boxShadow: [BoxShadow(color: Ice.cyan, blurRadius: 8)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.style});

  final TextStyle style;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> {
  Timer? _timer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() => _dots = (_dots + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Trailing spaces keep the width stable so the text doesn't jiggle.
    final tail = '.' * _dots + ' ' * (3 - _dots);
    return Text(
      'Loading$tail',
      style: widget.style,
      textAlign: TextAlign.center,
    );
  }
}
