import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../bloc/map_bloc.dart';
import '../widgets/location_map.dart';
import 'fake_gps_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<MapBloc>()..add(const MapLocationStarted()),
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
  void dispose() {
    _drawingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
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
              MapLocationFailure(:final message) => _ErrorView(message: message),
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
                child: Builder(
                  builder: (ctx) => _FloatingButton(
                    heroTag: 'menu',
                    icon: Icons.menu_rounded,
                    onPressed: hTap(() => Scaffold.of(ctx).openDrawer())!,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: kGreen),
      );
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
                onPressed: hTap(() => context
                    .read<MapBloc>()
                    .add(const MapLocationStarted())),
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
