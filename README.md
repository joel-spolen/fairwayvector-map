# FairwayVector Map — development API pause + GPXZ terrain

## Development pause — default for BOTH Debug and Release

**Golf API and GPXZ default to MOCK, regardless of existing credentials.**
Tracked build settings are `GOLF_API_MODE = mock` and `GPXZ_API_MODE = mock`.
The shared `DevelopmentAPIConfiguration` reads their Info.plist values; only
an explicit `live` value enables a provider. Missing/blank/unknown/unexpanded
values are mock. Existing ignored credential files were not read or edited.
Settings displays each provider's read-only mode. There is no persisted runtime
toggle and no automatic activation when a key exists.

- Golf API search/detail/coordinates/refresh run locally. Search **Sweden** and
  **Hills** (or leave the name blank) for **Demo Hills**, an invented 18-hole
  layout near 57.62° N, 12.00° E. Tee lengths, par, indexes, GPS tee/green
  markers and two rated tee sets are illustrative, **not factual Hills data**.
  Other countries/clubs return no matches; this is not worldwide coverage.
- Old live recent selections reopen as Demo Hills, explicitly labelled, without
  replacing the live recent reference. Demo recent selection has separate storage.
  CourseStore remaps before cache lookup, including legacy OSM references; mock
  geometry is reconstructed, never read/written/migrated in live geometry caches.
- Synthetic elevations form a smooth coordinate-based rolling surface, with
  coherent shared endpoints, no survey dates and no surveyed height datum.
  Charts/source metadata and recommendations say **Synthetic development terrain**
  / **DEMO DATA**. Not for play, navigation, real ratings or terrain assessment.
- GPXZ mock profiles use the same serialized overlap planner and journal/cache
  machinery, under `development-gpxz-v1:<courseID>` plus a separate versioned
  synthetic sidecar. Open/reopen and target commits can compute local fixtures,
  even with cache-only paid permits. They never read/write the live sidecar or
  inspect/initialize/reserve/reset the live budget, failure locks or backoff.
  UI shows **Mock · 0 paid requests**, not a reset live quota. Historical calls
  (including the existing five), locks and initialization markers stay intact.
- Both clients hard-gate at their final transport method **before URLSession**.
  Mock mode does not load bundle keys; explicit injected keys cannot enable it.
  Golf API mock bypasses all provider caches, including force refresh.
  Demo IDs are blocked from live provider requests after switching modes.
- **Open-Meteo weather and Apple Maps remain live/cache-backed and unchanged.**
  Recommendations still require complete matching weather and the existing
  Practice bag/calibration; no invented wind, weather or launch calibration.

### Explicit activation for later authorized testing

Leave tracked defaults at `mock`. In the existing ignored local config for the
provider being tested, add **`GOLF_API_MODE = live`** or **`GPXZ_API_MODE = live`**,
respectively. Local includes occur **after** tracked defaults. Keep the existing
`GOLF_API_KEY` / `GPXZ_API_KEY` privately configured there; never paste/print them.
Alternatively set those mode build settings explicitly in Xcode or as xcodebuild
build-setting overrides. Rebuild/reinstall and verify Settings says **LIVE** for
only the intended provider before using it. Keys alone never activate a provider.
To pause again, remove the local mode override or set it to `mock`, rebuild and
verify Settings. No UI action can flip a mock build to live.

For full real-course activation enable Golf API, select a real provider course
instead of a demo reference, and enable GPXZ separately when authorized. Live
mode retains the existing cache-first release-only acquisition, 100-call ledger,
failure-lock and backoff rules described below. Live course searches/update
checks and explicit missing shot terrain acquisition can spend provider calls.
This does not validate provider acceptance, account credentials or billing.

Offline regression **source** covers fail-safe mode parsing, existing-key mock
gates, country/club filters, cache bypass, 18-hole geometry, synthetic endpoints,
reversal/relaunch coverage, untouched five-call ledger/locks/markers/live cache,
and absence of new ledger initialization. Transport-evaluation tests now opt in
to `.live` explicitly **only with intercepted offline URLSessions**. Compilation
is permitted; test execution/app launch/live API calls are not part of this work.

## Local evaluation configuration

