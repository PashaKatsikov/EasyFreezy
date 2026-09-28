import 'package:flutter/material.dart';

import 'art.dart';
import 'bell.dart';
import 'book.dart';
import 'pill.dart';
import 'shelf.dart';

class InviteView extends StatelessWidget {
  const InviteView({
    super.key,
    required this.shelf,
    required this.bell,
    required this.onDone,
  });

  final Shelf shelf;
  final Bell bell;
  final VoidCallback onDone;

  Future<void> _accept() async {
    final granted = await bell.ask();
    if (!granted) {
      await shelf.snoozeUntil(_until());
    }
    onDone();
  }

  Future<void> _skip() async {
    await shelf.snoozeUntil(_until());
    onDone();
  }

  int _until() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + Book.snoozeSeconds;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    final bg = land ? SleetArt.bonusWide : SleetArt.bonusTall;
    return MediaQuery(
      data: land
          ? MediaQuery.of(context).copyWith(
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            )
          : MediaQuery.of(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF050814),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(bg, fit: BoxFit.cover, width: size.width, height: size.height),
            Positioned(
              left: size.width * (land ? 0.28 : 0.12),
              right: size.width * (land ? 0.28 : 0.12),
              bottom: size.height * (land ? 0.06 : 0.07),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IcePill(label: 'Accept', onTap: _accept),
                  SizedBox(height: land ? 8 : 12),
                  IcePill(label: 'Skip', filled: false, onTap: _skip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
