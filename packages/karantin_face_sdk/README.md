# karantin_face_sdk

Native Flutter **Face ID login for Karantin ID**. Replaces the in-webview face
scan with an on-device camera + ML Kit flow: it fetches the OAuth session,
guides the user through a face scan, submits the images to the Karantin ID
backend, follows the redirect chain and returns the authorization **`code`**.

- On-device face detection (Google ML Kit) — no face data leaves the device
  except the images sent to the official Karantin ID backend.
- Passive liveness (natural movement / blink / head pose) — **never** asks the
  user to turn or blink.
- Best-frame selection + image compression (small uploads for weak networks).
- Device binding (device id, fingerprint, GPS) for inspector anti-fraud.
- Platform-native camera-permission dialogs (Cupertino on iOS, Material on
  Android).

## Install

Add it as a path (or git) dependency:

```yaml
dependencies:
  karantin_face_sdk:
    path: packages/karantin_face_sdk
    # or:
    # git:
    #   url: https://github.com/axroromonov44/dala_nazorati.git
    #   path: packages/karantin_face_sdk
```

Then `flutter pub get`.

### Platform setup

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

`minSdkVersion` must be **21+**.

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Yuzni tasdiqlash uchun kamera kerak</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Tasdiqlash joyini qayd etish uchun joylashuv kerak</string>
```

## Usage

```dart
import 'package:karantin_face_sdk/karantin_face_sdk.dart';

final code = await KarantinFace.authenticate(
  context,
  config: const KarantinFaceConfig(
    clientId: 'your_client_id',
    redirectUri: 'https://your.app/callback',
    // baseUrl: 'https://id.karantin.uz', // default
    // authType: 'login',                 // default
    primaryColor: Color(0xFF2E7D32),
    debugLogging: kDebugMode,
  ),
);

if (code != null) {
  // Exchange `code` for tokens on your backend, as after a webview redirect.
}
```

Or push the page directly:

```dart
final code = await Navigator.of(context).push<String?>(
  MaterialPageRoute(
    builder: (_) => KarantinFaceAuthPage(config: config),
  ),
);
```

### Localising the UI

Pass `strings:` on the config:

```dart
KarantinFaceConfig(
  clientId: '…',
  redirectUri: '…',
  strings: KarantinFaceStrings(
    formTitle: 'Login with your face',
    continueButton: 'Continue',
    // …
  ),
)
```

## How it works

1. `GET /app/project/oauth/authorize` → parse the `token`/`name` (or
   `code`/`state`) from the redirect.
2. Collect passport / PNFL, then run the face scan.
3. `POST /app/project/oauth/{login,register,verify-doc}` with `face_image` +
   `check_image1..4` + device fields.
4. Follow `redirect_to` until the configured `redirectUri?code=…` and return the
   code.

A single cookie jar is shared across the requests so the OAuth session behaves
like a browser session.

## License

Internal use for the Nazorat AAT / Karantin ID project.
