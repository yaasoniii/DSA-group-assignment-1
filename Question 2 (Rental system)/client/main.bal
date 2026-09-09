
import ballerina/io;
import ballerina/grpc;

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

    stream<Property, grpc:Error?> propertyStream =
        check rentalClient->list_available_properties({
            location: "Windhoek",
            propertyType: "Apartment",
            minPrice: 0.0,
            maxPrice: 1000.0,
            minBedrooms: 2
        });

    io:println("AVAILABLE PROPERTIES:");

    check from Property p in propertyStream
        do {
            io:println(p);
        };

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
}


