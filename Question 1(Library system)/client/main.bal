import ballerina/http;
import ballerina/io;

public type Component record {|
string compId;
string name;
string description;
|};

public type Schedule record {|
    string scheduleId;
    string 'type; // MAINTENANCE | BOOKING
    string dueDate; // ISO date, e.g. "2026-09-01"
    string description;
|};

public type WorkOrderTask record {|
    string taskId;
    string description;
    boolean completed = false;
|};

public type WorkOrder record {|
    string orderId;
    string status; // OPEN | IN_PROGRESS | CLOSED
    string description;
    WorkOrderTask[] tasks = [];
|};

public type Asset record {|
    string assetTag;
    string name;
    string description;
    string institution;
    string site;
    string status; // AVAILABLE | LOANED_OUT | UNDER_MAINTENANCE | DISPOSED
    string dateAcquired;
    Component[] components = [];
    Schedule[] schedules = [];
    WorkOrder[] workOrders = [];
|};


// client part idk who doing but i would like too
