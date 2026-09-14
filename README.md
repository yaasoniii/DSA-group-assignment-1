# DSA612S — Assignment 1: Distributed Library & Rental Systems

Group assignment for Distributed Systems and Applications (DSA612S), NUST.
Two independent parts, each in its own top-level folder — Q1 is a REST API,
Q2 is gRPC.

## Prerequisites
- Ballerina Swan Lake 2201.9.0 or later (most sub-projects here pin `2201.12.7`): https://ballerina.io/downloads/
- Check your install with `bal version`
- Each `client`/`server` package includes a `.devcontainer.json` if you'd rather develop in a container

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

### Endpoints (`service/main.bal`)

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
| GET | `/library/assets/overdue` | Overdue dashboard (maintenance schedules past due). Optional `?asOf=YYYY-MM-DD` and `?institution=` |
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

### A few things worth knowing (Q1)
- All CRUD, filtering, institution, schedule, and work-order logic lives in
  `service/main.bal`. The client is split into one file per feature area
  (see the menu list above) plus shared HTTP helpers in `http_utils.bal`.
- `assets/overdue` compares each `MAINTENANCE` schedule's `dueDate` against
  today's date. Pass `?asOf=YYYY-MM-DD` to check what was overdue on a
  different day, and `?institution=` to scope it to one campus.
- `status`/`type` values are matched case-insensitively and stored
  upper-cased, so `"booking"` and `"BOOKING"` both work.
- Validation on the maintenance side (schedules, work orders, sub-tasks):
  - `400` for a blank `scheduleId`/`orderId`/`taskId`, a `type` outside
    `MAINTENANCE`/`BOOKING`, a status outside `OPEN`/`IN_PROGRESS`/`CLOSED`,
    a `dueDate`/`asOf` that isn't a real calendar date, or a body `assetTag`
    that contradicts the one in the URL.
  - `404` for an unknown asset, schedule, work order or sub-task.
  - `409` for a duplicate schedule/work-order/sub-task id, closing a work
    order that still has incomplete sub-tasks, re-opening a `CLOSED` order,
    or touching sub-tasks on an order that's already closed.
- `PUT /assets/{assetTag}` only replaces `components`/`schedules`/`workOrders`
  when the request body actually includes them, so editing an asset's own
  fields doesn't wipe its schedules and work orders.
- `bal test` from the service package starts its own listener, so the tests
  under `tests/` run without a separate `bal run`.
- The client is a thin wrapper over the HTTP API, so a bonus web/mobile
  client could call the same endpoints without changes on the service side.

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

The server (`server/rentalservice_service.bal`) keeps properties and
bookings in in-memory maps. The client (`client/main.bal`) has a menu
option for every RPC, including reading the streamed response from
`list_available_properties`.

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
