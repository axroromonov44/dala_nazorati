import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/connectivity/connectivity_cubit.dart';
import '../../../../core/map/tile_cache_service.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacings.dart';
import '../../domain/entities/location_point.dart';
import '../bloc/map_bloc.dart';
import 'field_form_sheet.dart';

class LocationMap extends StatefulWidget {
  const LocationMap({
    super.key,
    required this.location,
    required this.drawingNotifier,
  });

  final LocationPoint location;
  final ValueNotifier<bool> drawingNotifier;

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _flyController;
  late final CurvedAnimation _flyCurve;

  Animation<double>? _latAnim;
  Animation<double>? _lngAnim;
  Animation<double>? _zoomAnim;

  bool _mapReady = false;
  bool _isDrawing = false;
  final List<List<LatLng>> _polygons = [];
  final List<LatLng> _currentPoints = [];

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onFlyTick);
    _flyCurve = CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInOutCubic,
    );
  }

  void _onFlyTick() {
    if (_latAnim == null || !_mapReady) return;
    _mapController.move(
      LatLng(_latAnim!.value, _lngAnim!.value),
      _zoomAnim!.value,
    );
  }

  void _flyTo(LatLng target, {double zoom = 15.5}) {
    if (!_mapReady) return;
    final cam = _mapController.camera;
    _latAnim = Tween<double>(
      begin: cam.center.latitude,
      end: target.latitude,
    ).animate(_flyCurve);
    _lngAnim = Tween<double>(
      begin: cam.center.longitude,
      end: target.longitude,
    ).animate(_flyCurve);
    _zoomAnim = Tween<double>(begin: cam.zoom, end: zoom).animate(_flyCurve);
    _flyController.forward(from: 0);
  }

  @override
  void didUpdateWidget(LocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _flyTo(LatLng(widget.location.latitude, widget.location.longitude));
    }
  }

  @override
  void dispose() {
    _flyController.dispose();
    _flyCurve.dispose();
    super.dispose();
  }

  static const _maxRadiusMeters = 300.0;
  static const _distanceCalc = Distance();

  void _onMapTap(TapPosition tapPos, LatLng point) {
    if (_isDrawing) {
      final userLatLng =
          LatLng(widget.location.latitude, widget.location.longitude);
      final meters = _distanceCalc.as(LengthUnit.Meter, userLatLng, point);
      if (meters > _maxRadiusMeters) {
        final km = (meters / 1000).toStringAsFixed(1);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('pointTooFar'.tr(namedArgs: {'km': km}))),
                ],
              ),
              backgroundColor: kError,
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }
      setState(() => _currentPoints.add(point));
      return;
    }
    for (int i = 0; i < _polygons.length; i++) {
      if (_polygons[i].length >= 3 && _isPointInPolygon(point, _polygons[i])) {
        _showFieldFormSheet(i);
        return;
      }
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    final px = point.longitude;
    final py = point.latitude;
    final n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      if (((yi > py) != (yj > py)) &&
          px < (xj - xi) * (py - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _currentPoints.clear();
    });
    widget.drawingNotifier.value = true;
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawing = false;
      _currentPoints.clear();
    });
    widget.drawingNotifier.value = false;
  }

  void _removeLastPoint() {
    if (_currentPoints.isEmpty) return;
    setState(() => _currentPoints.removeLast());
  }

  void _finishDrawing() {
    if (_currentPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('minPointsRequired'.tr()),
          backgroundColor: kError,
        ),
      );
      return;
    }
    final completed = List<LatLng>.from(_currentPoints);
    setState(() {
      _polygons.add(completed);
      _currentPoints.clear();
      _isDrawing = false;
    });
    widget.drawingNotifier.value = false;
  }

  void _showFieldFormSheet(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: context.isTablet
          ? BoxConstraints(maxWidth: context.sheetMaxWidth)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FieldFormSheet(
        points: List.unmodifiable(_polygons[index]),
        onDelete: () => setState(() => _polygons.removeAt(index)),
        onRedraw: () {
          setState(() => _polygons.removeAt(index));
          _startDrawing();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latLng = LatLng(widget.location.latitude, widget.location.longitude);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = context.watch<ConnectivityCubit>().state;

    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    final polygonFill = isDark
        ? kGreenLight.withAlpha(60)
        : kGreen.withAlpha(50);
    final polygonBorder = isDark ? kGreenLight : kGreen;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: latLng,
            initialZoom: 15.5,
            onMapReady: () => setState(() => _mapReady = true),
            onTap: _onMapTap,
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'uz.dala.nazorati',
              maxNativeZoom: 19,
              keepBuffer: 5,
              retinaMode: RetinaMode.isHighDensity(context),
              tileDisplay: const TileDisplay.fadeIn(),
              tileProvider: TileCacheService.build(isOnline: isOnline),
              tileBuilder: isDark
                  ? (ctx, tile, _) => ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        1.35,
                        0,
                        0,
                        0,
                        18,
                        0,
                        1.35,
                        0,
                        0,
                        18,
                        0,
                        0,
                        1.35,
                        0,
                        18,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: tile,
                    )
                  : null,
            ),
            if (_isDrawing)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: latLng,
                    radius: _maxRadiusMeters,
                    useRadiusInMeter: true,
                    color: kGreen.withAlpha(18),
                    borderColor: kGreen.withAlpha(160),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            for (final poly in _polygons)
              if (poly.length >= 2)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: poly,
                      color: polygonFill,
                      borderColor: polygonBorder,
                      borderStrokeWidth: 2.5,
                    ),
                  ],
                ),
            if (_currentPoints.length >= 2)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _currentPoints,
                    color: kGreen.withAlpha(30),
                    borderColor: kGreen,
                    borderStrokeWidth: 2.5,
                  ),
                ],
              ),
            if (_currentPoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  for (var i = 0; i < _currentPoints.length; i++)
                    Marker(
                      point: _currentPoints[i],
                      width: 28,
                      height: 28,
                      child: _CornerMarker(index: i + 1),
                    ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: latLng,
                  width: 48,
                  height: 48,
                  child: const _PulsingMarker(),
                ),
              ],
            ),
          ],
        ),
        if (!_isDrawing)
          Positioned(
            bottom: context.rs(32.0, 48.0),
            right: context.rs(16.0, 24.0),
            child: Column(
              children: [
                _MapButton(
                  heroTag: 'zoom_in',
                  icon: Icons.add,
                  onPressed: hTap(
                    () => _flyTo(
                      _mapController.camera.center,
                      zoom: _mapController.camera.zoom + 1,
                    ),
                  )!,
                ),
                kVerticalSpace8,
                _MapButton(
                  heroTag: 'zoom_out',
                  icon: Icons.remove,
                  onPressed: hTap(
                    () => _flyTo(
                      _mapController.camera.center,
                      zoom: _mapController.camera.zoom - 1,
                    ),
                  )!,
                ),
                kVerticalSpace8,
                _MapButton(
                  heroTag: 'my_location',
                  icon: Icons.my_location,
                  onPressed: hTap(() {
                    _flyTo(latLng, zoom: 15.5);
                    context.read<MapBloc>().add(const MapLocationStarted());
                  })!,
                ),
                kVerticalSpace8,
                _MapButton(
                  heroTag: 'draw_field',
                  icon: Icons.draw_rounded,
                  onPressed: hTap(_startDrawing)!,
                ),
              ],
            ),
          ),
        if (_isDrawing) ...[
          Positioned(
            top: MediaQuery.of(context).padding.top + context.spaceSm,
            left: context.rs(12.0, 18.0),
            child: _DrawingTopButton(
              heroTag: 'undo_draw',
              icon: Icons.undo_rounded,
              label: 'undo'.tr(),
              enabled: _currentPoints.isNotEmpty,
              isDark: isDark,
              onPressed: hTap(_currentPoints.isNotEmpty ? _removeLastPoint : null),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + context.spaceSm,
            right: context.rs(12.0, 18.0),
            child: _DrawingDoneButton(
              enabled: _currentPoints.length >= 3,
              onPressed: hTapMedium(_currentPoints.length >= 3 ? _finishDrawing : null),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _DrawingBottomBar(
              pointCount: _currentPoints.length,
              onCancel: _cancelDrawing,
            ),
          ),
        ],
      ],
    );
  }
}

