import ballerina/http;

service /mechanicService on new http:Listener(8080) {

    resource function post requestJob(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();
        // Logic to handle the incoming request
        string mechanic = "Auto-assigned mechanic for the job"; 
        // Responding with assigned mechanic
        check caller->respond({message: "Job accepted", mechanic: mechanic});
    }
}


