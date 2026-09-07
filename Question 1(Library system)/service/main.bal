import ballerina/http;
import ballerina/time;


public type Component record {|
    string compId;
    string name;
    string description;
|};

public type Schedule record {|
    string scheduleId;
    string 'type; // MAINTENANCE / BOOKING
    string dueDate; // ISO date, e.g. "2026-09-01"
    string description;
|};

public type WorkOrderTask record {|
    string taskId;
    string description;
    boolean completed = false;
|};

public type WorkOrder record {|
    string orderId;
    string status; // OPEN/IN_PROGRESS/CLOSED
    string description;
    WorkOrderTask[] tasks = [];
|};

public type Asset record {|
    string assetTag;
    string name;
    string description;
    string institution;
    string site;
    string status; // AVAILABLE/LOANED_OUT/UNDER_MAINTENANCE/DISPOSED
    string dateAcquired;
    Component[] components = [];
    Schedule[] schedules = [];
    WorkOrder[] workOrders = [];
|};

// PUT /assets/{assetTag} payload. The sub-collections are optional so that an
// edit that only touches the asset's own fields does not silently wipe the
// components/schedules/work orders already stored against it.
public type AssetUpdate record {|
    string assetTag?;
    string name;
    string description;
    string institution;
    string site;
    string status;
    string dateAcquired;
    Component[] components?;
    Schedule[] schedules?;
    WorkOrder[] workOrders?;
|};

// PUT /assets/{assetTag}/workorders/{orderId} payload.
public type WorkOrderUpdate record {|
    string status;
    string description?;
|};

// PUT /assets/{assetTag}/workorders/{orderId}/tasks/{taskId} payload.
public type WorkOrderTaskUpdate record {|
    boolean completed;
    string description?;
|};

public type ErrorMessage record {|
    string message;
|};

public type StatusMessage record {|
    string message;
|};


// ---------------- Validation ----------------

final readonly & string[] SCHEDULE_TYPES = ["MAINTENANCE", "BOOKING"];
final readonly & string[] WORK_ORDER_STATUSES = ["OPEN", "IN_PROGRESS", "CLOSED"];

isolated function isValidDate(string date) returns boolean {
    if date.length() != 10 {
        return false;
    }
    if date.substring(4, 5) != "-" || date.substring(7, 8) != "-" {
        return false;
    }
    int|error year = int:fromString(date.substring(0, 4));
    int|error month = int:fromString(date.substring(5, 7));
    int|error day = int:fromString(date.substring(8, 10));
    if year is error || month is error || day is error {
        return false;
    }
    if month < 1 || month > 12 || day < 1 {
        return false;
    }
    return day <= daysInMonth(month, year);
}

isolated function daysInMonth(int month, int year) returns int {
    if month == 1 || month == 3 || month == 5 || month == 7
            || month == 8 || month == 10 || month == 12 {
        return 31;
    }
    if month == 4 || month == 6 || month == 9 || month == 11 {
        return 30;
    }
    return isLeapYear(year) ? 29 : 28;
}

isolated function isLeapYear(int year) returns boolean {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}

// Today as an ISO date. ISO dates are zero-padded, so comparing them as plain
// strings gives the same ordering as comparing the dates themselves.
isolated function todayIso() returns string {
    return time:utcToString(time:utcNow()).substring(0, 10);
}

// Enum values are compared case-insensitively, so "maintenance" and
// "MAINTENANCE" both work; the normalised form is what gets stored.
isolated function normalizeEnum(string value) returns string {
    return value.trim().toUpperAscii();
}

isolated function oneOf(readonly & string[] allowed) returns string {
    return string:'join(" / ", ...allowed);
}

isolated function findWorkOrder(Asset asset, string orderId) returns WorkOrder? {
    foreach WorkOrder wo in asset.workOrders {
        if wo.orderId == orderId {
            return wo;
        }
    }
    return ();
}

isolated function findTask(WorkOrder wo, string taskId) returns WorkOrderTask? {
    foreach WorkOrderTask t in wo.tasks {
        if t.taskId == taskId {
            return t;
        }
    }
    return ();
}

map<Asset> assetStore = {};
map<string> institutionStore = {}; // acts as a set: name -> name


