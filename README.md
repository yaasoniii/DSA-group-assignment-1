# DSA612S — Assignment 1: Distributed Library & Rental Systems

Group assignment for Distributed Systems and Applications (DSA612S), NUST.
Two independent parts, each in its own top-level folder.

**Build status (verified 8 September 2026, Ballerina 2201.13.5):** Q1 service
and client both compile clean; `bal test` reports **17 passing, 0 failing**.

## Prerequisites
- Ballerina Swan Lake (2201.9.0 or later — most sub-projects here pin `2201.12.7`; verified working on `2201.13.5`): https://ballerina.io/downloads/
- Verify install: `bal version`
- A `.devcontainer.json` is included in each `client`/`server` package if you prefer to develop in a container.

## Repository layout

```
.
├── README.md
├── .gitignore
├── Question 1(Library system)/        # Q1 — RESTful API (50 marks) — FEATURE COMPLETE
│   ├── service/                       # Ballerina REST API, port 8080
│   │   ├── Ballerina.toml
│   │   ├── Dependencies.toml
│   │   ├── main.bal
│   │   └── tests/
│   │       ├── asset_service_test.bal          # asset CRUD + validation
│   │       └── maintenance_service_test.bal    # schedules, work orders, sub-tasks, overdue
│   └── client/                        # Ballerina CLI client
│       ├── Ballerina.toml
│       ├── Dependencies.toml
│       ├── main.bal                   # entry point, types, menu loop, fetchAsset()
│       ├── asset_management.bal       # asset CRUD flows
│       ├── views.bal                  # global/institution/site/status views, overdue dashboard
│       ├── institutions.bal           # institution management
│       ├── components.bal             # component management
│       ├── schedules.bal              # schedule manager
│       ├── work_orders.bal            # work orders & tasks
│       ├── loan_book.bal              # loan/booking flow
│       ├── date_utils.bal             # ISO date validation + today's date
│       └── http_utils.bal             # shared HTTP GET/POST/PUT/DELETE helpers
│
└── Question 2 (Rental system)/        # Q2 — gRPC (50 marks) — PROTO DONE, SERVER/CLIENT NOT STARTED
    ├── proto/
    │   └── rental.proto               # complete: RentalService + all 8 RPCs + messages
    ├── server/
    │   ├── Ballerina.toml
    │   └── main.bal                   # still the generated "Hello, World!" stub
    └── client/
        ├── Ballerina.toml
        └── main.bal                   # still the generated "Hello, World!" stub
```

## Running Question 1 (REST)

**1. Start the service** (in one terminal):
```
cd "Question 1(Library system)/service"
bal run
```
It listens on `http://localhost:8080/library`.

**2. Start the client** (in another terminal):
```
cd "Question 1(Library system)/client"
bal run
```
Follow the menu prompts.

**Running the tests.** `bal test` from the service package starts the listener
itself. **Stop any `bal run` instance first** — leaving one running produces
`error: failed to start server connector '0.0.0.0:8080': Address already in
use: bind` and the whole suite fails before a single assertion runs.

```
cd "Question 1(Library system)/service"
bal test
```

### Endpoints implemented (`service/main.bal`)

| Method | Path | Purpose |
|---|---|---|
| POST | `/library/assets` | Create asset |
| GET | `/library/assets` | List all assets (global view) |
| GET | `/library/assets/{assetTag}` | Get one asset |
| PUT | `/library/assets/{assetTag}` | Update asset |
| DELETE | `/library/assets/{assetTag}` | Delete asset |
| GET | `/library/assets/institution/{institution}` | Filter by institution (campus view) |
| GET | `/library/assets/site/{site}` | Filter by site |
| GET | `/library/assets/status/{status}` | Filter by status |
| GET | `/library/assets/overdue` | Overdue dashboard (schedules of type MAINTENANCE past due). Optional `?asOf=YYYY-MM-DD` and `?institution=` query params |
| GET / POST / DELETE | `/library/institutions` | Manage institutions |
| POST / DELETE | `/library/assets/{assetTag}/components` | Manage components |
| POST / DELETE | `/library/assets/{assetTag}/schedules` | Manage servicing + booking schedules |
| POST / PUT / DELETE | `/library/assets/{assetTag}/workorders` | Open / update / close / delete work orders |
| POST | `/library/assets/{assetTag}/workorders/{orderId}/tasks` | Add sub-task |
| PUT / DELETE | `/library/assets/{assetTag}/workorders/{orderId}/tasks/{taskId}` | Complete / re-word / remove a sub-task |

### Client menu (`client/main.bal` + feature files)

1. Asset Management (create / view / update / delete) — `asset_management.bal`
2. Views: global list, by institution, by site, by status — `views.bal`
3. Overdue Dashboard — `views.bal`
4. Institution Management — `institutions.bal`
5. Schedule Manager — `schedules.bal`
6. Component Management — `components.bal`
7. Work Orders & Tasks (open / update / close, add / complete / remove sub-tasks) — `work_orders.bal`
8. Loan an Asset / Book a Room or Lab — `loan_book.bal`

