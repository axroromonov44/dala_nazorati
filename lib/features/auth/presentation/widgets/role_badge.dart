import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/inspector_role.dart';

/// Accent colour for an inspectorate; the neutral green stands in for a user
/// whose role code we could not place.
Color roleColor(InspectorRole? role) => switch (role) {
  InspectorRole.karantin => kRoleKarantin,
  InspectorRole.veterinary => kRoleVet,
  InspectorRole.ses => kRoleSes,
  null => kGreen,
};

IconData roleIcon(InspectorRole? role) => switch (role) {
  InspectorRole.karantin => Icons.eco_rounded,
  InspectorRole.veterinary => Icons.pets_rounded,
  InspectorRole.ses => Icons.science_rounded,
  null => Icons.badge_rounded,
};

String roleLabel(InspectorRole? role) =>
    (role?.labelKey ?? 'roleInspector').tr();

/// Pill showing which inspectorate the signed-in user works for.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.compact = false});

  final InspectorRole? role;

  /// Icon-tight version for app bars, where horizontal room is scarce.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 46 : 26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(isDark ? 120 : 76)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(roleIcon(role), size: compact ? 13 : 15, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            roleLabel(role),
            style: TextStyle(
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
