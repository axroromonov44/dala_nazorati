# Nazorat AAT — dala_nazorati

An offline-first Flutter app for quarantine, veterinary and sanitary
inspectors. Inspectors work in the field where the connection is weak or
absent, so being offline is not the exception — it is the normal case.

## Releases and infrastructure

**Whenever the subject is shipping a build, CI, Crashlytics, push, or the
update policy, read [`docs/DEVOPS.md`](docs/DEVOPS.md) first and follow the
procedure there.** It holds the release commands, the workflows, the list of
secrets and the invariants that must not be broken.

In short, a release is:

```bash
tool/bump_build.sh 1.1.0        # always +1 on the build number
git commit -am "chore: release 1.1.0"
git tag v1.1.0 && git push origin main v1.1.0
```

The build number must go up by one on every release — both stores reject an
upload that does not. CI refuses to build when the tag and the version in
`pubspec.yaml` disagree.

## Working rules

After any change, before handing it over:

```bash
dart format lib test packages/karantin_face_sdk/lib packages/karantin_face_sdk/test
flutter analyze --fatal-infos
flutter test
```

CI runs exactly this gate (`--fatal-infos`, so info-level lints fail too);
anything that does not pass locally will not pass there either.

When native code, a plugin or `pubspec.yaml` changes, also run
`flutter build apk --debug` — `flutter analyze` does not see Gradle or
CocoaPods problems.

## Things worth knowing about this project

- **There is no staging backend.** Every build talks to production
  (`dala.efito.uz`, `datahub.karantin.uz`, `id.karantin.uz`). Keep that in
  mind when testing anything that writes data.
- **The repository is public.** `google-services.json`,
  `GoogleService-Info.plist` and `android/key.properties` are all gitignored.
  Never put a secret in the source.
- **Three languages:** `assets/translations/{uz,ru,en}.json`. A new key must
  be added to all three — `test/inspector_role_test.dart` checks this.
- **iOS permission strings** live in English in `Info.plist` with
  `uz`/`ru` localizations under `ios/Runner/*.lproj/InfoPlist.strings`.
  Adding a permission means editing all four files.
- **Shorebird** is configured: a Dart-only fix can ship with
  `shorebird patch`, without the stores.
- **Diagnostics.** `lib/core/observability/diagnostics_log.dart` records every
  network request and sync step to disk and attaches them to crash reports —
  this is how offline failures become visible.

## Code style

Comments are written in **English**, and they explain *why* rather than
*what*. Follow the surrounding code: not "added a timeout", but "without a
timeout Dio waits forever and the dialog spins indefinitely".
