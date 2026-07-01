import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacings.dart';
import '../../../../core/utils/haptic.dart';
import '../bloc/auth_bloc.dart';

const _kOneIdUrl = 'https://sso.egov.uz';
const _kKarantinIdUrl = 'https://id.karantin.uz/sign-in?name=DALA+NAZORAT';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthLoginRequested(
              phone: _phoneController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  void _openWithCountdown(String url) {
    hapticMedium();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RedirectDialog(url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthBloc>().state is AuthLoading;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'phoneLabel'.tr(),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'phoneRequired'.tr() : null,
          ),
          kVerticalSpace16,
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'passwordLabel'.tr(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: kGreen,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'passwordMinLength'.tr() : null,
          ),
          kVerticalSpace32,
          ElevatedButton(
            onPressed: hTapMedium(isLoading ? null : _submit),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kWhite,
                    ),
                  )
                : Text('loginButton'.tr()),
          ),
          kVerticalSpace16,
          const _OrDivider(),
          kVerticalSpace16,
          _OneIdButton(onTap: () => _openWithCountdown(_kOneIdUrl)),
          const SizedBox(height: 10),
          _KarantinButton(onTap: () => _openWithCountdown(_kKarantinIdUrl)),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

class _OneIdButton extends StatelessWidget {
  const _OneIdButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF2D159A);
    const lightColor = Color(0xFF4B30C5);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [color, lightColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: color.withAlpha(70), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hTap(onTap),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/one-id.png',
                  height: 24,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(width: 10),
                Text(
                  'oneIdLoginSuffix'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KarantinButton extends StatelessWidget {
  const _KarantinButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kGreen, kGreenLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: kGreen.withAlpha(70), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hTap(onTap),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'karantinIdLogin'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'faceIdLogin'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RedirectDialog extends StatefulWidget {
  const _RedirectDialog({required this.url});
  final String url;

  @override
  State<_RedirectDialog> createState() => _RedirectDialogState();
}

class _RedirectDialogState extends State<_RedirectDialog> {
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
        _launch();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _launch() async {
    final uri = Uri.parse(widget.url);
    if (mounted) Navigator.pop(context);
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOneId = widget.url.contains('egov.uz');
    final accentColor = isOneId ? const Color(0xFF2D159A) : kGreen;
    final accentLight = isOneId ? const Color(0xFF4B30C5) : kGreenLight;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOneId) _OneIdDialogHeader(accentColor: accentColor) else _KarantinDialogHeader(accentColor: accentColor, accentLight: accentLight),
            const SizedBox(height: 20),
            Text(
              isOneId ? 'oneIdRedirectMsg'.tr() : 'karantinRedirectMsg'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isOneId ? 'oneIdRedirectDesc'.tr() : 'karantinRedirectDesc'.tr(),
              style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _SegmentedCountdown(count: _countdown, color: accentColor),
            const SizedBox(height: 18),
            Text(
              'redirectInSec'.tr(namedArgs: {'count': '$_countdown'}),
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OneIdDialogHeader extends StatelessWidget {
  const _OneIdDialogHeader({required this.accentColor});
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D159A).withAlpha(18) : const Color(0xFF2D159A).withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D159A).withAlpha(40)),
      ),
      child: Image.asset(
        'assets/images/one-id.png',
        height: 64,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _KarantinDialogHeader extends StatelessWidget {
  const _KarantinDialogHeader({required this.accentColor, required this.accentLight});
  final Color accentColor;
  final Color accentLight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withAlpha(isDark ? 35 : 18), accentLight.withAlpha(isDark ? 25 : 12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withAlpha(50)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accentColor, accentLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: accentColor.withAlpha(100), blurRadius: 18, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 34),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 6)],
                  ),
                  child: const Icon(Icons.eco_rounded, color: kGreen, size: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(isDark ? 15 : 200),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 11, color: accentColor),
                const SizedBox(width: 5),
                Text(
                  'id.karantin.uz',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedCountdown extends StatefulWidget {
  const _SegmentedCountdown({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  State<_SegmentedCountdown> createState() => _SegmentedCountdownState();
}

class _SegmentedCountdownState extends State<_SegmentedCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  int _prevCount = 3;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.count;
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_SegmentedCountdown old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) {
      _prevCount = old.count;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, child) {
              final prevSweep = _prevCount / 3 * 2 * math.pi;
              final targetSweep = widget.count / 3 * 2 * math.pi;
              final sweep = prevSweep + (targetSweep - prevSweep) * _anim.value;
              return CustomPaint(
                size: const Size(100, 100),
                painter: _CircleProgressPainter(sweep: sweep, color: widget.color),
              );
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '${widget.count}',
              key: ValueKey(widget.count),
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w900,
                color: widget.color,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  const _CircleProgressPainter({required this.sweep, required this.color});
  final double sweep;
  final Color color;

  static const _strokeWidth = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _strokeWidth / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withAlpha(30)
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    if (sweep > 0.01) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = color
          ..strokeWidth = _strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircleProgressPainter old) => old.sweep != sweep;
}
