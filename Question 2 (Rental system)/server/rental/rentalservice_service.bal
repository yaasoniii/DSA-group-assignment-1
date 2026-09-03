import ballerina/grpc;

listener grpc:Listener ep = new (9090);

map<Property> properties = {};

function matchesFilters(
    Property property,
    string location,
    string propertyType,
    float minPrice,
    float maxPrice,
    int minBedrooms
) returns boolean {
    if location != "" && property.location.toLowerAscii() != location.toLowerAscii() {
        return false;
    }

    if propertyType != "" && property.propertyType.toLowerAscii() != propertyType.toLowerAscii() {
        return false;
    }

    if minPrice > 0.0 && property.pricePerNight < minPrice {
        return false;
    }

    if maxPrice > 0.0 && property.pricePerNight > maxPrice {
        return false;
    }

    if minBedrooms > 0 && property.bedrooms < minBedrooms {
        return false;
    }

    return true;
}

@grpc:Descriptor {value: RENTAL_DESC}
service "RentalService" on ep {

    remote function add_property(AddPropertyRequest value) returns PropertyResponse|error {
        Property property = value.property;

        if property.propertyId == "" {
            return {
                success: false,
                message: "Property ID cannot be empty",
                property: property
            };
        }

        if property.name == "" {
            return {
                success: false,
                message: "Property name cannot be empty",
                property: property
            };
        }

        if property.location == "" {
            return {
                success: false,
                message: "Property location cannot be empty",
                property: property
            };
        }

        if property.pricePerNight <= 0.0 {
            return {
                success: false,
                message: "Price per night must be greater than zero",
                property: property
            };
        }

        if properties.hasKey(property.propertyId) {
            return {
                success: false,
                message: "Property already exists",
                property: property
            };
        }

        properties[property.propertyId] = property;

        return {
            success: true,
            message: "Property added successfully",
            property: property
        };
    }

    remote function update_property(UpdatePropertyRequest value) returns PropertyResponse|error {
        if value.propertyId == "" {
            return {
                success: false,
                message: "Property ID cannot be empty",
                property: value.property
            };
        }

        if !properties.hasKey(value.propertyId) {
            return {
                success: false,
                message: "Property not found",
                property: value.property
            };
        }

        Property updatedProperty = value.property;
        updatedProperty.propertyId = value.propertyId;

        if updatedProperty.name == "" {
            return {
                success: false,
                message: "Property name cannot be empty",
                property: updatedProperty
            };
        }

        if updatedProperty.location == "" {
            return {
                success: false,
                message: "Property location cannot be empty",
                property: updatedProperty
            };
        }

        if updatedProperty.pricePerNight <= 0.0 {
            return {
                success: false,
                message: "Price per night must be greater than zero",
                property: updatedProperty
            };
        }

        properties[value.propertyId] = updatedProperty;

        return {
            success: true,
            message: "Property updated successfully",
            property: updatedProperty
        };
    }

    remote function remove_property(RemovePropertyRequest value) returns OperationResponse|error {
        if value.propertyId == "" {
            return {
                success: false,
                message: "Property ID cannot be empty"
            };
        }

        if !properties.hasKey(value.propertyId) {
            return {
                success: false,
                message: "Property not found"
            };
        }

        _ = properties.remove(value.propertyId);

        return {
            success: true,
            message: "Property removed successfully"
        };
    }

    remote function search_property(SearchPropertyRequest value) returns SearchPropertyResponse|error {
        Property[] matches = [];

        if value.propertyId != "" {
            Property? property = properties[value.propertyId];

            if property is () {
                return {
                    success: false,
                    message: "Not Available",
                    properties: []
                };
            }

            if !property.available {
                return {
                    success: false,
                    message: "Not Available",
                    properties: []
                };
            }

            if !matchesFilters(
                property,
                value.location,
                value.propertyType,
                value.minPrice,
                value.maxPrice,
                value.minBedrooms
            ) {
                return {
                    success: false,
                    message: "Not Available",
                    properties: []
                };
            }

            matches.push(property);

            return {
                success: true,
                message: "Property found",
                properties: matches
            };
        }

        foreach Property property in properties {
            if property.available && matchesFilters(
                property,
                value.location,
                value.propertyType,
                value.minPrice,
                value.maxPrice,
                value.minBedrooms
            ) {
                matches.push(property);
            }
        }

        if matches.length() == 0 {
            return {
                success: false,
                message: "Not Available",
                properties: []
            };
        }

        return {
            success: true,
            message: "Properties found",
            properties: matches
        };
    }

    remote function book_property(BookPropertyRequest value) returns BookingResponse|error {
    }

    remote function confirm_booking(ConfirmBookingRequest value) returns ConfirmBookingResponse|error {
    }

    remote function create_users(stream<User, grpc:Error?> clientStream) returns CreateUsersResponse|error {
    }

    remote function list_available_properties(ListAvailablePropertiesRequest value) returns stream<Property, error?>|error {
        Property[] availableProperties = [];

        foreach Property property in properties {
            if property.available && matchesFilters(
                property,
                value.location,
                value.propertyType,
                value.minPrice,
                value.maxPrice,
                value.minBedrooms
            ) {
                availableProperties.push(property);
            }
        }

        return availableProperties.toStream();
    }
}