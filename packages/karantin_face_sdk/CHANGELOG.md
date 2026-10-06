# Changelog

## 0.1.0

Initial release — extracted from the Nazorat AAT app.

- Native Karantin ID face login: authorize → passport/PNFL → on-device face
  scan → multipart submit → redirect-chain → OAuth `code`.
- On-device face detection (Google ML Kit) with a forgiving readiness gate.
- Passive liveness (natural movement / blink / head pose) with no user prompts.
- Best-frame selection + image compression (main ≤720px, additional ≤640px),
  processed off the UI thread.
- Device binding: device id, fingerprint, network, GPS sent to the backend.
- Platform-native camera-permission dialogs (Cupertino / Material).
- Configurable client id, redirect URI, base URL, accent colour and UI strings.
