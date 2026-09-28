import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'book.dart';

const List<String> _hosts = <String>['github.com', 'apple.com'];

const Set<ConnectivityResult> _live = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

class Dial {
  Dial({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  var _cursor = 0;

  Future<bool> adapterUp() async {
    try {
      final states = await _connectivity.checkConnectivity();
      return states.any(_live.contains);
    } catch (_) {
      return false;
    }
  }

  Future<bool> canReach() async {
    if (!await adapterUp()) return false;
    final timeout = Duration(seconds: Book.dialTimeoutSeconds);
    for (var step = 0; step < _hosts.length; step++) {
      final host = _hosts[(_cursor + step) % _hosts.length];
      try {
        final answer = await InternetAddress.lookup(host).timeout(timeout);
        if (answer.any((item) => item.rawAddress.isNotEmpty)) {
          _cursor = (_cursor + 1) % _hosts.length;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
