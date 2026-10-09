import 'dart:convert';
import 'dart:isolate';

import 'book.dart';
import 'pack.dart';
import 'shelf.dart';
import 'slip.dart';
import 'veil.dart';

class Post {
  Post(this._shelf);

  final Shelf _shelf;

  /// Posts the attribution envelope through the native Chrome-fingerprinted
  /// transport (see rust/src/net.rs). The actual URL / method / headers all
  /// live encrypted in the native table and are resolved per call inside
  /// Rust, so there is nothing to pass or configure from here.
  Future<Reply> ask(Map<String, dynamic> body) async {
    final envelope = Pack.seal(body, openRelaySecret());
    if (envelope.isEmpty) return Reply.rejected('no_secret');
    try {
      final payload = utf8.encode(jsonEncode(envelope));
      // The FFI call blocks for up to postTimeoutSeconds (TLS + round trip),
      // so we hop to a short-lived worker isolate to keep the UI isolate
      // responsive. Isolate.run copies the result back automatically.
      final timeout = Book.postTimeoutSeconds;
      final result = await Isolate.run<({int status, String body})>(
        () => postConfigNative(payload, timeout),
      );
      final status = result.status;
      if (status == 0) {
        return Reply.rejected('transport:${result.body}');
      }
      if (status != 200) {
        return Reply.rejected('status_$status');
      }
      final reply = Reply.decodeBody(result.body);
      if (reply.hasDestination) {
        await _shelf.rememberUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } on FormatException {
      return Reply.rejected('bad_json');
    } catch (error) {
      return Reply.rejected('transport:$error');
    }
  }
}
