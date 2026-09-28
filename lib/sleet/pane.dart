import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../look.dart';
import 'bars.dart';
import 'bell.dart';
import 'book.dart';
import 'dial.dart';
import 'handset.dart';
import 'hooks.dart';
import 'shelf.dart';

class GlassPane extends StatefulWidget {
  const GlassPane({
    super.key,
    required this.url,
    required this.shelf,
    required this.bell,
    required this.onOffline,
  });

  final String url;
  final Shelf shelf;
  final Bell bell;
  final ValueChanged<String> onOffline;

  @override
  State<GlassPane> createState() => _GlassPaneState();
}

class _GlassPaneState extends State<GlassPane> with WidgetsBindingObserver {
  static const MethodChannel _pipe = MethodChannel('n6w/sheet');

  late final WebViewController _view;
  var _busy = true;
  var _left = false;
  String? _frame;
  var _loops = 0;
  Timer? _quiet;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  EdgeInsets _cutTall = EdgeInsets.zero;
  EdgeInsets _cutWide = EdgeInsets.zero;
  var _kb = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    Bars.tuck();
    _buildView();
    _pipe.setMethodCallHandler(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pull());
    widget.bell.onIncoming = (url) {
      if (mounted) _view.loadRequest(Uri.parse(url));
    };
    _sub = Dial().changes.listen((states) {
      final dead = states.isNotEmpty &&
          states.every((item) => item == ConnectivityResult.none);
      if (!dead) {
        _quiet?.cancel();
        return;
      }
      _quiet?.cancel();
      _quiet = Timer(Duration(milliseconds: Book.dropQuietMs), _goOffline);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Bars.tuck();
  }

  @override
  void didChangeMetrics() => _pull();

  Future<dynamic> _onTick(MethodCall call) async {
    if (call.method != 'insetTick') return;
    final raw = call.arguments;
    if (raw is Map) await _apply(Map<dynamic, dynamic>.from(raw));
  }

  Future<void> _apply(Map<dynamic, dynamic> pane) async {
    if (!mounted) return;
    final notch = EdgeInsets.only(
      left: (pane['nLeft'] as num?)?.toDouble() ?? 0,
      top: (pane['nTop'] as num?)?.toDouble() ?? 0,
      right: (pane['nRight'] as num?)?.toDouble() ?? 0,
    );
    final wide = notch.left > 0 || notch.right > 0;
    if (wide) {
      if (notch != _cutWide) setState(() => _cutWide = notch);
    } else if (notch != _cutTall) {
      setState(() => _cutTall = notch);
    }
    final kb = (pane['kb'] as num?)?.toDouble() ?? 0;
    if ((kb - _kb).abs() < 1) return;
    _kb = kb;
    await Hooks.seat(_view, kb);
  }

  Future<void> _pull() async {
    if (!mounted) return;
    try {
      final native = await _pipe.invokeMethod<Object>('measure');
      if (native is Map) {
        await _apply(Map<dynamic, dynamic>.from(native));
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    final view = View.of(context);
    await Hooks.seat(_view, view.viewInsets.bottom / view.devicePixelRatio);
  }

  void _buildView() {
    _view = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(Handset.agent)
      ..setBackgroundColor(Ice.voidBg)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _busy = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _busy = false);
            _loops = 0;
            Hooks.install(_view).whenComplete(_pull);
          },
          onWebResourceError: _onError,
          onNavigationRequest: _onNavigate,
        ),
      );
    _wireAndroid();
    _view.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;
    final desc = err.description.toLowerCase();
    final loop = desc.contains('too_many_redirects') ||
        desc.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;
    if (loop && _frame != null && _loops < Book.loopRetries) {
      _loops++;
      _view.loadRequest(Uri.parse(_frame!));
      return;
    }
    if (mounted) setState(() => _busy = true);
    final dropped = desc.contains('name_not_resolved') ||
        desc.contains('address_unreachable') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;
    if (dropped) {
      _goOffline();
    } else {
      _guard();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const inside = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (inside.contains(uri.scheme)) {
      if (req.isMainFrame) _frame = req.url;
      return NavigationDecision.navigate;
    }
    _outside(uri);
    return NavigationDecision.prevent;
  }

  void _wireAndroid() {
    if (!Platform.isAndroid) return;
    if (_view.platform is! AndroidWebViewController) return;
    final controller = _view.platform as AndroidWebViewController;
    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnPlatformPermissionRequest((request) => request.grant());
    controller.setOnShowFileSelector(_choose);
    final cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams.fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _choose(FileSelectorParams params) async {
    try {
      final picked = await _pipe.invokeMethod<List<Object?>>('choose', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes.where((item) => item.trim().isNotEmpty).toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _outside(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guard() async {
    if (_left) return;
    if (await Dial().canReach()) return;
    _goOffline();
  }

  void _goOffline() {
    if (_left || !mounted) return;
    _left = true;
    widget.onOffline(_frame ?? widget.url);
  }

  Future<void> _back() async {
    if (await _view.canGoBack()) await _view.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipe.setMethodCallHandler(null);
    _quiet?.cancel();
    _sub?.cancel();
    widget.bell.onIncoming = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    final gutter = land ? _cutWide : _cutTall;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _back();
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
        child: Scaffold(
          backgroundColor: Ice.voidBg,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Padding(padding: gutter, child: WebViewWidget(controller: _view)),
              if (_busy)
                const ColoredBox(
                  color: Color(0x99050814),
                  child: Center(
                    child: CircularProgressIndicator(color: Ice.cyan),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