### Example: create an asset
```bash
curl -X POST http://localhost:8080/library/assets \
  -H "Content-Type: application/json" \
  -d '{
    "assetTag": "NUST-LIB-3DP-001",
    "name": "Pro-Series 3D Printer",
    "description": "High-precision lab printer",
    "institution": "Namibia University of Science and Technology",
    "site": "Main Campus - Innovation Lab",
    "status": "AVAILABLE",
    "dateAcquired": "2024-03-10"
  }'
```

### Validation and error handling (Q1)

Asset endpoints:
- `400` — blank `assetTag`, a `status` outside the enum, or a `dateAcquired`
  that is not a real ISO calendar date (`2026-02-30` is rejected, not just
  malformed strings).
- `404` — unknown asset on read, update or delete.
- `409` — creating an asset whose `assetTag` already exists.

Maintenance endpoints (schedules, work orders, sub-tasks):
- `400` — blank `scheduleId`/`orderId`/`taskId`, a `type` outside
  `MAINTENANCE`/`BOOKING`, a status outside `OPEN`/`IN_PROGRESS`/`CLOSED`,
  a `dueDate`/`asOf` that is not a real ISO calendar date, or a body
  `assetTag` that contradicts the one in the URL.
- `404` — unknown asset, schedule, work order or sub-task. Deletes used to
  return `200` for ids that were never there; they now 404.
- `409` — duplicate schedule/work-order/sub-task id, closing a work order
  that still has incomplete sub-tasks, re-opening a `CLOSED` order, or
  touching the sub-tasks of a closed order.

**Asset status enum:** `AVAILABLE`, `LOANED_OUT`, `OCCUPIED`,
`UNDER_MAINTENANCE`, `DISPOSED`. Status and type enums are matched
case-insensitively and stored upper-cased, so `"occupied"` and `"OCCUPIED"`
both work and both come back as `OCCUPIED`.

### Notes for the team (Q1)
- All CRUD, filtering, institution, schedule, and work-order logic lives in
  `service/main.bal`. The client is split into one file per feature area
  (see table above) plus shared helpers in `http_utils.bal`.
- `assets/overdue` compares each `MAINTENANCE` schedule's `dueDate` against
  today's date via `time:utcToString(time:utcNow())`. Pass `?asOf=YYYY-MM-DD`
  to ask "what was overdue on this day" instead of today, and `?institution=`
  to scope the dashboard to one campus; an unparseable `asOf` returns `400`.
