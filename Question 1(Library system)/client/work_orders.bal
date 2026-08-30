import ballerina/io;

function workOrderMenu() returns error? {
    boolean back = false;

    while !back {
        io:println("\nWORK ORDERS & TASKS");
        io:println("1. View work orders for an asset");
        io:println("2. Create a work order");
        io:println("3. Update work-order status");
        io:println("4. Delete a work order");
        io:println("5. Add a task to a work order");
        io:println("0. Back to main menu");

        string choice = prompt("Select an option");

        match choice {
            "1" => {
                viewWorkOrders();
            }
            "2" => {
                createWorkOrder();
            }
            "3" => {
                updateWorkOrderStatus();
            }
            "4" => {
                deleteWorkOrder();
            }
            "5" => {
                addWorkOrderTask();
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

function viewWorkOrders() {
    string assetTag = prompt("Asset tag");

    Asset? asset = fetchAsset(assetTag);

    if asset is () {
        return;
    }

    io:println("\n-- Work Orders for " + asset.assetTag + " --");

    if asset.workOrders.length() == 0 {
        io:println("No work orders found.");
        return;
    }

    foreach WorkOrder wo in asset.workOrders {
        io:println(
            "[" + wo.orderId + "] " +
            wo.status + " - " +
            wo.description
        );

        if wo.tasks.length() == 0 {
            io:println("    No tasks.");
        } else {
            foreach WorkOrderTask task in wo.tasks {
                string completed = task.completed ? "completed" : "pending";

                io:println(
                    "    [" + task.taskId + "] " +
                    task.description + " (" + completed + ")"
                );
            }
        }
    }
}

function createWorkOrder() {
    string assetTag = prompt("Asset tag");
    string orderId = prompt("Work order ID");
    string status = prompt("Status (OPEN / IN_PROGRESS / CLOSED)");
    string description = prompt("Description");

    WorkOrder workOrder = {
        orderId: orderId,
        status: status,
        description: description
    };

    [int, json]|error result =
        httpPost("/assets/" + assetTag + "/workorders", workOrder);

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [statusCode, body] = result;

    if statusCode == 200 || statusCode == 201 {
        io:println("Work order created successfully.");
    } else {
        printApiError(statusCode, body);
    }
}

function updateWorkOrderStatus() {
    string assetTag = prompt("Asset tag");
    string orderId = prompt("Work order ID");
    string status = prompt("New status (OPEN / IN_PROGRESS / CLOSED)");

    record {|string status;|} body = {
        status: status
    };

    [int, json]|error result =
        httpPut(
            "/assets/" + assetTag + "/workorders/" + orderId,
            body
        );

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [statusCode, responseBody] = result;

    if statusCode == 200 {
        io:println("Work order status updated successfully.");
    } else {
        printApiError(statusCode, responseBody);
    }
}

function deleteWorkOrder() {
    string assetTag = prompt("Asset tag");
    string orderId = prompt("Work order ID");

    [int, json]|error result =
        httpDelete(
            "/assets/" + assetTag + "/workorders/" + orderId
        );

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [statusCode, body] = result;

    if statusCode == 200 {
        io:println("Work order deleted successfully.");
    } else {
        printApiError(statusCode, body);
    }
}

function addWorkOrderTask() {
    string assetTag = prompt("Asset tag");
    string orderId = prompt("Work order ID");
    string taskId = prompt("Task ID");
    string description = prompt("Task description");

    WorkOrderTask task = {
        taskId: taskId,
        description: description,
        completed: false
    };

    [int, json]|error result =
        httpPost(
            "/assets/" + assetTag + "/workorders/" + orderId + "/tasks",
            task
        );

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [statusCode, body] = result;

    if statusCode == 200 || statusCode == 201 {
        io:println("Task added successfully.");
    } else {
        printApiError(statusCode, body);
    }
}