// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Мониторинг поля';

  @override
  String get loginTitle => 'Вход';

  @override
  String get loginSubtitle => 'Введите данные для продолжения';

  @override
  String get phoneLabel => 'Номер телефона';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get loginButton => 'Войти';

  @override
  String get phoneRequired => 'Введите номер телефона';

  @override
  String get passwordMinLength => 'Минимум 6 символов';

  @override
  String get locationLoading => 'Определение местоположения...';

  @override
  String get retry => 'Повторить';

  @override
  String get locationError => 'Не удалось определить местоположение';

  @override
  String accuracy(String meters) {
    return 'Точность: $meters м';
  }

  @override
  String get fakeGpsTitle => 'Обнаружен фиктивный GPS!';

  @override
  String get fakeGpsDescription =>
      'Приложение обнаружило использование программы для подмены GPS. Отключите её, чтобы продолжить.';

  @override
  String get fakeGpsStep1 => 'Откройте Настройки телефона';

  @override
  String get fakeGpsStep2 =>
      'Параметры разработчика → Отключить имитацию геолокации';

  @override
  String get fakeGpsStep3 => 'Вернитесь в приложение и повторите попытку';

  @override
  String get fakeGpsRetry => 'Проверить снова';

  @override
  String get mapTitle => 'Карта';

  @override
  String get noInternet => 'Нет интернета';

  @override
  String get languageLabel => 'Язык';

  @override
  String get darkMode => 'Тёмный режим';

  @override
  String get lightMode => 'Светлый режим';

  @override
  String get drawField => 'Нарисовать поле';

  @override
  String drawHint(int count) {
    return 'Нажмите на карту, чтобы добавить точку  •  $count точек';
  }

  @override
  String get minPointsRequired => 'Добавьте минимум 3 точки';

  @override
  String get cancel => 'Отмена';

  @override
  String get done => 'Готово';

  @override
  String get deleteLabel => 'Удалить';

  @override
  String get redraw => 'Перерисовать';

  @override
  String get coordinates => 'Координаты';

  @override
  String get coordinatesCopied => 'Координаты скопированы';

  @override
  String get copyLabel => 'Копировать';

  @override
  String get deleteField => 'Удалить поле';

  @override
  String get close => 'Закрыть';

  @override
  String fieldCorners(int count) {
    return 'Углы поля ($count точек)';
  }

  @override
  String get latitude => 'Широта';

  @override
  String get longitude => 'Долгота';
}
