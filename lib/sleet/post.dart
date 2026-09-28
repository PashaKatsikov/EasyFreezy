import 'dart:convert';

import 'book.dart';
import 'ferry.dart';
import 'shelf.dart';
import 'slip.dart';

class Post {
  Post(this._shelf);

  final Shelf _shelf;

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<Reply> ask(Map<String, dynamic> body) async {
    final endpoint = Book.endpoint;
    if (endpoint.isEmpty) return Reply.rejected('no_endpoint');
    final uri = Uri.tryParse(endpoint);
    if (uri == null) return Reply.rejected('bad_endpoint');
    try {
      final response = await ferry
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(Duration(seconds: Book.postTimeoutSeconds));
      if (response.statusCode != 200) {
        return Reply.rejected('status_${response.statusCode}');
      }
      final reply = Reply.decodeBody(response.body);
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