class _DrawingTopButton extends StatelessWidget {
  const _DrawingTopButton({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.isDark,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isDark;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2A2A2A) : kWhite;
    final fg = enabled
        ? (isDark ? kGreenLight : kGreen)
        : (isDark ? Colors.white24 : Colors.black26);

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(context.fabRadius),
          border: Border.all(color: fg, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingDoneButton extends StatelessWidget {
  const _DrawingDoneButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [kGreen, kGreenLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : Colors.grey.withAlpha(80),
          borderRadius: BorderRadius.circular(context.fabRadius),
          boxShadow: enabled
              ? [BoxShadow(color: kGreen.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 18,
                color: enabled ? Colors.white : Colors.white54),
            const SizedBox(width: 5),
            Text(
              'done'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: enabled ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingBottomBar extends StatelessWidget {
  const _DrawingBottomBar({
    required this.pointCount,
    required this.onCancel,
  });

  final int pointCount;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: kGreen.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGreen.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_rounded, color: kGreen, size: 15),
                const SizedBox(width: 6),
                Text(
                  pointCount == 0
                      ? 'drawingPrompt'.tr()
                      : 'drawingPointsAdded'.tr(namedArgs: {'count': pointCount.toString()}),
                  style: const TextStyle(
                    color: kGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: hTapHeavy(onCancel),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text(
                'cancelAction'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kError,
                side: const BorderSide(color: kError, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  const _CornerMarker({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: kGreen,
      shape: BoxShape.circle,
      border: Border.all(color: kWhite, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
    ),
    child: Text(
      '$index',
      style: const TextStyle(
        color: kWhite,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    ),
  );
}

class _PulsingMarker extends StatefulWidget {
  const _PulsingMarker();

  @override
  State<_PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<_PulsingMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _scale = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 48 * _scale.value,
            height: 48 * _scale.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGreen.withAlpha(60),
              border: Border.all(color: kGreen.withAlpha(120), width: 1.5),
            ),
          ),
        ),
      ),
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: kGreen,
          shape: BoxShape.circle,
          border: Border.all(color: kWhite, width: 3),
          boxShadow: [
            BoxShadow(
              color: kGreen.withAlpha(120),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    ],
  );
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.heroTag,
    required this.icon,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A2A2A) : kWhite;
    final fg = isDark ? kGreenLight : kGreen;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(context.fabRadius),
      side: BorderSide(color: fg),
    );
    final child = Icon(icon, size: context.fabIconSize);

    if (context.isTablet) {
      return FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 3,
        shape: shape,
        child: child,
      );
    }
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 3,
      shape: shape,
      child: child,
    );
  }
}
