import ballerina/grpc;
import ballerina/io;

listener grpc:Listener ep = new (9090);

map<Property> propertyStore = {
    "PROP001": {
        propertyId: "PROP001",
        ownerId: "USER001",
        name: "Windhoek Apartment",
        description: "Two bedroom apartment",
        location: "Windhoek",
        propertyType: "Apartment",
        bedrooms: 2,
        pricePerNight: 850.0,
        available: true
    }
};
map<User> userStore = {};

@grpc:Descriptor {
    value: RENTAL_DESC
}
service "RentalService" on ep {

    remote function add_property(AddPropertyRequest value) returns PropertyResponse|error {
        Property property = value.property;

        if property.propertyId.trim().length() == 0 {
            return {
                success: false,
                message: "Property ID is required",
                property: property
            };
        }

        if propertyStore.hasKey(property.propertyId) {
            return {
                success: false,
                message: "Property already exists",
                property: property
            };
        }

        propertyStore[property.propertyId] = property;

        return {
            success: true,
            message: "Property added successfully",
            property: property
        };
    }

    remote function create_users(stream<User, grpc:Error?> clientStream)
            returns CreateUsersResponse|error {

        int createdCount = 0;

        check clientStream.forEach(function(User user) {
            userStore[user.userId] = user;
            createdCount += 1;
        });

        return {
            success: true,
            message: "Users created successfully",
            usersCreated: createdCount
        };
    }

    remote function update_property(UpdatePropertyRequest value)
            returns PropertyResponse|error {

        if !propertyStore.hasKey(value.propertyId) {
            return {
                success: false,
                message: "Property not found",
                property: value.property
            };
        }

        Property updatedProperty = value.property;
        updatedProperty.propertyId = value.propertyId;

        propertyStore[value.propertyId] = updatedProperty;

        return {
            success: true,
            message: "Property updated successfully",
            property: updatedProperty
        };
    }

    remote function remove_property(RemovePropertyRequest value)
            returns OperationResponse|error {

        if !propertyStore.hasKey(value.propertyId) {
            return {
                success: false,
                message: "Property not found"
            };
        }

        _ = propertyStore.remove(value.propertyId);

        return {
            success: true,
            message: "Property removed successfully"
        };
    }

    remote function list_available_properties(RentalServicePropertyCaller caller,
            ListAvailablePropertiesRequest value) returns error? {

        io:println("list_available_properties called with filters: ", value);

        boolean anySent = false;

        foreach Property property in propertyStore {
            if property.available && matchesAvailableFilters(property, value) {
                check caller->sendProperty(property);
                anySent = true;
            }
        }

        if !anySent {
            Property sentinel = {
                propertyId: "",
                ownerId: "",
                name: "",
                description: "",
                location: "",
                propertyType: "",
                bedrooms: 0,
                pricePerNight: 0.0,
                available: false
            };
            check caller->sendProperty(sentinel);
        }

        check caller->complete();
    }

    remote function search_property(SearchPropertyRequest value)
                returns SearchPropertyResponse|error {

        Property[] matches = [];
        boolean unavailableMatchFound = false;

        foreach Property property in propertyStore {

            if matchesSearchFilters(property, value) {

                if property.available {
                    matches.push(property);
                } else {
                    unavailableMatchFound = true;
                }
            }
        }

        if matches.length() > 0 {
            return {
                success: true,
                message: "Property found",
                properties: matches
            };
        }

        if unavailableMatchFound {
            return {
                success: false,
                message: "Not Available",
                properties: []
            };
        }

        return {
            success: false,
            message: "Property not found",
            properties: []
        };
    }

    remote function book_property(BookPropertyRequest value)
                returns BookingResponse|error {

        Booking booking = {
            bookingId: "",
            propertyId: value.propertyId,
            userId: value.userId,
            checkInDate: value.checkInDate,
            checkOutDate: value.checkOutDate,
            status: "Pending"
        };

        return {
            success: false,
            message: "Booking functionality not implemented yet",
            booking: booking
        };
    }

    remote function confirm_booking(ConfirmBookingRequest value)
                returns ConfirmBookingResponse|error {

        Booking booking = {
            bookingId: value.bookingId,
            propertyId: "",
            userId: "",
            checkInDate: "",
            checkOutDate: "",
            status: "Pending"
        };

        return {
            success: false,
            message: "Booking confirmation not implemented yet",
            booking: booking,
            totalCost: 0.0
        };
    }
}

function matchesSearchFilters(
        Property property,
        SearchPropertyRequest value
) returns boolean {

    if value.propertyId != "" &&
            property.propertyId != value.propertyId {
        return false;
    }

    if value.location != "" &&
            property.location.toLowerAscii() != value.location.toLowerAscii() {
        return false;
    }

    if value.propertyType != "" &&
            property.propertyType.toLowerAscii() !=
                value.propertyType.toLowerAscii() {
        return false;
    }

    if value.minPrice > 0.0 &&
            property.pricePerNight < value.minPrice {
        return false;
    }

    if value.maxPrice > 0.0 &&
            property.pricePerNight > value.maxPrice {
        return false;
    }

    if value.minBedrooms > 0 &&
            property.bedrooms < value.minBedrooms {
        return false;
    }

    return true;
}

function matchesAvailableFilters(
        Property property,
        ListAvailablePropertiesRequest value
) returns boolean {

    if value.location != "" &&
            property.location.toLowerAscii() != value.location.toLowerAscii() {
        return false;
    }

    if value.propertyType != "" &&
            property.propertyType.toLowerAscii() !=
                value.propertyType.toLowerAscii() {
        return false;
    }

    if value.minPrice > 0.0 &&
            property.pricePerNight < value.minPrice {
        return false;
    }

    if value.maxPrice > 0.0 &&
            property.pricePerNight > value.maxPrice {
        return false;
    }

    if value.minBedrooms > 0 &&
            property.bedrooms < value.minBedrooms {
        return false;
    }

    return true;
}

