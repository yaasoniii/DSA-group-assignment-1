import ballerina/test;
import ballerina/http;

http:Client testClient = check new ("http://localhost:8080/library");

@test:Config {}
function testCreateAndGetAsset() returns error? {
    json newAsset = {
        assetTag: "TEST001",
        name: "Test Laptop",
        description: "A laptop used for testing",
        institution: "Test University",
        site: "Main Campus",
        dateAcquired: "2026-01-01",
        status: "active"
    };

    http:Response createResp = check testClient->post("/assets", newAsset);
    test:assertEquals(createResp.statusCode, 201, "Expected 201 Created");

    http:Response getResp = check testClient->get("/assets/TEST001");
    test:assertEquals(getResp.statusCode, 200, "Expected 200 OK");

    json payload = check getResp.getJsonPayload();
    test:assertEquals(payload.assetTag, "TEST001", "Asset tag should match");
}

@test:Config { dependsOn: [testCreateAndGetAsset] }
function testUpdateAsset() returns error? {
    json updatedAsset = {
        assetTag: "TEST001",
        name: "Test Laptop Updated",
        description: "A laptop used for testing, now updated",
        institution: "Test University",
        site: "Main Campus",
        dateAcquired: "2026-01-01",
        status: "inactive"
    };

    http:Response updateResp = check testClient->put("/assets/TEST001", updatedAsset);
    test:assertEquals(updateResp.statusCode, 200, "Expected 200 OK");

    http:Response getResp = check testClient->get("/assets/TEST001");
    json payload = check getResp.getJsonPayload();
    test:assertEquals(payload.name, "Test Laptop Updated", "Asset name should be updated");
    test:assertEquals(payload.status, "inactive", "Asset status should be updated");
}

@test:Config { dependsOn: [testUpdateAsset] }
function testDeleteAsset() returns error? {
    http:Response deleteResp = check testClient->delete("/assets/TEST001");
    test:assertEquals(deleteResp.statusCode, 200, "Expected 200 OK");

    http:Response getResp = check testClient->get("/assets/TEST001");
    test:assertEquals(getResp.statusCode, 404, "Asset should no longer exist");
}