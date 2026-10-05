/// Karantin ID native face-login SDK for Flutter.
///
/// Drives the front camera and on-device face detection, captures the face,
/// submits it to the Karantin ID OAuth backend and returns the authorization
/// `code` — a native replacement for the in-webview face flow.
library;

import 'package:flutter/material.dart';

import 'src/karantin_face_auth_page.dart';
import 'src/karantin_face_config.dart';

export 'src/karantin_face_auth_page.dart' show KarantinFaceAuthPage;
export 'src/karantin_face_config.dart'
    show KarantinFaceConfig, KarantinFaceStrings;
export 'src/karantin_face_exception.dart' show KarantinFaceException;
export 'src/karantin_face_remote_datasource.dart'
    show KarantinFacePayload, KarantinFaceRemoteDataSource;
export 'src/karantin_face_session.dart'
    show KarantinFaceFlow, KarantinFaceSession;

/// Convenience entry point.
///
/// Opens the native face-login screen and resolves to the OAuth `code`, or
/// `null` if the user cancelled. Exchange the code for tokens on your backend.
abstract final class KarantinFace {
  const KarantinFace._();

  static Future<String?> authenticate(
    BuildContext context, {
    required KarantinFaceConfig config,
    bool rootNavigator = true,
  }) {
    return Navigator.of(context, rootNavigator: rootNavigator).push<String?>(
      MaterialPageRoute(
        builder: (_) => KarantinFaceAuthPage(config: config),
      ),
    );
  }
}
