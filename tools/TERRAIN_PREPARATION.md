# Hills Sweden: genuine offline terrain preparation

> **ARCHIVED — not the active terrain workflow.** The iOS runtime now uses
> GPXZ worldwide exclusively. This document and its offline preparer are preserved
> as historical work, not GPXZ inputs. RH2000 packages must never enter the EGM2008
> cache. No raster resource is loaded by the app. See the repository README for
> current configuration, durable caching, budget safeguards, and privacy.

## Current acquisition gate

Public OSM relation **10480238**, named **Hills Golf & Country Club**, is a
golf-course multipolygon. Its 164 outer boundary nodes give the exact WGS84 bbox:

**west 11.983088, south 57.616891, east 12.0170528, north 57.6303488**.

Source: https://www.openstreetmap.org/api/0.6/relation/10480238/full.json

The approximate 57.64 / 12.05 starting point is NOT the final course extent.
This bbox covers the mapped course polygon, not an independently re-audited
inventory of all 18 hole paths. No Golf API or simulator secrets were consulted.

The default 200 m buffer in the engine's local spherical EQC expands that bbox to
11.979729055413056, 57.61509235678816, 12.020411744586944, 57.63214744321184.
The output center bounds are rounded outwards by less than one additional metre.

Verified grid planning gives projection origin lat 57.6236199, lon 12.0000704,
top-left center x=-1212 m, y=949 m, and **2425 × 1899 cells**. Expected raw size is
**18,420,300 bytes**; this is a calculated size, NOT an existing terrain binary.
The actual projection/inverse checks measured 8.52e-10 m / 7.11e-15 degrees error.

Public search used:
https://api.lantmateriet.se/stac-hojd/v1/search?bbox=11.979729055413056,57.61509235678816,12.020411744586944,57.63214744321184&collections=mhm-63_3&limit=100

Four candidates were returned (no next page). The native extents are adjoining
2.5 km squares within easting 317500–322500, northing 6387500–6392500:

| Item        | Original COG      | Advertised bytes | STAC survey interval    |
| ----------- | ----------------- | ---------------: | ----------------------- |
| 639_32_0000 | 63900_3200_25.tif |         10885081 | 2019-11-29 / 2024-05-18 |
| 639_31_0075 | 63900_3175_25.tif |         10556359 | 2019-11-29              |
| 638_32_7500 | 63875_3200_25.tif |         11635961 | 2019-11-29 / 2024-05-18 |
| 638_31_7575 | 63875_3175_25.tif |         11606439 | 2019-11-29 / 2022-06-24 |

Collection: https://api.lantmateriet.se/stac-hojd/v1/collections/mhm-63_3

Items: append `/items/ITEM_ID` to the collection URL. Data asset base:
https://dl1.lantmateriet.se/hojd/data/grid1m/63_3/50/

**The first COG's anonymous HEAD returned HTTP 401** with
`WWW-Authenticate: Basic realm="Authorization Server"` (HTML, 172 bytes).
Raster acquisition stopped; other binary endpoints were not probed. Discovery
and public source metadata are accessible, but this does not grant raster access.
Obtain the small candidate COGs through the provider's authorized workflow outside
this assistant; never place credentials in this repository or pass them through
chat/tools. The preparer has no networking or authentication code.

All four STAC items declare `geometriskupplosning=1`, 2500 × 2500 cells and
EPSG:5845. PROJ identifies this as **SWEREF99 TM + RH2000 height**. These are
provider metadata declarations, NOT inspected raster headers. The first tile's
public `ursprung` metadata also contains observed `matdatum` values (including
2022-06-24 and 2024-05-18), with mixed survey techniques. Creation/modification
timestamps must not be used as survey dates.

Collection license is explicitly **CC-BY-4.0**, provider Lantmäteriet. Product:
https://geotorget.lantmateriet.se/geodataprodukter/markhojdmodell-nedladdning-api

