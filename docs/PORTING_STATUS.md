# Porting status

_Last updated: 2026-11-10. Source is branch `feature/ios-native`. The Flutter reference is the BLoC flight-booking version._

## Summary

| | Dart files | Dart lines | Swift files | Swift lines | Test files |
| --- | ---: | ---: | ---: | ---: | ---: |
| Auth | 42 | 4,728 | 41 | 4,335 | 12 |
| Booking | 74 | 19,515 | 73 | 16,748 | 27 |
| Home | 3 | 4,392 | 3 | 3,001 | 1 |
| Hotel | 13 | 1,853 | 12 | 1,720 | 1 |
| Member | 14 | 3,253 | 13 | 2,853 | 2 |
| Notification | 18 | 1,664 | 17 | 2,041 | 6 |
| Profile | 7 | 2,035 | 7 | 1,496 | 1 |
| Promo | 9 | 393 | 8 | 407 | 0 |
| Ticket | 25 | 7,342 | 24 | 6,838 | 9 |
| Tour | 11 | 2,355 | 10 | 1,895 | 1 |
| Visa | 13 | 1,882 | 13 | 1,734 | 3 |
| Welcome | 1 | 205 | 1 | 140 | 0 |
| Core + App | 37 | 5,537 | 48 | 6,369 | 3 |

Every non-barrel Dart file under `lib/features/` (222 files) has a Swift file of the same name at the mirrored path.
The Dart test suite became **373 XCTest methods**. Widget-only tests (finders, goldens, gestures) were not ported. Where they asserted a rule, that rule became a unit test.

## Verification state

**Nothing has been compiled yet.** The port was written on Windows, which has no Swift toolchain.
What has been checked:

- Static cross-file checks (scripts run during integration):
  - every type, `AppContainer` property, `Route` case, `FlightBookingEvent` case, `LocaleKeys` key and `Icons` name that is referenced is also declared
  - braces and brackets balance in every file
  - every page initializer matches `RouteView`
  - no non-private redeclarations across files
  - argument-label order on every call into the foundation APIs
- One ambiguity was fixed: a file-private `ClassBadge` in `TripOptionCard.swift` clashed with the shared one.
- Each port group read back its own files and checked its calls against the other groups' Swift.

**Next step:** build on a Mac (`xcodegen && open EpicWorld.xcodeproj`, scheme *EpicWorld-uat*), then fix compile errors.
Expect a batch of them, mostly type-inference and SwiftUI builder issues, given how much was written without a compiler.
Then run the tests (⌘U) and compare each screen against the Flutter build.

## Core/App mapping (consolidated files)

The feature code is mirrored one file to one file. The cross-cutting Dart files were merged into the foundation:

| Dart | Swift |
| --- | --- |
| `main.dart`, `app/bootstrap/bootstrap.dart` | `App/EpicWorldApp.swift` (+ `AppDelegate.swift` for UIKit callbacks) |
| `app/app_widget.dart` | `App/AppWidget.swift` |
| `app/router/app_router.dart` (+ `.gr.dart`) | `App/Router/Route.swift`, `AppRouter.swift`, `RouteView.swift` |
| `app/shell/main_shell_page.dart` | `App/Shell/MainShellPage.swift` |
| `app/config/flavors.dart`, `env.dart` | `App/Config/Flavor.swift`, `Env.swift` |
| `app/config/firebase_json.dart` | not needed: iOS reads the flavor's `GoogleService-Info.plist` |
| `core/providers/*.dart` | `App/DI/AppContainer.swift` |
| `core/network/dio_client.dart`, `app_network/*` | `Core/Network/HTTPClient.swift`, `FunctionsException.swift`, `ApiException.swift`, `AppResponse.swift` |
| `core/network/api_endpoints.dart` | `Core/Network/Endpoints.swift` |
| `core/config/*.dart` | `Core/Config/AppConsts.swift`, `AppAssets.swift`, `L10n.swift` |
| `core/presentation/widgets/locale_scope.dart` | `LocaleStore` (Observation re-renders every view that shows a translation) |
| `core/presentation/widgets/{brand_logo,airline_brand_badge,flight_orbit_loader,photo_hero}.dart` | `Core/UI/Widgets/CoreWidgets.swift` |
| `core/utils/pdf_saver*.dart` | `Core/Utils/SharePresenter.swift` |
| `core/utils/super_print.dart` | `Core/Utils/Log.swift` |
| `app_core` (Result, Failure, UseCase) | `Core/Foundation/AppResult.swift`, `AppFailure.swift`, `UseCase.swift` |
| `app_storage` | `Core/Storage/AppPrefs.swift`, `SecureSessionStore.swift` |
| `app_ui_kit` | `Core/UI/Tokens/*`, `Core/UI/Components/*` |

## Known approximations

Some visuals can't be reproduced exactly, or differ by platform. Each is commented at its site.

- **Fonts:**
  - **Inter** isn't bundled yet, so headings fall back to the system font. See README → Fonts.
  - Roboto ships without a 600 weight, so `w600` resolves to the nearest available weight.
- **Blur:** `BackdropFilter` blurs use `.ultraThinMaterial`, sometimes with a tint. This affects the search card, sign-up backdrop, loading overlay, rating badges and the glass back button.
- **Sheets and dialogs:**
  - `DraggableScrollableSheet` and Material resizable sheets (filter sheet, flight details) open at a fixed height. Dragging the handle resizes some of them, but scrolling doesn't expand any of them.
  - `showDatePicker` is a dialog wrapping SwiftUI's graphical `DatePicker`.
  - The NRC dropdowns use system `Menu`s. The Title, Gender and Nationality dropdowns use a Material-style anchored popup.
  - The modal host insets dialogs by Flutter's default 40/24pt. A few dialogs with custom insets compensate with a negative padding.
- **Small differences from Material:**
  - Indeterminate spinners are iOS `ProgressView`s.
  - Material checkbox and slider colours were copied by hand.
  - Elevation shadows are approximated.
- **Keyboard:** the checkout's bottom bar rises above the keyboard; in Flutter it stays behind it. Pressing return doesn't move focus to the next field, because `AppTextField` doesn't expose its focus state.
- **E-ticket PDF:** it is drawn with Core Graphics. It breaks pages between whole blocks, where the Dart `pdf` package can split some widgets across pages.
- **Platform-specific code dropped (commented):** the Android-only paths (Play services check, notification channels, Google `clientConfigurationError`, the SmartPay in-app WebView). The iOS Flutter build opens SmartPay in the system browser too.

## Foundation gaps that features filled locally

These are candidates to move into `Core/` once the app compiles:

- A flow `Wrap` layout (written separately in Booking, Hotel and Ticket files).
- A view-width reader standing in for `LayoutBuilder` / `MediaQuery` width.
- A `TextEditingController`-like object with listeners.
- An autofocus / next-field focus API on `AppTextField`.
- A `showDialog(insetPadding:)` parameter.
- QR (`QrImageView`) and Code 128 (`Barcode`, `BarcodeWidget`) renderers in the Ticket feature.
- Riverpod `select`. `AsyncResource` now reloads only when its dependency's *value* changes (fixed during integration). Several features still carry a small private selection helper written before that fix; it is now redundant but harmless.

## Upgrade compatibility (Flutter build → native build)

- **Same bundle IDs** for prod, uat and qa.
- **Preferences:** the same `UserDefaults` keys (`flutter.` prefix), including easy_localization's `flutter.locale`.
- **Session:** the same Keychain items (`flutter_secure_storage_service`, account = key), so the signed-in session survives.
- **Same backend:** the same callable URLs, REST base URLs, payload shapes and `accept-language` header.
