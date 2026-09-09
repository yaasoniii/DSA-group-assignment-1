import ballerina/grpc;

listener grpc:Listener ep = new (9090);

map<Property> propertyStore = {};

@grpc:Descriptor {value: RENTAL_DESC}
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
                property: propertyStore[property.propertyId]
            };
        }

        propertyStore[property.propertyId] = property;

        return {
            success: true,
            message: "Property added successfully",
            property: property
        };
    }

remote function update_property(UpdatePropertyRequest value) returns PropertyResponse|error {
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

 remote function remove_property(RemovePropertyRequest value) returns OperationResponse|error {
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
remote function search_property(SearchPropertyRequest value) returns SearchPropertyResponse|error {
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

}

function matchesSearchFilters(Property property, SearchPropertyRequest value) returns boolean {
    if value.propertyId != "" && property.propertyId != value.propertyId {
        return false;
    }

    if value.location != "" &&
            property.location.toLowerAscii() != value.location.toLowerAscii() {
        return false;
    }

    if value.propertyType != "" &&
            property.propertyType.toLowerAscii() != value.propertyType.toLowerAscii() {
        return false;
    }

    if value.minPrice > 0.0 && property.pricePerNight < value.minPrice {
        return false;
    }

    if value.maxPrice > 0.0 && property.pricePerNight > value.maxPrice {
        return false;
    }

    if value.minBedrooms > 0 && property.bedrooms < value.minBedrooms {
        return false;
    }

    return true;
}
