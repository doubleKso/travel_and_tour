# Epic World — native iOS (Swift / SwiftUI)

This is a native rewrite of the Flutter app in this repository. It has the same logic,
UI and flow, the same backend, and the same bundle IDs and stored keys.

- **SwiftUI, iOS 17+.** It uses Observation (`@Observable`), `NavigationStack` and Swift 5 language mode.
- **The architecture mirrors `lib/`.** The clean-architecture layers per feature
  (`Data` / `Domain` / `Presentation` / `DI`) keep the same file names, type names and
  member names as the Dart code. See [docs/PORTING_GUIDE.md](docs/PORTING_GUIDE.md).
- **The backend is unchanged.** It still uses the Firebase callables (`FirebaseFunctions`), Firebase Auth +
  Google Sign-In, Firebase Messaging, and the REST API with the same endpoints and payloads.
- **An upgrade keeps the user's data.** Preferences use the same `flutter.`-prefixed
  `UserDefaults` keys, and the session uses the same Keychain layout as `flutter_secure_storage`.
  A user moving from the Flutter build stays signed in and keeps their language.
- **The pixels match.** Icons are drawn from Flutter's own MaterialIcons font, Roboto is
  bundled, and colours and sizes come from the same design tokens.

## Build on a Mac

```bash
brew install xcodegen
cd ios_native
scripts/sync_resources.sh      # only after Flutter assets/translations change
xcodegen                       # generates EpicWorld.xcodeproj from project.yml
open EpicWorld.xcodeproj
```

Pick a scheme: **EpicWorld-prod**, **EpicWorld-uat** or **EpicWorld-qa**. Each scheme
selects its flavor's bundle ID, display name, app icon, Google Sign-In URL scheme and
`.firebase/<flavor>/GoogleService-Info.plist` (a build phase copies the plist into
the app). Swift packages (Firebase, GoogleSignIn) resolve on the first build.

Run the tests with ⌘U, or:
`xcodebuild test -scheme EpicWorld-uat -destination 'platform=iOS Simulator,name=iPhone 16'`.

### Fonts

Roboto and the MaterialIcons font are copied from the Flutter SDK cache by
`sync_resources.sh`. The Flutter app also uses **Inter** for headings, and Inter
isn't in that cache. Until you add it, headings fall back to the system font,
which looks very similar. To match exactly:

1. Download Inter (OFL) from https://fonts.google.com/specimen/Inter (static TTFs).
2. Copy `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`,
   `Inter-Bold.ttf` and `Inter-ExtraBold.ttf` into `EpicWorld/Resources/Fonts/`.
3. List them under `UIAppFonts` in `EpicWorld/Resources/Info.plist`.

### Regenerating code from the Flutter tree

| Script | Regenerates | Run after |
|---|---|---|
| `scripts/sync_resources.sh` | images, SVG image sets, app icons, launch images, `l10n/*.json`, fonts | Flutter assets or translations change |
| `scripts/gen_locale_keys.sh` | `Core/Config/LocaleKeys.swift` | `lib/l10n/locale_keys.g.dart` changes |
| `scripts/gen_material_icons.sh` | `Core/UI/Icons.swift` | a new `Icons.x` is used in Dart or Swift |

The scripts need `FLUTTER_ROOT` (or `flutter` on `PATH`) for the font and icon sources.

## Layout

```
ios_native/
  project.yml               XcodeGen spec (targets, flavors, packages, schemes)
  Config/<flavor>.xcconfig  per-flavor bundle id, name, icon, Google URL scheme
  EpicWorld/
    App/                    entry point, AppDelegate, AppWidget (root), router, shell, DI container
    Core/                   Dart-compatibility layer, network, storage, l10n, UI kit, shared widgets
    Features/<Feature>/     Data · Domain · Presentation · DI, mirroring lib/features/<feature>/
    Resources/              Info.plist, entitlements, Assets.xcassets, assets/, l10n/, Fonts/
  EpicWorldTests/           XCTest ports of the Dart unit tests
  docs/PORTING_GUIDE.md     Dart → Swift conventions (read before changing code)
  docs/PORTING_STATUS.md    what is ported, verification state, known gaps
```

## Keeping the two apps in step

The Flutter app is still the reference. When Dart code changes, port the same change
to the mirrored Swift file. File and type names are identical, so the Swift file is
easy to find.