service /library on new http:Listener(8080) {

    //Asset CRUD

    resource function post assets(@http:Payload Asset newAsset)
            returns Asset|http:Conflict|http:BadRequest {
        if newAsset.assetTag.trim().length() == 0 {
            return <http:BadRequest>{body: {message: "assetTag is required"}};
        }
        if assetStore.hasKey(newAsset.assetTag) {
            return <http:Conflict>{body: {message: "Asset already exists: " + newAsset.assetTag}};
        }
        assetStore[newAsset.assetTag] = newAsset;
        return newAsset;
    }

    resource function get assets() returns Asset[] {
        return assetStore.toArray();
    }

    resource function get assets/[string assetTag]() returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is Asset {
            return found;
        }
        return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
    }

    resource function put assets/[string assetTag](@http:Payload AssetUpdate updated)
            returns Asset|http:NotFound|http:BadRequest {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset existing = found;
        string? bodyTag = updated.assetTag;
        if bodyTag is string && bodyTag.trim() != assetTag {
            return <http:BadRequest>{
                body: {
                    message: "assetTag in the body (" + bodyTag +
                            ") does not match the one in the URL (" + assetTag + ")"
                }
            };
        }
        Asset merged = {
            assetTag: assetTag,
            name: updated.name,
            description: updated.description,
            institution: updated.institution,
            site: updated.site,
            status: updated.status,
            dateAcquired: updated.dateAcquired,
            components: updated.components ?: existing.components,
            schedules: updated.schedules ?: existing.schedules,
            workOrders: updated.workOrders ?: existing.workOrders
        };
        assetStore[assetTag] = merged;
        return merged;
    }

    resource function delete assets/[string assetTag]() returns StatusMessage|http:NotFound {
        if !assetStore.hasKey(assetTag) {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        _ = assetStore.remove(assetTag);
        return {message: "Deleted " + assetTag};
    }

    // filtering an d views

    resource function get assets/institution/[string institution]() returns Asset[] {
        return from Asset a in assetStore
            where a.institution == institution
            select a;
    }

    resource function get assets/site/[string site]() returns Asset[] {
        return from Asset a in assetStore
            where a.site == site
            select a;
    }

    // Assets with at least one MAINTENANCE schedule whose dueDate has passed.
    // `asOf` checks the overdue position on a given day instead of today (handy
    // for demos and tests); `institution` narrows the dashboard to one campus.
    resource function get assets/overdue(string? asOf = (), string? institution = ())
            returns Asset[]|http:BadRequest {
        if asOf is string && !isValidDate(asOf) {
            return <http:BadRequest>{
                body: {message: "asOf must be a valid ISO date (YYYY-MM-DD), got: '" + asOf + "'"}
            };
        }
        string cutoff = asOf is string ? asOf : todayIso();
        Asset[] overdue = from Asset a in assetStore
            where (institution is () || a.institution == institution)
                && a.schedules.some(s => s.'type == "MAINTENANCE"
                        && isValidDate(s.dueDate)
                        && s.dueDate < cutoff)
            select a;
        return overdue;
    }

    resource function get assets/status/[string status]() returns Asset[] {
        return from Asset a in assetStore
            where a.status == status
            select a;
    }

    // Institution Management

    resource function get institutions() returns string[] {
        return institutionStore.toArray();
    }

    resource function post institutions(@http:Payload record {|string name;|} body)
            returns StatusMessage|http:Conflict {
        if institutionStore.hasKey(body.name) {
            return <http:Conflict>{body: {message: "Institution already exists: " + body.name}};
        }
        institutionStore[body.name] = body.name;
        return {message: "Institution added: " + body.name};
    }

    resource function delete institutions/[string name]() returns StatusMessage|http:NotFound {
        if !institutionStore.hasKey(name) {
            return <http:NotFound>{body: {message: "Institution not found: " + name}};
        }
        _ = institutionStore.remove(name);
        return {message: "Institution removed: " + name};
    }

    // Component Management

    resource function post assets/[string assetTag]/components(@http:Payload Component comp)
            returns Asset|http:NotFound|http:BadRequest|http:Conflict {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        if comp.compId.trim().length() == 0 {
            return <http:BadRequest>{body: {message: "compId is required"}};
        }
        if asset.components.some(c => c.compId == comp.compId) {
            return <http:Conflict>{body: {message: "Component already exists: " + comp.compId}};
        }
        asset.components.push(comp);
        assetStore[assetTag] = asset;
        return asset;
    }

    resource function delete assets/[string assetTag]/components/[string compId]()
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        Component[] remaining = from Component c in asset.components
            where c.compId != compId
            select c;
        if remaining.length() == asset.components.length() {
            return <http:NotFound>{
                body: {message: "Component not found on " + assetTag + ": " + compId}
            };
        }
        asset.components = remaining;
        assetStore[assetTag] = asset;
        return asset;
    }

    // Schedule Management (servicing + bookings)

    resource function post assets/[string assetTag]/schedules(@http:Payload Schedule sched)
            returns Asset|http:NotFound|http:BadRequest|http:Conflict {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;

        string scheduleId = sched.scheduleId.trim();
        if scheduleId.length() == 0 {
            return <http:BadRequest>{body: {message: "scheduleId is required"}};
        }
        string scheduleType = normalizeEnum(sched.'type);
        if SCHEDULE_TYPES.indexOf(scheduleType) is () {
            return <http:BadRequest>{
                body: {
                    message: "type must be one of " + oneOf(SCHEDULE_TYPES) +
                            ", got: '" + sched.'type + "'"
                }
            };
        }
        string dueDate = sched.dueDate.trim();
        if !isValidDate(dueDate) {
            return <http:BadRequest>{
                body: {
                    message: "dueDate must be a valid ISO date (YYYY-MM-DD), got: '" +
                            sched.dueDate + "'"
                }
            };
        }
        if asset.schedules.some(s => s.scheduleId == scheduleId) {
            return <http:Conflict>{
                body: {message: "Schedule already exists on " + assetTag + ": " + scheduleId}
            };
        }

        asset.schedules.push({
            scheduleId: scheduleId,
            'type: scheduleType,
            dueDate: dueDate,
            description: sched.description.trim()
        });
        assetStore[assetTag] = asset;
        return asset;
    }

    resource function delete assets/[string assetTag]/schedules/[string scheduleId]()
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        Schedule[] remaining = from Schedule s in asset.schedules
            where s.scheduleId != scheduleId
            select s;
        if remaining.length() == asset.schedules.length() {
            return <http:NotFound>{
                body: {message: "Schedule not found on " + assetTag + ": " + scheduleId}
            };
        }
        asset.schedules = remaining;
        assetStore[assetTag] = asset;
        return asset;
    }

    // Work orders & tasks

    // Open a work order. Sending no status opens it as OPEN.
    resource function post assets/[string assetTag]/workorders(@http:Payload WorkOrder wo)
            returns Asset|http:NotFound|http:BadRequest|http:Conflict {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;

        string orderId = wo.orderId.trim();
        if orderId.length() == 0 {
            return <http:BadRequest>{body: {message: "orderId is required"}};
        }
        string status = wo.status.trim().length() == 0 ? "OPEN" : normalizeEnum(wo.status);
        if WORK_ORDER_STATUSES.indexOf(status) is () {
            return <http:BadRequest>{
                body: {
                    message: "status must be one of " + oneOf(WORK_ORDER_STATUSES) +
                            ", got: '" + wo.status + "'"
                }
            };
        }
        if findWorkOrder(asset, orderId) is WorkOrder {
            return <http:Conflict>{
                body: {message: "Work order already exists on " + assetTag + ": " + orderId}
            };
        }

        // Sub-tasks can arrive with the order, so they get the same checks as
        // the ones added later through the /tasks endpoint.
        WorkOrderTask[] tasks = [];
        foreach WorkOrderTask t in wo.tasks {
            string taskId = t.taskId.trim();
            if taskId.length() == 0 {
                return <http:BadRequest>{body: {message: "taskId is required for every sub-task"}};
            }
            if tasks.some(seen => seen.taskId == taskId) {
                return <http:Conflict>{body: {message: "Duplicate sub-task id: " + taskId}};
            }
            tasks.push({
                taskId: taskId,
                description: t.description.trim(),
                completed: t.completed
            });
        }

        asset.workOrders.push({
            orderId: orderId,
            status: status,
            description: wo.description.trim(),
            tasks: tasks
        });
        assetStore[assetTag] = asset;
        return asset;
    }

    // Update / close a work order.
    resource function put assets/[string assetTag]/workorders/[string orderId](
            @http:Payload WorkOrderUpdate body)
            returns Asset|http:NotFound|http:BadRequest|http:Conflict {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        WorkOrder? target = findWorkOrder(asset, orderId);
        if target is () {
            return <http:NotFound>{
                body: {message: "Work order not found on " + assetTag + ": " + orderId}
            };
        }
        WorkOrder workOrder = target;

        string status = normalizeEnum(body.status);
        if WORK_ORDER_STATUSES.indexOf(status) is () {
            return <http:BadRequest>{
                body: {
                    message: "status must be one of " + oneOf(WORK_ORDER_STATUSES) +
                            ", got: '" + body.status + "'"
                }
            };
        }
        if workOrder.status == "CLOSED" && status != "CLOSED" {
            return <http:Conflict>{
                body: {
                    message: "Work order " + orderId +
                            " is CLOSED; open a new work order instead of re-opening it"
                }
            };
        }
        if status == "CLOSED" {
            WorkOrderTask[] pending = from WorkOrderTask t in workOrder.tasks
                where !t.completed
                select t;
            if pending.length() > 0 {
                return <http:Conflict>{
                    body: {
                        message: "Cannot close " + orderId + ": " + pending.length().toString() +
                                " sub-task(s) still incomplete"
                    }
                };
            }
        }

        workOrder.status = status;
        string? description = body.description;
        if description is string {
            workOrder.description = description.trim();
        }
        assetStore[assetTag] = asset;
        return asset;
    }

    resource function delete assets/[string assetTag]/workorders/[string orderId]()
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        WorkOrder[] remaining = from WorkOrder wo in asset.workOrders
            where wo.orderId != orderId
            select wo;
        if remaining.length() == asset.workOrders.length() {
            return <http:NotFound>{
                body: {message: "Work order not found on " + assetTag + ": " + orderId}
            };
        }
        asset.workOrders = remaining;
        assetStore[assetTag] = asset;
        return asset;
    }

    resource function post assets/[string assetTag]/workorders/[string orderId]/tasks(
            @http:Payload WorkOrderTask task)
            returns Asset|http:NotFound|http:BadRequest|http:Conflict {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        WorkOrder? target = findWorkOrder(asset, orderId);
        if target is () {
            return <http:NotFound>{
                body: {message: "Work order not found on " + assetTag + ": " + orderId}
            };
        }
        WorkOrder workOrder = target;
        if workOrder.status == "CLOSED" {
            return <http:Conflict>{
                body: {message: "Work order " + orderId + " is CLOSED; no sub-tasks can be added"}
            };
        }

        string taskId = task.taskId.trim();
        if taskId.length() == 0 {
            return <http:BadRequest>{body: {message: "taskId is required"}};
        }
        if findTask(workOrder, taskId) is WorkOrderTask {
            return <http:Conflict>{
                body: {message: "Sub-task already exists on " + orderId + ": " + taskId}
            };
        }

        workOrder.tasks.push({
            taskId: taskId,
            description: task.description.trim(),
            completed: task.completed
        });
        assetStore[assetTag] = asset;
        return asset;
    }

    // Tick a sub-task off (or re-word it).
    resource function put assets/[string assetTag]/workorders/[string orderId]/tasks/[string taskId](
            @http:Payload WorkOrderTaskUpdate body)
            returns Asset|http:NotFound|http:Conflict {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        WorkOrder? targetOrder = findWorkOrder(asset, orderId);
        if targetOrder is () {
            return <http:NotFound>{
                body: {message: "Work order not found on " + assetTag + ": " + orderId}
            };
        }
        WorkOrder workOrder = targetOrder;
        if workOrder.status == "CLOSED" {
            return <http:Conflict>{
                body: {message: "Work order " + orderId + " is CLOSED; its sub-tasks are frozen"}
            };
        }
        WorkOrderTask? targetTask = findTask(workOrder, taskId);
        if targetTask is () {
            return <http:NotFound>{
                body: {message: "Sub-task not found on " + orderId + ": " + taskId}
            };
        }
        WorkOrderTask t = targetTask;

        t.completed = body.completed;
        string? description = body.description;
        if description is string {
            t.description = description.trim();
        }
        assetStore[assetTag] = asset;
        return asset;
    }

    resource function delete assets/[string assetTag]/workorders/[string orderId]/tasks/[string taskId]()
            returns Asset|http:NotFound|http:Conflict {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        WorkOrder? targetOrder = findWorkOrder(asset, orderId);
        if targetOrder is () {
            return <http:NotFound>{
                body: {message: "Work order not found on " + assetTag + ": " + orderId}
            };
        }
        WorkOrder workOrder = targetOrder;
        if workOrder.status == "CLOSED" {
            return <http:Conflict>{
                body: {message: "Work order " + orderId + " is CLOSED; its sub-tasks are frozen"}
            };
        }
        WorkOrderTask[] remaining = from WorkOrderTask t in workOrder.tasks
            where t.taskId != taskId
            select t;
        if remaining.length() == workOrder.tasks.length() {
            return <http:NotFound>{
                body: {message: "Sub-task not found on " + orderId + ": " + taskId}
            };
        }
        workOrder.tasks = remaining;
        assetStore[assetTag] = asset;
        return asset;
    }
}
