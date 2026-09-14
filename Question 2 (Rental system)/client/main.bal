import ballerina/grpc;
import ballerina/io;

function createSampleUsers(RentalServiceClient rentalClient) returns error? {
    Create_usersStreamingClient streamingClient = check rentalClient->create_users();

    User[] sampleUsers = [
        {userId: "USER001", firstName: "Patrick", lastName: "Jane", email: "patrickjane@gmail.com", phoneNumber: "0812345678"},
        {userId: "USER002", firstName: "Bill", lastName: "Gates", email: "billgates@gmail.com", phoneNumber: "0818765432"},
        {userId: "USER003", firstName: "Michael", lastName: "Jackson", email: "mjackson@gmail.com", phoneNumber: "0818765234"}
    ];

    foreach User user in sampleUsers {
        check streamingClient->sendUser(user);
        io:println("Sent user: " + user.userId + "(" + user.firstName + " " + user.lastName + ")");
    }

    check streamingClient->complete();

    CreateUsersResponse? response = check streamingClient->receiveCreateUsersResponse();

    if response is CreateUsersResponse {
        io:println("\nCREATE USERS RESULT:");
        io:println("  Success       : " + response.success.toString());
        io:println("  Message       : " + response.message);
        io:println("  Users created : " + response.usersCreated.toString());
    } else {
        io:println("No response received from the server.");
    }

}

