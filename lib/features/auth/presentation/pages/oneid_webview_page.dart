import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/oneid_config.dart';

/// ONE ID orqali kirish uchun WebView sahifasi.
/// Foydalanuvchi ONE ID'da tizimga kirgach, sso.egov.uz sahifasi
/// [OneIdConfig.redirectUri]'ga o'tishga urinadi — shu daqiqada navigatsiya
/// to'xtatilib, URL'dagi "code" parametri o'qib olinadi va sahifa shu kod
/// bilan yopiladi. Bekor qilinsa (yopilsa) `null` qaytadi.
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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(OneIdConfig.buildAuthorizationUrl()));
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (_handled || !request.url.startsWith(OneIdConfig.redirectUri)) {
      return NavigationDecision.navigate;
    }
    _handled = true;
    final code = Uri.parse(request.url).queryParameters['code'];
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
