import ballerina/io;


function loanBookFlow() returns error? {
    string assetTag = prompt("Asset tag to loan/book");
    Asset? existing = fetchAsset(assetTag);
    if existing is () {
        return;
    }
    Asset current = existing;

    if current.status != "AVAILABLE" {
        io:println("Cannot loan/book " + assetTag + " — current status is " + current.status + ".");
        return;
    }

    io:println("Asset: " + current.name + " (" + current.institution + " - " + current.site + ")");
    string newStatus = prompt("Set status to (LOANED_OUT for loans / OCCUPIED for room-lab bookings)");

    Asset updated = {
        assetTag: current.assetTag,
        name: current.name,
        description: current.description,
        institution: current.institution,
        site: current.site,
        status: newStatus,
        dateAcquired: current.dateAcquired,
        components: current.components,
        schedules: current.schedules,
        workOrders: current.workOrders
    };

    [int, json]|error result = httpPut("/assets/" + assetTag, updated.toJson());
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        io:println(assetTag + " is now " + newStatus + ".");
    } else {
        printApiError(status, body);
    }
}
