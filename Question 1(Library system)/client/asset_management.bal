import ballerina/io;
import ballerina/http;
function printAssetMenu() {
    io:println("\nASSET MANAGEMENT MENU");
    io:println("1. Create asset");
    io:println("2. View one asset");
    io:println("3. Update asset");
    io:println("4. Delete asset");
    io:println("5. View all assets");
    io:println("0. Back to main menu");
}

function assetManagementMenu() returns error? {
    boolean running = true;
    while running {
        printAssetMenu();
        string choice = io:readln("Select an option: ").trim();
        match choice {
            "1" => { check createAssetFlow(); }
            "2" => { check viewAssetFlow(); }
            "3" => { check updateAssetFlow(); }
            "4" => { check deleteAssetFlow(); }
            "5" => { check viewAllAssetsFlow(); }
            "0" => { running = false; }
            _ => { io:println("Invalid option, please try again."); }
        }
    }
}

function createAssetFlow() returns error? {
    string assetTag = io:readln("Enter asset tag: ");
    string name = io:readln("Enter asset name: ");
    string description = io:readln("Enter description: ");
    string institution = io:readln("Enter institution: ");
    string site = io:readln("Enter site: ");
    string dateAcquired = io:readln("Enter date acquired: ");
    Asset newAsset = {
        assetTag: assetTag,
        name: name,
        description: description,
        institution: institution,
        site: site,
        status: "AVAILABLE",
        dateAcquired: dateAcquired
    };

    http:Response resp = check libClient->post("/assets", newAsset);

    if resp.statusCode == 200 || resp.statusCode == 201 {
        json _ = check resp.getJsonPayload();
        io:println("Asset created: ", newAsset.assetTag);
    } else {
        json body = check resp.getJsonPayload();
        io:println("Failed to create asset: ", body.toString());
    }
}

function viewAssetFlow() returns error? {
    string assetTag = io:readln("Enter asset tag: ");

    http:Response resp = check libClient->get("/assets/" + assetTag);

    if resp.statusCode == 200 {
        json asset = check resp.getJsonPayload();
        io:println("Asset details: ", asset);
    } else if resp.statusCode == 404 {
        io:println("Asset not found.");
    } else {
        io:println("Failed to view asset.");
    }
}

function viewAllAssetsFlow() returns error? {
    http:Response resp = check libClient->get("/assets");

    if resp.statusCode == 200 {
        json assets = check resp.getJsonPayload();
        json[] assetList = <json[]>assets;

        if assetList.length() == 0 {
            io:println("No assets found.");
        } else {
            io:println("All Assets (", assetList.length(), " total):");
            foreach json asset in assetList {
                io:println(asset.toJsonString());
            }
        }
    } else {
        io:println("Failed to retrieve assets.");
    }
}
function updateAssetFlow() returns error? {
    string assetTag = io:readln("Enter asset tag to update: ");
    string name = io:readln("Enter new asset name: ");
    string description = io:readln("Enter new description: ");
    string institution = io:readln("Enter new institution: ");
    string site = io:readln("Enter new site: ");
    io:println("Status options:");
    io:println("AVAILABLE, LOANED_OUT, OCCUPIED, UNDER_MAINTENANCE, DISPOSED");
    string statusInput = io:readln("Enter new status: ");
   string status = "AVAILABLE";

 match statusInput {
    "AVAILABLE" => { status = "AVAILABLE"; }
    "LOANED_OUT" => { status = "LOANED_OUT"; }
    "OCCUPIED" => { status = "OCCUPIED"; }
    "UNDER_MAINTENANCE" => { status = "UNDER_MAINTENANCE"; }
    "DISPOSED" => { status = "DISPOSED"; }
    _ => {
        io:println("Invalid status.");
        return;
    }
}
    string dateAcquired = io:readln("Enter new date acquired: ");
    Asset updatedAsset = {
        assetTag: assetTag,
        name: name,
        description: description,
        institution: institution,
        site: site,
        status: status,
        dateAcquired: dateAcquired
    };
    http:Response resp = check libClient->put(
        "/assets/" + assetTag,
        updatedAsset
    );
    if resp.statusCode == 200 || resp.statusCode == 204 {
        json _ = check resp.getJsonPayload();
        io:println("Asset updated: ", assetTag);
    } else {
        io:println("Failed to update asset.");
    }
}

function deleteAssetFlow() returns error? {
    string assetTag = io:readln("Enter asset tag to delete: ");

    http:Response resp = check libClient->delete("/assets/" + assetTag);

    if resp.statusCode == 200 {
        json response = check resp.getJsonPayload();
        io:println(response.message);
    } else if resp.statusCode == 404 {
        io:println("Asset not found.");
    } else {
        io:println("Failed to delete asset.");
    }
}