For later explicitly enabled live evaluation, the tracked GPXZ configuration defaults to a blank key. Optionally create
`fairwayvector-map/GPXZ.local.xcconfig` locally and set `GPXZ_API_KEY` there.
It is ignored by Git and excluded from resources. It is independent of the
Golf API key. Opening a course/hole/tee/saved flag reads terrain cache only,
without checking remote credentials. Blank or unresolved build placeholders
produce configuration guidance only on an explicit acquisition, with **zero
GPXZ HTTP requests**; cached terrain can still be used.
Do not paste credentials into chat, commit them, log them, or put them in URLs.

**A direct-client development key is extractable from the app bundle, even when
the local configuration is ignored. Production requires a backend proxy or
equivalent protected credential architecture. This migration does not implement
that backend or account-wide enforcement.** Review GPXZ and underlying data
source terms and credits before redistributing any cached data.

## Provider and validation

In explicitly enabled live mode, only GPXZ `POST /v1/elevation/sample` supplies runtime terrain worldwide.
Paths use WGS84 latitude/longitude vertices, retained in order, with
pipe-separated `latlons`, `samples` between 2 and 512, `interpolation: bilinear`,
`bathymetry: false`, and `x-api-key` in the header only. Maximum path size is
5,000 vertices. Requests use documented `application/x-www-form-urlencoded`
POST fields: `samples` is `String(count)`, a plain ASCII decimal integer,
`interpolation=bilinear`, and `bathymetry=false`. `URLQueryItem` constructs the
percent-encoded body in fixed field order; literal `+` and `|` are escaped
(`%2B`, `%7C`) so form decoding cannot turn coordinate text into spaces or
unescaped separators. For new uncovered spans up to 511 m the requested interval is
approximately 1 m; longer spans use at most 512 samples and honestly wider
spacing, not gratuitous batches. Each disconnected missing interval needs its
own request; bends within a connected missing interval are retained.

HTTP/status/count/finite coordinate, height and resolution/endpoints/order are
validated before saving anything. Raw error bodies and invalid profiles are never
persisted. Only the documented JSON `error` field may be shown, after bounded
decoding, key/URL redaction and rejection of header/credential-bearing detail.
Unknown error formats show HTTP status and an explicit missing-detail message;
transport errors never expose underlying URLSession URLs. Redirects are rejected.
There are no automatic retries, probes,
prefetch, auth checks, expiry downloads, or paid force-refresh operation.
`Retry-After` is persisted and respected by later explicit requests. Timeouts,
cancellations, server failures and other uncertain attempts remain counted.

Every validated returned point is preserved exactly with source name, source
resolution, capture dates, dataset version header, interpolation, fetched date,
and **EGM2008** height datum. Displayed sample interval and actual source
resolution are separate. Terrain alone does not imply guaranteed accuracy,
green-reading or plays-like advice. The profile and Settings link to GPXZ and its public
source/credit/licence catalogue. The sheet displays separate provenance for
origin→target and target→flag, including each path's returned source identifiers,
resolution, dates, version and sample interval. No real source-specific credit
records or full licence texts have been downloaded or bundled, and the links are
not a claim of complete attribution/licence compliance: review the catalogue
entries identified by the actual returned source names. Opening those links is an explicit user browser action, not a terrain
probe or prefetch.

## Durable course-scoped point and line cache

Course geometry and the versioned `terrain-gpxz-v1.json` sidecar live in
Application Support / CourseData / SHA256(stable provider course ID).
Identity is `golfapi:<courseID>` or `osm:<relationID>`; tee names, hole numbers
and changing course display names do not define the terrain cache.
Existing flat course caches are read and copied forward, with originals left
intact. Terrain is not cleared by course refresh, tee switching, or new GPS
fixes. The former Hills RH2000 raster packages are never migrated or loaded.

Each immutable response retains its original polyline, all exact provider
points, original sample chainages and provenance history. Covered intervals are
derived from those original segments using a local geographic numeric
projection and a 2 cm collinearity tolerance—not GPS-sized snapping, nearby
points, or sample chords across bends. Reverse/subsection/partial overlap reuse
works across holes and tees in the same provider course. For example, saved
0–200 m covers 0–150 m and 50–150 m without HTTP; 0–300 m requests only the
uncovered 200–300 m extension (the shared boundary can occur in both responses).
Disconnected points never create line coverage. Exact shared point heights can
anchor other paths. A zero-length path returns a known cached height with zero
delta; otherwise it remains unavailable, with no invented height or API call.

