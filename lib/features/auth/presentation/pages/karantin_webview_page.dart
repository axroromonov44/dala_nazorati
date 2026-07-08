import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/karantin_config.dart';

// Real browsers append a distinctive suffix that embedded WebViews omit by
// default — some identity-verification pages sniff this to decide whether
// to allow the getUserMedia face-scan camera at all. Presenting as a real
// browser avoids that block without touching the remote page.
const String _iosSafariUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 '
    'Safari/604.1';
const String _androidChromeUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Mobile Safari/537.36';

/// [KarantinIdConfig.redirectUri]'ga o'tishga urinadi — shu daqiqada
class KarantinWebViewPage extends StatefulWidget {
  const KarantinWebViewPage({super.key});

  @override
  State<KarantinWebViewPage> createState() => _KarantinWebViewPageState();
}

class _KarantinWebViewPageState extends State<KarantinWebViewPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    // Android WebView only actually delivers the camera stream to the page
    // (even after `request.grant()`) if the app already holds the OS-level
    // CAMERA runtime permission — request it upfront so face-scan works.
    final statuses = await [Permission.camera, Permission.microphone].request();
    final cameraStatus = statuses[Permission.camera];
    if (cameraStatus == PermissionStatus.permanentlyDenied && mounted) {
      await _showPermissionDeniedDialog();
    }

    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // iOS defaults to promoting <video> to native fullscreen playback
      // unless inline playback is explicitly allowed — that's what forced
      // the face-scan camera out of the site's circular preview.
      params =
          WebKitWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
            params,
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          );
    }

    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) {
        debugPrint('[KarantinID] permission request: ${request.types}');
        request.grant();
      },
    );

    await controller.setUserAgent(
      Platform.isIOS ? _iosSafariUserAgent : _androidChromeUserAgent,
    );

    if (controller.platform is AndroidWebViewController) {
      // Without this, tapping a face-scan camera input on Android WebView
      // silently does nothing — there's no default file/camera chooser UI
      // unless the app supplies one.
      await (controller.platform as AndroidWebViewController)
          .setOnShowFileSelector(_onShowFileSelector);
    }

    final authUrl = KarantinIdConfig.buildAuthorizationUrl();
    debugPrint('[KarantinID] authorization url: $authUrl');
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
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
    );
    await controller.loadRequest(Uri.parse(authUrl));

    if (mounted) {
      setState(() => _controller = controller);
    }
  }

  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    debugPrint(
      '[KarantinID] file selector requested, capture=${params.isCaptureEnabled}',
    );
    final picker = ImagePicker();
    final wantsCamera =
        params.isCaptureEnabled ||
        params.acceptTypes.any((type) => type.startsWith('image/')) ||
        params.acceptTypes.any((type) => type.startsWith('video/'));
    final isVideo = params.acceptTypes.any(
      (type) => type.startsWith('video/'),
    );

    final XFile? file = isVideo
        ? await picker.pickVideo(
            source: wantsCamera ? ImageSource.camera : ImageSource.gallery,
          )
        : await picker.pickImage(
            source: wantsCamera ? ImageSource.camera : ImageSource.gallery,
          );

    if (file == null) return [];
    return [Uri.file(file.path).toString()];
  }

  Future<void> _showPermissionDeniedDialog() {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kameraga ruxsat kerak'),
        content: const Text(
          'Yuz skanerlash uchun kameradan foydalanish ruxsati talab '
          'qilinadi. Sozlamalar orqali ruxsat bering.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Sozlamalarga o\'tish'),
          ),
        ],
      ),
    );
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
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: kGreen)),
        ],
      ),
    );
  }
}
