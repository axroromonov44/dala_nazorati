import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import '../../../fields/presentation/bloc/fields_bloc.dart';
import '../../../reference/domain/repositories/reference_repository.dart';
import '../bloc/map_bloc.dart';
import '../widgets/app_download_dialog.dart';
import '../widgets/location_map.dart';
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
    // `user/me` is fetched once at app bootstrap, independent of the map
    // tab — see `MainPage.initState`, not here, so it isn't tied to
    // this tab ever being opened.

    final includeCatalog = !getIt<ReferenceRepository>().isCatalogCached();
    final mapDownload = computeRegionalMapDownload(context);
    if (includeCatalog || mapDownload != null) {
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
      body: BlocBuilder<MapBloc, MapState>(
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

