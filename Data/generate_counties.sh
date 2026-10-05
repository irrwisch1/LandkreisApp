#!/usr/bin/env bash
# Generates LandkreisJaeger/counties.geojson (WGS84, simplified) from the BKG dataset VG250, layer KRS.
# Usage:     Data/generate_counties.sh /path/to/VG250_KRS.shp
# Requires:  Node.js (for mapshaper), e.g. brew install node
set -euo pipefail
SHP="${1:?Please pass the path to VG250_KRS.shp}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/LandkreisJaeger/counties.geojson"

npx --yes mapshaper -i "$SHP" encoding=utf8 \
  -filter 'GF == 4' \
  -filter-fields AGS,GEN,BEZ \
  -proj wgs84 \
  -simplify 25% keep-shapes \
  -o format=geojson precision=0.00001 "$OUT"

echo "Done: $OUT ($(du -h "$OUT" | cut -f1))"
