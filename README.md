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
├── Question 1(Library system)/        # Q1 — RESTful API (50 marks) — IN PROGRESS
│   ├── service/                       # Ballerina REST API, port 8080
│   │   ├── Ballerina.toml
│   │   └── main.bal
│   ├── Service/                       # ⚠️ see "Known issue" below
│   │   ├── Dependencies.toml
│   │   └── tests/
│   │       └── asset_service_test.bal
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
│       └── http_utils.bal             # shared HTTP GET/POST/PUT/DELETE helpers
│
└── Question 2 (Rental system)/        # Q2 — gRPC (50 marks) — NOT STARTED
    ├── proto/
    │   └── rental.proto               # currently empty — service/messages not yet defined
    ├── server/
    │   ├── Ballerina.toml
    │   └── main.bal                   # still the generated "Hello, World!" stub
    └── client/
        ├── Ballerina.toml
        └── main.bal                   # still the generated "Hello, World!" stub
```

## ⚠️ Known issue to fix before submitting Q1

`Question 1(Library system)/` currently has **two differently-cased folders** that should be one:

- `service/` (lowercase) — has `Ballerina.toml` and `main.bal`
- `Service/` (capital S) — has `Dependencies.toml` and `tests/`

On most systems you'll actually work on (Linux, macOS with case-sensitive mode, GitHub, CI runners) these are treated as **separate directories**. That means:
- the real service package (`service/`) has no `Dependencies.toml` of its own yet (Ballerina will regenerate one on first `bal build`, so this alone isn't fatal), and
- `tests/asset_service_test.bal` is sitting in a folder with no `Ballerina.toml`/`main.bal`, so `bal test` won't find the package config it needs.

**Fix:** move `Dependencies.toml` and `tests/` into the lowercase `service/` folder and delete the stray `Service/` folder, then re-run `bal build` / `bal test` from `service/` to confirm it resolves.

Also worth a look while you're in there: `tests/asset_service_test.bal` posts `"status": "active"` / `"inactive"`, which aren't part of the assignment's status enum (`AVAILABLE`, `LOANED_OUT`/`OCCUPIED`, `UNDER_MAINTENANCE`, `DISPOSED`). The server doesn't currently validate the status value, so the tests will still pass, but it's inconsistent with the spec and worth aligning.

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
| GET | `/library/assets/overdue` | Overdue dashboard (schedules of type MAINTENANCE past due) |
| GET / POST / DELETE | `/library/institutions` | Manage institutions |
| POST / DELETE | `/library/assets/{assetTag}/components` | Manage components |
| POST / DELETE | `/library/assets/{assetTag}/schedules` | Manage schedules |
| POST / PUT / DELETE | `/library/assets/{assetTag}/workorders` | Manage work orders |
| POST | `/library/assets/{assetTag}/workorders/{orderId}/tasks` | Add sub-task |

### Client menu (`client/main.bal` + feature files)

1. Asset Management (create / view / update / delete) — `asset_management.bal`
2. Views: global list, by institution, by site, by status — `views.bal`
3. Overdue Dashboard — `views.bal`
4. Institution Management — `institutions.bal`
5. Schedule Manager — `schedules.bal`
6. Component Management — `components.bal`
7. Work Orders & Tasks — `work_orders.bal`
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
  today's date via `time:utcToString(time:utcNow())` — double-check this
  behaves as expected on your installed Ballerina version, since the `time`
  module API has changed across Swan Lake releases.
- Error handling currently returns `404` for missing assets/institutions,
  `409` for duplicate creation, and `400` for missing required fields
  (e.g. blank `assetTag`/`compId`). Add more validation as needed for the
  "error and wrong API calls" marks — e.g. status-enum validation, date
  format checks on schedules (the client and service both use
  `isValidDate`-style ISO date strings), and validation on schedule/work
  order/component payloads which currently accept anything.
- The client is intentionally a thin wrapper over the HTTP API — if you go
  for the bonus web/mobile client, it can call the exact same endpoints.
- Fix the `service` / `Service` casing issue above before running `bal build`
  from a fresh clone or in CI.

## Question 2 (gRPC — Rental Accommodation System)

**Status: not yet started.** `proto/rental.proto` is empty, and both
`server/main.bal` and `client/main.bal` are still the default generated
`"Hello, World!"` stub.

Per the assignment brief, this needs:
- A `.proto` contract defining `add_property`, `create_users` (client
  streaming), `update_property`, `remove_property`, `list_available_properties`
  (server streaming), `search_property`, `book_property`, and
  `confirm_booking`.
- A Ballerina gRPC server (`server/main.bal`) holding properties/bookings in
  a `map`/`table`, with date-overlap validation and cost calculation on
  `confirm_booking`.
- A Ballerina gRPC client (`client/main.bal`) that exercises every RPC,
  including handling the streamed response from `list_available_properties`.

## Submission checklist
- [ ] Fix `service`/`Service` folder casing in Q1
- [ ] Align test payload status values with the assignment's status enum
- [ ] Add remaining validation to Q1 service (status enum, dates on schedules/work orders)
- [ ] Design `rental.proto` for Q2
- [ ] Implement Q2 gRPC server
- [ ] Implement Q2 gRPC client
- [ ] All group members added as contributors on the repo
- [ ] Group presentation prepared
