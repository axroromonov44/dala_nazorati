import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class LocationMap extends StatefulWidget {
  const LocationMap({super.key, required this.location});

  final LocationPoint location;

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
  final List<LatLng> _drawnPoints = [];

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

  void _onMapTap(TapPosition tapPos, LatLng point) {
    if (!_isDrawing) return;
    setState(() => _drawnPoints.add(point));
  }

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _drawnPoints.clear();
    });
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawing = false;
      _drawnPoints.clear();
    });
  }

  void _removeLastPoint() {
    if (_drawnPoints.isEmpty) return;
    setState(() => _drawnPoints.removeLast());
  }

  void _finishDrawing() {
    if (_drawnPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('minPointsRequired'.tr()),
          backgroundColor: kError,
        ),
      );
      return;
    }
    setState(() => _isDrawing = false);
    _showCornersSheet();
  }

  void _showCornersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Planshetda keng ekranda narrow sheet
      constraints: context.isTablet
          ? BoxConstraints(maxWidth: context.sheetMaxWidth)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CornersSheet(
        points: List.unmodifiable(_drawnPoints),
        onClear: () {
          Navigator.pop(context);
          setState(() => _drawnPoints.clear());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latLng = LatLng(widget.location.latitude, widget.location.longitude);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = context.watch<ConnectivityCubit>().state;

    // {r} → Retina ekranda @2x tile yuklaydi (matnlar 2x aniqroq)
    // Light: Voyager | Dark: Dark All
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
              // Oflaynda keshdan darhol qaytaradi, onlaynda yangilaydi
              tileProvider: TileCacheService.build(isOnline: isOnline),
              // Dark mode da obektlar (yo'llar, binolar) aniqroq ko'rinsin
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

            // Chizilgan polygon
            if (_drawnPoints.length >= 2)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _drawnPoints,
                    color: polygonFill,
                    borderColor: polygonBorder,
                    borderStrokeWidth: 2.5,
                  ),
                ],
              ),

            // Chizilgan nuqtalar (raqamli markerlar)
            if (_drawnPoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  for (var i = 0; i < _drawnPoints.length; i++)
                    Marker(
                      point: _drawnPoints[i],
                      width: 28,
                      height: 28,
                      child: _CornerMarker(index: i + 1),
                    ),
                ],
              ),

            // Foydalanuvchi lokatsiyasi
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

        // Zoom + my_location + draw buttons (o'ng tomon)
        Positioned(
          bottom: (_isDrawing || (_drawnPoints.length >= 3 && !_isDrawing))
              ? context.rs(120.0, 160.0)
              : context.rs(32.0, 48.0),
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
              if (!_isDrawing && _drawnPoints.isEmpty) ...[
                kVerticalSpace8,
                _MapButton(
                  heroTag: 'draw_field',
                  icon: Icons.draw_rounded,
                  onPressed: hTap(_startDrawing)!,
                ),
              ],
            ],
          ),
        ),

        // Pastki panel — faqat chizish rejimida yoki polygon tayyor bo'lganda
        if (_isDrawing || (_drawnPoints.length >= 3 && !_isDrawing))
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _DrawingPanel(
              isDrawing: _isDrawing,
              pointCount: _drawnPoints.length,
              hasPolygon: _drawnPoints.length >= 3 && !_isDrawing,
              onStartDraw: _startDrawing,
              onFinish: _finishDrawing,
              onUndo: _removeLastPoint,
              onCancel: _cancelDrawing,
              onShowResult: _showCornersSheet,
              onClear: () => setState(() => _drawnPoints.clear()),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Drawing bottom panel
// ---------------------------------------------------------------------------

class _DrawingPanel extends StatelessWidget {
  const _DrawingPanel({
    required this.isDrawing,
    required this.pointCount,
    required this.hasPolygon,
    required this.onStartDraw,
    required this.onFinish,
    required this.onUndo,
    required this.onCancel,
    required this.onShowResult,
    required this.onClear,
  });

  final bool isDrawing;
  final int pointCount;
  final bool hasPolygon;
  final VoidCallback onStartDraw;
  final VoidCallback onFinish;
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback onShowResult;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final h = context.spaceMd;
    return Container(
      padding: EdgeInsets.fromLTRB(
        h,
        context.spaceSm,
        h,
        MediaQuery.of(context).padding.bottom + context.spaceSm,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: isDrawing
          ? _DrawingControls(
              pointCount: pointCount,
              onFinish: onFinish,
              onUndo: onUndo,
              onCancel: onCancel,
            )
          : _PolygonDoneControls(
              onShowResult: onShowResult,
              onClear: onClear,
              onRedraw: onStartDraw,
            ),
    );
  }
}

class _DrawingControls extends StatelessWidget {
  const _DrawingControls({
    required this.pointCount,
    required this.onFinish,
    required this.onUndo,
    required this.onCancel,
  });

  final int pointCount;
  final VoidCallback onFinish;
  final VoidCallback onUndo;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.touch_app_rounded, color: kGreen, size: context.iconSm),
            SizedBox(width: context.spaceSm),
            Text(
              'drawHint'.tr(namedArgs: {'count': pointCount.toString()}),
              style: TextStyle(
                color: kGreen,
                fontWeight: FontWeight.w600,
                fontSize: context.rs(13.0, 16.0),
              ),
            ),
          ],
        ),
        SizedBox(height: context.spaceSm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hTapHeavy(onCancel),
                icon: const Icon(Icons.close, size: 18),
                label: Text('cancel'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kError,
                  side: const BorderSide(color: kError),
                ),
              ),
            ),
            kHorizontalSpace8,
            OutlinedButton(
              onPressed: hTap(pointCount > 0 ? onUndo : null),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextSecondary,
                side: const BorderSide(color: kTextSecondary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              child: const Icon(Icons.undo_rounded, size: 20),
            ),
            kHorizontalSpace8,
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hTapMedium(pointCount >= 3 ? onFinish : null),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text('done'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolygonDoneControls extends StatelessWidget {
  const _PolygonDoneControls({
    required this.onShowResult,
    required this.onClear,
    required this.onRedraw,
  });

  final VoidCallback onShowResult;
  final VoidCallback onClear;
  final VoidCallback onRedraw;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hTapHeavy(onClear),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text('deleteLabel'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: kError,
              side: const BorderSide(color: kError),
            ),
          ),
        ),
        kHorizontalSpace8,
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hTap(onRedraw),
            icon: const Icon(Icons.draw_rounded, size: 18),
            label: Text('redraw'.tr()),
          ),
        ),
        kHorizontalSpace8,
        Expanded(
          child: ElevatedButton.icon(
            onPressed: hTap(onShowResult),
            icon: const Icon(Icons.list_alt_rounded, size: 18),
            label: Text('coordinates'.tr()),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Corners result bottom sheet
// ---------------------------------------------------------------------------

class _CornersSheet extends StatelessWidget {
  const _CornersSheet({required this.points, required this.onClear});

  final List<LatLng> points;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (sheetCtx, controller) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: kPaddingH16,
              child: Row(
                children: [
                  const Icon(Icons.crop_free_rounded, color: kGreen),
                  kHorizontalSpace8,
                  Text(
                    'fieldCorners'.tr(
                      namedArgs: {'count': points.length.toString()},
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      final text = points
                          .asMap()
                          .entries
                          .map(
                            (e) =>
                                '${e.key + 1}. ${e.value.latitude.toStringAsFixed(7)}, '
                                '${e.value.longitude.toStringAsFixed(7)}',
                          )
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('coordinatesCopied'.tr())),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, color: kGreen),
                    tooltip: 'copyLabel'.tr(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: kPaddingAll16,
                itemCount: points.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = points[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: kGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: kWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        kHorizontalSpace12,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'latitude'.tr()}:  ${p.latitude.toStringAsFixed(7)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${'longitude'.tr()}:  ${p.longitude.toStringAsFixed(7)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hTapHeavy(onClear),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text('deleteField'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kError,
                        side: const BorderSide(color: kError),
                      ),
                    ),
                  ),
                  kHorizontalSpace8,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: hTap(() => Navigator.pop(context)),
                      child: Text('close'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Corner number marker
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Pulsing location marker
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Map control button
// ---------------------------------------------------------------------------

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