function addProperty(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID: ").trim();
    string ownerId = io:readln("Owner (host) user ID: ").trim();
    string name = io:readln("Property name: ").trim();
    string description = io:readln("Description: ").trim();
    string location = io:readln("Location: ").trim();
    string propertyType = io:readln("Property type (e.g. Apartment, House): ").trim();
    int bedrooms = readRequiredInt("Number of bedrooms: ");
    float pricePerNight = readRequiredFloat("Price per night: ");

    Property property = {
        propertyId: propertyId,
        ownerId: ownerId,
        name: name,
        description: description,
        location: location,
        propertyType: propertyType,
        bedrooms: bedrooms,
        pricePerNight: pricePerNight,
        available: true
    };

    PropertyResponse response = check rentalClient->add_property({property: property});

    io:println("\nADD PROPERTY RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);
}

function browseAvailableProperties(RentalServiceClient rentalClient) returns error? {
    io:println("Leave any filter blank to skip it.");
    string location = io:readln("Filter by location: ").trim();
    string propertyType = io:readln("Filter by property type: ").trim();
    float minPrice = readOptionalFloat("Min price per night: ");
    float maxPrice = readOptionalFloat("Max price per night: ");
    int minBedrooms = readOptionalInt("Min bedrooms: ");

    stream<Property, grpc:Error?> propertyStream = check rentalClient->list_available_properties({
        location: location,
        propertyType: propertyType,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minBedrooms: minBedrooms
    });

    io:println("\nAVAILABLE PROPERTIES BASED ON FILTERS:");
    int count = 0;

    record {|Property value;|}|grpc:Error? next = propertyStream.next();
    while next is record {|Property value;|} {
        Property p = next.value;
        if p.propertyId != "" {
            count += 1;
            io:println("  [" + p.propertyId + "] " + p.name + " - " + p.location +
                    " | " + p.bedrooms.toString() + " bed | N$" + p.pricePerNight.toString() + "/night");
        }
        next = propertyStream.next();
    }

    if next is grpc:Error {
        return next;
    }

    if count == 0 {
        io:println(" (No properties found based on the provided filters.)");
    }
}

function searchPropertyById(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID to search for:").trim();

    SearchPropertyResponse response = check rentalClient->search_property({
        propertyId: propertyId
    });

    io:println("\nSEARCH RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);

    if response.properties.length() == 0 {
        io:println(" (no matching properties found)");
    } else {
        foreach Property p in response.properties {
            string availability = p.available ? "Available" : "Not Available";
            io:println(" [" + p.propertyId + "] " + p.name + "-" + p.location + " | " + p.bedrooms.toString() + " bed | N$" + p.pricePerNight.toString() + "/night | " + availability);
        }
    }
}

function updateProperty(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID to update: ").trim();
    string ownerId = io:readln("Owner (host) user ID: ").trim();
    string name = io:readln("New property name: ").trim();
    string description = io:readln("New description: ").trim();
    string location = io:readln("New location: ").trim();
    string propertyType = io:readln("New property type (e.g. Apartment, House): ").trim();
    int bedrooms = readRequiredInt("New number of bedrooms: ");
    float pricePerNight = readRequiredFloat("New price per night: ");
    boolean available = readRequiredBoolean("Available for booking? (y/n): ");

    Property updated = {
        propertyId: propertyId,
        ownerId: ownerId,
        name: name,
        description: description,
        location: location,
        propertyType: propertyType,
        bedrooms: bedrooms,
        pricePerNight: pricePerNight,
        available: available
    };

    PropertyResponse response = check rentalClient->update_property({
        propertyId: propertyId,
        property: updated
    });

    io:println("\nUPDATE PROPERTY RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);
}

function removeProperty(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID to remove: ").trim();

    OperationResponse response = check rentalClient->remove_property({
        propertyId: propertyId
    });

    io:println("\nREMOVE PROPERTY RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);
}

function bookProperty(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID to book: ").trim();
    string userId = io:readln("Guest (user) ID: ").trim();
    string checkInDate = io:readln("Check-in date (YYYY-MM-DD): ").trim();
    string checkOutDate = io:readln("Check-out date (YYYY-MM-DD): ").trim();

    BookingResponse response = check rentalClient->book_property({
        propertyId: propertyId,
        userId: userId,
        checkInDate: checkInDate,
        checkOutDate: checkOutDate
    });

    io:println("\nBOOK PROPERTY RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);

    if response.success {
        io:println("  Booking ID : " + response.booking.bookingId);
        io:println("  Status     : " + response.booking.status);
        io:println("  (Use this Booking ID with 'Confirm a booking' to finalize it.)");
    }
}

function confirmBooking(RentalServiceClient rentalClient) returns error? {
    string bookingId = io:readln("Booking ID to confirm: ").trim();

    ConfirmBookingResponse response = check rentalClient->confirm_booking({
        bookingId: bookingId
    });

    io:println("\nCONFIRM BOOKING RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);

    if response.success {
        io:println("  Booking ID  : " + response.booking.bookingId);
        io:println("  Property ID : " + response.booking.propertyId);
        io:println("  Check-in    : " + response.booking.checkInDate);
        io:println("  Check-out   : " + response.booking.checkOutDate);
        io:println("  Status      : " + response.booking.status);
        io:println("  Total cost  : N$" + response.totalCost.toString());
    }
}

public function main() returns error? {
    RentalServiceClient rentalClient = check new ("http://localhost:9090", timeout = 5);

    boolean running = true;

    while running {
        io:println("\n=== RENTAL SYSTEM CLIENT MENU ===");
        io:println("1. Add a property");
        io:println("2. Update a property");
        io:println("3. Remove a property");
        io:println("4. Create sample users (streaming)");
        io:println("5. Browse available properties");
        io:println("6. Search property by ID");
        io:println("7. Book a property");
        io:println("8. Confirm a booking");
        io:println("9. Exit");

        string choice = io:readln("Select an option: ").trim();

        match choice {
            "1" => {
                check addProperty(rentalClient);
            }
            "2" => {
                check updateProperty(rentalClient);
            }
            "3" => {
                check removeProperty(rentalClient);
            }
            "4" => {
                check createSampleUsers(rentalClient);
            }
            "5" => {
                check browseAvailableProperties(rentalClient);
            }
            "6" => {
                check searchPropertyById(rentalClient);
            }
            "7" => {
                check bookProperty(rentalClient);
            }
            "8" => {
                check confirmBooking(rentalClient);
            }
            "9" => {
                running = false;
            }
            _ => {
                io:println("Invalid option, please try again.");
            }
        }
    }
}

function readOptionalFloat(string prompt) returns float {
    while true {
        string input = io:readln(prompt).trim();
        if input == "" {
            return 0.0;
        }
        float|error parsed = float:fromString(input);
        if parsed is float {
            return parsed;
        }
        io:println("  Invalid number, please try again or leave blank.");
    }
}

function readOptionalInt(string prompt) returns int {
    while true {
        string input = io:readln(prompt).trim();
        if input == "" {
            return 0;
        }
        int|error parsed = int:fromString(input);
        if parsed is int {
            return parsed;
        }
        io:println("  Invalid whole number, please try again or leave blank.");
    }
}

function readRequiredFloat(string prompt) returns float {
    while true {
        string input = io:readln(prompt).trim();
        float|error parsed = float:fromString(input);
        if parsed is float {
            return parsed;
        }
        io:println("  Invalid number, please try again (e.g. 950 or 950.50).");
    }
}

function readRequiredInt(string prompt) returns int {
    while true {
        string input = io:readln(prompt).trim();
        int|error parsed = int:fromString(input);
        if parsed is int {
            return parsed;
        }
        io:println("  Invalid whole number, please try again (e.g. 3).");
    }

}

function readRequiredBoolean(string prompt) returns boolean {
    while true {
        string input = io:readln(prompt).trim().toLowerAscii();
        if input == "y" || input == "yes" {
            return true;
        }
        if input == "n" || input == "no" {
            return false;
        }
        io:println("  Please answer y or n.");
    }
}

