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
        builder: (context, isOnline) => AnimatedSize(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.topCenter,
          child: isOnline
              ? const SizedBox(width: double.infinity)
              : Material(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFD32F2F),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                      bottom: 5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          color: Colors.white,
                          size: 18,
                        ),
                        kHorizontalSpace8,
                        Text(
                          'noInternet'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
