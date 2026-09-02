import ballerina/test;
import ballerina/http;

// Role 3 — maintenance schedules, work orders, sub-tasks and the overdue check.
// Every test also pins down the failure path, since the marks for this section
// cover "error and wrong API calls" as much as the happy path.

http:Client maintenanceClient = check new ("http://localhost:8080/library");

const string R3_ASSET = "R3-TEST-001";

function assetTags(json payload) returns string[]|error {
    Asset[] assets = check payload.cloneWithType();
    return from Asset a in assets
        select a.assetTag;
}

function fetchAsset(string assetTag) returns Asset|error {
    http:Response resp = check maintenanceClient->get("/assets/" + assetTag);
    return check (check resp.getJsonPayload()).cloneWithType();
}

@test:Config {}
function testRole3Fixture() returns error? {
    json asset = {
        assetTag: R3_ASSET,
        name: "Role 3 Test Printer",
        description: "fixture for schedules and work orders",
        institution: "Test University",
        site: "Main Campus",
        status: "AVAILABLE",
        dateAcquired: "2024-01-10"
    };
    http:Response resp = check maintenanceClient->post("/assets", asset);
    test:assertEquals(resp.statusCode, 201, "Expected 201 Created for the fixture asset");
}

// ---------------- Schedules ----------------

@test:Config {dependsOn: [testRole3Fixture]}
function testAddSchedules() returns error? {
    json overdueService = {
        scheduleId: "SCH-PAST",
        'type: "MAINTENANCE",
        dueDate: "2020-01-15",
        description: "annual service"
    };
    http:Response resp = check maintenanceClient->post(
            "/assets/" + R3_ASSET + "/schedules", overdueService);
    test:assertEquals(resp.statusCode, 201, "Expected 201 Created for a valid schedule");

    // Lower case is accepted and normalised, so the overdue check can rely on
    // the stored value being "BOOKING"/"MAINTENANCE".
    json booking = {
        scheduleId: "SCH-BOOKING",
        'type: "booking",
        dueDate: "2030-12-01",
        description: "lab booking"
    };
    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/schedules", booking);
    test:assertEquals(resp.statusCode, 201, "Expected 201 Created for a booking schedule");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertEquals(asset.schedules.length(), 2, "Both schedules should be stored");
    test:assertEquals(asset.schedules[1].'type, "BOOKING", "Schedule type should be normalised");
}

@test:Config {dependsOn: [testAddSchedules]}
function testScheduleValidation() returns error? {
    http:Response resp = check maintenanceClient->post("/assets/NO-SUCH-ASSET/schedules", {
        scheduleId: "S1",
        'type: "MAINTENANCE",
        dueDate: "2025-01-01",
        description: "x"
    });
    test:assertEquals(resp.statusCode, 404, "Unknown asset should be 404");

    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/schedules", {
        scheduleId: "  ",
        'type: "MAINTENANCE",
        dueDate: "2025-01-01",
        description: "x"
    });
    test:assertEquals(resp.statusCode, 400, "Blank scheduleId should be 400");

    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/schedules", {
        scheduleId: "S1",
        'type: "SERVICING",
        dueDate: "2025-01-01",
        description: "x"
    });
    test:assertEquals(resp.statusCode, 400, "Unknown schedule type should be 400");

    // 30 February is a well-formed string but not a real date.
    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/schedules", {
        scheduleId: "S1",
        'type: "MAINTENANCE",
        dueDate: "2025-02-30",
        description: "x"
    });
    test:assertEquals(resp.statusCode, 400, "Impossible calendar date should be 400");

    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/schedules", {
        scheduleId: "S1",
        'type: "MAINTENANCE",
        dueDate: "15/01/2025",
        description: "x"
    });
    test:assertEquals(resp.statusCode, 400, "Non-ISO date should be 400");

    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/schedules", {
        scheduleId: "SCH-PAST",
        'type: "MAINTENANCE",
        dueDate: "2025-01-01",
        description: "duplicate"
    });
    test:assertEquals(resp.statusCode, 409, "Duplicate scheduleId should be 409");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertEquals(asset.schedules.length(), 2, "Rejected schedules must not be stored");
}

@test:Config {dependsOn: [testScheduleValidation]}
function testRemoveSchedule() returns error? {
    http:Response resp = check maintenanceClient->delete(
            "/assets/" + R3_ASSET + "/schedules/NO-SUCH-SCHEDULE");
    test:assertEquals(resp.statusCode, 404, "Removing a schedule that is not there should be 404");

    resp = check maintenanceClient->delete("/assets/" + R3_ASSET + "/schedules/SCH-BOOKING");
    test:assertEquals(resp.statusCode, 200, "Removing a real schedule should be 200");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertEquals(asset.schedules.length(), 1, "Only the maintenance schedule should remain");
}

