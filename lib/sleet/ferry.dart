import 'package:http/http.dart' as http;

import 'handset.dart';

class Ferry extends http.BaseClient {
  Ferry({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final ua = Handset.agent;
    if (request.headers['User-Agent'] != ua) {
      request.headers['User-Agent'] = ua;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

Ferry? _shared;

Ferry get ferry => _shared ??= Ferry();
