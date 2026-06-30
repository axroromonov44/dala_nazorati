import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacings.dart';
import 'connectivity_cubit.dart';

class NoInternetBanner extends StatelessWidget {
  const NoInternetBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          BlocBuilder<ConnectivityCubit, bool>(
            builder: (context, isOnline) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isOnline ? 0 : 36,
              color: const Color(0xFFD32F2F),
              child: isOnline
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          color: kWhite,
                          size: 16,
                        ),
                        kHorizontalSpace8,
                        Text(
                          'noInternet'.tr(),
                          style: const TextStyle(
                            color: kWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Expanded(child: child),
        ],
      );
}
