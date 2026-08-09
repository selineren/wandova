---
name: map-polygon-freeze-v11
description: Known map polygon freeze (VectorKit overlay invalidation) targeted for v1.1 — not a sync regression
metadata:
  type: project
---

Wandova has a known on-device freeze (confirmed 2026-08-09 during 1.0.1 testing): ~141% CPU, ~889 MB memory, zero disk/network. Paused stacks show VectorKit `md::OverlayLayerDataSource::invalidate` / `_updateNonTileOverlays`. Root cause is the map rendering path, planned for the v1.1 list:

- `world_countries.geojson` is 13 MB of full-resolution Natural Earth polygons.
- `VisitedCountriesMapView.updatePolygonItems()` copies every coordinate of every selected country into fresh arrays and rebuilds on each state change; SwiftUI `MapPolygon` diffs thousand-vertex polygons on `.hybrid(elevation: .realistic)`.

Ruled out as causes (verified 2026-08-09): the 1.0.1 sync changes — mergePhotos caption LWW, the by-value `mergedPhotos != localPhotos` comparison (memcmps imageData but never decodes; bounded, once per country per sync), and VisitDocumentMapper (strictly less work than 1.0). The freeze path is identical in the 1.0 App Store build (commit 2167967, build 3).

Likely fixes to explore in v1.1: simplified/decimated polygon geometry, caching PolygonItems, or MKMapView+MKPolygonRenderer instead of SwiftUI MapPolygon.
