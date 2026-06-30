import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacings.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import '../bloc/map_bloc.dart';

class FakeGpsPage extends StatelessWidget {
  const FakeGpsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: Padding(
              padding: EdgeInsets.all(context.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Align(
                    child: Container(
                      width: context.rs(100.0, 136.0),
                      height: context.rs(100.0, 136.0),
                      decoration: BoxDecoration(
                        color: kError.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.gps_off_rounded,
                        size: context.rs(52.0, 72.0),
                        color: kError,
                      ),
                    ),
                  ),
                  SizedBox(height: context.spaceXl),
                  Text(
                    'fakeGpsTitle'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: kError,
                        ),
                  ),
                  SizedBox(height: context.spaceMd),
                  Text(
                    'fakeGpsDescription'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                  SizedBox(height: context.spaceLg),
                  Container(
                    padding: EdgeInsets.all(context.spaceMd),
                    decoration: BoxDecoration(
                      color: kError.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kError.withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Step(number: '1', text: 'fakeGpsStep1'.tr()),
                        kVerticalSpace8,
                        _Step(number: '2', text: 'fakeGpsStep2'.tr()),
                        kVerticalSpace8,
                        _Step(number: '3', text: 'fakeGpsStep3'.tr()),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: kWhite,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text('fakeGpsRetry'.tr()),
                    onPressed: hTap(() =>
                        context.read<MapBloc>().add(const MapLocationStarted())),
                  ),
                  SizedBox(height: context.spaceMd),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.rs(24.0, 32.0),
            height: context.rs(24.0, 32.0),
            decoration: const BoxDecoration(
              color: kError,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                color: kWhite,
                fontSize: context.rs(12.0, 15.0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: context.spaceSm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      );
}
