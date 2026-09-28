import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'gfx.dart';
import 'look.dart';

class BootView extends StatefulWidget {
  const BootView({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  State<BootView> createState() => _BootViewState();
}

class _BootViewState extends State<BootView> {
  double _t = 0;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final minWait = Future<void>.delayed(const Duration(milliseconds: 2400));
    final n = Gfx.all.length;
    for (var i = 0; i < n; i++) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(Gfx.all[i]), context);
      } catch (_) {}
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      setState(() => _t = (i + 1) / n * 0.92);
    }
    await minWait;
    if (!mounted) return;
    setState(() => _t = 1);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (_fired || !mounted) return;
    _fired = true;
    widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    final logo = Image.asset(Gfx.wordmark, filterQuality: FilterQuality.high);
    final bar = _Meter(t: _t);

    final body = land
        ? Row(
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
                      Text('${(_t * 100).floor()}%', style: russo(22, Ice.cream)),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Column(
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
              Text(_t < 1 ? 'CHILLING THE REELS…' : 'READY',
                  style: barlow(15, Ice.dim, ls: 1.6)),
              const SizedBox(height: 8),
              Text('${(_t * 100).floor()}%', style: russo(20, Ice.cream)),
              const Spacer(flex: 2),
            ],
          );

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
          SafeArea(child: body),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return Container(
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xCC071018),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Ice.cyan.withValues(alpha: 0.7), width: 1.4),
        ),
        padding: const EdgeInsets.all(2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: (w - 6) * t.clamp(0, 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Ice.cyan, Ice.magenta]),
              boxShadow: const [BoxShadow(color: Ice.cyan, blurRadius: 8)],
            ),
          ),
        ),
      );
    });
  }
}