Extracted subpath boundaries and bends are interpolated along **original
provider chainage**, retaining both bracketing provenances and identifying local
interpolation. Missing coverage remains explicit chart gaps. No expiry refresh
or fallback raster/weather/phone altitude is used. A serial acquisition queue
covers read/plan/reserve/send/save through HTTP suspension, so overlapping
pending requests replan after the earlier atomic save. Valid responses are saved
even if the user has moved on; generations suppress obsolete UI publication.
Validated responses are retained immediately in repository-owned pending memory
before any disk write. A full response/cache snapshot is atomically written to a
separate pending journal before replacing the course sidecar. Subsequent explicit
requests first perform storage-only recovery from pending memory or the journal;
no new paid calls are permitted until the snapshot is saved and journal cleanup
succeeds. Outstanding in-memory writes also block requests for other courses
until storage-only recovery succeeds. Restart journal recovery is idempotent
(no duplicate append/refetch).
Corrupt cache or ledger fails closed instead of triggering paid redownload.
Preserve damaged files for recovery. **If storage is totally unavailable, even the
journal cannot be saved: received points survive only in the running repository's
memory, not a process termination.** No implementation can guarantee durable
persistence without writable storage; resolve storage before leaving the app.

## Local monthly safety budget

Application Support / GPXZ / monthly-ledger-v1.json records reservations
**before each outgoing paid attempt**. The limit is 100 attempts per UTC calendar
month, shared by every course and map store on this installation. Atomic writes
must succeed before dispatch. First initialization atomically saves the ledger,
then records initialization in an independent sibling marker and a UserDefaults
marker keyed by SHA256 of the standardized ledger path, before any request.
An existing validated ledger is safely bootstrapped with these markers. A missing
ledger with either marker present fails closed rather than resetting to zero;
marker/persistence failures also prevent dispatch. Old months are retained and
never silently reset on decoding errors. Exhaustion allows saved terrain only; partial cached
profiles stay visible when later gaps cannot be filled. Used/remaining counts
and uncovered-span counts are shown in the profile panel.

The same ledger also stores SHA256 fingerprints of the **actual HTTP body**
and sanitized failure reasons, never request bodies or credentials. Fixed field
order makes the corrected form body's digest deterministic. Historical invalid
JSON digests remain recorded but do not block the different corrected form body.
An identical failed HTTP/transport/validation request is blocked **before another
reservation**, including after reopening a hole, repeating a target commit or
restarting the app. Cached coverage remains usable. Failure locks do not expire
at a month boundary. **Retry terrain requires confirmation** and clears failure
locks only, after already-sent requests finish, archiving their digests/reasons
as failure history; it never refunds/resets used calls,
clears initialization markers, bypasses `Retry-After`, or overwrites saved terrain.
Correct the reported cause before confirming; a genuinely changed request can
still require a new paid attempt. Failure-lock persistence errors fail closed.

This is a **local safety limit**, not cross-device/provider billing authority.
Other devices/tools, reinstall, backup restoration, deletion of the ledger **and
both independent initialization markers**, or another application process can
bypass it. Deleting only the ledger cannot reset an initialized allowance.
Use the provider dashboard and a production
proxy for account-wide control. UTC month boundaries may differ from provider
billing; adjust the ledger policy only after confirming your actual cycle.

## Interaction and privacy

Opening a course, hole, tee, or saved flag is **cache-only**, including the
initial origin→flag/shot chain. There is **no automatic paid hole request**, on
opening, first map tap, or release of a previously paused interaction. Cache-only
permits cannot dispatch; the repository returns saved partial coverage before
request building, credential checks, failure-lock checks, ledger initialization
or reservations. An existing ledger's used count is read without writing it;
opening does not create/repair/reset a ledger. An old HTTP 400 UI status is cleared
on opening, while its ledger failure history remains intact. Without saved
coverage, the panel invites a map tap rather than immediately reporting a
missing key or repeating a previous HTTP 400.

