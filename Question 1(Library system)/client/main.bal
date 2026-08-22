import ballerina/http;
import ballerina/io;

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


// client part idk who doing but i would like too
configurable string serviceUrl = "http://localhost:8080/library";

final http:Client libClient = checkpanic new (serviceUrl);


public function main() returns error? {
    io:println("=======================================================");
    io:println(" Library & Resource Management System — CLI Client");
    io:println(" Connected to: " + serviceUrl);
    io:println("=======================================================");

    boolean running = true;
    while running {
        printMainMenu();
        string choice = io:readln("Select an option: ").trim();
        match choice {
            "1" => { check assetManagementMenu(); }
            "2" => { check viewsMenu(); }
            "3" => { check overdueDashboard(); }
            "4" => { check institutionMenu(); }
            "5" => { check scheduleMenu(); }
            "6" => { check componentMenu(); }
            "7" => { check workOrderMenu(); }
            "8" => { check loanBookFlow(); }
            "0" => {
                running = false;
                io:println("Goodbye!");
            }
            _ => {
                io:println("Invalid option, please try again.");
            }
        }
    }
}


function printMainMenu() {
    io:println("\n--------------------- MAIN MENU ----------------------");
    io:println("1. Asset Management (create / view / update / delete)");
    io:println("2. Views (global list, by institution, site, status)");
    io:println("3. Overdue Dashboard");
    io:println("4. Institution Management");
    io:println("5. Schedule Manager");
    io:println("6. Component Management");
    io:println("7. Work Orders & Tasks");
    io:println("8. Loan an Asset / Book a Room or Lab");
    io:println("0. Exit");
    io:println("--------------------------------------------------------");
}
// someone has to do the function for the main menu