import ballerina/time;

// Shared date helpers. ISO dates are zero-padded, so comparing them as plain
// strings gives the same ordering as comparing the dates themselves.
// These mirror the checks in the service so the client can catch a bad date
// before spending a round trip on it.

function todayIso() returns string {
    return time:utcToString(time:utcNow()).substring(0, 10);
}

function isValidDate(string date) returns boolean {
    if date.length() != 10 {
        return false;
    }
    if date.substring(4, 5) != "-" || date.substring(7, 8) != "-" {
        return false;
    }
    int|error year = int:fromString(date.substring(0, 4));
    int|error month = int:fromString(date.substring(5, 7));
    int|error day = int:fromString(date.substring(8, 10));
    if year is error || month is error || day is error {
        return false;
    }
    if month < 1 || month > 12 || day < 1 {
        return false;
    }
    return day <= daysInMonth(month, year);
}

function daysInMonth(int month, int year) returns int {
    if month == 1 || month == 3 || month == 5 || month == 7
            || month == 8 || month == 10 || month == 12 {
        return 31;
    }
    if month == 4 || month == 6 || month == 9 || month == 11 {
        return 30;
    }
    return isLeapYear(year) ? 29 : 28;
}

function isLeapYear(int year) returns boolean {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}
