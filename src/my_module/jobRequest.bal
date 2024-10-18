import ballerina/http;

service /jobRequest on new http:Listener(8081) {
    resource function post request(http:Caller caller, http:Request req) returns error? {
        // Code to handle job request
        check caller->respond({message: "Job Request Received"});
    }
}