// ---------------- Overdue check ----------------

@test:Config {dependsOn: [testAddSchedules]}
function testOverdueCheck() returns error? {
    // SCH-PAST is due 2020-01-15.
    http:Response resp = check maintenanceClient->get("/assets/overdue?asOf=2020-01-16");
    string[] tags = check assetTags(check resp.getJsonPayload());
    test:assertTrue(tags.indexOf(R3_ASSET) !is (), "Asset should be overdue the day after its due date");

    resp = check maintenanceClient->get("/assets/overdue?asOf=2020-01-15");
    tags = check assetTags(check resp.getJsonPayload());
    test:assertTrue(tags.indexOf(R3_ASSET) is (), "An asset is not overdue on its due date");

    resp = check maintenanceClient->get("/assets/overdue?institution=Nowhere");
    tags = check assetTags(check resp.getJsonPayload());
    test:assertEquals(tags.length(), 0, "Filtering by an unknown institution should return nothing");

    resp = check maintenanceClient->get("/assets/overdue?asOf=not-a-date");
    test:assertEquals(resp.statusCode, 400, "A bad asOf date should be 400");

    // /assets/overdue must not be swallowed by /assets/{assetTag}.
    resp = check maintenanceClient->get("/assets/overdue");
    test:assertEquals(resp.statusCode, 200, "The overdue route should win over the assetTag route");
}

// ---------------- Work orders and sub-tasks ----------------

@test:Config {dependsOn: [testRole3Fixture]}
function testOpenWorkOrder() returns error? {
    // No status means "open this one".
    http:Response resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/workorders", {
        orderId: "WO-1",
        status: "",
        description: "replace nozzle"
    });
    test:assertEquals(resp.statusCode, 201, "Expected 201 Created for a new work order");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertEquals(asset.workOrders[0].status, "OPEN", "A work order with no status opens as OPEN");
}

@test:Config {dependsOn: [testOpenWorkOrder]}
function testWorkOrderValidation() returns error? {
    http:Response resp = check maintenanceClient->post("/assets/NO-SUCH-ASSET/workorders", {
        orderId: "WO-9",
        status: "OPEN",
        description: "x"
    });
    test:assertEquals(resp.statusCode, 404, "Unknown asset should be 404");

    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/workorders", {
        orderId: "",
        status: "OPEN",
        description: "x"
    });
    test:assertEquals(resp.statusCode, 400, "Blank orderId should be 400");

    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/workorders", {
        orderId: "WO-9",
        status: "PENDING",
        description: "x"
    });
    test:assertEquals(resp.statusCode, 400, "Unknown work order status should be 400");

    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/workorders", {
        orderId: "WO-1",
        status: "OPEN",
        description: "duplicate"
    });
    test:assertEquals(resp.statusCode, 409, "Duplicate orderId should be 409");

    resp = check maintenanceClient->put("/assets/" + R3_ASSET + "/workorders/NO-SUCH-ORDER", {
        status: "CLOSED"
    });
    test:assertEquals(resp.statusCode, 404, "Updating a work order that is not there should be 404");

    resp = check maintenanceClient->put("/assets/" + R3_ASSET + "/workorders/WO-1", {
        status: "DONE"
    });
    test:assertEquals(resp.statusCode, 400, "Updating to an unknown status should be 400");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertEquals(asset.workOrders.length(), 1, "Rejected work orders must not be stored");
}

