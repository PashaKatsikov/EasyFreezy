import 'package:webview_flutter/webview_flutter.dart';

import 'veil.dart';

class Hooks {
  Hooks._();

  static Future<void> install(WebViewController view) async {
    final scripts = <String>[openSafeArea(), openKeyboard(), openAutoplay()];
    for (final src in scripts) {
      if (src.isEmpty) continue;
      await view.runJavaScript(src);
    }
  }

  static Future<void> seat(WebViewController view, double logicalPx) async {
    final hook = openHook();
    if (hook.isEmpty) return;
    final px = logicalPx.round().clamp(0, 3600);
    try {
      await view.runJavaScript('window.$hook&&window.$hook($px)');
    } catch (_) {}
  }
}
