import 'package:flutter/widgets.dart';

/// Shared neon gradient backdrop for the relay screens (notifications / offline).
///
/// These screens intentionally use no image assets — the look is produced
/// entirely with gradients so it stays in style with the frozen-neon palette.
class SleetBackdrop extends StatelessWidget {
  const SleetBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0C1340), Color(0xFF070A1C), Color(0xFF13061F)],
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.78),
                radius: 1.15,
                colors: <Color>[Color(0x3322E3FF), Color(0x0022E3FF)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 1.0),
                radius: 1.15,
                colors: <Color>[Color(0x33FF2BD6), Color(0x00FF2BD6)],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