The visible hole chart reads cached coverage only and may remain partial even
after shot acquisition. Distinct holes are never concatenated. Its
compact chart stays available while a target is dragged. Target taps commit at
release; genuine target drags update draft marker/distance on change and commit
once on end. Ordinary pan/zoom/heading and incoming GPS fixes do not request
terrain. Target interaction closes a shared thread-safe dispatch gate and
invalidates **both** hole and shot permits. The displayed hole and its pending
loading state are retained; stale shot values are invalidated and marked pending.
Already-sent responses still finish validation/persistence, even during a drag.
No subsequent gap or queued path can pass the interaction gate while dragging.
The final task creation/resume is performed under the same lock as closing the
gate, not merely checked before an asynchronous executor hop. An already-sent
request can still transfer/finish during interaction; it is not cancelled or refunded.
Release/commit reopens it for **clicked shot legs only**. The hole chart may reread
the latest cache but never spends on unrelated whole-hole gaps. Hole generations
stay independent: a cache read cannot restore the original shot after a newer
user shot. Provider, budget and storage failures do not qualify for automatic
release retries. A commit
captures the latest GPS/tee fallback origin; its profile labels retain that
snapshot rather than adopting later fixes. Refresh is explicit, cache-first,
and captures the latest origin; it does not force a paid overwrite of saved data.
There is no initial paid hole/shot chain. A failed paid origin→target load
suppresses the target→flag follow-up; cache-only chains can read both legs even
when the first is missing. The current-shot mode is selected immediately on a
target commit. Paid paths are only origin→clicked target and clicked target→flag
when distinct, each independently cache-first and budgeted; only uncovered
intervals are acquired. Explicit confirmed Retry/Refresh can acquire these shot
legs using the latest origin (flag is the target if none was selected), never
the unrelated whole hole. Hole/current-shot modes share one compact/expanded
gap-aware chart renderer. Sheet inspection only updates the map inspection mark.

### HTTP 400 diagnosis (documentation checked 2026-10-05)

