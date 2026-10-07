import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nazorat_aat/core/theme/app_theme.dart';
import 'package:nazorat_aat/features/auth/domain/entities/user.dart';
import 'package:nazorat_aat/features/auth/domain/repositories/auth_repository.dart';
import 'package:nazorat_aat/features/auth/domain/usecases/gov_login_usecase.dart';
import 'package:nazorat_aat/features/auth/domain/usecases/karantin_login_usecase.dart';
import 'package:nazorat_aat/features/auth/domain/usecases/login_usecase.dart';
import 'package:nazorat_aat/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nazorat_aat/features/auth/presentation/widgets/login_form.dart';
import 'package:nazorat_aat/features/auth/presentation/widgets/login_metrics.dart';

/// The login screen used to scroll on short Android phones. This measures the
/// real form and adds the header the page puts above it — both sized from the
/// same [LoginMetrics] — then checks the column fits the viewport.
///
/// Note: `flutter_test` renders with a test font whose every glyph is a full em
/// square, so labels are far wider here than on a device. The measurement is a
/// pessimistic upper bound: passing here means it fits in reality too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // easy_localization persists the chosen locale through shared_preferences.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  /// Screen sizes in logical pixels, and the chrome that eats into them.
  const screens = <String, Size>{
    'small phone (360x640)': Size(360, 640),
    'common phone (360x780)': Size(360, 780),
    'tall phone (412x915)': Size(412, 915),
  };
  const chrome = 24.0 + 48.0 + 56.0; // status bar, navigation bar, app bar

  // All sizes in one test: easy_localization keeps process-wide state, so it is
  // initialised once and the tree is re-pumped per size.
  testWidgets('the login column fits without scrolling on short phones', (
    tester,
  ) async {
    final bloc = _bloc();
    addTearDown(tester.view.reset);

    for (final entry in screens.entries) {
      final size = entry.value;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;

      final available = size.height - chrome;
      final metrics = LoginMetrics.forHeight(available);

      await tester.pumpWidget(
        _harness(bloc: bloc, metrics: metrics, width: size.width),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(LoginForm),
        findsOneWidget,
        reason: 'the form did not build on ${entry.key}',
      );
      final formHeight = tester.getSize(find.byType(LoginForm)).height;

      // What the page stacks above the form, straight from the metrics.
      final header =
          metrics.logoHeight +
          metrics.logoGap +
          metrics.titleSize * 1.4 + // headline line height
          metrics.titleGap;
      final total = metrics.pagePadding * 2 + header + formHeight;

      expect(
        total,
        lessThanOrEqualTo(available),
        reason:
            'login column is ${total.toStringAsFixed(1)}dp but only '
            '${available.toStringAsFixed(1)}dp is available on ${entry.key}',
      );
    }

    // The narrowest phone we support, where the long Uzbek/Russian labels used
    // to wrap and make the Karantin button almost twice as tall.
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(
      _harness(bloc: bloc, metrics: LoginMetrics.forHeight(512), width: 320),
    );
    await tester.pumpAndSettle();

    final karantinLabel = find.text('karantinIdLogin'.tr());
    expect(karantinLabel, findsOneWidget);
    // One line: the label must stay inside a single line box of its 14px style.
    expect(
      tester.getSize(karantinLabel).height,
      lessThan(14 * 1.6),
      reason: 'the Karantin ID label wrapped onto a second line',
    );
  });

  test('metrics shrink as the viewport gets shorter and then stop', () {
    final tight = LoginMetrics.forHeight(400);
    final small = LoginMetrics.forHeight(520);
    final roomy = LoginMetrics.forHeight(760);
    final huge = LoginMetrics.forHeight(1200);

    expect(tight.logoHeight, small.logoHeight); // clamped at the bottom
    expect(small.logoHeight, lessThan(roomy.logoHeight));
    expect(roomy.logoHeight, huge.logoHeight); // clamped at the top
    expect(small.buttonHeight, lessThan(roomy.buttonHeight));
    expect(roomy.logoHeight, 180);
  });
}

AuthBloc _bloc() {
  final repository = _StubAuthRepository();
  final bloc = AuthBloc(
    LoginUseCase(repository),
    GovLoginUseCase(repository),
    KarantinLoginUseCase(repository),
  );
  addTearDown(bloc.close);
  return bloc;
}

Widget _harness({
  required AuthBloc bloc,
  required LoginMetrics metrics,
  required double width,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('uz')],
    path: 'assets/translations',
    fallbackLocale: const Locale('uz'),
    startLocale: const Locale('uz'),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: AppTheme.light,
        home: Scaffold(
          // Mirrors the page: the scroll view gives the column unbounded
          // height, so it reports its intrinsic size instead of filling the
          // screen.
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width - metrics.pagePadding * 2,
                child: BlocProvider<AuthBloc>.value(
                  value: bloc,
                  child: LoginForm(metrics: metrics),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _StubAuthRepository implements AuthRepository {
  @override
  Future<({User user, String accessToken, String refreshToken})> login({
    required String username,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<({User user, String accessToken, String refreshToken})>
  loginWithGovCode({required String code}) => throw UnimplementedError();

  @override
  Future<({User user, String accessToken, String refreshToken})>
  loginWithKarantinCode({required String code}) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<User?> getCurrentUser() => throw UnimplementedError();

  @override
  Future<User> fetchProfile() => throw UnimplementedError();
}
