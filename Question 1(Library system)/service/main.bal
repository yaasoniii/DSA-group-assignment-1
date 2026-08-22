import ballerina/http;
import ballerina/time;


public type Component record {|
    string compId;
    string name;
    string description;
|};

public type Schedule record {|
    string scheduleId;
    string 'type; // MAINTENANCE | BOOKING
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
    string status; // OPEN | IN_PROGRESS | CLOSED
    string description;
    WorkOrderTask[] tasks = [];
|};

public type Asset record {|
    string assetTag;
    string name;
    string description;
    string institution;
    string site;
    string status; // AVAILABLE | LOANED_OUT | UNDER_MAINTENANCE | DISPOSED
    string dateAcquired;
    Component[] components = [];
    Schedule[] schedules = [];
    WorkOrder[] workOrders = [];
|};

public type ErrorMessage record {|
    string message;
|};

public type StatusMessage record {|
    string message;
|};



map<Asset> assetStore = {};
map<string> institutionStore = {}; // acts as a set: name -> name


service /library on new http:Listener(8080) {

    // ---------------- Asset CRUD ----------------

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

    resource function put assets/[string assetTag](@http:Payload Asset updated)
            returns Asset|http:NotFound {
        if !assetStore.hasKey(assetTag) {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        assetStore[assetTag] = updated;
        return updated;
    }

    resource function delete assets/[string assetTag]() returns StatusMessage|http:NotFound {
        if !assetStore.hasKey(assetTag) {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        _ = assetStore.remove(assetTag);
        return {message: "Deleted " + assetTag};
    }

    // ------------- Views & filtering  -------------

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

    // Assets with at least one schedule whose dueDate has passed.
    resource function get assets/overdue() returns Asset[] {
        string today = time:utcToString(time:utcNow()).substring(0, 10);
        return from Asset a in assetStore
            where a.schedules.some(s => s.dueDate < today)
            select a;
    }

    resource function get assets/status/[string status]() returns Asset[] {
        return from Asset a in assetStore
            where a.status == status
            select a;
    }

    // ---------- Institution management ----------

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

    // ------------ Component management ------------

    resource function post assets/[string assetTag]/components(@http:Payload Component comp)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
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
        asset.components = from Component c in asset.components
            where c.compId != compId
            select c;
        assetStore[assetTag] = asset;
        return asset;
    }

    // ------------- Schedule management  -------------

    resource function post assets/[string assetTag]/schedules(@http:Payload Schedule sched)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        asset.schedules.push(sched);
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
        asset.schedules = from Schedule s in asset.schedules
            where s.scheduleId != scheduleId
            select s;
        assetStore[assetTag] = asset;
        return asset;
    }

    // ------------- Work orders & tasks  -------------

    resource function post assets/[string assetTag]/workorders(@http:Payload WorkOrder wo)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        asset.workOrders.push(wo);
        assetStore[assetTag] = asset;
        return asset;
    }

    resource function put assets/[string assetTag]/workorders/[string orderId](
            @http:Payload record {|string status;|} body)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        WorkOrder[] updatedOrders = [];
        foreach WorkOrder wo in asset.workOrders {
            if wo.orderId == orderId {
                wo.status = body.status;
            }
            updatedOrders.push(wo);
        }
        asset.workOrders = updatedOrders;
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
        asset.workOrders = from WorkOrder wo in asset.workOrders
            where wo.orderId != orderId
            select wo;
        assetStore[assetTag] = asset;
        return asset;
    }

    resource function post assets/[string assetTag]/workorders/[string orderId]/tasks(
            @http:Payload WorkOrderTask task)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
        }
        Asset asset = found;
        WorkOrder[] updatedOrders = [];
        foreach WorkOrder wo in asset.workOrders {
            if wo.orderId == orderId {
                wo.tasks.push(task);
            }
            updatedOrders.push(wo);
        }
        asset.workOrders = updatedOrders;
        assetStore[assetTag] = asset;
        return asset;
    }
}
