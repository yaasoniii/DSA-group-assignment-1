import ballerina/io;

function componentMenu() returns error? {
    boolean back = false;

    while !back {
        io:println("\nCOMPONENT MANAGEMENT");
        io:println("1. View components for an asset");
        io:println("2. Add a component");
        io:println("3. Remove a component");
        io:println("0. Back to main menu");

        string choice = prompt("Select an option");

        match choice {
            "1" => {
                viewComponents();
            }
            "2" => {
                addComponent();
            }
            "3" => {
                removeComponent();
            }
            "0" => {
                back = true;
            }
            _ => {
                io:println("Invalid option.");
            }
        }
    }
}

function viewComponents() {
    string assetTag = prompt("Asset tag");

    Asset? asset = fetchAsset(assetTag);

    if asset is () {
        return;
    }

    io:println("\n-- Components for " + asset.assetTag + " --");

    if asset.components.length() == 0 {
        io:println("No components found.");
        return;
    }

    foreach Component component in asset.components {
        io:println(
            "[" + component.compId + "] " +
            component.name + " - " +
            component.description
        );
    }
}

function addComponent() {
    string assetTag = prompt("Asset tag");
    string compId = prompt("Component ID");
    string name = prompt("Component name");
    string description = prompt("Component description");

    Component component = {
        compId: compId,
        name: name,
        description: description
    };

    [int, json]|error result =
        httpPost("/assets/" + assetTag + "/components", component);

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [status, body] = result;

    if status == 200 || status == 201 {
        io:println("Component added successfully.");
    } else {
        printApiError(status, body);
    }
}

function removeComponent() {
    string assetTag = prompt("Asset tag");
    string compId = prompt("Component ID");

    [int, json]|error result =
        httpDelete("/assets/" + assetTag + "/components/" + compId);

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [status, body] = result;

    if status == 200 {
        io:println("Component removed successfully.");
    } else {
        printApiError(status, body);
    }
}