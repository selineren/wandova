# tools

## simplify-borders.sh

Regenerates `WandovaIOS/Wandova/Resources/world_countries_simplified.geojson`
from the full-resolution `world_countries.geojson`.

```sh
./tools/simplify-borders.sh            # default: INTERVAL=5000 (meters)
INTERVAL=3000 ./tools/simplify-borders.sh   # finer output, more vertices
```

### Why this exists

`world_countries.geojson` is 13 MB of full-resolution Natural Earth
polygons (~548K vertices; Canada alone is 68K). Rendering those as SwiftUI
`MapPolygon` overlays on the `.hybrid(elevation: .realistic)` globe made
VectorKit re-tessellate everything on each overlay change — multi-second
main-thread stalls and ~1 GB of render memory (the v1.0.x map freeze).

The fix is data reduction, not threading: the map *renders* the simplified
file, while tap hit-testing (`CountryBoundaryService.getCountryOverlays()`)
keeps using the full-resolution file so border taps stay accurate.

### How it simplifies

- **mapshaper with Visvalingam simplification on a shared-arc topology.**
  mapshaper converts the polygons to shared arcs before simplifying, so a
  border shared by two countries is simplified once, identically for both
  sides. Per-feature simplification (e.g. naive Douglas-Peucker per
  polygon) would open visible gaps/overlaps between neighbours.
- **Interior rings survive.** Holes (the Lesotho hole in South Africa) are
  ordinary arcs in the topology; the script fails loudly if the South
  Africa hole disappears.
- **`keep-shapes`** prevents small islands/microstates from being removed
  entirely; the feature count must stay at 258.
- **`interval=5000`** (meters) yields vertex densities equivalent to a
  ~0.01° Douglas-Peucker tolerance: total 548K → ~44K vertices, file
  13.3 MB → ~0.9 MB. Measured per country:

  | Country   | Full-res | Simplified |
  |-----------|---------:|-----------:|
  | Canada    |   68,193 |     ~4,200 |
  | Russia    |   36,756 |     ~3,200 |
  | USA       |   35,981 |     ~2,100 |
  | Indonesia |   19,565 |     ~2,000 |
  | Brazil    |   11,121 |     ~1,000 |

- **Property filtering.** Only the ISO code fields the app reads
  (`ISO_A2`, `ISO_A2_EH`, `ADM0_A3`, `ISO_A3`) plus `ADMIN` are kept;
  Natural Earth's other ~160 fields per feature are dropped.

The output is deterministic for a given source file and interval, so the
bundled file can be regenerated and diffed at any time. Regenerate whenever
`world_countries.geojson` changes, and re-run the `WandovaTests` bundle —
`SimplifiedBoundariesTests` asserts the invariants above from the app's
point of view.
