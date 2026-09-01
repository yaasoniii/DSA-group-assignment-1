import ballerina/io;
function scheduleMenu() returns error? {
    boolean back = false;
    while !back {
        io:println("\n---------------- SCHEDULE MANAGER ----------------");
        io:println("1. View schedules for an asset");
        io:println("2. Add a schedule");
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
// i am tired someone do this 
function viewSchedules() {
    string assetTag = prompt("Asset tag");

    Asset? asset = fetchAsset(assetTag);

    if asset is () {
        return;
    }

    io:println("\n-- Schedules for " + asset.assetTag + " --");

    if asset.schedules.length() == 0 {
        io:println("No schedules found.");
        return;
    }

    foreach Schedule schedule in asset.schedules {
        io:println(
            "[" + schedule.scheduleId + "] " +
            schedule.'type + " due " + schedule.dueDate + " - " +
            schedule.description
        );
    }
}

function addSchedule() {
    string assetTag = prompt("Asset tag");
    string scheduleId = prompt("Schedule ID");
    string scheduleType = prompt("Type (MAINTENANCE / BOOKING)");
    string dueDate = prompt("Due date (YYYY-MM-DD)");
    string description = prompt("Description");

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