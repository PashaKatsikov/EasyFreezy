import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bank.dart';
import 'boot.dart';
import 'floor.dart';
import 'legal.dart';
import 'lobby.dart';
import 'look.dart';
import 'machine.dart';
import 'sleet/bars.dart';
import 'sleet/bell.dart';
import 'sleet/board.dart';
import 'sleet/dial.dart';
import 'sleet/gap.dart';
import 'sleet/handset.dart';
import 'sleet/invite.dart';
import 'sleet/pane.dart';
import 'sleet/post.dart';
import 'sleet/shelf.dart';
import 'sleet/slip.dart';
import 'sleet/trace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final o = Firebase.app().options;
    debugPrint('[EF.FIRE] init ok: project=${o.projectId} '
        'app=${o.appId} sender=${o.messagingSenderId}');
  } catch (e, st) {
    debugPrint('[EF.FIRE] init FAILED: $e');
    debugPrint('$st');
  }
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
    debugPrint('[EF.FIRE] appcheck activated '
        '(${kDebugMode ? 'debug' : 'playIntegrity'})');
  } catch (e) {
    debugPrint('[EF.FIRE] appcheck activate failed: $e');
  }

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  await Bars.tuck();
  await Handset.prime();

  final shelf = Shelf();
  final bankFuture = Bank.open();
  await shelf.prime();
  final bank = await bankFuture;
  final dial = Dial();
  final bell = Bell(shelf);
  final board = Board(
    shelf: shelf,
    dial: dial,
    trace: Trace(),
    post: Post(shelf),
    bell: bell,
  );
  final startGap = shelf.mark != Mark.cabin && !await dial.adapterUp();

  runApp(
    EasyFreezy(
      bank: bank,
      board: board,
      shelf: shelf,
      bell: bell,
      startGap: startGap,
    ),
  );
}

enum Stage { boot, lobby, table, invite, pane, gap }

class EasyFreezy extends StatefulWidget {
  const EasyFreezy({
    super.key,
    required this.bank,
    required this.board,
    required this.shelf,
    required this.bell,
    required this.startGap,
  });

  final Bank bank;
  final Board board;
  final Shelf shelf;
  final Bell bell;
  final bool startGap;

  @override
  State<EasyFreezy> createState() => _EasyFreezyState();
}

class _EasyFreezyState extends State<EasyFreezy> with WidgetsBindingObserver {
  final _bandit = Bandit();
  final _nav = GlobalKey<NavigatorState>();
  final _floor = GlobalKey<FloorViewState>();
  late Stage _stage;
  var _visualDone = false;
  var _launchReady = false;
  var _bootProgress = 0.0;
  var _bootEpoch = 0;
  var _gapFromPane = false;
  Landing? _landing;
  String? _glassUrl;

  Bank get _bank => widget.bank;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stage = widget.startGap ? Stage.gap : Stage.boot;
    if (!widget.startGap) _settle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Bars.tuck();
  }

  Future<void> _settle() async {
    final landing = await widget.board.settle(
      onProgress: (p) {
        if (mounted) setState(() => _bootProgress = p);
      },
    );
    if (!mounted) return;
    _landing = landing;
    if (landing is GapLanding) {
      setState(() => _stage = Stage.gap);
      return;
    }
    // Launch target resolved: let the boot bar run to 100% before we switch.
    setState(() {
      _bootProgress = 1;
      _launchReady = true;
    });
    _advance();
  }

  void _onBootReady() {
    _visualDone = true;
    _advance();
  }

  void _advance() {
    final landing = _landing;
    if (!_visualDone || landing == null || _stage != Stage.boot) return;
    if (landing is CabinLanding) {
      _lockPortrait();
      setState(() => _stage = Stage.lobby);
      return;
    }
    if (landing is GlassLanding) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      final ask = !landing.coldTap && widget.shelf.shouldAsk;
      debugPrint('[EF.FIRE] glass landing: coldTap=${landing.coldTap} '
          'shouldAsk=${widget.shelf.shouldAsk} -> '
          '${ask ? 'INVITE' : 'PANE'}');
      setState(() {
        _glassUrl = landing.url;
        _stage = ask ? Stage.invite : Stage.pane;
      });
    }
  }

  void _retry() {
    if (_gapFromPane && _glassUrl != null) {
      setState(() {
        _gapFromPane = false;
        _stage = Stage.pane;
      });
      return;
    }
    setState(() {
      _bootEpoch++;
      _visualDone = false;
      _launchReady = false;
      _bootProgress = 0;
      _landing = null;
      _gapFromPane = false;
      _stage = Stage.boot;
    });
    _settle();
  }

  void _openGlass() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    setState(() => _stage = Stage.pane);
  }

  void _paneOffline(String url) {
    setState(() {
      _glassUrl = url;
      _gapFromPane = true;
      _stage = Stage.gap;
    });
  }

  Future<void> _lockPortrait() {
    return SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  void _goto(Stage s) {
    setState(() {
      _stage = s;
    });
    if (s == Stage.boot) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } else {
      _lockPortrait();
    }
  }

  void _openLegal(String title, String url) {
    _nav.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = _glassUrl;
    return MaterialApp(
      navigatorKey: _nav,
      title: 'Easy Freezy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Ice.voidBg,
        fontFamily: 'Barlow',
        useMaterial3: false,
        colorScheme: const ColorScheme.dark(
          primary: Ice.cyan,
          secondary: Ice.magenta,
          surface: Ice.voidBg,
        ),
      ),
      home: switch (_stage) {
        Stage.boot => BootView(
          key: ValueKey<int>(_bootEpoch),
          onReady: _onBootReady,
          progress: _bootProgress,
          launchReady: _launchReady,
        ),
        Stage.lobby => LobbyView(
          bank: _bank,
          onPlay: () => _goto(Stage.table),
          onDaily: () {
            _goto(Stage.table);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _floor.currentState?.showDaily();
            });
          },
          onPay: () {
            _goto(Stage.table);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _floor.currentState?.showPay();
            });
          },
          onPrivacy: () => _openLegal('Privacy Policy', privacyUrl),
          onSupport: () => _openLegal('Support', supportUrl),
        ),
        Stage.table => FloorView(
          key: _floor,
          bank: _bank,
          bandit: _bandit,
          onLobby: () => _goto(Stage.lobby),
          onPrivacy: () => _openLegal('Privacy Policy', privacyUrl),
          onSupport: () => _openLegal('Support', supportUrl),
        ),
        Stage.invite => InviteView(
          shelf: widget.shelf,
          bell: widget.bell,
          onDone: _openGlass,
        ),
        Stage.pane =>
          glass == null
              ? GapView(onRetry: _retry)
              : GlassPane(
                  key: ValueKey<String>(glass),
                  url: glass,
                  shelf: widget.shelf,
                  bell: widget.bell,
                  onOffline: _paneOffline,
                ),
        Stage.gap => GapView(onRetry: _retry),
      },
    );
  }
}
