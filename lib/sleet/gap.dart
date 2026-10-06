import 'package:flutter/material.dart';

import '../look.dart';
import 'art.dart';
import 'pill.dart';
import 'veil.dart';

class GapView extends StatefulWidget {
  const GapView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  State<GapView> createState() => _GapViewState();
}

class _GapViewState extends State<GapView> {
  var _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 480));
    if (!mounted) return;
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    final w = MediaQuery.sizeOf(context).width;
    final pillHeight = land ? 42.0 : 52.0;
    return Scaffold(
      body: SleetBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: land ? 56 : 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(flex: 2),
                Icon(
                  Icons.wifi_off_rounded,
                  size: land ? 52 : 72,
                  color: Ice.cyan,
                ),
                SizedBox(height: land ? 16 : 28),
                Text(
                  openGapTitle(),
                  textAlign: TextAlign.center,
                  style: russo(land ? 21 : 25, Ice.cream, ls: 1.0, glow: true),
                ),
                const SizedBox(height: 14),
                Text(
                  openGapBody(),
                  textAlign: TextAlign.center,
                  style: barlow(land ? 15 : 17, Ice.dim),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  height: pillHeight,
                  child: Center(
                    child: _busy
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Ice.cyan,
                            ),
                          )
                        : IcePill(
                            label: 'Retry',
                            width: land ? w * 0.34 : w * 0.64,
                            onTap: _retry,
                          ),
                  ),
                ),
                SizedBox(height: land ? 16 : 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
