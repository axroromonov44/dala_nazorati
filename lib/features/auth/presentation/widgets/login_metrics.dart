import 'dart:ui' show lerpDouble;

/// Sizing for the login screen, derived from the height it actually has.
///
/// The login column (logo + title + form + two provider buttons) is taller than
/// the viewport of a short Android phone, so the page used to scroll there.
/// Every size here shrinks together as the viewport gets shorter, which keeps
/// the proportions intact instead of cropping or cramming a single widget.
/// Roomy screens keep the original, larger sizes.
class LoginMetrics {
  const LoginMetrics({
    required this.logoHeight,
    required this.pagePadding,
    required this.logoGap,
    required this.titleGap,
    required this.titleSize,
    required this.fieldGap,
    required this.fieldPaddingV,
    required this.submitGap,
    required this.buttonHeight,
    required this.dividerGap,
    required this.providerPaddingV,
    required this.providerGap,
  });

  /// Below [_tightHeight] everything is at its smallest; from [_roomyHeight] up
  /// nothing shrinks any more.
  static const _tightHeight = 520.0;
  static const _roomyHeight = 760.0;

  /// [availableHeight] is the height left for the scrollable column, i.e. the
  /// viewport minus the app bar and the safe areas.
  factory LoginMetrics.forHeight(
    double availableHeight, {
    bool isTablet = false,
  }) {
    final span = _roomyHeight - _tightHeight;
    final t = availableHeight.isFinite
        ? ((availableHeight - _tightHeight) / span).clamp(0.0, 1.0)
        : 1.0;
    double scale(double tight, double roomy) => lerpDouble(tight, roomy, t)!;

    return LoginMetrics(
      // The logo is by far the biggest item, so it gives up the most room.
      logoHeight: scale(80, isTablet ? 260 : 180),
      pagePadding: scale(16, isTablet ? 36 : 24),
      logoGap: scale(6, 16),
      titleGap: scale(10, 16),
      titleSize: scale(22, 28),
      fieldGap: scale(10, 16),
      fieldPaddingV: scale(13, 18),
      submitGap: scale(16, 32),
      buttonHeight: scale(46, 52),
      dividerGap: scale(10, 16),
      providerPaddingV: scale(10, 13),
      providerGap: scale(8, 10),
    );
  }

  /// Height of the app logo.
  final double logoHeight;

  /// Padding around the whole column.
  final double pagePadding;

  /// Logo -> title.
  final double logoGap;

  /// Title -> form.
  final double titleGap;

  /// Font size of the app title.
  final double titleSize;

  /// Between the two text fields.
  final double fieldGap;

  /// Vertical content padding inside a text field.
  final double fieldPaddingV;

  /// Password field -> sign-in button.
  final double submitGap;

  /// Height of the sign-in button.
  final double buttonHeight;

  /// Around the "or" divider.
  final double dividerGap;

  /// Vertical padding inside the OneID / Karantin ID buttons.
  final double providerPaddingV;

  /// Between the two provider buttons.
  final double providerGap;
}
