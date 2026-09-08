#!/usr/bin/env bash
# Regenerate the circular badge PNGs the Maps pins use, from assets/logos/*.svg.
#
# Why pre-rendered: Mapbox annotation icons need image BYTES at runtime, and
# the public flutter_svg API deliberately doesn't expose a rasteriser — so the
# SVGs are rasterised ONCE here with headless Chrome (which renders the exact
# same markup as the browser) and committed as 128px RGBA PNGs on a white badge
# ring. If a logo SVG changes, re-run this.
#
#   cd frontend/save-some-ui && tool/rasterise_logos.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=assets/logos
OUT="$SRC/png"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

for svg in "$SRC"/*.svg; do
  slug=$(basename "$svg" .svg)
  cat > "$TMP/badge.html" <<HTML
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0;background:transparent}
.badge{width:128px;height:128px;display:flex;align-items:center;justify-content:center}
.ring{width:104px;height:104px;border-radius:50%;background:#fff;
  box-shadow:0 2px 6px rgba(0,0,0,.35);display:flex;align-items:center;justify-content:center;
  border:3px solid #fff}
img{width:76px;height:76px;object-fit:contain;display:block}
</style></head><body><div class="badge"><div class="ring">
<img src="file://$(realpath "$svg")">
</div></div></body></html>
HTML
  google-chrome --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --default-background-color=00000000 --window-size=128,128 \
    --screenshot="$OUT/$slug.png" "file://$TMP/badge.html" >/dev/null 2>&1
  echo "$OUT/$slug.png"
done
