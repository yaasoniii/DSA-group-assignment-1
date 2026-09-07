import ballerina/io;

function scheduleMenu() returns error? {
    boolean back = false;
    while !back {
        io:println("\n---------------- SCHEDULE MANAGER ----------------");
        io:println("1. View schedules for an asset");
        io:println("2. Add a schedule (servicing or booking)");
        io:println("3. Remove a schedule");
        io:println("0. Back to main menu");
        string choice = prompt("Select an option");
        match choice {
            "1" => { viewSchedules(); }
            "2" => { addSchedule(); }
            "3" => { removeSchedule(); }
            "0" => { back = true; }
            _ => { io:println("Invalid option."); }
        }
    }
}

function viewSchedules() {
    string assetTag = prompt("Asset tag");
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }

    Asset? asset = fetchAsset(assetTag);

    if asset is () {
        return;
    }

    io:println("\n-- Schedules for " + asset.assetTag + " --");

    if asset.schedules.length() == 0 {
        io:println("No schedules found.");
        return;
    }

    string today = todayIso();
    foreach Schedule schedule in asset.schedules {
        string flag = schedule.'type == "MAINTENANCE" && schedule.dueDate < today
            ? "  << OVERDUE"
            : "";
        io:println(
            "[" + schedule.scheduleId + "] " +
            schedule.'type + " due " + schedule.dueDate + " - " +
            schedule.description + flag
        );
    }
}

function addSchedule() {
    string assetTag = prompt("Asset tag");
    string scheduleId = prompt("Schedule ID");
    string scheduleType = prompt("Type (MAINTENANCE / BOOKING)").toUpperAscii();
    string dueDate = prompt("Due date (YYYY-MM-DD)");
    string description = prompt("Description");

    // Checked here as well as on the server so an obvious typo costs no round trip.
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }
    if scheduleId.length() == 0 {
        io:println("Schedule ID is required.");
        return;
    }
    if scheduleType != "MAINTENANCE" && scheduleType != "BOOKING" {
        io:println("Type must be MAINTENANCE or BOOKING.");
        return;
    }
    if !isValidDate(dueDate) {
        io:println("Due date must be a real calendar date in YYYY-MM-DD format.");
        return;
    }

    Schedule schedule = {
        scheduleId: scheduleId,
        'type: scheduleType,
        dueDate: dueDate,
        description: description
    };

    [int, json]|error result =
        httpPost("/assets/" + assetTag + "/schedules", schedule);

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [status, body] = result;

    if status == 200 || status == 201 {
        io:println("Schedule added successfully.");
    } else {
        printApiError(status, body);
    }
}

function removeSchedule() {
    string assetTag = prompt("Asset tag");
    string scheduleId = prompt("Schedule ID");

    if assetTag.length() == 0 || scheduleId.length() == 0 {
        io:println("Asset tag and schedule ID are both required.");
        return;
    }

    [int, json]|error result =
        httpDelete("/assets/" + assetTag + "/schedules/" + scheduleId);

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [status, body] = result;

    if status == 200 {
        io:println("Schedule removed successfully.");
    } else {
        printApiError(status, body);
    }
}
