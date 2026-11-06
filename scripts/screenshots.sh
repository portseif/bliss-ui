#!/bin/zsh
#
# Regenerates docs/images from the BlissCatalog app: every component in the
# index (light and dark), the hero shots, and one shot per theme.
#
#   scripts/screenshots.sh
#
# Needs `cwebp` (brew install webp) and Screen Recording permission for your
# terminal (System Settings → Privacy & Security). Windows open and close on
# their own while it runs; keep the pointer off them for the cleanest shots.
#
set -euo pipefail

cd "${0:A:h}/.."

if ! command -v cwebp >/dev/null; then
  echo "cwebp not found — brew install webp" >&2
  exit 1
fi

swift build --product BlissCatalog
CATALOG=.build/debug/BlissCatalog
RAW=$(mktemp -d)
OUT=docs/images
FRAME="{{120, 120}, {1180, 720}}"

# Every component, one window each.
for scheme in Light Dark; do
  "$CATALOG" -gallery "$RAW/components/$scheme" -bliss.colorScheme "$scheme" -bliss.theme system
done

# A full catalog page: shot <name> <scheme> <theme> <catalog args…>
shot() {
  local name=$1 scheme=$2 theme=$3
  shift 3
  "$CATALOG" -capture "$RAW/pages/$name.png" -bliss.colorScheme "$scheme" -bliss.theme "$theme" \
    -blissCatalog.windowFrame "$FRAME" "$@"
}

shot hero-dark Dark system -page table -demo selection
shot hero-light Light system -page table -demo selection
shot sheet-dark Dark system -page sheets -demo sheet
shot sheet-light Light system -page sheets -demo sheet
shot theme-system Dark system -page table -demo selection
shot theme-high-contrast Light high-contrast -page table -demo selection
shot theme-color-blind-safe Dark color-blind-safe -page table -demo selection
shot theme-low-glare Light low-glare -page table -demo selection

# PNG → WebP. Component shots stay at 2x; page shots are scaled to 1600px wide.
rm -rf "$OUT/components" "$OUT/pages"
mkdir -p "$OUT/components" "$OUT/pages"
for scheme in Light Dark; do
  for file in "$RAW/components/$scheme"/*.png; do
    cwebp -quiet -q 92 -m 6 -alpha_q 100 "$file" -o "$OUT/components/${file:t:r}-${scheme:l}.webp"
  done
done
for file in "$RAW/pages"/*.png; do
  sips -Z 1600 "$file" >/dev/null
  cwebp -quiet -q 90 -m 6 -alpha_q 100 "$file" -o "$OUT/pages/${file:t:r}.webp"
done

rm -rf "$RAW"
echo "Wrote $(ls "$OUT"/components | wc -l | tr -d ' ') component and $(ls "$OUT"/pages | wc -l | tr -d ' ') page images to $OUT"
