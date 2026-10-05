# Nazorat AAT

Field monitoring app (Flutter) — GPS-based field boundary drawing, offline map
tiles, and a crop/pest reference encyclopedia synced from the open
karantin.uz catalog.

## Stack

- **Flutter** 3.41+ / Dart SDK `^3.11.4`
- **State management**: `flutter_bloc` (Bloc/Cubit)
- **DI**: `get_it`, wired by hand in `lib/core/di/injection.dart`
  (`injectable`/`injectable_generator` are listed as dev dependencies but
  nothing in `lib/` is annotated — there is no generated DI config to run)
- **Networking**: `dio`, two separate clients:
  - `DioService` — the authenticated main API (`lib/core/network/dio_service.dart`)
  - `ReferenceRemoteDataSource` — the public karantin.uz reference API, no auth
- **Local storage**: `hive_flutter` (`HiveService`), plus on-disk file caches
  for map tiles (`TileCacheService`), field photos (`FieldMediaCache`), and
  reference-catalog photos (`ReferenceImageCache`)
- **Maps**: `flutter_map` (OSM-style tiles) + `latlong2`
- **Navigation**: `go_router` (`lib/core/router/app_router.dart`)
- **Localization**: `easy_localization`, JSON files in `assets/translations/`
  (`uz`, `ru`, `en` — `uz` is the fallback/start locale)
- **Auth**: Firebase Auth + Firestore (`firebase_core`, `firebase_auth`,
  `cloud_firestore`)
- **OTA updates**: Shorebird (`shorebird_code_push`, `shorebird.yaml`)

## Prerequisites

- Flutter SDK matching `environment.sdk` in `pubspec.yaml` (`^3.11.4`)
- Firebase config files (not committed — see `.gitignore`), obtained from the
  Firebase console for this project:
  - `android/app/google-services.json`
  - `ios/GoogleService-Info.plist`
  - `lib/firebase_options.dart` (if generated via `flutterfire configure`)

## Setup

```bash
flutter pub get
```

Then drop in the Firebase config files listed above before running.

## Common commands

```bash
flutter run                       # run on a connected device/simulator
flutter analyze                   # static analysis (flutter_lints)
dart format lib                   # format source
flutter test                      # run tests (test/)
flutter build apk --release       # Android release build
flutter build ios --release       # iOS release build
```

## Code generation

- `dart run build_runner build --delete-conflicting-outputs` — present via
  `build_runner`/`injectable_generator`/`json_serializable`, but **currently
  unused**: all DI registration (`injection.dart`) and all JSON
  `fromJson`/`toJson` (`*_model.dart` files) are hand-written, not generated.
  Only run this if/when `@JsonSerializable`/`@injectable` annotations are
  actually added to the codebase.
- `dart run flutter_launcher_icons` — regenerates app icons from
  `assets/images/app_icon.png` per the `flutter_launcher_icons:` config in
  `pubspec.yaml`. Run after changing the app icon.
- `dart run flutter_native_splash:create` — regenerates the native splash
  screen assets from `flutter_native_splash.yaml`. Run after changing splash
  branding.

## Shorebird (OTA patches)

```bash
shorebird release android   # or ios — ship a new release
shorebird patch android     # or ios — push a code patch to an existing release
```

`app_id` lives in `shorebird.yaml`; `ShorebirdUpdateService` checks for and
silently applies patches on launch (see `lib/main.dart`).

## Backend endpoints

- Main app API: `https://dala.efito.uz/api/v1` (`lib/core/constants/api_endpoints.dart`) —
  authenticated, fields/login/etc.
- Open reference API: `https://datahub.karantin.uz/api` (`lib/core/constants/reference_endpoints.dart`) —
  public, no auth; crop/plant/pest catalog synced into `HiveService.referenceDataBox`
  and `ReferenceImageCache` (see `lib/features/reference/`).

## Project structure

```
lib/
  core/            # DI, router, network, storage, map/tile caching, theming, shared widgets
  features/
    auth/          # login, profile cubit
    fields/        # field CRUD, spatial index, media cache
    home/          # map page, drawing, monitoring form, download dialogs
    profile/       # settings, cache clearing, logout
    reference/     # karantin.uz crop/plant/pest catalog + image cache
    sync/          # offline write queue sync
```

Each feature follows `domain/` (entities, repository interfaces) →
`data/` (repository impls, remote datasources, models) →
`presentation/` (bloc/cubit, pages, widgets).