- `PUT /assets/{assetTag}` only replaces `components`/`schedules`/`workOrders`
  when the request actually sends them. Before, the client's asset-edit screen
  (which sends only the asset's own fields) silently wiped every schedule and
  work order on the asset.
- The client is intentionally a thin wrapper over the HTTP API — if you go
  for the bonus web/mobile client, it can call the exact same endpoints.
- The `service/` package is lowercase. The old `Service/` (capital S) split is
  resolved; use the lowercase path in every command and script, since only that
  one resolves on a case-sensitive filesystem.

## Question 2 (gRPC — Rental Accommodation System)

**Status: contract done, implementation not started.**

`proto/rental.proto` now defines `service RentalService` with all eight
required RPCs — `add_property`, `create_users` (client streaming),
`update_property`, `remove_property`, `list_available_properties` (server
streaming), `search_property`, `book_property`, `confirm_booking` — plus the
supporting messages (`Property`, `User`, `Booking`, the request/response pairs,
and `OperationResponse`).

Both `server/main.bal` and `client/main.bal` are still the default generated
`"Hello, World!"` stub. Remaining work:

- Generate the stubs and confirm they compile:
  ```
  cd "Question 2 (Rental system)"
  bal grpc --input proto/rental.proto --output server/modules
  bal grpc --input proto/rental.proto --output client/modules
  ```
- A Ballerina gRPC server (`server/main.bal`) holding properties/users/booking
  carts/confirmed bookings in module-level `map`/`table` variables — the same
  pattern as `assetStore` in Q1 — with date-overlap validation and
  `totalCost = pricePerNight × nights` on `confirm_booking`.
- A Ballerina gRPC client (`client/main.bal`) that exercises every RPC,
  including streaming several users in one `create_users` call and consuming
  the streamed `list_available_properties` response.

## Submission checklist

**Question 1 (50 marks)**
- [x] Fix `service`/`Service` folder casing
- [x] Asset CRUD — create, read, update, delete
- [x] Global view, campus views (institution + site), status filter
- [x] Overdue dashboard, with `?asOf=` and `?institution=` scoping
- [x] Institution, component and schedule management
- [x] Work orders with full sub-task lifecycle
- [x] CLI client covering every endpoint
- [x] Validation on schedules / work orders / sub-tasks (dates, enums, missing ids, duplicates)
- [x] Asset-status enum + `dateAcquired` validation on the asset endpoints
- [x] Test payload status values aligned with the assignment's status enum
- [x] Clean `bal build` on service and client; `bal test` 17 passing / 0 failing
- [x] Full CLI + endpoint run-through
- [ ] `OCCUPIED` restored to the asset status enum *(see Known issues)*
- [ ] Bonus: web/mobile front end (~10 marks, optional)

**Question 2 (50 marks)**
- [x] Design `rental.proto` — RentalService, 8 RPCs, all messages
- [ ] Generate and compile the gRPC stubs
- [ ] Implement Q2 gRPC server
- [ ] Implement Q2 gRPC client

**Submission**
- [ ] All group members added as contributors on the repo
- [ ] Group presentation prepared

## Known issues

**1. `OCCUPIED` is missing from the asset status enum. 🔴**

`ASSET_STATUSES` in `service/main.bal` lists only `AVAILABLE`, `LOANED_OUT`,
`UNDER_MAINTENANCE`, `DISPOSED`. The assignment brief specifies five values,
including `OCCUPIED`, and the client offers it in three places
(`asset_management.bal` status menu, `loan_book.bal` room/lab booking prompt,
`views.bal` status filter). Booking a room or lab therefore fails:

```
PUT /library/assets/LAB-1  {"status":"OCCUPIED"}
-> 400 {"message":"status must be one of AVAILABLE / LOANED_OUT / UNDER_MAINTENANCE / DISPOSED, got: 'OCCUPIED'"}
```

That is menu option 8, one of the flows the brief names for the demo. Fix is
one line — add `"OCCUPIED",` to the array. Verified: with it added, the build
is clean, `bal test` stays at 17 passing, `OCCUPIED` and `occupied` both
succeed and normalise to `OCCUPIED`, `/assets/status/OCCUPIED` returns the
booked asset, and invalid values are still rejected with 400.

**2. "Add institution" reports success as an error. 🟠**

`addInstitution` in `client/institutions.bal` checks `status == 200`, but
Ballerina returns `201 Created` from `post` resource methods. A successful add
prints `Error (201): Institution added: NUST`. Every other POST wrapper in the
client already checks `200 || 201`; institutions is the only one that missed
it.

**3. "View one asset" prints raw JSON. 🟡**

`viewAssetFlow` dumps an unformatted payload, while `printAssetDetail()` in
`client/main.bal` is fully written, formats components/schedules/work orders
properly, and is never called from anywhere.

## Contributors

Every member must appear in the commit history — contribution history is part
of the group mark. Commit your own work under your own GitHub account.

| Name | Area | GitHub |
|---|---|---|
| Jason | Q1 — repository owner, integration | [@yaasoniii](https://github.com/yaasoniii) |
| Gerson | Q1 — asset-field validation | *(add handle)* |
| Robert | Q1 — test alignment, build verification, docs | *(add handle)* |
| Renate | Q1 — maintenance endpoints | [@renaote](https://github.com/renaote) |
| Penny | Q2 — users & discovery (streaming RPCs) | *(add handle)* |
| Celine | Q2 — property management | *(add handle)* |
| Albert | Q2 — booking workflow & integration | *(add handle)* |

## Demo notes — Question 1

**Opening (30 seconds).** A REST service on port 8080 under `/library`, and a
CLI client that is a thin wrapper over the HTTP API. Nine resource groups, an
in-memory `map<Asset>` store keyed on `assetTag`. The client shares no code
with the service — it re-declares the record types and talks over the wire,
which is the point of the exercise.

**Walk the happy path in this order.** Create an asset → view it → add a
component → add a schedule → open a work order → add a sub-task → complete the
sub-task → close the work order → check the overdue dashboard → loan the asset
→ filter by status → update the asset and show the schedules survive → delete.
That covers every marked feature as one continuous story.

**Design decisions to have ready:**

- *Why in-memory rather than a database?* The brief scopes this to a
  distributed-systems exercise, not persistence. `map<Asset>` gives O(1)
  lookup on the natural key. State lives in module-level variables — the same
  pattern Q2 will use for its property store.
- *Why are components, schedules and work orders nested under the asset?*
  They have no independent identity; a component only means something relative
  to its asset. Nesting the paths makes that ownership explicit and means
  deleting an asset cannot orphan anything.
- *Status codes.* `201` on create because a new resource now exists at a new
  URI. `409` rather than `400` on duplicate create, because the payload is
  valid and it is the *state* that conflicts. `409` again for closing a work
  order with incomplete sub-tasks — same reasoning, the request is well-formed
  but the transition is illegal.
- *The overdue algorithm.* Compare each `MAINTENANCE` schedule's `dueDate`
  against today as an ISO string. Lexicographic ordering on `YYYY-MM-DD` is
  equivalent to chronological ordering, so no date parsing is needed in the hot
  path; `isValidDate` guards malformed input before it reaches the comparison.
  `?asOf=` exists so the dashboard can be demonstrated deterministically
  instead of depending on the clock.
- *Case-insensitive enums.* Input is normalised then matched, and stored
  upper-cased, so the API is forgiving at the edge but the stored data stays
  canonical — which is what lets `/assets/status/{status}` use exact matching.

**Name your own limitations before the marker does.** No persistence across
restarts. No concurrency control on the shared map — the service methods are
not `isolated`, so Ballerina serialises calls rather than running them
concurrently. Plus the three items under Known issues above, each with an
identified fix. Having a numbered list of your own defects, with the remedy
already worked out, is a stronger position than hoping nobody clicks option 8.
