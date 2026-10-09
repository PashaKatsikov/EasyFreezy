import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'book.dart';
import 'shelf.dart';
import 'slip.dart';
import 'veil.dart';

class Post {
  Post(this._shelf);

  final Shelf _shelf;

  /// Posts the attribution map as plain JSON through the native
  /// Chrome-fingerprinted transport (see rust/src/net.rs). The partner
  /// config reads this body directly and answers with plain JSON:
  ///
  ///   `200 { "ok": true, "url": "...", "expires": <unix seconds> }`
  ///   `404 { "ok": false, "message": "No data" }`
  ///
  /// Only the first shape opens the WebView. The URL, method and header
  /// names stay encrypted in the native table.
  Future<Reply> ask(Map<String, dynamic> body) async {
    try {
      final payload = utf8.encode(jsonEncode(body));
      // The FFI call blocks for up to postTimeoutSeconds (TLS + round trip),
      // so we hop to a short-lived worker isolate to keep the UI isolate
      // responsive. Isolate.run copies the result back automatically.
      final timeout = Book.postTimeoutSeconds;
      final result = await Isolate.run<({int status, String body})>(
        () => postConfigNative(payload, timeout),
      );
      final status = result.status;
      if (status == 0) {
        debugPrint('[EF.POST] transport ${result.body}');
        return Reply.rejected('transport:${result.body}');
      }
      final reply = _read(result.body);
      debugPrint('[EF.POST] status=$status ok=${reply.approved} '
          'url=${reply.hasDestination} note=${reply.note}');
      if (status != 200 || !reply.hasDestination) {
        return Reply.rejected(reply.note ?? 'status_$status');
      }
      await _shelf.rememberUrl(reply.url!, reply.expiresAt);
      return reply;
    } on FormatException {
      return Reply.rejected('bad_json');
    } catch (error) {
      debugPrint('[EF.POST] transport $error');
      return Reply.rejected('transport:$error');
    }
  }

  Reply _read(String raw) {
    try {
      return Reply.decodeBody(raw);
    } on FormatException {
      return Reply.rejected('bad_json');
    }
  }
}
