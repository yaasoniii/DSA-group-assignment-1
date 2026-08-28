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
function viewSchedules() {}
function addSchedule(){}
function removeSchedule(){}