# DevOps runbook — Nazorat AAT

This file does two jobs:

1. **Operations manual.** When asked to "ship to test", follow
   [Release procedure](#release-procedure) — nothing else needs to be
   consulted.
2. **Infrastructure record.** What each file is for, and which invariants
   must not be broken.

> **About copied code.** The **configuration** here is complete (CI/CD YAML,
> Gradle, manifest, plists) — it is easy to lose and tedious to reconstruct.
> **Dart code is not duplicated**: only its path and its invariants are
> recorded. Keeping 800 lines in two places guarantees they drift apart, and
> at that point nobody knows which copy is right. The repository is the source
> of truth.

---

## Current state

| | |
|---|---|
| CI (analyze + test + build) | ✅ working, verified locally |
| Firebase project `nazorat-aat` | ✅ created, Android + iOS apps registered |
| Crashlytics | ✅ wired, config files in place |
| Diagnostics log | ✅ working |
| Remote Config update policy | ✅ parameters published |
| Push (FCM) | ✅ working, verified on a real device |
| CD — Android half | ✅ proven end to end — `v1.0.1` shipped 1.0.1+19 to the internal track |
| CD — iOS half | ⚠️ 1 of 7 secrets set, **needs the Apple credentials** |
| Release signing | ✅ verified locally — `flutter build appbundle --release` produces a signed 79 MB AAB |
| Branch protection on `main` | ⛔ deliberately not enabled |
| Shorebird code push | ✅ configured (`shorebird.yaml`) |

The ⚠️ row depends on [CD secrets](#cd-secrets).

---

## Release procedure

### What "ship to test" means

```bash
# 1. Gate, locally, before anything is pushed
dart format --output=none --set-exit-if-changed \
  lib test packages/karantin_face_sdk/lib packages/karantin_face_sdk/test
flutter analyze --fatal-infos
(cd packages/karantin_face_sdk && flutter analyze --fatal-infos)
flutter test
(cd packages/karantin_face_sdk && flutter test)

# 2. Bump the build number. Always +1 — both stores reject an upload whose
#    build number is not higher than the previous one.
tool/bump_build.sh           # 1.0.0+18 -> 1.0.0+19   (same version name)
tool/bump_build.sh 1.1.0     # 1.0.0+18 -> 1.1.0+19   (new version name)

# 3. Commit, tag, push
git commit -am "chore: release $(grep '^version:' pubspec.yaml | sed 's/version: //')"
git tag v1.1.0
git push origin main v1.1.0
```

The tag starts `.github/workflows/release.yml`:
`verify` → (`android` ‖ `ios`) → Play internal testing + TestFlight.

`verify` refuses to continue when the tag does not match the version name in
`pubspec.yaml`. That catches the likeliest mistake — tagging without bumping —
before a 40-minute build ends in a store rejection.

### Choosing the version name

| change | example |
|---|---|
| bug fix | `1.0.0` → `1.0.1` |
| new feature | `1.0.1` → `1.1.0` |
| breaking change or large rewrite | `1.1.0` → `2.0.0` |

The build number is independent and only ever goes up by one.

### When only Dart changed

No need to wait for the stores — a Shorebird patch reaches devices in minutes:

```bash
shorebird patch --platforms=android,ios
```

A patch **cannot** carry changes to native code, plugins, `pubspec.yaml` or
assets. Those need a full release.

### Rolling back

Halt the internal-track release in Play Console; expire the build in
TestFlight. A Shorebird patch is undone by publishing the previous one again.

---

## CI — `.github/workflows/ci.yml`

Three jobs run in parallel on every push and pull request. The repository is
public, so even the macOS runner is free.

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

env:
  FLUTTER_VERSION: "3.47.1"

jobs:
  analyze:
    name: Analyze & test
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - name: Dependencies
        run: |
          flutter pub get
          flutter pub get -C packages/karantin_face_sdk
      - name: Format
        run: |
          dart format --output=none --set-exit-if-changed \
            lib test packages/karantin_face_sdk/lib packages/karantin_face_sdk/test
      - name: Analyze (app)
        run: flutter analyze --fatal-infos
      - name: Analyze (karantin_face_sdk)
        run: flutter analyze --fatal-infos
        working-directory: packages/karantin_face_sdk
      - name: Test (app)
        run: flutter test --coverage
      - name: Test (karantin_face_sdk)
        run: flutter test
        working-directory: packages/karantin_face_sdk
      - name: Coverage report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/lcov.info
          if-no-files-found: ignore

  build-android:
    name: Android build
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build apk --debug

  build-ios:
    name: iOS build
    runs-on: macos-latest
    timeout-minutes: 40
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build ios --debug --no-codesign
```

**Why the build jobs exist:** `flutter analyze` only reads Dart. A Gradle
plugin clash, a CocoaPods problem or missing desugaring shows up only in a
real build — which is exactly what happened in this project when
`flutter_local_notifications` turned out to need core library desugaring.

**Bump `FLUTTER_VERSION` together with the local SDK.** Otherwise CI checks
against a different one and "works on my machine" becomes possible again.

---

## CD — `.github/workflows/release.yml`

The full workflow lives in the repository. Shape: `verify` (version guard +
analyze + test) → `android` and `ios` in parallel.

### Secrets it needs

GitHub → Settings → Secrets and variables → Actions:

| secret | what | how to get it |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | signing key | `base64 -i android/keystore.jks \| pbcopy` |
| `ANDROID_KEY_PROPERTIES` | key passwords | `base64 -i android/key.properties \| pbcopy` |
| `ANDROID_GOOGLE_SERVICES_JSON` | Firebase (Android) | `base64 -i android/app/google-services.json \| pbcopy` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Play API | Google Cloud service account JSON, **plain text, not base64** — see [CD secrets](#cd-secrets) |
| `IOS_GOOGLE_SERVICE_INFO_PLIST` | Firebase (iOS) | `base64 -i ios/Runner/GoogleService-Info.plist \| pbcopy` |
| `IOS_CERTIFICATE_P12` | distribution certificate | Keychain → export .p12 → base64 |
| `IOS_CERTIFICATE_PASSWORD` | .p12 password | chosen during export |
| `IOS_PROVISIONING_PROFILE` | profile | Apple Developer → Profiles → base64 |
| `APPSTORE_KEY_ID` | ASC API key | App Store Connect → Users → Integrations → Keys |
| `APPSTORE_ISSUER_ID` | ASC issuer | same page |
| `APPSTORE_PRIVATE_KEY` | contents of the `.p8` | downloaded once, at key creation |

> **No Apple ID password is used** — two-factor auth makes it useless in CI.
> Only the App Store Connect API key (`.p8`).

`ios/ExportOptions.plist` is in the repository with `teamID = PTV6284A36`,
which must match `DEVELOPMENT_TEAM` on the Runner target.

---

## Firebase

Project **`nazorat-aat`** (console:
`https://console.firebase.google.com/project/nazorat-aat`), created with the
CLI together with both apps:

| | id |
|---|---|
| Android | `1:980297703068:android:e70382e0cf0ed4aceb9759` |
| iOS | `1:980297703068:ios:03f2183c045a5bd9eb9759` |

Config files are gitignored (the repository is public). To fetch them again:

```bash
firebase apps:sdkconfig ANDROID 1:980297703068:android:e70382e0cf0ed4aceb9759 \
  --project nazorat-aat --out android/app/google-services.json
firebase apps:sdkconfig IOS 1:980297703068:ios:03f2183c045a5bd9eb9759 \
  --project nazorat-aat --out ios/Runner/GoogleService-Info.plist
```

> **Invariant:** `GoogleService-Info.plist` is registered in
> `project.pbxproj` under the Runner target's *Copy Bundle Resources* phase.
> Dropping the file into `ios/Runner/` is not enough — without that entry it
> never reaches the app bundle and Firebase stays dead on iOS.
>
> The flip side: because it is a declared build input, Xcode refuses to build
> at all when the file is absent. The file is gitignored, so CI would fail on
> every run. The CI job therefore writes a placeholder before building — it
> only compiles, never launches the app — while the release workflow restores
> the real file from `IOS_GOOGLE_SERVICE_INFO_PLIST`. Android solves the same
> problem differently, by applying its Gradle plugins conditionally, because
> there the plugin is what demands the file.

### Gradle plugins are conditional

`android/app/build.gradle.kts`. `google-services.json` is gitignored, so the
plugin is applied only when the file exists — otherwise CI and a fresh clone
would not build:

```kotlin
val googleServicesFile = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    logger.lifecycle(
        "google-services.json not found - Crashlytics is disabled for this " +
            "build. Download it from the Firebase console into android/app/."
    )
}
```

The trap is that this is a log line, not an error: a release build on a machine
without the file succeeds and produces an AAB with no Crashlytics and no push.
CI is safe — it writes the file from `ANDROID_GOOGLE_SERVICES_JSON` first — but
a hand-built AAB is only as good as what is in `android/app/`.

`android/settings.gradle.kts`:

```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
id("com.google.firebase.crashlytics") version "3.0.2" apply false
```

This mirrors the `hasReleaseSigning` pattern already used for signing.

---

## Observability

The problem: the app works offline, so a failure stays **on the inspector's
phone**. Three layers close that gap.

### 1. Crashlytics — crashes

`lib/core/observability/crash_reporting.dart`

- `FlutterError.onError` and `PlatformDispatcher.instance.onError` are wired
- collection is **off in debug** (`setCrashlyticsCollectionEnabled(!kDebugMode)`)
- `Firebase.initializeApp()` is called **without options**, inside `try/catch`

> **Do not change:** `firebase_options.dart` is deliberately unused. It would
> have to be generated for the code to compile at all, binding the whole
> project to one Firebase project. Reading the native config files instead
> means a missing file degrades to "no crash reporting" rather than "no build".

### 2. Diagnostics log — failures that are not crashes

`lib/core/observability/diagnostics_log.dart` and
`lib/core/network/diagnostics_interceptor.dart`

Crashlytics catches crashes. "I could not sign in", "the sync never
finished", "the image did not load" are not crashes. So a ring buffer is kept
on disk:

- the last **1000 lines** live in Hive and survive a restart
- every line also becomes a Crashlytics breadcrumb, so it travels with a crash
- flushed to disk when the app leaves the foreground
  (`DiagnosticsLifecycleObserver`)

What it looks like:

```
2026-10-06T14:22:08 INFO  [http] POST /auth/login 401 820ms
2026-10-06T14:23:15 ERROR [http] GET /reference/pests/ FAILED connectionTimeout 15004ms
2026-10-06T14:23:15 INFO  [sync] pests -> error
```

The first line is a wrong password, the second a dead connection. Previously
both looked like "it did not work".

> **Do not change:**
> - Response bodies are **not** logged — catalog responses run to megabytes
>   and may carry personal data.
> - Only `uri.path` is logged; a full URL may carry a token in its query.
> - The interceptor is attached **only** to `DioService` and
>   `ReferenceRemoteDataSource`. Do not attach it to the map tile or reference
>   image clients: 1255 requests would bury the log.

**How it reaches the developer:** automatically (alongside any crash or
non-fatal report), or on demand — Profile → **"Send diagnostics log"**, which
shares the file over Telegram.

### 3. Non-fatal reports

Failures that do not stop the app but are worth knowing about:

| where | what is reported |
|---|---|
| `reference_repository_impl.dart` | a catalog step failed |
| `app_download_controller.dart` | offline map download failed |
| `remote_config_service.dart` | Remote Config unavailable |
| `push_service.dart` | push service did not start |

---

## Update policy (Remote Config)

`lib/core/update/app_version.dart` · `remote_config_service.dart` ·
`update_prompt.dart`

Parameters are version-controlled in `remoteconfig.template.json` and
published with:

```bash
firebase deploy --only remoteconfig --project nazorat-aat
```

| key | example | effect |
|---|---|---|
| `min_supported_version` | `1.2.0` | below this — **forced** update, dialog cannot be dismissed |
| `latest_version` | `1.5.0` | below this — **optional**, with a "Later" button |
| `update_message` | text | replaces the built-in copy when set |
| `store_url_android` | Play link | falls back to a built-in link when empty |
| `store_url_ios` | App Store link | the button stays hidden when empty |

No new build is needed to block an old version: change the value in the
console (or the template file) and devices pick it up on their next launch
(`minimumFetchInterval` is one hour).

> **Do not change:** `resolveUpdateRequirement` returns
> `UpdateRequirement.none` for anything unparseable. Typing `v1.2.0` instead
> of `1.2.0` in the console must lock **nobody** out. `test/app_version_test.dart`
> guards this with 14 tests, including the `"1.10.0"` vs `"1.9.0"` case where
> a text comparison would place `1.10.0` lower.

---

## Push notifications (FCM)

`lib/core/notifications/push_service.dart`

All four states are handled: foreground (`onMessage` → local notification),
background (the system), terminated (`getInitialMessage`), and tapped
(`onMessageOpenedApp`).

> **Do not change:**
> - The background handler is a **top-level function** annotated with
>   `@pragma('vm:entry-point')`. Without it, tree shaking removes it from
>   release builds and background messages silently stop working.
> - The channel id `nazorat_default` appears in **three places**:
>   `PushService._channel`, the `AndroidManifest.xml` meta-data, and
>   `_showForeground`. If they disagree, nothing appears on Android 8+.

### Native configuration

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
...
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="nazorat_default" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@mipmap/ic_launcher" />
```

`android/app/build.gradle.kts` — required by `flutter_local_notifications`:

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

`ios/Runner/AppDelegate.swift`:

```swift
if #available(iOS 10.0, *) {
  UNUserNotificationCenter.current().delegate = self
}
application.registerForRemoteNotifications()
```

`ios/Runner/Runner.entitlements` (wired into all three build configurations
through `CODE_SIGN_ENTITLEMENTS`):

```xml
<key>aps-environment</key>
<string>development</string>
```

Xcode rewrites this to `production` on App Store export, so `development` is
the correct value to keep in the file.

`ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### APNs

An APNs **authentication key** is uploaded to Firebase (Key ID `WDL4G34DNC`,
Team ID `PTV6284A36`). One key covers both development and production, never
expires, and serves every app on the account.

The "APNs Certificates" section in the Firebase console is deliberately empty:
certificates are the legacy alternative to the key, not a companion to it, and
they would have to be renewed yearly.

The Runner target carries the *Push Notifications* capability; the
`aps-environment` entitlement is wired through
`CODE_SIGN_ENTITLEMENTS` in all three build configurations.

---

## Permissions

### Android

Declared in `android/app/src/main/AndroidManifest.xml`: internet, fine /
coarse / background location, camera, microphone, media and legacy storage
reads, and `POST_NOTIFICATIONS` for Android 13+.

### iOS

`Info.plist` holds the **English** usage descriptions, which is what App
Store review reads. Inspectors still see their own language because the
strings are localized:

```
ios/Runner/en.lproj/InfoPlist.strings
ios/Runner/uz.lproj/InfoPlist.strings
ios/Runner/ru.lproj/InfoPlist.strings
```

> **Do not change:** the three files form a `PBXVariantGroup` in
> `project.pbxproj` and `uz`/`ru` are listed in `knownRegions`. A language
> missing from `knownRegions` is not built at all, and a variant group missing
> from *Copy Bundle Resources* never reaches the bundle — in both cases the
> prompts silently fall back to English. Verify after changing:
> `ls build/ios/iphoneos/Runner.app/*.lproj`.

Adding a new permission means editing four files: `Info.plist` (English) plus
the three `InfoPlist.strings`.

---

## File map

| file | purpose |
|---|---|
| `.github/workflows/ci.yml` | analyze · test · android/ios build |
| `.github/workflows/release.yml` | tag → Play internal + TestFlight |
| `tool/bump_build.sh` | increments the build number in pubspec.yaml |
| `firebase.json` · `remoteconfig.template.json` | Remote Config as code |
| `ios/ExportOptions.plist` | IPA export settings (teamID, dSYM upload) |
| `lib/core/observability/crash_reporting.dart` | Crashlytics wiring |
| `lib/core/observability/diagnostics_log.dart` | on-disk ring buffer |
| `lib/core/observability/analytics_service.dart` | Analytics wrapper |
| `lib/core/network/diagnostics_interceptor.dart` | logs every request |
| `lib/core/notifications/push_service.dart` | FCM |
| `lib/core/update/app_version.dart` | version comparison (pure logic) |
| `lib/core/update/remote_config_service.dart` | reads the update policy |
| `lib/core/update/update_prompt.dart` | forced / optional dialog |
| `test/app_version_test.dart` | 14 tests guarding the forced update |

---

## Where this was left off

Last updated 2026-10-07. Everything below is the state of the repository as it
actually stands, not a plan.

### Done and verified

- `main` carries the whole pipeline; CI passes there (analyze, tests, real
  Android and iOS builds).
- Firebase project `nazorat-aat` with both apps registered; Crashlytics,
  Analytics, Remote Config and FCM are wired.
- Remote Config parameters are published from `remoteconfig.template.json`.
- Push notifications were tested end to end on a real device.
- `flutter build appbundle --release` produces a signed bundle, so the signing
  configuration itself is known good.
- **The Android pipeline has run for real.** Tag `v1.0.1` built and uploaded
  1.0.1+19; the internal track reports it `completed`. Nothing on that side is
  theoretical any more.

### Deliberately skipped

Branch protection on `main` is **not** enabled. CI runs on every push and pull
request but does not block a merge. This was a conscious choice, not an
oversight — do not "fix" it without being asked.

### CD secrets

Already set — the whole Android half:

```
ANDROID_KEYSTORE_BASE64
ANDROID_KEY_PROPERTIES
ANDROID_GOOGLE_SERVICES_JSON
GOOGLE_PLAY_SERVICE_ACCOUNT
IOS_GOOGLE_SERVICE_INFO_PLIST
```

`GOOGLE_PLAY_SERVICE_ACCOUNT` is the `play-release-ci@nazorat-aat` service
account, created in the `nazorat-aat` Google Cloud project — a Firebase project
*is* a Cloud project, so no second one was made. It carries **no Cloud IAM
role**; the upload right comes from the Play Console invitation, not from
Cloud. The old "Play Console → Setup → API access" route no longer exists:

1. Cloud Console → enable `Google Play Android Developer API`
2. IAM & Admin → Service Accounts → create, skip the role step → Keys → JSON
3. Play Console → **Users and permissions → Invite new users** → that service
   account's email → `com.nazorat.aat.uz` → *View app information* and
   *Release to testing tracks*

The key goes in as **plain text** (`serviceAccountJsonPlainText`), unlike every
other secret here, which is base64. Access can be checked without spending a
40-minute build on it — this returns HTTP 200 once the invitation has landed:

```bash
gcloud auth activate-service-account --key-file=<key>.json
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token \
  --scopes=https://www.googleapis.com/auth/androidpublisher)" \
  -H "Content-Length: 0" \
  https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.nazorat.aat.uz/edits
```

Still needed — each lives in an external console, so it has to be fetched by
hand:

| secret | where |
|---|---|
| `IOS_CERTIFICATE_P12` | Keychain Access → export the distribution certificate |
| `IOS_CERTIFICATE_PASSWORD` | chosen during that export |
| `IOS_PROVISIONING_PROFILE` | Apple Developer → Profiles |
| `APPSTORE_KEY_ID` | App Store Connect → Users → Integrations → Keys |
| `APPSTORE_ISSUER_ID` | same page |
| `APPSTORE_PRIVATE_KEY` | the `.p8`, downloadable only once |

```bash
base64 -i ~/Downloads/dist.p12 | gh secret set IOS_CERTIFICATE_P12
```

The two halves are independent: the Android job releases on its own, without
waiting for any of the Apple credentials. Until they exist the iOS job fails
while Android still reaches Play — a red run is not a broken release.

### Next steps, in order

1. **The six Apple secrets**, then re-run the release. Expect the signing step
   to need adjusting on its first run.
2. **Wire `onMessageOpened` to navigation.** The handler exists but goes
   nowhere, because which screen to open depends on what `data` the backend
   sends with a push. Needs a decision first, not code.
3. **Rotate the keystore passwords** in `android/key.properties`, then update
   `ANDROID_KEY_PROPERTIES`. Routine hygiene:
   ```bash
   keytool -storepasswd -keystore android/keystore.jks
   keytool -keypasswd -alias upload -keystore android/keystore.jks
   ```
   This changes only the passwords, not the key, so nothing breaks in Play
   Console.
4. **Backend conversations** (separate track, nothing here blocks on them):
   - Catalog images total **1.04 GB**. Thumbnails would cut that to roughly
     68 MB (WebP 1280px) or 17 MB (320px). Raise with the
     `datahub.karantin.uz` team.
   - There is no staging backend, so a clearly marked test inspector on
     production is needed — today `flutter run` writes to the real database.
   - `page_size` is ignored on `/reference/plants/`, so 184 plants cost 10
     sequential requests.

### The retired bundle id

`com.dala.nazorati.uz` is **dead**. It was the earlier id, it still had a Play
listing, and the release service account gets `403` on it — which reads like a
permissions problem and is not one. The live package is `com.nazorat.aat.uz`,
in `android/app/build.gradle.kts`, `release.yml` and the iOS target alike.

Related: SHA fingerprints come from the signing certificate, never from a
device or a package name, and under Play App Signing the certificate that
matters is Google's, not the local upload key. The one way to read the real
one without waiting for a Console page is to ask an installed build:

```bash
adb shell pm path com.nazorat.aat.uz          # then pull that base.apk
apksigner verify --print-certs base.apk
```

`CN=Android, O=Google Inc.` in the output means Play re-signed it, so those
digests are the production fingerprints. `CN=Android Debug` means the build
came from `flutter run` and its fingerprint is worth nothing to Firebase.

### Known, accepted, not a bug

Face capture sends frames **un-mirrored** (`karantin_face_scanner.dart` has no
flip) while the old webview flipped them horizontally. The flow was verified on
a device and works. If the backend ever starts rejecting face matches, this is
the first place to look.

## Keeping this file current

Update it whenever the infrastructure changes — a new workflow, a new secret,
a new observability layer. A stale runbook is worse than none, because people
trust it.
