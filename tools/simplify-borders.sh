#!/usr/bin/env bash
#
# Regenerates WandovaIOS/Wandova/Resources/world_countries_simplified.geojson
# from the full-resolution world_countries.geojson.
#
# The simplified file is what the map RENDERS (MapPolygon overlays). Tap
# hit-testing keeps using the full-resolution file, so border-tap accuracy
# is unaffected. See tools/README.md for background and tuning notes.
#
# Requirements: node/npx (mapshaper is fetched via npx), python3.
#
# Why mapshaper + Visvalingam, not per-feature Douglas-Peucker:
# mapshaper builds a shared-arc topology before simplifying, so a border
# shared by two countries is simplified once and identically for both.
# Per-feature simplification would shift each side independently and open
# gaps/overlaps between neighbours. Interior rings (e.g. the Lesotho hole
# in South Africa) are ordinary arcs in that topology and survive intact.
#
# INTERVAL is Visvalingam's threshold in meters. 5000 m produces vertex
# densities equivalent to roughly 0.01-degree Douglas-Peucker tolerance
# (~548K total vertices -> ~44K; Canada 68K -> ~4K). keep-shapes prevents
# small islands and microstates from being simplified out of existence.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/WandovaIOS/Wandova/Resources/world_countries.geojson"
OUT="$REPO_ROOT/WandovaIOS/Wandova/Resources/world_countries_simplified.geojson"
INTERVAL="${INTERVAL:-5000}"

# Only the fields the app reads survive into the bundled file: the ISO code
# fields used by CountryBoundaryService.extractCountryCode, plus ADMIN for
# tests/debugging. This halves the output size (Natural Earth ships ~168
# property fields per feature).
FIELDS="ISO_A2,ISO_A2_EH,ADM0_A3,ISO_A3,ADMIN"

npx mapshaper "$SRC" \
  -simplify visvalingam interval="$INTERVAL" keep-shapes \
  -filter-fields "$FIELDS" \
  -o precision=0.00001 force "$OUT"

python3 - "$SRC" "$OUT" <<'EOF'
import json, os, sys

def stats(path):
    with open(path) as f:
        gj = json.load(f)
    total, per = 0, {}
    for feat in gj["features"]:
        name = feat.get("properties", {}).get("ADMIN", "?")
        g = feat["geometry"]
        if g["type"] == "Polygon":
            v = sum(len(r) for r in g["coordinates"])
        elif g["type"] == "MultiPolygon":
            v = sum(len(r) for poly in g["coordinates"] for r in poly)
        else:
            v = 0
        per[name] = per.get(name, 0) + v
        total += v
    return len(gj["features"]), total, per

src, out = sys.argv[1], sys.argv[2]
sn, st, sper = stats(src)
on, ot, oper = stats(out)
print(f"\nfeatures: {sn} -> {on}" + ("  !! FEATURE COUNT CHANGED" if sn != on else ""))
print(f"total vertices: {st:,} -> {ot:,} ({100*ot/st:.1f}%)")
print(f"file size: {os.path.getsize(src)/1e6:.1f} MB -> {os.path.getsize(out)/1e6:.1f} MB")
for c in ["Canada", "Russia", "United States of America", "Indonesia", "Brazil", "South Africa", "Lesotho"]:
    print(f"  {c:28s} {sper.get(c, 0):>8,} -> {oper.get(c, 0):>7,}")

# Hole check: South Africa must keep its Lesotho interior ring.
with open(out) as f:
    gj = json.load(f)
for feat in gj["features"]:
    if feat["properties"].get("ADMIN") == "South Africa":
        g = feat["geometry"]
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        holes = sum(len(p) - 1 for p in polys)
        print(f"South Africa interior rings: {holes}")
        if holes == 0:
            sys.exit("ERROR: Lesotho hole was lost during simplification")
EOF
