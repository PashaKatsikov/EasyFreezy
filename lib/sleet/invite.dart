import 'package:flutter/material.dart';

import '../look.dart';
import 'art.dart';
import 'bell.dart';
import 'book.dart';
import 'pill.dart';
import 'shelf.dart';
import 'veil.dart';

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
    // Trigger the system notification permission dialog, then never show the
    // invite screen again — regardless of whether the user allowed or denied.
    await bell.ask();
    await shelf.markAsked();
    onDone();
  }

  Future<void> _skip() async {
    // Show the invite again on a later launch, once the snooze window elapses.
    await shelf.snoozeUntil(_until());
    onDone();
  }

  int _until() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + Book.snoozeSeconds;

  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    final w = MediaQuery.sizeOf(context).width;
    final pillWidth = land ? w * 0.34 : w * 0.72;
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
                  Icons.notifications_active_rounded,
                  size: land ? 52 : 72,
                  color: Ice.cyan,
                ),
                SizedBox(height: land ? 16 : 28),
                Text(
                  openInviteTitle(),
                  textAlign: TextAlign.center,
                  style: russo(land ? 21 : 25, Ice.cream, ls: 1.0, glow: true),
                ),
                const SizedBox(height: 14),
                Text(
                  openInviteBody(),
                  textAlign: TextAlign.center,
                  style: barlow(land ? 15 : 17, Ice.dim),
                ),
                const Spacer(flex: 3),
                IcePill(label: 'Accept', width: pillWidth, onTap: _accept),
                SizedBox(height: land ? 8 : 12),
                IcePill(
                  label: 'Skip',
                  width: pillWidth,
                  filled: false,
                  onTap: _skip,
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
