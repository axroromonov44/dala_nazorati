// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Field Monitor';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginSubtitle => 'Enter your credentials to continue';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get phoneRequired => 'Please enter your phone number';

  @override
  String get passwordMinLength => 'Minimum 6 characters required';

  @override
  String get locationLoading => 'Detecting location...';

  @override
  String get retry => 'Try again';

  @override
  String get locationError => 'Could not determine location';

  @override
  String accuracy(String meters) {
    return 'Accuracy: $meters m';
  }

  @override
  String get fakeGpsTitle => 'Fake GPS Detected!';

  @override
  String get fakeGpsDescription =>
      'The app detected a fake location provider. Please disable it to continue.';

  @override
  String get fakeGpsStep1 => 'Open your phone Settings';

  @override
  String get fakeGpsStep2 => 'Developer options → Disable mock location';

  @override
  String get fakeGpsStep3 => 'Return to the app and try again';

  @override
  String get fakeGpsRetry => 'Check again';

  @override
  String get mapTitle => 'Map';

  @override
  String get noInternet => 'No internet connection';

  @override
  String get languageLabel => 'Language';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get lightMode => 'Light mode';

  @override
  String get drawField => 'Draw field';

  @override
  String drawHint(int count) {
    return 'Tap on map to add point  •  $count points';
  }

  @override
  String get minPointsRequired => 'Add at least 3 points';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get deleteLabel => 'Delete';

  @override
  String get redraw => 'Redraw';

  @override
  String get coordinates => 'Coordinates';

  @override
  String get coordinatesCopied => 'Coordinates copied';

  @override
  String get copyLabel => 'Copy';

  @override
  String get deleteField => 'Delete field';

  @override
  String get close => 'Close';

  @override
  String fieldCorners(int count) {
    return 'Field corners ($count points)';
  }

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';
}
