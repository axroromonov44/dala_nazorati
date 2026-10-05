import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/device/karantin_device_data.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/datasources/karantin_face_remote_datasource.dart';
import '../../data/face/karantin_face_session.dart';
import '../widgets/karantin_face_scanner.dart';
import '../widgets/karantin_passport_form.dart';

/// Native karantin-id face login page. Drop-in replacement for
/// [KarantinWebViewPage]: it collects the passport/PNFL and face entirely in
/// Flutter, submits them to the karantin-id backend, follows the OAuth redirect
/// chain, and returns the authorization `code` via `Navigator.pop` — the same
/// contract the webview honored.
class KarantinFaceAuthPage extends StatefulWidget {
  const KarantinFaceAuthPage({super.key, this.dataSource, this.collector});

  final KarantinFaceRemoteDataSource? dataSource;
  final KarantinDeviceDataCollector? collector;

  @override
  State<KarantinFaceAuthPage> createState() => _KarantinFaceAuthPageState();
}

enum _Phase { loading, form, face, success, error }

/// Terms that indicate a non-face problem (bad passport/token/expired link),
/// in which case the user should go back to the form rather than rescan.
/// Mirrors `NON_FACE_TERMS` in the web client's `apiError.ts`.
const _nonFaceTerms = [
  'passport',
  'pasport',
  'pinfl',
  'pnfl',
  'token',
  'havola',
  'link',
  'expired',
  'eskirgan',
  'one_code',
  'code',
];

class _KarantinFaceAuthPageState extends State<KarantinFaceAuthPage> {
  late final KarantinFaceRemoteDataSource _dataSource =
      widget.dataSource ?? KarantinFaceRemoteDataSource();
  late final KarantinDeviceDataCollector _collector =
      widget.collector ?? KarantinDeviceDataCollector();

  _Phase _phase = _Phase.loading;
  String _errorMessage = '';

  KarantinFaceSession? _session;
  String _identifier = '';
  bool _isPnfl = false;

  bool _isUploading = false;
  bool _isUploaded = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() => _phase = _Phase.loading);
    try {
      final session = await _dataSource.startSession();
      if ((session.token == null || session.token!.isEmpty) &&
          session.flow != KarantinFaceFlow.register) {
        _fail('Karantin ID sessiyasini ochib boʻlmadi. Qayta urinib koʻring.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _phase = _Phase.form;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Karantin ID bilan bogʻlanib boʻlmadi. Qayta urinib koʻring.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _errorMessage = message;
    });
  }

  Future<void> _onFormSubmit(String identifier, bool isPnfl) async {
    _identifier = identifier;
    _isPnfl = isPnfl;

    final token = _session?.token;
    if (token != null && token.isNotEmpty) {
      // Fire-and-forget, like the web client's sendPassport.
      unawaited(
        _dataSource.notifyLogin(token: token, passportNumber: identifier),
      );
    }

    // Prompt for location up front (awaited) so the GPS coordinates are ready by
    // the time the face is captured — they are part of the inspector anti-fraud
    // data sent to the backend.
    await _ensureLocationPermission();

    // The camera plugin itself triggers the native OS permission prompt on
    // initialize(), which is the reliable path on both platforms (and makes the
    // app appear under Settings). We no longer pre-gate with permission_handler.
    if (!mounted) return;
    setState(() => _phase = _Phase.face);
  }

  Future<void> _ensureLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      // Non-fatal: submit proceeds without coordinates.
    }
  }

  bool _permissionDialogOpen = false;

  /// Shown when the camera plugin reports the permission was denied. Uses a
  /// Cupertino-style dialog on iOS and a Material dialog on Android so each
  /// platform gets its native look.
  Future<void> _onCameraPermissionDenied() async {
    if (!mounted || _permissionDialogOpen) return;
    _permissionDialogOpen = true;

    final title = 'cameraPermissionTitle'.tr();
    final body = 'cameraPermissionBody'.tr();
    final cancel = 'cancelAction'.tr();
    final open = 'openSettings'.tr();

    final goSettings = Platform.isIOS
        ? await showCupertinoDialog<bool>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text(title),
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(body),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(cancel),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(open),
                ),
              ],
            ),
          )
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGreen),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(open),
                ),
              ],
            ),
          );

    _permissionDialogOpen = false;
    if (!mounted) return;

    if (goSettings == true) {
      await openAppSettings();
    }
    // Either way, step back to the form so the user isn't stuck on a black camera.
    if (mounted) setState(() => _phase = _Phase.form);
  }

  Future<void> _onCapture(KarantinFacePayload payload) async {
    final session = _session;
    if (session == null) return;

    setState(() => _isUploading = true);
    try {
      final device = await _collector.collect();
      final includeScreens = !session.registerState.isNotDeepened;

      final String redirectTo;
      switch (session.flow) {
        case KarantinFaceFlow.register:
          redirectTo = await _dataSource.submitRegister(
            oneCode: session.code ?? '',
            token: session.registerState.token,
            includeScreens: includeScreens,
            payload: payload,
            device: device,
          );
        case KarantinFaceFlow.verifyDocument:
          redirectTo = await _dataSource.submitVerifyDocument(
            token: session.token ?? '',
            includeScreens: includeScreens,
            payload: payload,
            device: device,
          );
        case KarantinFaceFlow.login:
          redirectTo = await _dataSource.submitLogin(
            token: session.token ?? '',
            identifier: _identifier,
            isPnfl: _isPnfl,
            includeScreens: includeScreens,
            payload: payload,
            device: device,
          );
      }

      final code = await _dataSource.followToCode(redirectTo);
      if (!mounted) return;
      setState(() {
        _isUploaded = true;
        _phase = _Phase.success;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop(code);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showError(e.message);
      if (_shouldReturnToForm(e.message)) {
        setState(() => _phase = _Phase.form);
        return;
      }
      rethrow; // keep the scanner, which resets for another attempt
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showError('Nomaʼlum xatolik. Qaytadan urinib koʻring.');
      rethrow;
    }
  }

  bool _shouldReturnToForm(String message) {
    final lower = message.toLowerCase();
    return _nonFaceTerms.any(lower.contains);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kError),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('karantinIdPageTitle'.tr()),
        backgroundColor: kGreen,
        foregroundColor: kWhite,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator(color: kGreen)),
        );
      case _Phase.error:
        return _ErrorView(message: _errorMessage, onRetry: _loadSession);
      case _Phase.form:
        return KarantinPassportForm(
          systemName: _session?.name,
          onSubmit: _onFormSubmit,
        );
      case _Phase.face:
      case _Phase.success:
        return KarantinFaceScanner(
          onCapture: _onCapture,
          isUploading: _isUploading,
          isUploaded: _isUploaded,
          onError: _showError,
          onPermissionDenied: _onCameraPermissionDenied,
        );
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: kError, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            icon: const Icon(Icons.refresh),
            label: Text('retryAction'.tr()),
          ),
        ],
      ),
    );
  }
}