@test:Config {dependsOn: [testWorkOrderValidation]}
function testSubTaskLifecycle() returns error? {
    http:Response resp = check maintenanceClient->post(
            "/assets/" + R3_ASSET + "/workorders/WO-1/tasks",
            {taskId: "T-1", description: "order the part"});
    test:assertEquals(resp.statusCode, 201, "Expected 201 Created for a new sub-task");

    resp = check maintenanceClient->post(
            "/assets/" + R3_ASSET + "/workorders/NO-SUCH-ORDER/tasks",
            {taskId: "T-2", description: "x"});
    test:assertEquals(resp.statusCode, 404, "A sub-task on an unknown work order should be 404");

    resp = check maintenanceClient->post(
            "/assets/" + R3_ASSET + "/workorders/WO-1/tasks",
            {taskId: " ", description: "x"});
    test:assertEquals(resp.statusCode, 400, "Blank taskId should be 400");

    resp = check maintenanceClient->post(
            "/assets/" + R3_ASSET + "/workorders/WO-1/tasks",
            {taskId: "T-1", description: "duplicate"});
    test:assertEquals(resp.statusCode, 409, "Duplicate taskId should be 409");

    // An order with unfinished sub-tasks cannot be closed.
    resp = check maintenanceClient->put("/assets/" + R3_ASSET + "/workorders/WO-1",
            {status: "CLOSED"});
    test:assertEquals(resp.statusCode, 409, "Closing with an open sub-task should be 409");

    resp = check maintenanceClient->put(
            "/assets/" + R3_ASSET + "/workorders/WO-1/tasks/NO-SUCH-TASK", {completed: true});
    test:assertEquals(resp.statusCode, 404, "Completing a sub-task that is not there should be 404");

    resp = check maintenanceClient->put(
            "/assets/" + R3_ASSET + "/workorders/WO-1/tasks/T-1", {completed: true});
    test:assertEquals(resp.statusCode, 200, "Completing a sub-task should be 200");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertTrue(asset.workOrders[0].tasks[0].completed, "The sub-task should be marked complete");
}

@test:Config {dependsOn: [testSubTaskLifecycle]}
function testCloseWorkOrder() returns error? {
    http:Response resp = check maintenanceClient->put("/assets/" + R3_ASSET + "/workorders/WO-1",
            {status: "in_progress"});
    test:assertEquals(resp.statusCode, 200, "Status should be accepted case-insensitively");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertEquals(asset.workOrders[0].status, "IN_PROGRESS", "Status should be normalised");

    resp = check maintenanceClient->put("/assets/" + R3_ASSET + "/workorders/WO-1",
            {status: "CLOSED"});
    test:assertEquals(resp.statusCode, 200, "Closing with all sub-tasks done should be 200");

    resp = check maintenanceClient->put("/assets/" + R3_ASSET + "/workorders/WO-1",
            {status: "OPEN"});
    test:assertEquals(resp.statusCode, 409, "Re-opening a closed work order should be 409");

    resp = check maintenanceClient->post("/assets/" + R3_ASSET + "/workorders/WO-1/tasks",
            {taskId: "T-9", description: "too late"});
    test:assertEquals(resp.statusCode, 409, "Adding a sub-task to a closed order should be 409");
}

@test:Config {dependsOn: [testCloseWorkOrder]}
function testDeleteWorkOrder() returns error? {
    http:Response resp = check maintenanceClient->delete(
            "/assets/" + R3_ASSET + "/workorders/NO-SUCH-ORDER");
    test:assertEquals(resp.statusCode, 404, "Deleting a work order that is not there should be 404");

    resp = check maintenanceClient->delete("/assets/" + R3_ASSET + "/workorders/WO-1");
    test:assertEquals(resp.statusCode, 200, "Deleting a real work order should be 200");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertEquals(asset.workOrders.length(), 0, "The work order should be gone");
}

// ---------------- Asset edits must not wipe maintenance data ----------------

@test:Config {dependsOn: [testRemoveSchedule, testDeleteWorkOrder]}
function testAssetUpdateKeepsSchedules() returns error? {
    // The client's asset edit screen sends only the asset's own fields.
    http:Response resp = check maintenanceClient->put("/assets/" + R3_ASSET, {
        assetTag: R3_ASSET,
        name: "Role 3 Test Printer (serviced)",
        description: "fixture for schedules and work orders",
        institution: "Test University",
        site: "Main Campus",
        status: "UNDER_MAINTENANCE",
        dateAcquired: "2024-01-10"
    });
    test:assertEquals(resp.statusCode, 200, "Expected 200 OK for the asset update");

    Asset asset = check fetchAsset(R3_ASSET);
    test:assertEquals(asset.name, "Role 3 Test Printer (serviced)", "The edit should apply");
    test:assertEquals(asset.schedules.length(), 1, "The schedule must survive an asset edit");

    resp = check maintenanceClient->put("/assets/" + R3_ASSET, {
        assetTag: "SOME-OTHER-TAG",
        name: "x",
        description: "x",
        institution: "x",
        site: "x",
        status: "AVAILABLE",
        dateAcquired: "2024-01-10"
    });
    test:assertEquals(resp.statusCode, 400, "A body/URL assetTag mismatch should be 400");
}

@test:Config {dependsOn: [testAssetUpdateKeepsSchedules]}
function testRole3Teardown() returns error? {
    http:Response resp = check maintenanceClient->delete("/assets/" + R3_ASSET);
    test:assertEquals(resp.statusCode, 200, "Expected 200 OK when removing the fixture");
}
