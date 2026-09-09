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
