import ballerina/grpc;
import ballerina/io;
import ballerina/uuid;
import ballerina/time;

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
map<Booking> bookingCart = {};
map<Booking[]> confirmedBookings = {};

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

        if !propertyStore.hasKey(value.propertyId) {
            return {
                success: false,
                message: "Property not found",
                booking: booking
            };
        }

        time:Utc|time:Error checkIn = time:utcFromString(value.checkInDate + "T00:00:00.00Z");
        time:Utc|time:Error checkOut = time:utcFromString(value.checkOutDate + "T00:00:00.00Z");

        if checkIn is time:Error || checkOut is time:Error {
            return {
                success: false,
                message: "Invalid date format, expected YYYY-MM-DD",
                booking: booking
            };
        }

        if time:utcDiffSeconds(checkOut, checkIn) <= 0d {
            return {
                success: false,
                message: "Check-out date must be after check-in date",
                booking: booking
            };
        }

        string bookingId = uuid:createType1AsString();
        booking.bookingId = bookingId;
        bookingCart[bookingId] = booking;

        return {
            success: true,
            message: "Booking added to cart, pending confirmation",
            booking: booking
        };
    }

    remote function confirm_booking(ConfirmBookingRequest value)
                returns ConfirmBookingResponse|error {

        Booking? pending = bookingCart[value.bookingId];

        if pending is () {
            return {
                success: false,
                message: "No pending booking found for this booking ID",
                booking: {
                    bookingId: value.bookingId,
                    propertyId: "",
                    userId: "",
                    checkInDate: "",
                    checkOutDate: "",
                    status: "Pending"
                },
                totalCost: 0.0
            };
        }

        Booking booking = pending;

        if !propertyStore.hasKey(booking.propertyId) {
            return {
                success: false,
                message: "Property no longer available",
                booking: booking,
                totalCost: 0.0
            };
        }

        Property property = propertyStore.get(booking.propertyId);

        time:Utc|time:Error checkIn = time:utcFromString(booking.checkInDate + "T00:00:00.00Z");
        time:Utc|time:Error checkOut = time:utcFromString(booking.checkOutDate + "T00:00:00.00Z");

        if checkIn is time:Error || checkOut is time:Error {
            return {
                success: false,
                message: "Stored booking has an invalid date format",
                booking: booking,
                totalCost: 0.0
            };
        }

        time:Utc newCheckIn = checkIn;
        time:Utc newCheckOut = checkOut;

        Booking[] existing = confirmedBookings[booking.propertyId] ?: [];

        foreach Booking other in existing {
            time:Utc|time:Error otherCheckIn = time:utcFromString(other.checkInDate + "T00:00:00.00Z");
            time:Utc|time:Error otherCheckOut = time:utcFromString(other.checkOutDate + "T00:00:00.00Z");

            if otherCheckIn is time:Error || otherCheckOut is time:Error {
                continue;
            }

            boolean overlaps = time:utcDiffSeconds(otherCheckOut, newCheckIn) > 0d &&
                                time:utcDiffSeconds(newCheckOut, otherCheckIn) > 0d;

            if overlaps {
                return {
                    success: false,
                    message: "Property is already booked for the selected date range",
                    booking: booking,
                    totalCost: 0.0
                };
            }
        }

        decimal seconds = time:utcDiffSeconds(newCheckOut, newCheckIn);
        int nights = <int> (seconds / 86400d);

        float totalCost = property.pricePerNight * <float> nights;

        booking.status = "Confirmed";
        _ = bookingCart.remove(value.bookingId);

        Booking[] updatedList = existing.clone();
        updatedList.push(booking);
        confirmedBookings[booking.propertyId] = updatedList;

        return {
            success: true,
            message: "Booking confirmed",
            booking: booking,
            totalCost: totalCost
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