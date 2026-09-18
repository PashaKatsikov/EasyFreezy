import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bank.dart';
import 'boot.dart';
import 'debug_rack.dart';
import 'floor.dart';
import 'legal.dart';
import 'lobby.dart';
import 'look.dart';
import 'machine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final bank = await Bank.open();
  runApp(EasyFreezy(bank: bank));
}

enum Stage { boot, lobby, table }

class EasyFreezy extends StatefulWidget {
  const EasyFreezy({super.key, required this.bank});

  final Bank bank;

  @override
  State<EasyFreezy> createState() => _EasyFreezyState();
}

class _EasyFreezyState extends State<EasyFreezy> {
  final _bandit = Bandit();
  final _nav = GlobalKey<NavigatorState>();
  final _floor = GlobalKey<FloorViewState>();
  Stage _stage = Stage.boot;
  bool _rack = false;

  Bank get _bank => widget.bank;

  Future<void> _lockPortrait() {
    return SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _goto(Stage s) {
    setState(() {
      _stage = s;
      _rack = false;
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
      home: Stack(
        fit: StackFit.expand,
        children: [
          switch (_stage) {
            Stage.boot => BootView(onReady: () => _goto(Stage.lobby)),
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
          },
          if (kDebugMode && !_rack)
            SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _rack = true),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(width: 44, height: 36),
                  ),
                ),
              ),
            ),
          if (kDebugMode && _rack)
            DebugRack(
              bank: _bank,
              onBoot: () => _goto(Stage.boot),
              onLobby: () => _goto(Stage.lobby),
              onTable: () => _goto(Stage.table),
              onPrivacy: () {
                setState(() => _rack = false);
                _openLegal('Privacy Policy', privacyUrl);
              },
              onSupport: () {
                setState(() => _rack = false);
                _openLegal('Support', supportUrl);
              },
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
              onSpin: (force) {
                _goto(Stage.table);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _floor.currentState?.pull(force: force);
                });
              },
              onClose: () => setState(() => _rack = false),
            ),
        ],
      ),
    );
  }
}
