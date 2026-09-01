import ballerina/http;
import ballerina/io;



function httpGet(string path) returns [int, json]|error {
    http:Response resp = check libClient->get(path);
    json body = check resp.getJsonPayload();
    return [resp.statusCode, body];
}

function httpPost(string path, json payload) returns [int, json]|error {
    http:Response resp = check libClient->post(path, payload);
    json body = check resp.getJsonPayload();
    return [resp.statusCode, body];
}

function httpPut(string path, json payload) returns [int, json]|error {
    http:Response resp = check libClient->put(path, payload);
    json body = check resp.getJsonPayload();
    return [resp.statusCode, body];
}

function httpDelete(string path) returns [int, json]|error {
    http:Response resp = check libClient->delete(path);
    json body = check resp.getJsonPayload();
    return [resp.statusCode, body];
}

function printApiError(int statusCode, json body) {
    string message = "Unknown error";
    if body is map<json> && body.hasKey("message") {
        json m = body["message"];
        message = m.toString();
    }
    io:println("Error (" + statusCode.toString() + "): " + message);
}
