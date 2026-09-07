import ballerina/io;


function viewsMenu() returns error? {
    boolean back = false;
    while !back {
        io:println("\n----------------- VIEWS -----------------");
        io:println("1. Global view (all assets)");
        io:println("2. Campus view — by institution");
        io:println("3. Campus view — by site");
        io:println("4. Filter by status");
        io:println("0. Back to main menu");
        string choice = prompt("Select an option");
        match choice {
            "1" => { globalView(); }
            "2" => { institutionView(); }
            "3" => { siteView(); }
            "4" => { statusView(); }
            "0" => { back = true; }
            _ => { io:println("Invalid option."); }
        }
    }
}

function globalView() {
    [int, json]|error result = httpGet("/assets");
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        Asset[]|error assets = body.cloneWithType();
        if assets is Asset[] {
            io:println("\n-- All Assets (" + assets.length().toString() + ") --");
            printAssetList(assets);
        } else {
            io:println("Failed to parse assets: " + assets.message());
        }
    } else {
        printApiError(status, body);
    }
}

function institutionView() {
    string institution = prompt("Institution name");
    [int, json]|error result = httpGet("/assets/institution/" + institution);
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        Asset[]|error assets = body.cloneWithType();
        if assets is Asset[] {
            io:println("\n-- Assets at " + institution + " (" + assets.length().toString() + ") --");
            printAssetList(assets);
        }
    } else {
        printApiError(status, body);
    }
}

function siteView() {
    string site = prompt("Site / campus name");
    [int, json]|error result = httpGet("/assets/site/" + site);
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        Asset[]|error assets = body.cloneWithType();
        if assets is Asset[] {
            io:println("\n-- Assets at site " + site + " (" + assets.length().toString() + ") --");
            printAssetList(assets);
        }
    } else {
        printApiError(status, body);
    }
}

function statusView() {
    string status = prompt("Status (AVAILABLE / LOANED_OUT / OCCUPIED / UNDER_MAINTENANCE / DISPOSED)");
    [int, json]|error result = httpGet("/assets/status/" + status);
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [statusCode, body] = result;
    if statusCode == 200 {
        Asset[]|error assets = body.cloneWithType();
        if assets is Asset[] {
            io:println("\n-- Assets with status " + status + " (" + assets.length().toString() + ") --");
            printAssetList(assets);
        }
    } else {
        printApiError(statusCode, body);
    }
}


function overdueDashboard() returns error? {
    string asOf = prompt("As-of date (YYYY-MM-DD, blank = today)");
    string path = "/assets/overdue";
    if asOf.length() > 0 {
        if !isValidDate(asOf) {
            io:println("As-of date must be a real calendar date in YYYY-MM-DD format.");
            return;
        }
        path = path + "?asOf=" + asOf;
    }
    string cutoff = asOf.length() > 0 ? asOf : todayIso();

    [int, json]|error result = httpGet(path);
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        Asset[]|error assets = body.cloneWithType();
        if assets is Asset[] {
            io:println("\n-- Overdue Dashboard as at " + cutoff +
                    " (" + assets.length().toString() + " asset(s)) --");
            if assets.length() == 0 {
                io:println("Nothing overdue. All clear.");
            }
            foreach Asset a in assets {
                printAssetSummary(a);
                // Only the maintenance schedules that are actually past due —
                // bookings and future services are not overdue work.
                foreach Schedule s in a.schedules {
                    if s.'type == "MAINTENANCE" && s.dueDate < cutoff {
                        io:println("      -> [" + s.scheduleId + "] MAINTENANCE was due " +
                                s.dueDate + " - " + s.description);
                    }
                }
            }
        } else {
            io:println("Failed to parse assets: " + assets.message());
        }
    } else {
        printApiError(status, body);
    }
}
