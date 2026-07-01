import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import '../pages/monitoring_page.dart';

class FieldFormSheet extends StatelessWidget {
  const FieldFormSheet({
    super.key,
    required this.points,
    required this.onDelete,
    required this.onRedraw,
  });

  final List<LatLng> points;
  final VoidCallback onDelete;
  final VoidCallback onRedraw;

  void _copyAll(BuildContext context) {
    hapticMedium();
    final text = points
        .asMap()
        .entries
        .map((e) =>
            '${e.key + 1}. ${e.value.latitude.toStringAsFixed(7)}, '
            '${e.value.longitude.toStringAsFixed(7)}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('allCoordsCopied'.tr()),
      backgroundColor: kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).padding.bottom;
    final bg = isDark ? const Color(0xFF111111) : const Color(0xFFEEF1EE);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(50) : Colors.black.withAlpha(20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kGreen, kGreenLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [BoxShadow(color: kGreen.withAlpha(80), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(Icons.crop_landscape_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'fieldDataTitle'.tr(),
                        style: TextStyle(
                          fontSize: context.rs(15.0, 17.0),
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: kGreen.withAlpha(isDark ? 45 : 28),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'cornerPointsCount'.tr(namedArgs: {'count': points.length.toString()}),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? kGreenLight : kGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () { hapticLight(); Navigator.pop(context); },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withAlpha(60), indent: 20, endIndent: 20),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.38,
            ),
            child: _CoordsList(points: points, isDark: isDark, colorScheme: colorScheme, onCopyAll: () => _copyAll(context)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 16),
            child: Column(
              children: [
                _MonitoringButton(
                  onTap: () {
                    hapticMedium();
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => MonitoringPage(points: points),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: hTap(() {
                          Navigator.pop(context);
                          onRedraw();
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
                          ),
                        ),
                        child: Text('redraw'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: hTapHeavy(() {
                          Navigator.pop(context);
                          onDelete();
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: kError,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: kError, width: 1.2),
                          ),
                        ),
                        child: Text('deleteField'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordsList extends StatelessWidget {
  const _CoordsList({
    required this.points,
    required this.isDark,
    required this.colorScheme,
    required this.onCopyAll,
  });

  final List<LatLng> points;
  final bool isDark;
  final ColorScheme colorScheme;
  final VoidCallback onCopyAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
          child: Row(
            children: [
              Text(
                'coordinates'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onCopyAll,
                style: TextButton.styleFrom(
                  foregroundColor: kGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('copyAll'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: points.length,
            itemBuilder: (context, i) {
              final p = points[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(8) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDark
                      ? null
                      : [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 1))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [kGreen, kGreenLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${p.latitude.toStringAsFixed(6)},  ${p.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        hapticLight();
                        Clipboard.setData(ClipboardData(
                          text: '${p.latitude.toStringAsFixed(7)}, ${p.longitude.toStringAsFixed(7)}',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('pointCopied'.tr(namedArgs: {'index': '${i + 1}'})),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kGreen.withAlpha(isDark ? 35 : 18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.copy_rounded, size: 14, color: kGreen),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _MonitoringButton extends StatelessWidget {
  const _MonitoringButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1D6AE5);
    const blueLight = Color(0xFF4B8FF5);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [blue, blueLight], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: blue.withAlpha(90), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'monitoringBtn'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
