---
name: map-polygon-freeze-v11
description: Map polygon freeze (VectorKit overlay invalidation) — fixed in 1.0.2 via bundled simplified borders + cached polygon items; keep concurrency out of the map path
metadata:
  type: project
---

Wandova had an on-device freeze (confirmed 2026-08-09 during 1.0.1 testing): ~140% CPU, up to ~1.11 GB memory, zero disk/network. Paused stacks showed VectorKit `md::OverlayLayerDataSource::invalidate` / `_updateNonTileOverlays`. Root cause was the map rendering path: 13 MB of full-resolution Natural Earth polygons (~548K vertices; Canada 68K) rendered as SwiftUI `MapPolygon` on `.hybrid(elevation: .realistic)`, fully rebuilt and re-diffed on every country toggle AND every camera settle.

**Fixed in 1.0.2** (branch perf/v1.0.2-map-performance, 2026-08-09) by reducing work, deliberately touching no concurrency:

- `tools/simplify-borders.sh` (mapshaper, shared-arc Visvalingam, `interval=5000`, `keep-shapes`) generates bundled `world_countries_simplified.geojson` (~44K vertices, 1 MB). Rendering reads it; tap hit-testing keeps the full-resolution file.
- `CountryPolygonItemBuilder` caches per-country render items once at load (MKPolygon references incl. `interiorPolygons` — this also fixed holes: Lesotho used to be painted over); toggles concat over a **sorted** country list (Set iteration order previously caused nondeterministic ForEach order).
- Camera settles no longer invalidate any body: exact latDelta lives in non-observed class boxes (`CameraTracker`, `LatDeltaBox`); only threshold flags (`MapZoomUIState`) are @State; zoom buttons send `MapZoomCommand` (fresh UUID identity) instead of a shared latDelta binding.
- `WorldGeoJSONStore` decodes the full-res file once for both CountryBoundaryService and CountryDataService.
- Guarded by `SimplifiedBoundariesTests` / `CountryPolygonItemBuilderTests` / `WorldGeoJSONStoreTests` / `MapZoomStateTests`.

**History lesson (verified 2026-08-09):** the recollection of "three reverted map fixes" is wrong — no revert commits, no closed-unmerged PRs exist. What exists: four MKMapView-era optimization attempts (PRs #67, #80, #89, #91), each patching the previous one's race (async-load first-tap race → sync-fallback double-add → cross-thread renderer cache → stale diff-based annotations), all wiped by the SwiftUI globe migration (PR #172). The standing rule: reduce the map's work; do not add threading to make redundant work safe. `ComparisonMapView` intentionally stays on full-res overlays (single set used for both rendering and taps inside MKMapView renderer callbacks — the old race territory).

Ruled out as causes (verified 2026-08-09): the 1.0.1 sync changes — mergePhotos caption LWW, the by-value photo comparison, and VisitDocumentMapper. The freeze path was identical in the 1.0 App Store build (commit 2167967, build 3).
