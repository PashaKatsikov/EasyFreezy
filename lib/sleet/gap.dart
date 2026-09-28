import 'package:flutter/material.dart';

import '../look.dart';
import 'art.dart';
import 'pill.dart';

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
    final size = MediaQuery.sizeOf(context);
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    final bg = land ? SleetArt.offlineWide : SleetArt.offlineTall;
    return MediaQuery(
      data: land
          ? MediaQuery.of(context).copyWith(
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            )
          : MediaQuery.of(context),
      child: Scaffold(
        backgroundColor: Ice.voidBg,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(bg, fit: BoxFit.cover, width: size.width, height: size.height),
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * (land ? 0.07 : 0.08),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Ice.cyan,
                        ),
                      )
                    : IcePill(
                        label: 'Retry',
                        width: land ? size.width * 0.28 : size.width * 0.56,
                        onTap: _retry,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
