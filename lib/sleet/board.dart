import 'dart:async';
import 'dart:io';

import 'book.dart';
import 'dial.dart';
import 'post.dart';
import 'shelf.dart';
import 'slip.dart';
import 'trace.dart';
import 'bell.dart';

class Board {
  Board({
    required this.shelf,
    required this.dial,
    required this.trace,
    required this.post,
    required this.bell,
  });

  final Shelf shelf;
  final Dial dial;
  final Trace trace;
  final Post post;
  final Bell bell;

  Future<Landing>? _busy;

  Future<Landing> settle({void Function(double)? onProgress}) {
    return _busy ??= _run(onProgress ?? (_) {}).whenComplete(() => _busy = null);
  }

  Future<Landing> _run(void Function(double) onProgress) async {
    if (!Book.ready) {
      onProgress(1);
      return const CabinLanding();
    }

    bell.onToken = _resend;

    final mark = shelf.mark;
    if (mark == Mark.cabin) {
      onProgress(0.18);
      return _cabin(onProgress);
    }

    if (!await dial.adapterUp() || !await dial.canReach()) {
      return const GapLanding(backToCabin: false);
    }

    final cold = await bell.coldOpen(within: Duration(seconds: Book.coldTapSeconds));
    if (cold != null && cold.isNotEmpty) {
      await shelf.saveMark(Mark.glass);
      unawaited(_side());
      onProgress(1);
      return GlassLanding(cold, coldTap: true);
    }
    await shelf.stashPending(null);

    onProgress(0.18);
    if (mark == Mark.glass) return _glass(onProgress);
    return _first(onProgress);
  }

  Future<Landing> _first(void Function(double) onProgress) async {
    onProgress(0.34);
    try {
      await bell.boot();
    } catch (_) {}
    onProgress(0.52);
    await trace.start();
    await trace.awaitSignals(installSeconds: Book.firstWaitSeconds);
    onProgress(0.78);
    final answer = await _ask();
    onProgress(1);
    if (answer.hasDestination) {
      await shelf.saveMark(Mark.glass);
      return GlassLanding(answer.url!);
    }
    await shelf.saveMark(Mark.cabin);
    return const CabinLanding();
  }

  Future<Landing> _glass(void Function(double) onProgress) async {
    final pending = await shelf.takePending();
    if (pending != null && pending.isNotEmpty) {
      onProgress(1);
      return GlassLanding(pending);
    }
    final cached = await shelf.cachedUrl();
    if (cached != null && !shelf.cacheStale) {
      onProgress(1);
      return GlassLanding(cached);
    }

    await Future.wait<void>(<Future<void>>[bell.boot(), trace.start()]);
    onProgress(0.62);
    await trace.awaitSignals(installSeconds: Book.returnWaitSeconds);
    final answer = await _ask();
    onProgress(1);
    if (answer.hasDestination) return GlassLanding(answer.url!);
    if (cached != null) return GlassLanding(cached);
    return const GapLanding(backToCabin: false);
  }

  Future<Landing> _cabin(void Function(double) onProgress) async {
    if (!await dial.adapterUp()) {
      onProgress(1);
      return const CabinLanding();
    }
    await Future.wait<void>(<Future<void>>[bell.boot(), trace.start()]);
    if (!await dial.canReach()) {
      onProgress(1);
      return const CabinLanding();
    }
    onProgress(0.58);
    await trace.awaitSignals(installSeconds: Book.returnWaitSeconds);
    final answer = await _ask();
    onProgress(1);
    if (!answer.hasDestination) return const CabinLanding();
    await shelf.saveMark(Mark.glass);
    return GlassLanding(answer.url!);
  }

  Future<Reply> _ask({String? token}) {
    return trace
        .compose(
          locale: Platform.localeName.replaceAll('-', '_'),
          pushToken: token ?? bell.token,
        )
        .then(post.ask);
  }

  Future<void> _side() async {
    try {
      await Future.wait<void>(<Future<void>>[bell.boot(), trace.start()]);
      await trace.awaitSignals(installSeconds: Book.returnWaitSeconds);
      await _ask();
    } catch (_) {}
  }

  Future<void> _resend(String token) async {
    try {
      await _ask(token: token);
    } catch (_) {}
  }
}
