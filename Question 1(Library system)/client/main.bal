import ballerina/http;

http:Client libClient = check new ("http://localhost:8080/library", {
    http1Settings: {keepAlive: http:KEEPALIVE_NEVER}
});

public function main() returns error? {
    check assetManagementMenu();
}