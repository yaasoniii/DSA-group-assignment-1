import ballerina/io;

function workOrderMenu() returns error? {
    boolean back = false;

    while !back {
        io:println("\nWORK ORDERS & TASKS");
        io:println("1. View work orders for an asset");
        io:println("2. Open a work order");
        io:println("3. Update / close a work order");
        io:println("4. Delete a work order");
        io:println("5. Add a task to a work order");
        io:println("6. Complete / re-word a task");
        io:println("7. Remove a task");
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
            "6" => {
                updateWorkOrderTask();
            }
            "7" => {
                deleteWorkOrderTask();
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
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }

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
            int pending = 0;
            foreach WorkOrderTask task in wo.tasks {
                string completed = task.completed ? "completed" : "pending";
                if !task.completed {
                    pending += 1;
                }

                io:println(
                    "    [" + task.taskId + "] " +
                    task.description + " (" + completed + ")"
                );
            }
            if pending > 0 && wo.status != "CLOSED" {
                io:println("    (" + pending.toString() +
                        " task(s) still open - the order cannot be closed yet)");
            }
        }
    }
}

function createWorkOrder() {
    string assetTag = prompt("Asset tag");
    string orderId = prompt("Work order ID");
    string status = prompt("Status (OPEN / IN_PROGRESS / CLOSED, blank = OPEN)").toUpperAscii();
    string description = prompt("Description");

    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }
    if orderId.length() == 0 {
        io:println("Work order ID is required.");
        return;
    }
    if !isValidWorkOrderStatus(status) {
        io:println("Status must be OPEN, IN_PROGRESS or CLOSED (or blank for OPEN).");
        return;
    }

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
    string status = prompt("New status (OPEN / IN_PROGRESS / CLOSED)").toUpperAscii();

    if assetTag.length() == 0 || orderId.length() == 0 {
        io:println("Asset tag and work order ID are both required.");
        return;
    }
    if status.length() == 0 || !isValidWorkOrderStatus(status) {
        io:println("Status must be OPEN, IN_PROGRESS or CLOSED.");
        return;
    }

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

    if assetTag.length() == 0 || orderId.length() == 0 {
        io:println("Asset tag and work order ID are both required.");
        return;
    }

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

    if assetTag.length() == 0 || orderId.length() == 0 {
        io:println("Asset tag and work order ID are both required.");
        return;
    }
    if taskId.length() == 0 {
        io:println("Task ID is required.");
        return;
    }

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

function updateWorkOrderTask() {
    string assetTag = prompt("Asset tag");
    string orderId = prompt("Work order ID");
    string taskId = prompt("Task ID");
    string done = prompt("Mark as completed? (y/n)").toLowerAscii();
    string description = prompt("New description (blank = leave unchanged)");

    if assetTag.length() == 0 || orderId.length() == 0 || taskId.length() == 0 {
        io:println("Asset tag, work order ID and task ID are all required.");
        return;
    }
    if done != "y" && done != "yes" && done != "n" && done != "no" {
        io:println("Please answer y or n.");
        return;
    }
    boolean completed = done == "y" || done == "yes";

    json body = description.length() == 0
        ? {completed: completed}
        : {completed: completed, description: description};

    [int, json]|error result =
        httpPut(
            "/assets/" + assetTag + "/workorders/" + orderId + "/tasks/" + taskId,
            body
        );

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [statusCode, responseBody] = result;

    if statusCode == 200 {
        io:println("Task updated successfully.");
    } else {
        printApiError(statusCode, responseBody);
    }
}

function deleteWorkOrderTask() {
    string assetTag = prompt("Asset tag");
    string orderId = prompt("Work order ID");
    string taskId = prompt("Task ID");

    if assetTag.length() == 0 || orderId.length() == 0 || taskId.length() == 0 {
        io:println("Asset tag, work order ID and task ID are all required.");
        return;
    }

    [int, json]|error result =
        httpDelete(
            "/assets/" + assetTag + "/workorders/" + orderId + "/tasks/" + taskId
        );

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [statusCode, body] = result;

    if statusCode == 200 {
        io:println("Task removed successfully.");
    } else {
        printApiError(statusCode, body);
    }
}

// Blank is allowed on create — the service opens the order as OPEN.
function isValidWorkOrderStatus(string status) returns boolean {
    return status.length() == 0 || status == "OPEN" || status == "IN_PROGRESS"
            || status == "CLOSED";
}
