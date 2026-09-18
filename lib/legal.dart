import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'look.dart';

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final WebViewController _ctl;
  double _t = 0;
  String? _err;

  bool get _privacy => widget.url.contains('privacy-policy');

  @override
  void initState() {
    super.initState();
    _ctl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_privacy ? const Color(0xFFFFFFFF) : Ice.voidBg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _t = p / 100),
        onWebResourceError: (e) => setState(() => _err = e.description),
        onPageFinished: (_) {
          if (_privacy) {
            _ctl.runJavaScript(
              "document.documentElement.style.background='white';"
              "document.body.style.background='white';"
              "document.body.style.color='#111';",
            );
          }
          setState(() {
            _t = 1;
            _err = null;
          });
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _privacy ? Colors.white : Ice.voidBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1522),
        foregroundColor: Ice.cream,
        elevation: 0,
        title: Text(widget.title, style: russo(18, Ice.cyan)),
      ),
      body: Column(
        children: [
          if (_t < 1 && _err == null)
            LinearProgressIndicator(
              value: _t == 0 ? null : _t,
              minHeight: 2,
              color: Ice.cyan,
              backgroundColor: const Color(0xFF1A2430),
            ),
          Expanded(
            child: _err == null
                ? WebViewWidget(controller: _ctl)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Could not load the page.', style: russo(18, Ice.cream)),
                          const SizedBox(height: 8),
                          Text(_err!, style: barlow(14, Ice.dim), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              setState(() => _err = null);
                              _ctl.loadRequest(Uri.parse(widget.url));
                            },
                            child: Text('RETRY', style: barlow(16, Ice.cyan, w: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

const privacyUrl = 'https://easyfreezy.online/privacy-policy.html';
const supportUrl = 'https://easyfreezy.online/support.html';
