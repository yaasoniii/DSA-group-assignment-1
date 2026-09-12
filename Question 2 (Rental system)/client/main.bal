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

function browseAvailableProperties(RentalServiceClient rentalClient) returns error? {
    io:println("Leave any filter blank to skip it.");
    string location = io:readln("Filter by location: ").trim();
    string propertyType = io:readln("Filter by property type: ").trim();
    string minPriceInput = io:readln("Min price per night: ").trim();
    string maxPriceInput = io:readln("Max price per night: ").trim();
    string minBedroomsInput = io:readln("Min bedrooms: ").trim();

    float minPrice = minPriceInput != "" ? check float:fromString(minPriceInput) : 0.0;
    float maxPrice = maxPriceInput != "" ? check float:fromString(maxPriceInput) : 0.0;
    int minBedrooms = minBedroomsInput != "" ? check int:fromString(minBedroomsInput) : 0;

    stream<Property, grpc:Error?> propertyStream = check rentalClient->list_available_properties({
        location: location,
        propertyType: propertyType,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minBedrooms: minBedrooms
    });

    io:println("\nAVAILABLE PROPERTIES BASED ON FILTERS:");
    int count = 0;

    check from Property p in propertyStream
        do {
            count += 1;
            io:println("  [" + p.propertyId + "] " + p.name + " - " + p.location + " | " + p.bedrooms.toString() + " bed | N$" + p.pricePerNight.toString() + "/night");
        };

    if count == 0 {
        io:println(" (No properties found based on the provided filters.)");
    }

}

function searchPropertyById(RentalServiceClient rentalClient) returns errors? {
    string propertyId = io:readln("Property ID to search for:").trim();
}

public function main() returns error? {
    RentalServiceClient rentalClient = check new ("http://localhost:9090");

    Property property = {
        propertyId: "PROP001",
        ownerId: "USER001",
        name: "Windhoek Apartment",
        description: "Two bedroom apartment",
        location: "Windhoek",
        propertyType: "Apartment",
        bedrooms: 2,
        pricePerNight: 850.0,
        available: true
    };

    PropertyResponse addResponse = check rentalClient->add_property({
        property: property
    });

    io:println("ADD:");
    io:println(addResponse);

    SearchPropertyResponse searchResponse = check rentalClient->search_property({
        propertyId: "PROP001"
    });

    io:println("SEARCH:");
    io:println(searchResponse);

    Property updatedProperty = {
        propertyId: "PROP001",
        ownerId: "USER001",
        name: "Updated Windhoek Apartment",
        description: "Updated apartment",
        location: "Windhoek",
        propertyType: "Apartment",
        bedrooms: 3,
        pricePerNight: 950.0,
        available: true
    };

    PropertyResponse updateResponse = check rentalClient->update_property({
        propertyId: "PROP001",
        property: updatedProperty
    });

    io:println("UPDATE:");
    io:println(updateResponse);

    //Replaced by browseAvailableProperties(rentalClient) function
    //stream<Property, grpc:Error?> propertyStream =
    //    check rentalClient->list_available_properties({
    //    location: "Windhoek",
    //    propertyType: "Apartment",
    //    minPrice: 0.0,
    //    maxPrice: 1000.0,
    //    minBedrooms: 2
    //});

    //io:println("AVAILABLE PROPERTIES:");

    //check from Property p in propertyStream
      //  do {
      //      io:println(p);
      //  };

    OperationResponse removeResponse = check rentalClient->remove_property({
        propertyId: "PROP001"
    });

    io:println("REMOVE:");
    io:println(removeResponse);

    SearchPropertyResponse missingResponse = check rentalClient->search_property({
        propertyId: "PROP001"
    });

    io:println("SEARCH AFTER DELETE:");
    io:println(missingResponse);

    check createSampleUsers(rentalClient);

    check browseAvailableProperties(rentalClient);

    check searchPropertyById(rentalClient);
}