The user reported GPXZ's exact reason: **“Samples argument should be a positive
integer.”**, with **5 previous local calls** to retain. The
[GPXZ points/sample reference](https://www.gpxz.io/docs/api-reference-points)
explicitly supports `/sample` POST using the same form or JSON encoding as
`/points`. The previous typed JSON integer was correct in source; this evidence
supports a **wire/server interoperability correction**, not a proven Swift
JSON library boolean/integer bug. The client now uses the documented form POST
with an explicit decimal `samples` string. The valid 2…512 bounds, coordinate
order, path normalization, and exact returned-result validation are unchanged;
no speculative lower cap was introduced.

All existing cached points/responses, old failure fingerprints/reasons and the
ledger's historical counts remain intact. This change neither resets nor refunds
the reported 5 calls. Offline regression **source** checks the form body,
percent encoding, count boundaries, both clicked legs, cache-only opens, and old
JSON locks with a five-call fixture. The fixture does not read or modify the real
user ledger. Tests have not been executed. No provider response, live request,
account usage, app launch or secrets were inspected. Compilation alone cannot
establish that the provider will accept the corrected wire format.

Runtime GPXZ sampling sends course/shot coordinates, potentially the golfer's
captured GPS location, to GPXZ. Weather (Open-Meteo), course providers and Apple
Maps remain independent and unchanged. This README/UI disclosure is not a
substitute for reviewing the release privacy policy and App Store declarations.

## On-course club recommendation

After releasing a selected map target, a compact card above the terrain panel
shows the best modeled full-swing club and up to two closest alternatives, with
predicted carry and signed short/long error against the horizontal origin→target
distance. Tap for alternatives, existing Trajectory results/physics charts with
target markers, captured conditions and endpoint terrain provenance. GPS is used
when the existing on-hole origin resolver permits it; otherwise the card explicitly
labels the tee fallback. No recommendation is shown for an unselected flag alone.

Practice and Course share `ClubRecommendationEngine`: the same effective club
launch profiles, Physics V1.1 integration, bundled HGB residual models, and absolute
corrected-carry-error ranking. Evaluation uses immutable launch snapshots on a
background actor and never prepares/selects a club or writes Practice conditions,
results, units or profile state. Missing model outputs do not fall back to stock
yardages. Setup and a nonempty bag are required. Simple mode explicitly labels its
handicap-based defaults; Medium/Advanced without any applicable calibration anchor
offer the existing Practice/Profile configuration sheet instead of predictions.

Complete captured course temperature, relative humidity, **surface** pressure and
wind plus matching finite origin/target terrain endpoints are required. No flat,
calm, sea-level-pressure or phone-altitude fallback is invented. Weather wind is
already m/s; meteorological FROM direction is rotated relative to the true shot
bearing: tailwind = −speed·cos(FROM−bearing), right-crosswind = −speed·sin(FROM−bearing).
The weather UI's km/h conversion is display-only. Pressure remains hPa; the existing
atmosphere routine converts it to Pa exactly once. Absolute GPXZ heights are shown
as provenance; target-minus-origin height alone sets the landing plane. Direct
surface pressure is **not** compensated again for terrain altitude.

The shared top-down physics chart is viewed from the golfer toward the target:
forward is up, positive lateral (physical right) is screen-right, and the target
is at zero lateral/selected downrange. Previously it plotted downrange horizontally
and lateral vertically (positive right upward), a different viewpoint from the map.
Course details now show a blowing-TO arrow from the **captured** tail/right wind
components in these same chart axes, true shot/right cardinal bearings, and the
selected club's modeled spin axis. The map arrow still correctly converts FROM
to TO and subtracts the actual camera heading, initially tee→green; that heading
can differ from the captured origin→target bearing. Physics, FROM conversion,
Practice wind controls and recommendation ranking are unchanged. Spin-induced
curvature can oppose wind; no claim is made that it caused the reported shot.
New offline regression source covers northward shots with east/west FROM wind,
shared-engine wind signs, zero-spin physical lateral signs, top-down coordinates,
target placement and arrow rotations. This fix is validated with an **app-only**
build; these new tests are neither compiled nor executed in that validation.

Dragging clears obsolete recommendations; only committed targets are evaluated.
Weather/profile changes recompute locally, with cancellation, captured-input
identity and publication guards. Incoming GPS fixes do **not** recommit shots,
read terrain cache, or invalidate captured-origin advice or an ongoing acquisition.
The card explicitly describes advice at the committed GPS/tee fallback position,
not live GPS. Releasing a target or confirming Refresh terrain captures the latest
origin using the existing cache-first acquisition/permission flow. Practice also
invalidates pending results on Reset, target/condition edits and profile/bag changes;
only the matching request generation and complete captured input may publish or
finish its calculating state. The recommender contains no GPXZ, Golf API or weather
requests and does not trigger weather refresh. Existing weather refresh/cache
behavior is unchanged; a read-only weather-location association guard prevents
old-location weather from being relabelled during a geometry change. Details always identify the provider observation time,
which can be cached; forecast surface pressure and 10 m wind are course-level,
not measurements at the golfer. Gusts and altitude-based pressure relocation are
not modeled.

Carry includes the existing ML correction; charts and lateral/downrange outcomes
remain uncorrected physics paths and are labelled accordingly. Ranking is closest
carry (the existing horizontal landing distance including lateral drift, not
downrange alone), not a guaranteed target hit or crosswind-optimized aim. The landing surface
is a horizontal plane at the target elevation, not the intervening terrain profile:
obstacles, hazards, roll, partial swings, GPS error and shot dispersion are not
simulated. Short/unreachable physics flights are disclosed in details. Offline
regression source covers wind rotation, pressure/height separation, missing inputs,
stale endpoint rejection, shared-engine equivalence and Practice-state preservation;
it is compiled only, **not executed**.

## Legacy work and validation policy

The offline Hills preparer, its requirements, acquisition status and preparation
document are explicitly archived and preserved. The acquisition-status resource
and all xcconfig files are excluded from the app's resource membership. No active
TerrainGrid raster engine remains.

This implementation is validated by compilation and `git diff --check` only.
No app launch, test execution, network/API call or credential inspection is
authorized for this migration. Offline mock/planner/ledger acceptance test source
is included for later separately authorized execution; successful compilation
does not establish live provider behavior or licence compliance.
