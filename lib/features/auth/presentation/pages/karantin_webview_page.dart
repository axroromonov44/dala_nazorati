import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/karantin_config.dart';

/// [KarantinIdConfig.redirectUri]'ga o'tishga urinadi — shu daqiqada
class KarantinWebViewPage extends StatefulWidget {
  const KarantinWebViewPage({super.key});

  @override
  State<KarantinWebViewPage> createState() => _KarantinWebViewPageState();
}

class _KarantinWebViewPageState extends State<KarantinWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    final authUrl = KarantinIdConfig.buildAuthorizationUrl();
    debugPrint('[KarantinID] authorization url: $authUrl');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[KarantinID] page started: $url');
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            debugPrint('[KarantinID] page finished: $url');
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            debugPrint(
              'code=${error.errorCode} desc=${error.description} '
              'url=${error.url} isMainFrame=${error.isForMainFrame}',
            );
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    debugPrint('[KarantinID] navigation request: ${request.url}');
    if (_handled || !request.url.startsWith(KarantinIdConfig.redirectUri)) {
      return NavigationDecision.navigate;
    }
    _handled = true;
    final code = Uri.parse(request.url).queryParameters['code'];
    debugPrint('[KarantinID] redirect caught, code=$code');
    Navigator.of(context).pop(code);
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karantin ID'),
        backgroundColor: kGreen,
        foregroundColor: kWhite,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: kGreen)),
        ],
      ),
    );
  }
}
