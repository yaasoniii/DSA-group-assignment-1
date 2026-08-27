import ballerina/io;


function institutionMenu() returns error? {
    boolean back = false;
    while !back {
        io:println("\n------------- INSTITUTION MANAGEMENT -------------");
        io:println("1. List institutions");
        io:println("2. Add institution");
        io:println("3. Remove institution");
        io:println("0. Back to main menu");
        string choice = prompt("Select an option");
        match choice {
            "1" => { listInstitutions(); }
            "2" => { addInstitution(); }
            "3" => { removeInstitution(); }
            "0" => { back = true; }
            _ => { io:println("Invalid option."); }
        }
    }
}

function addInstitution() {
    string name = prompt("Institution name");
    json payload = {name: name};
    [int, json]|error result = httpPost("/institutions", payload);
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        io:println("Institution added.");
    } else {
        printApiError(status, body);
    }
}

