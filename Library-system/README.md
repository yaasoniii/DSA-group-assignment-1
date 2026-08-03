# Library and Resource Management System (Q1 - REST)

## Prerequisites
- Ballerina Swan Lake (2201.9.0 or later): https://ballerina.io/downloads/
- Verify install: `bal version`

## Project layout
```
library-system/
├── service/     # Ballerina REST API (port 8080)
│   ├── Ballerina.toml
│   └── main.bal
└── client/      # Ballerina CLI client
    ├── Ballerina.toml
    └── main.bal
```

## Running it

**1. Start the service** (in one terminal):
```
cd library-system/service
bal run
```
It listens on `http://localhost:8080/library`.

**2. Start the client** (in another terminal):
```
cd library-system/client
bal run
```
Follow the menu prompts.

## Endpoints implemented

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
| GET | `/library/assets/overdue` | Overdue dashboard |
| GET / POST / DELETE | `/library/institutions` | Manage institutions |
| POST / DELETE | `/library/assets/{assetTag}/components` | Manage components |
| POST / DELETE | `/library/assets/{assetTag}/schedules` | Manage schedules |
| POST / PUT / DELETE | `/library/assets/{assetTag}/workorders` | Manage work orders |
| POST | `/library/assets/{assetTag}/workorders/{orderId}/tasks` | Add sub-task |

## Example: create an asset
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

## Notes for the team
- All CRUD, filtering, institution, schedule, and work-order logic lives in
  `service/main.bal`, grouped into commented sections matching the team
  split (Person 2: core CRUD, Person 3: views/filtering, Person 4:
  institutions/components/schedules/work orders).
- The `assets/overdue` endpoint compares each schedule's `dueDate` against
  today's date using `time:utcToString`/`time:utcNow()` — double check this
  behaves as expected on your installed Ballerina version, since the time
  module API has changed across Swan Lake releases.
- Error handling currently returns `404` for missing assets/institutions,
  `409` for duplicate creation, and `400` for missing required fields. Add
  more validation as needed for the "error and wrong API calls" marks.
- The client is intentionally a thin wrapper over the HTTP API — if you go
  for the bonus web/mobile client, it can call the exact same endpoints.
- Not compiled/tested in this environment (no Ballerina runtime available
  here) — run `bal build` locally first thing to catch any syntax issues,
  then divide up the TODO-style sections above among the team.
