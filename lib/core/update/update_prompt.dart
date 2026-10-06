import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../di/injection.dart';
import '../observability/diagnostics_log.dart';
import 'app_version.dart';
import 'remote_config_service.dart';

/// Shows the user whatever update Remote Config asks for.
///
/// A required update cannot be dismissed: neither the back button nor a tap
/// outside closes it. That is harsh on purpose — if the backend has dropped
/// the old API the app will not work anyway, and a clear instruction beats a
/// stream of "why is it erroring" calls.
Future<void> promptForUpdateIfNeeded(BuildContext context) async {
  final status = await getIt<RemoteConfigService>().checkForUpdate();
  if (status.requirement == UpdateRequirement.none) return;
  if (!context.mounted) return;

  final isRequired = status.requirement == UpdateRequirement.required;
  DiagnosticsLog.info('update', 'prompt shown: ${status.requirement.name}');

  await showDialog<void>(
    context: context,
    barrierDismissible: !isRequired,
    builder: (dialogContext) => PopScope(
      canPop: !isRequired,
      child: AlertDialog(
        title: Text(
          isRequired ? 'updateRequiredTitle'.tr() : 'updateAvailableTitle'.tr(),
        ),
        content: Text(
          // The console string wins, so an urgent release can spell out the
          // reason ("versions before 3 November stop working").
          status.message.trim().isNotEmpty
              ? status.message
              : (isRequired
                    ? 'updateRequiredBody'.tr()
                    : 'updateAvailableBody'.tr()),
        ),
        actions: [
          if (!isRequired)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('updateLater'.tr()),
            ),
          FilledButton(
            onPressed: () => _openStore(status.storeUrl),
            child: Text('updateNow'.tr()),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openStore(String configured) async {
  final url = configured.trim().isNotEmpty
      ? configured
      // With Remote Config empty: Android can go straight to the store page,
      // while iOS needs an app id, so nothing opens rather than dumping the
      // user into a search.
      : (Platform.isAndroid
            ? 'https://play.google.com/store/apps/details?id=com.nazorat.aat.uz'
            : '');
  if (url.isEmpty) return;

  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    DiagnosticsLog.warn('update', 'could not open the store', error: error);
  }
}
