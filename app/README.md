# App (Flutter: Android, iOS, Web)

Phase 5. One codebase for Android, iOS and Web. It shows the live topology,
device health and OSPF neighbours, and lets operators take WAN links up or
down, toggle and add firewall rules, read the audit log, and get alerts.

## Run (local flavor)

Start the control API first (see [`api/README.md`](../api/README.md)). Then:

```sh
cd app
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define-from-file=config/local.json
flutter run -d <android-emulator> --dart-define-from-file=config/local-android-emulator.json
flutter run -d <ios-simulator>    --dart-define-from-file=config/local.json      # on the Mac
```

- Sign in as `operator` / `operator-local`, or as `viewer` / `viewer-local`
  for view-only mode.
- The Android emulator reaches your computer at `10.0.2.2`, which is why it
  has its own config file. The iOS simulator and web use `localhost`.
- Web must run on port 8080, because that is the origin the API's CORS
  allows.
- Plain HTTP is allowed only to local addresses:
  - Android: a debug-only network security config (`10.0.2.2` and
    `localhost`); release builds keep cleartext off.
  - iOS: `NSAllowsLocalNetworking`.

## Architecture

The same conventions as Privacy Lens (STANDARDS §6):

```
lib/
  app/        app.dart: MaterialApp.router, go_router with deep links, providers
  core/       config (flavors), errors (Result / AppFailure), network (dio + interceptors),
              storage (secure token store), theme (M3 light/dark), notifications
  features/   auth | network | firewall | audit, each with domain / data / presentation
  shared/     app shell (bottom bar on phones, rail on desktop), state views, status chips
  generated/  API client generated from ../api/openapi.json (do not edit)
  l10n/       app_en.arb; every UI string lives here
```

- **State:** Cubits. App-scope Cubits are `AuthCubit` and `AlertsCubit`;
  screen-scope Cubits are topology, device, firewall and audit.
- **Errors:** repositories return `Result<T>`, never throw. RFC 9457
  problems from the API become typed `AppFailure`s with the server's detail.
- **Networking:** a Dio client with interceptors:
  - `X-Request-ID` on every call;
  - a bearer token, plus auto sign-out on 401;
  - retry with backoff for GETs only;
  - debug-only logging that never prints tokens.
- **Writes:** adding a rule sends an `Idempotency-Key`. A retry of the same
  form submission reuses the key, so the rule is never created twice.
- **Terraform-backed changes** show `Applying` and are re-checked until
  Terraform reports `Applied` or `Planned`.
- **Alerts:** polled every 10 s. New alerts appear as an in-app message on
  any screen, and the alert strip summarises them. This is the local mock
  notifier. FCM comes with the AWS phase (`docs/local-gaps.md`).
- **Accessibility (WCAG 2.2 AA):**
  - every map node is a labelled 48 dp button;
  - status uses text and icons, never colour alone;
  - errors are announced as live regions;
  - text scales.

Regenerate the client after the API changes:

```sh
dart run swagger_parser && dart run build_runner build --delete-conflicting-outputs
```

## Tests

```sh
flutter analyze                              # 0 issues
flutter test --coverage                      # 60 tests: unit, cubit, widget, golden
dart run tool/coverage_check.dart            # hand-written code: ~94% (minimum 70%)
flutter test --tags live                     # contract test against a running API
flutter test integration_test -d <device>    # core flow on an emulator/simulator
```

- **Goldens** (`test/goldens/`) cover login, the topology in light and dark,
  desktop layout and firewall rules.
  - They are generated on **Linux**, the CI platform. Windows and macOS
    render anti-aliasing slightly differently, so local runs use a 1.5%
    tolerance.
  - To regenerate them, use the Docker command at the top of
    `test/golden_test.dart`.
- **Builds checked:** `flutter build web` and `flutter build apk --debug`.
  iOS is built on the Mac.

## What it cannot do yet

- No push notifications when the app is closed. That needs Firebase (AWS
  phase).
- Subnets can be created through the API, but there is no screen for them
  yet.
