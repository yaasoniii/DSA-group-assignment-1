import ballerina/grpc;

listener grpc:Listener ep = new (9090);

@grpc:Descriptor {value: RENTAL_DESC}
service "RentalService" on ep {

    remote function add_property(AddPropertyRequest value) returns PropertyResponse|error {
    }

    remote function update_property(UpdatePropertyRequest value) returns PropertyResponse|error {
    }

    remote function remove_property(RemovePropertyRequest value) returns OperationResponse|error {
    }

    remote function search_property(SearchPropertyRequest value) returns SearchPropertyResponse|error {
    }

    remote function book_property(BookPropertyRequest value) returns BookingResponse|error {
    }

    remote function confirm_booking(ConfirmBookingRequest value) returns ConfirmBookingResponse|error {
    }

    remote function create_users(stream<User, grpc:Error?> clientStream) returns CreateUsersResponse|error {
    }

    remote function list_available_properties(ListAvailablePropertiesRequest value) returns stream<Property, error?>|error {
    }
}
