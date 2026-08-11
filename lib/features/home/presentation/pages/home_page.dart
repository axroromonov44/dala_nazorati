import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/notifications/app_notification.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../../fields/presentation/bloc/fields_bloc.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../reference/domain/repositories/reference_repository.dart';
import '../bloc/map_bloc.dart';
import '../widgets/app_download_dialog.dart';
import '../widgets/location_map.dart';
import '../widgets/notifications_panel.dart';
import 'fake_gps_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => getIt<MapBloc>()..add(const MapLocationStarted()),
      ),
      BlocProvider(create: (_) => getIt<FieldsBloc>()),
    ],
    child: const _HomeView(),
  );
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _drawingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    unawaited(context.read<ProfileCubit>().refresh());

    // One combined download dialog covers both concerns, never two popups:
    // - reference catalog: fresh after every login (logout wipes
    //   referenceDataBox), skipped on a plain app resume where it's cached.
    // - regional map tiles: decided synchronously from already-cached field
    //   bounds (no GPS wait) — see `computeRegionalMapDownload`.
    final includeCatalog = !getIt<ReferenceRepository>().isCatalogCached();
    final mapDownload = computeRegionalMapDownload(context);
    if (includeCatalog || mapDownload != null) {
      // Let the home page (map, identity header) settle in first — the
      // dialog interrupts less if it isn't the very first thing the user
      // sees.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          unawaited(
            showAppDownloadDialog(
              context,
              includeCatalog: includeCatalog,
              mapDownload: mapDownload,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _drawingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          BlocBuilder<MapBloc, MapState>(
            builder: (context, state) => switch (state) {
              MapInitial() => const SizedBox.expand(),
              MapLocationLoading() => const _LoadingView(),
              MapLocationLoaded(:final location) => LocationMap(
                location: location,
                drawingNotifier: _drawingNotifier,
              ),
              MapFakeGpsDetected() => const FakeGpsPage(),
              MapLocationFailure(:final message) => _ErrorView(
                message: message,
              ),
            },
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + context.spaceSm,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _drawingNotifier,
              builder: (context, isDrawing, child) => AnimatedOpacity(
                opacity: isDrawing ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: Builder(
                    builder: (context) {
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        'mapTitle'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white : kGreen,
                          fontSize: context.rs(18.0, 22.0),
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: isDark
                                  ? Colors.black54
                                  : Colors.white.withAlpha(200),
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: _drawingNotifier,
            builder: (ctx, isDrawing, child) {
              if (isDrawing) return const SizedBox.shrink();
              return Positioned(
                top: MediaQuery.of(context).padding.top + context.spaceSm,
                left: context.rs(12.0, 18.0),
                child: const _ProfileButton(),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: _drawingNotifier,
            builder: (ctx, isDrawing, child) {
              if (isDrawing) return const SizedBox.shrink();
              return Positioned(
                top: MediaQuery.of(context).padding.top + context.spaceSm,
                right: context.rs(12.0, 18.0),
                child: const _NotificationButton(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationCenter.items,
      builder: (context, items, child) => Stack(
        clipBehavior: Clip.none,
        children: [
          _FloatingButton(
            heroTag: 'notifications',
            onPressed: hTap(() => showNotificationsPanel(context))!,
            child: const Icon(Icons.notifications_none_rounded),
          ),
          if (items.isNotEmpty)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: kError,
                  shape: BoxShape.circle,
                  border: Border.all(color: kWhite, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: kGreen));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off, size: context.iconLg, color: kGreen),
          SizedBox(height: context.spaceMd),
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: context.spaceMd),
          ElevatedButton(
            onPressed: hTap(
              () => context.read<MapBloc>().add(const MapLocationStarted()),
            ),
            child: Text('retry'.tr()),
          ),
        ],
      ),
    ),
  );
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({
    required this.heroTag,
    required this.child,
    required this.onPressed,
  });

  final String heroTag;
  final Widget child;
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
    final iconTheme = IconThemeData(size: context.fabIconSize, color: fg);

    if (context.isTablet) {
      return FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 3,
        shape: shape,
        child: IconTheme(data: iconTheme, child: child),
      );
    }
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 3,
      shape: shape,
      child: IconTheme(data: iconTheme, child: child),
    );
  }
}

class _ProfileButton extends StatefulWidget {
  const _ProfileButton();

  @override
  State<_ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends State<_ProfileButton> {
  // Mirrors `ProfileAvatar`'s loaded-tracking: the verified badge only
  // appears once the real photo has actually decoded for the current URL.
  String? _loadedForUrl;

  void _markLoaded(String url) {
    if (_loadedForUrl == url) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _loadedForUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A2A2A) : kWhite;
    final fg = isDark ? kGreenLight : kGreen;
    final imageUrl = context.watch<ProfileCubit>().state?.imageUrl;
    final hasPhoto = imageUrl != null && imageUrl.isNotEmpty;
    final size = context.rs(40.0, 56.0);
    final radius = context.fabRadius;
    final showBadge = hasPhoto && _loadedForUrl == imageUrl;

    return GestureDetector(
      onTap: hTap(() => context.push('/profile')),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: hasPhoto ? const EdgeInsets.all(2) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: fg),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                hasPhoto ? radius - 2 : radius,
              ),
              child: hasPhoto
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _ProfileFallbackIcon(color: fg),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          _markLoaded(imageUrl);
                          return child;
                        }
                        return _ProfileFallbackIcon(color: fg);
                      },
                    )
                  : _ProfileFallbackIcon(color: fg),
            ),
          ),
          if (showBadge)
            Positioned(
              right: -size * 0.04,
              bottom: -size * 0.04,
              child: ProfileVerifiedBadge(avatarSize: size, sizeBoost: 2),
            ),
        ],
      ),
    );
  }
}

class _ProfileFallbackIcon extends StatelessWidget {
  const _ProfileFallbackIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      Icons.account_circle_rounded,
      size: context.fabIconSize,
      color: color,
    ),
  );
}
