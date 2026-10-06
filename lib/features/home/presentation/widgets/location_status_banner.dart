import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/repositories/location_repository.dart';

/// Sits over the top of the map when something stops the position from being
/// read, and disappears the moment it is fixed.
///
/// It overlays rather than replaces the map on purpose: an inspector with the
/// location switch off still needs to see the fields they came to inspect, and
/// an error page in place of the map takes that away for no gain.
class LocationStatusBanner extends StatelessWidget {
  const LocationStatusBanner({
    super.key,
    required this.reason,
    required this.onPressed,
  });

  final LocationBlock reason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final serviceOff = reason == LocationBlock.serviceDisabled;

    final title = serviceOff
        ? 'locationServiceOffTitle'.tr()
        : 'locationPermissionBlockedTitle'.tr();
    final body = serviceOff
        ? 'locationServiceOffBody'.tr()
        : 'locationPermissionBlockedBody'.tr();
    final action = serviceOff
        ? 'locationServiceOffAction'.tr()
        : 'locationPermissionBlockedAction'.tr();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.all(context.spaceMd),
        child: Material(
          color: colorScheme.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spaceMd,
              vertical: context.spaceSm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_off_rounded,
                  color: colorScheme.error,
                  size: context.iconSm,
                ),
                SizedBox(width: context.spaceSm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.spaceSm),
                FilledButton(
                  onPressed: () {
                    hapticSelect();
                    onPressed();
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(horizontal: context.spaceMd),
                  ),
                  child: Text(action),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
