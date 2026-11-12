#!/usr/bin/env bash
# Copies the Flutter app's shared resources into the native iOS project.
#
# The Flutter tree stays the single source of truth for imagery, icons,
# translations and app icons. Re-run this after any of them change:
#
#   ios_native/scripts/sync_resources.sh
#
# What lands where (all under ios_native/EpicWorld/Resources):
#   assets/…            raster images, mirrored at their Flutter paths and
#                       shipped as a folder reference, so `AppAssets` keeps
#                       the exact strings Dart uses ("assets/images/b4.jpg").
#   Assets.xcassets/Svg every .svg as a vector image set named by its file
#                       stem — UIKit cannot draw an SVG from a loose file.
#   Assets.xcassets/AppIcon-<flavor>.appiconset   from ios/Runner.
#   l10n/en.json, my.json                         from assets/l10n.
#   Fonts/              Roboto + Flutter's MaterialIcons font, taken from the
#                       Flutter SDK cache (set FLUTTER_ROOT if `flutter` is not
#                       on PATH). Inter is not in that cache — see README.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
RES="$HERE/EpicWorld/Resources"
XC="$RES/Assets.xcassets"

if [[ -z "${FLUTTER_ROOT:-}" ]] && command -v flutter >/dev/null 2>&1; then
  FLUTTER_ROOT="$(cd "$(dirname "$(command -v flutter)")/.." && pwd)"
fi
FONTS_SRC="${FLUTTER_ROOT:-}/bin/cache/artifacts/material_fonts"

contents_json() { # $1 = file name inside the set
  cat <<JSON
{
  "images" : [
    {
      "filename" : "$1",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "original"
  }
}
JSON
}

echo "→ raster images"
rm -rf "$RES/assets"
(cd "$REPO" && find assets/images assets/icons -type f ! -name '*.svg' ! -name '.DS_Store') |
  while IFS= read -r f; do
    mkdir -p "$RES/$(dirname "$f")"
    cp "$REPO/$f" "$RES/$f"
  done

echo "→ svg image sets"
mkdir -p "$XC"
[[ -f "$XC/Contents.json" ]] || printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' > "$XC/Contents.json"
rm -rf "$XC/Svg"
mkdir -p "$XC/Svg"
printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' > "$XC/Svg/Contents.json"
dupes="$(cd "$REPO" && find assets -name '*.svg' -exec basename {} .svg \; | sort | uniq -d)"
if [[ -n "$dupes" ]]; then
  echo "SVG names must be unique across assets/ (image sets are named by stem): $dupes" >&2
  exit 1
fi
(cd "$REPO" && find assets -type f -name '*.svg') |
  while IFS= read -r f; do
    name="$(basename "$f" .svg)"
    set_dir="$XC/Svg/$name.imageset"
    mkdir -p "$set_dir"
    cp "$REPO/$f" "$set_dir/$name.svg"
    contents_json "$name.svg" > "$set_dir/Contents.json"
  done

echo "→ app icons + launch images"
for flavor in prod uat qa; do
  src="$REPO/ios/Runner/Assets.xcassets/AppIcon-$flavor.appiconset"
  if [[ -d "$src" ]]; then
    rm -rf "$XC/AppIcon-$flavor.appiconset"
    cp -R "$src" "$XC/AppIcon-$flavor.appiconset"
  fi
  launch="$REPO/ios/Runner/Assets.xcassets/${flavor}LaunchImage.imageset"
  if [[ -d "$launch" ]]; then
    rm -rf "$XC/LaunchImage-$flavor.imageset"
    cp -R "$launch" "$XC/LaunchImage-$flavor.imageset"
    rm -f "$XC/LaunchImage-$flavor.imageset/README.md"
  fi
done
# The Flutter launch storyboards draw the image on black.
mkdir -p "$XC/LaunchBackground.colorset"
cat > "$XC/LaunchBackground.colorset/Contents.json" <<'JSON'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.000", "green" : "0.000", "red" : "0.000" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "→ translations"
mkdir -p "$RES/l10n"
cp "$REPO"/assets/l10n/*.json "$RES/l10n/"

echo "→ fonts"
mkdir -p "$RES/Fonts"
if [[ -d "$FONTS_SRC" ]]; then
  cp "$FONTS_SRC/materialicons-regular.otf" "$RES/Fonts/MaterialIcons-Regular.otf"
  for weight in thin light regular medium bold black; do
    cp "$FONTS_SRC/roboto-$weight.ttf" "$RES/Fonts/Roboto-$weight.ttf"
  done
  cp "$FONTS_SRC/materialicons_license.txt" "$RES/Fonts/MaterialIcons-LICENSE.txt"
  cp "$FONTS_SRC/roboto_license.txt" "$RES/Fonts/Roboto-LICENSE.txt"
else
  echo "  ! Flutter SDK font cache not found ($FONTS_SRC) — fonts left as they are." >&2
fi

echo "✓ resources synced into $RES"
