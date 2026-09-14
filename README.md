# DSA612S — Assignment 1: Distributed Library & Rental Systems

Group assignment for Distributed Systems and Applications (DSA612S), NUST.
Two independent parts, each in its own top-level folder.

## Prerequisites
- Ballerina Swan Lake (2201.9.0 or later — most sub-projects here pin `2201.12.7`): https://ballerina.io/downloads/
- Verify install: `bal version`
- A `.devcontainer.json` is included in each `client`/`server` package if you prefer to develop in a container.

## Repository layout

```
.
├── README.md
├── .gitignore
├── Question 1(Library system)/        # Q1 — RESTful API (50 marks)
│   ├── service/                       # Ballerina REST API, port 8080
│   │   ├── Ballerina.toml
│   │   ├── Dependencies.toml
│   │   ├── main.bal
│   │   └── tests/
│   │       ├── asset_service_test.bal
│   │       └── maintenance_service_test.bal   # schedules, work orders, sub-tasks, overdue
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
└── Question 2 (Rental system)/        # Q2 — gRPC (50 marks)
    ├── proto/
    │   └── rental.proto               # full contract — all 8 RPCs + messages
    ├── server/                        # Ballerina gRPC server
    │   ├── Ballerina.toml
    │   ├── Dependencies.toml
    │   ├── rental_pb.bal              # generated from rental.proto
    │   └── rentalservice_service.bal  # all 8 RPCs implemented
    └── client/                        # Ballerina gRPC client
        ├── Ballerina.toml
        ├── Dependencies.toml
        ├── rental_pb.bal              # generated from rental.proto
        └── main.bal                   # menu covering all 8 RPCs
```

## ⚠️ Known gaps

The old `Service/` (capital S) vs `service/` (lowercase) folder split is **resolved** —
everything now lives in the lowercase `service/` package, and `bal build` / `bal test`
run from there.

The asset `status` field is now validated against the assignment's enum
(`AVAILABLE`, `LOANED_OUT`/`OCCUPIED`, `UNDER_MAINTENANCE`, `DISPOSED`) on
create and update, and `tests/asset_service_test.bal` posts valid enum values.
Still open: `dateAcquired` is not date-checked on the asset CRUD endpoints
(`isValidDate` in `service/main.bal` is there to reuse). Q2 has no automated
tests yet — everything there has only been exercised manually via the client.

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

### Notes for the team (Q1)
- All CRUD, filtering, institution, schedule, and work-order logic lives in
  `service/main.bal`. The client is split into one file per feature area
  (see table above) plus shared helpers in `http_utils.bal`.
- `assets/overdue` compares each `MAINTENANCE` schedule's `dueDate` against
  today's date via `time:utcToString(time:utcNow())`. Verified against
  Ballerina 2201.13.4. Pass `?asOf=YYYY-MM-DD` to ask "what was overdue on
  this day" instead of today, and `?institution=` to scope the dashboard to
  one campus; an unparseable `asOf` returns `400`.
- Status/type enums are matched case-insensitively and stored upper-cased,
  so `"booking"` and `"BOOKING"` both work.
- Error handling on the maintenance side (schedules, work orders, sub-tasks):
  - `400` — blank `scheduleId`/`orderId`/`taskId`, a `type` outside
    `MAINTENANCE`/`BOOKING`, a status outside `OPEN`/`IN_PROGRESS`/`CLOSED`,
    a `dueDate`/`asOf` that is not a real ISO calendar date (`2025-02-30` and
    `15/01/2025` are both rejected), or a body `assetTag` that contradicts
    the one in the URL.
  - `404` — unknown asset, schedule, work order or sub-task. Deletes used to
    return `200` for ids that were never there; they now 404.
  - `409` — duplicate schedule/work-order/sub-task id, closing a work order
    that still has incomplete sub-tasks, re-opening a `CLOSED` order, or
    touching the sub-tasks of a closed order.
- `PUT /assets/{assetTag}` only replaces `components`/`schedules`/`workOrders`
  when the request actually sends them. Before, the client's asset-edit screen
  (which sends only the asset's own fields) silently wiped every schedule and
  work order on the asset.
- Still open for whoever owns asset CRUD: `dateAcquired` is not date-checked.
  `isValidDate` in `service/main.bal` is there to reuse.
- `bal test` from the service package starts the listener itself, so the
  tests in `tests/` run without a separate `bal run`.
- The client is intentionally a thin wrapper over the HTTP API — if you go
  for the bonus web/mobile client, it can call the exact same endpoints.
- Run the service tests with `bal test` from `Question 1(Library system)/service`.

## Question 2 (gRPC — Rental Accommodation System)

`proto/rental.proto` defines the full contract, and both the server and
client implement all 8 RPCs:
- `add_property`, `update_property`, `remove_property`
- `create_users` (client streaming)
- `list_available_properties` (server streaming)
- `search_property`
- `book_property` — rejects overlapping bookings for the same property via
  date-range overlap checks
- `confirm_booking` — computes `totalCost` from nights stayed × the
  property's nightly rate

The gRPC server (`server/rentalservice_service.bal`) holds properties and
bookings in in-memory maps. The gRPC client (`client/main.bal`) has a menu
option for every RPC, including reading the streamed response from
`list_available_properties`.

Known gap: there are no automated tests for Q2 yet (unlike Q1's
`tests/asset_service_test.bal`) — it has only been verified by running the
client against the server manually.

**Running Q2:**
```
cd "Question 2 (Rental system)/server"
bal run
```
In another terminal:
```
cd "Question 2 (Rental system)/client"
bal run
```

## Submission checklist
- [x] Fix `service`/`Service` folder casing in Q1
- [x] Align test payload status values with the assignment's status enum
- [x] Add validation to schedules / work orders / sub-tasks (dates, enums, missing ids, duplicates)
- [x] Add asset-status enum validation to the asset CRUD endpoints
- [ ] Add `dateAcquired` validation to the asset CRUD endpoints
- [x] Design `rental.proto` for Q2
- [x] Implement Q2 gRPC server
- [x] Implement Q2 gRPC client
- [ ] Add automated tests for Q2
- [ ] All group members added as contributors on the repo
- [ ] Group presentation prepared
