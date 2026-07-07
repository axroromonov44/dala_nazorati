import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/oneid_config.dart';

/// [OneIdConfig.redirectUri]'ga o'tishga urinadi — shu daqiqada navigatsiya
class OneIdWebViewPage extends StatefulWidget {
  const OneIdWebViewPage({super.key});

  @override
  State<OneIdWebViewPage> createState() => _OneIdWebViewPageState();
}

class _OneIdWebViewPageState extends State<OneIdWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    final authUrl = OneIdConfig.buildAuthorizationUrl();
    debugPrint('[OneID] authorization url: $authUrl');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[OneID] page started: $url');
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            debugPrint('[OneID] page finished: $url');
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
    debugPrint('[OneID] navigation request: ${request.url}');
    if (_handled || !request.url.startsWith(OneIdConfig.redirectUri)) {
      return NavigationDecision.navigate;
    }
    _handled = true;
    final code = Uri.parse(request.url).queryParameters['code'];
    debugPrint('[OneID] redirect caught, code=$code');
    Navigator.of(context).pop(code);
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ONE ID'),
        backgroundColor: const Color(0xFF2D159A),
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