The inspected public product pages confirmed 1 m terrain but did not expose an
explicit RH2000 statement. **Provider documentation confirmation of vertical
datum, actual raster CRS/resolution/units/NoData and source heights remain gates.**
No runnable terrain manifest or elevation binary has been created.

## Local inputs and invocation

Install only `terrain-requirements.txt` into the selected Python environment.
Run `prepare_hills_terrain.py --help` for the full CLI. Inputs are local files:

- Positional `sources`: original COG(s), retaining provider asset filenames.
- `--bounds WEST SOUTH EAST NORTH`: verified **unbuffered** course bbox above.
- `--bounds-source`: the public OSM relation URL above (or verified cache provenance).
- `--buffer-meters`: defaults to **200**; use **0** only for already-buffered bounds.
- `--stac-items`: original saved item or complete search FeatureCollection.
- `--collection`: original saved STAC collection, including its license and self link.
- `--survey-metadata`: original `_ursprung.json` files, one per COG, in COG order.
- `--datum-evidence`: local JSON with `verticalDatum: "RH2000"`, `url` pointing to
  provider documentation, and `statement` quoting its verified RH2000 statement.
  Do not create this evidence merely from an assumed datum. No vertical conversion
  is performed; provider ground heights in metres remain RH2000.
- `--output`: defaults to the app's Resources/Terrain directory.
- `--overwrite`: explicit permission to replace existing derived outputs.
- `--allow-nodata`: explicit partial-coverage opt-in; normally omitted so gaps fail.

The program checks native raster spacing, CRS vs STAC, Float32 elevation band,
units when encoded, scale/offset, shape, bounds and original advertised byte size.
It records the actual GeoTIFF driver/layout and requires observed survey date
extrema to agree with STAC's start/end interval before publishing.
It rejects remote URLs/GDAL virtual paths before raster opening. Missing metadata
fails closed. With horizontal-only raster CRS, vertical provenance still depends
on verified provider documentation, not a made-up raster vertical CRS.

Survey date is the observed minimum/maximum `matdatum` across complete input
tiles, retained as an ISO date or `start/end` range. This is deliberately
conservative: it does not pretend every cropped pixel has the same survey date.

## Derived package and checks

The native rasters are window-cropped with a 3 m interpolation halo and mosaicked
before bilinear warping, avoiding isolated interpolation at tile seams. Neither a
national mosaic nor any fixture terrain is generated. Target CRS is exactly:

`+proj=eqc +lat_ts=origin.lat +lat_0=origin.lat +lon_0=origin.lon +R=6371000 +units=m`

`projectionOrigin` is the midpoint of the verified unbuffered bbox. The target is
1 m north-to-south, row-major IEEE Float32, explicitly little endian. `originX/Y`
are the **top-left cell CENTER**, not GDAL's top-left cell corner. NoData is NaN;
never zero-filled. The grid is limited to 16 million cells and 16384 per dimension.

Outputs, only published after preprocessing validation succeeds:

- `hills-terrain-v1.f32`: raw cell heights, exactly width × height × 4 bytes.
- `hills-terrain-v1.json`: every required schema-1 TerrainGrid field and SHA256.
- `hills-preparation-report.json`: source attribution/item URLs, observed survey
  dates, datum evidence, exact bounds/buffer/PROJ string, coverage counts and checks.

The SHA256 links metadata to binary; publish/replace the manifest last. Do not
read the package concurrently with replacement. An interrupted replacement may
leave checksum-mismatched files, which the existing engine rejects.

Preprocessing checks compare Swift's spherical projection and its inverse with
PROJ at bbox corners/center (<1e-7 m and <1e-10 degrees), and compare a 7 × 7
selection of output cell centers with independent bilinear source heights (at
least five finite references, <0.02 m maximum discrepancy). These are data
preprocessing checks, not the app or Python test suites. Actual source height
equivalence cannot be verified until genuine COGs are supplied. No tests, app
launch, UI/engine edits, Golf API calls or secret access are part of this workflow.
