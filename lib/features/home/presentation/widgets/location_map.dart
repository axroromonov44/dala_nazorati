import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/connectivity/connectivity_cubit.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/map/tile_cache_service.dart';
import '../../../../core/map/tile_math.dart';
import '../../../../core/map/uzbekistan_regions.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacings.dart';
import '../../../fields/domain/entities/field_detail.dart';
import '../../../fields/domain/entities/field_summary.dart';
import '../../../fields/domain/repositories/field_repository.dart';
import '../../../fields/presentation/bloc/fields_bloc.dart';
import '../../domain/entities/location_point.dart';
import '../bloc/map_bloc.dart';
import 'field_form_sheet.dart';
import 'offline_map_download_dialog.dart';

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
  bool _offlineDialogChecked = false;
  bool _introPlayed = false;
  final List<List<LatLng>> _polygons = [];
  final List<LatLng> _currentPoints = [];
  Timer? _viewportDebounce;

  static const _tileSubdomains = ['a', 'b', 'c', 'd'];

  // Server-synced fields render in amber, distinct from the green used for
  // fields the user is drawing/has drawn locally.
  static const _serverFieldFill = Color(0x33FF8F00);
  static const _serverFieldBorder = Color(0xFFFF8F00);

  // Joriy joylashuv atrofidagi mayda (dala chizish darajasidagi) hudud —
  // viloyat bo'yicha keshdan farqli, bu doim yangilanib turishi kerak
  // (25 kunda bir marta), shuning uchun alohida, kichikroq va yuqori
  // zoom'li qilib saqlanadi.
  static const _fieldRadiusMeters = 1000.0;
  static const _fieldMinZoom = 14;
  static const _fieldMaxZoom = 18;

  // Joriy joylashuv qaysi viloyatda bo'lsa, o'sha atrofidagi kengroq
  // (lekin kam tafsilotli) hudud — bir martalik, foydalanuvchi hozir
  // turgan joyga qarab avtomatik markazlashadi (butun viloyat emas —
  // ba'zi viloyatlar juda katta, shuning uchun joriy joylashuv atrofi).
  static const _regionalRadiusMeters = 30000.0;
  static const _regionalMinZoom = 10;
  // 15 edi — z14/z15 hududning 90%+ og'irligini tashkil qilardi (30km radius
  // + retina tayllar bilan ~340 MB), lekin bu qatlam "kam tafsilotli umumiy
  // ko'rinish" uchun (yuqoridagi izohga qarang) — yaqin-diqqat tafsilot
  // joriy joylashuv atrofidagi alohida `_field*` qatlamdan keladi. 13 gacha
  // tushirish umumiy (regional+field) yuklab olishni ~370 MB dan ~50 MB ga
  // tushiradi, kartaning maqsadidan (keng, kam tafsilotli umumiy ko'rinish)
  // hech narsa yo'qotmay.
  static const _regionalMaxZoom = 13;

  String _tileUrlFor(bool isDark) => isDark
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  /// Bitta xarita ochilishida bittagina taklif dialogi chiqadi — agar
  /// viloyat va joy-darajasidagi hududlarning ikkalasi ham hali yuklab
  /// olinmagan bo'lsa, ular BITTA umumiy hajm/bitta tasdiq bilan
  /// birlashtiriladi (foydalanuvchiga ikki marta savol berilmaydi). Faqat
  /// biri kerak bo'lsa (masalan viloyat allaqachon yuklangan, joy-darajasi
  /// esa 25 kunda yangilanishi kerak bo'lsa), faqat o'sha bittasi so'raladi.
  /// Viloyat nomi foydalanuvchining joriy joylashuviga qarab avtomatik
  /// aniqlanadi (masalan Qashqadaryoda bo'lsa — "Qashqadaryo xaritasi...").
  void _maybePromptOfflineDownload() {
    if (_offlineDialogChecked || !mounted) return;
    _offlineDialogChecked = true;

    final center = LatLng(widget.location.latitude, widget.location.longitude);
    final isOnline = context.read<ConnectivityCubit>().state;
    if (!isOnline) return;

    final regionalRegionId = TileCacheService.regionalRegionId(center);
    final regionalPending = TileCacheService.shouldPromptDownload(
      regionalRegionId,
      isOnline: isOnline,
      checkFreshness: false,
    );
    final fieldRegionId = TileCacheService.locationRegionId(center);
    final fieldPending = TileCacheService.shouldPromptDownload(fieldRegionId, isOnline: isOnline);

    final jobs = [
      if (regionalPending)
        TileDownloadJob(
          regionId: regionalRegionId,
          center: center,
          radiusMeters: _regionalRadiusMeters,
          minZoom: _regionalMinZoom,
          maxZoom: _regionalMaxZoom,
          checkFreshness: false,
        ),
      if (fieldPending)
        TileDownloadJob(
          regionId: fieldRegionId,
          center: center,
          radiusMeters: _fieldRadiusMeters,
          minZoom: _fieldMinZoom,
          maxZoom: _fieldMaxZoom,
        ),
    ];
    if (jobs.isEmpty) return;

    final regionName =
        UzbekistanRegions.nearestTo(center).localizedName(context.locale.languageCode);

    final String title;
    final String body;
    if (regionalPending && fieldPending) {
      title = 'offlineMapCombinedTitle'.tr(namedArgs: {'region': regionName});
      body = 'offlineMapCombinedBody'.tr(namedArgs: {'region': regionName});
    } else if (regionalPending) {
      title = 'offlineMapCityTitle'.tr(namedArgs: {'region': regionName});
      body = 'offlineMapCityBody'.tr(namedArgs: {'region': regionName});
    } else {
      title = 'offlineMapTitle'.tr();
      body = 'offlineMapBody'.tr();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showOfflineMapDownloadDialog(
      context,
      jobs: jobs,
      title: title,
      body: body,
      urlTemplate: _tileUrlFor(isDark),
      subdomains: _tileSubdomains,
      retina: RetinaMode.isHighDensity(context),
    );
  }

  /// App ochilganda avval butun Toshkent shahri ko'rinishi (kamera shahar
  /// chegarasiga moslanadi), keyin 3-4 sekunddan so'ng joriy joylashuvga
  /// silliq yaqinlashadi. Yuklab olish dialogi esa joriy joylashuv
  /// ko'rsatilib bo'lgach (parvoz animatsiyasi tugagach), yana 2 soniyadan
  /// keyin chiqadi — shaharni ko'rsatish bilan bir vaqtda emas.
  void _playCityIntro() {
    if (_introPlayed || !mounted) return;
    _introPlayed = true;

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      _flyTo(LatLng(widget.location.latitude, widget.location.longitude), zoom: 15.5);

      final flyDuration = _flyController.duration ?? const Duration(milliseconds: 900);
      Future.delayed(flyDuration + const Duration(seconds: 2), () {
        if (!mounted) return;
        _maybePromptOfflineDownload();
      });
    });
  }

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
    TileCacheService.cacheVersion.addListener(_onCacheCleared);
  }

  /// Kesh sozlamalardan (drawer) tozalansa, xarita hali ochiq turgan bo'lsa
  /// ham — drawer yopilgach — yuklab olish taklifi qayta so'raladi, foydalanuvchi
  /// ilovani qayta ochishiga hojat qolmaydi. Drawer yopilish animatsiyasi
  /// tugashi uchun kichik kechikish beriladi.
  void _onCacheCleared() {
    if (!mounted) return;
    _offlineDialogChecked = false;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _maybePromptOfflineDownload();
    });
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
    TileCacheService.cacheVersion.removeListener(_onCacheCleared);
    _viewportDebounce?.cancel();
    _flyController.dispose();
    _flyCurve.dispose();
    super.dispose();
  }

  /// Map pan/zoom fires far more often than the visible field-polygon list
  /// actually needs to change, so the viewport query dispatched to
  /// [FieldsBloc] is debounced here rather than on every camera tick.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      context.read<FieldsBloc>().add(
            FieldsViewportChanged(
              bounds: camera.visibleBounds,
              zoom: camera.zoom,
            ),
          );
    });
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
    final serverFields = context.read<FieldsBloc>().state.fields;
    for (final field in serverFields) {
      if (field.points.length >= 3 && _isPointInPolygon(point, field.points)) {
        _showServerFieldDetail(field);
        return;
      }
    }
    for (int i = 0; i < _polygons.length; i++) {
      if (_polygons[i].length >= 3 && _isPointInPolygon(point, _polygons[i])) {
        _showFieldFormSheet(i);
        return;
      }
    }
  }

  void _showServerFieldDetail(FieldSummary field) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: context.isTablet
          ? BoxConstraints(maxWidth: context.sheetMaxWidth)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ServerFieldDetailSheet(field: field),
    );
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

    final tileUrl = _tileUrlFor(isDark);

    final polygonFill = isDark
        ? kGreenLight.withAlpha(60)
        : kGreen.withAlpha(50);
    final polygonBorder = isDark ? kGreenLight : kGreen;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            // Birinchi ochilishda joriy joylashuv atrofidagi kengroq hudud
            // ko'rinadi, so'ng `_playCityIntro` orqali aniq joylashuvga
            // yaqinlashiladi.
            initialCameraFit: CameraFit.bounds(
              bounds: TileMath.boundsFor(latLng, _regionalRadiusMeters),
              padding: const EdgeInsets.all(24),
            ),
            onMapReady: () {
              setState(() => _mapReady = true);
              _playCityIntro();
            },
            onTap: _onMapTap,
            onPositionChanged: _onPositionChanged,
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: _tileSubdomains,
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
            BlocBuilder<FieldsBloc, FieldsState>(
              builder: (context, state) => PolygonLayer(
                polygonCulling: true,
                simplificationTolerance: 3,
                polygons: [
                  for (final field in state.fields)
                    if (field.points.length >= 3)
                      Polygon(
                        points: field.points,
                        color: _serverFieldFill,
                        borderColor: _serverFieldBorder,
                        borderStrokeWidth: 2,
                      ),
                ],
              ),
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

/// Minimal detail view for a server-synced field, tapped from the amber
/// polygon layer. Fetches full detail (description/crop info/photo
/// metadata) on demand — never eagerly downloaded as part of the index
/// sync. Wiring this into the full multi-tab form (photos gallery, editing)
/// is a follow-up UI task; this sheet only proves the offline-detail path
/// end to end (network first, cached fallback via [FieldRepository]).
class _ServerFieldDetailSheet extends StatelessWidget {
  const _ServerFieldDetailSheet({required this.field});

  final FieldSummary field;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            field.cropType,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FutureBuilder<FieldDetail>(
            future: getIt<FieldRepository>().getFieldDetail(field.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'errorGeneric'.tr(),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                );
              }
              return Text(
                snapshot.data!.description,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
              );
            },
          ),
        ],
      ),
    );
  }
}
