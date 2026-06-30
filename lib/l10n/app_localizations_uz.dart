// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Dala Nazorati';

  @override
  String get loginTitle => 'Tizimga kiring';

  @override
  String get loginSubtitle => 'Davom etish uchun ma\'lumotlaringizni kiriting';

  @override
  String get phoneLabel => 'Telefon raqam';

  @override
  String get passwordLabel => 'Parol';

  @override
  String get loginButton => 'Kirish';

  @override
  String get phoneRequired => 'Telefon raqamini kiriting';

  @override
  String get passwordMinLength => 'Kamida 6 ta belgi kiritilishi shart';

  @override
  String get locationLoading => 'Joylashuv aniqlanmoqda...';

  @override
  String get retry => 'Qayta urinish';

  @override
  String get locationError => 'Joylashuvni aniqlab bo\'lmadi';

  @override
  String accuracy(String meters) {
    return 'Aniqlik: $meters m';
  }

  @override
  String get fakeGpsTitle => 'Soxta GPS aniqlandi!';

  @override
  String get fakeGpsDescription =>
      'Ilova soxta joylashuv ilovasi ishlatilayotganini aniqladi. Davom etish uchun uni o\'chiring.';

  @override
  String get fakeGpsStep1 => 'Telefoningiz Sozlamalarini oching';

  @override
  String get fakeGpsStep2 =>
      'Dasturchi sozlamalari → Soxta joylashuvni o\'chirish';

  @override
  String get fakeGpsStep3 => 'Ilovaga qayting va qayta urinib ko\'ring';

  @override
  String get fakeGpsRetry => 'Qayta tekshirish';

  @override
  String get mapTitle => 'Xarita';

  @override
  String get noInternet => 'Internet mavjud emas';

  @override
  String get languageLabel => 'Til';

  @override
  String get darkMode => 'Qorong\'u rejim';

  @override
  String get lightMode => 'Yorug\' rejim';

  @override
  String get drawField => 'Maydon chizish';

  @override
  String drawHint(int count) {
    return 'Mapga bosib nuqta qo\'ying  •  $count nuqta';
  }

  @override
  String get minPointsRequired => 'Kamida 3 ta nuqta qo\'ying';

  @override
  String get cancel => 'Bekor';

  @override
  String get done => 'Tayyor';

  @override
  String get deleteLabel => 'O\'chirish';

  @override
  String get redraw => 'Qayta chizish';

  @override
  String get coordinates => 'Koordinatlar';

  @override
  String get coordinatesCopied => 'Koordinatlar nusxalandi';

  @override
  String get copyLabel => 'Nusxalash';

  @override
  String get deleteField => 'Maydonni o\'chirish';

  @override
  String get close => 'Yopish';

  @override
  String fieldCorners(int count) {
    return 'Maydon burchaklari ($count nuqta)';
  }

  @override
  String get latitude => 'Kenglik';

  @override
  String get longitude => 'Uzunlik';
}
