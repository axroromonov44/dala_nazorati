import 'package:flutter/material.dart';

import '../../features/home/presentation/widgets/app_download_dialog.dart';
import '../constants/app_colors.dart';
import '../di/injection.dart';
import '../router/navigation_service.dart';
import 'app_download_controller.dart';

class AppDownloadOverlay extends StatelessWidget {
  const AppDownloadOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = getIt<AppDownloadController>();
    return Stack(
      children: [
        child,
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final visible = controller.isActive && controller.minimized;
            return _AnimatedBadge(visible: visible, controller: controller);
          },
        ),
      ],
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  const _AnimatedBadge({required this.visible, required this.controller});

  final bool visible;
  final AppDownloadController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: visible ? Curves.easeOutBack : Curves.easeIn,
      left: 16,
      bottom: visible ? 24 + bottomInset : -80,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          child: _DownloadBadge(controller: controller),
        ),
      ),
    );
  }
}

class _DownloadBadge extends StatelessWidget {
  const _DownloadBadge({required this.controller});

  final AppDownloadController controller;

  void _reopen() {
    controller.restore();
    final navigatorContext = NavigationService.navigatorKey.currentContext;
    if (navigatorContext != null) {
      showAppDownloadProgressDialog(navigatorContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _reopen,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: kGreen,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: controller.hasFailures ? null : controller.fraction,
                  strokeWidth: 3,
                  color: kWhite,
                  backgroundColor: Colors.white24,
                ),
              ),
              const Icon(Icons.file_download_rounded, color: kWhite, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
