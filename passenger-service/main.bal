import ballerina/http;
import ballerina/io;

// --- Records for Data Structures ---

type LoginRequest record {|
    string email;
    string password;
|};

// Represents a passenger in the system.
type Passenger record {|
    readonly int id;
    string name;
    string email;
    string password;
|};

// --- In-Memory Data Store ---

// In-memory table to store passenger data.
// The 'id' field is the primary key.
table<Passenger> key(id) passengerTable = table [];
int nextPassengerId = 1;

// --- Service Implementation ---

service /passengers on new http:Listener(9090) {

    // Registers a new passenger.
    // POST /passengers/register
    // Payload: { "name": "...", "email": "...", "password": "..." }
    resource function post register(@http:Payload json payload) returns http:Created|http:BadRequest|error {
        map<json> passengerJson = check payload.ensureType();
        
        json nameJson = passengerJson["name"];
        json emailJson = passengerJson["email"];
        json passwordJson = passengerJson["password"];

        if nameJson is () || emailJson is () || passwordJson is () {
            return <http:BadRequest>{ body: "Missing required fields: name, email, password" };
        }

        string name = nameJson.toString();
        string email = emailJson.toString();
        string password = passwordJson.toString();

        // Create and add the new passenger.
        lock {
            Passenger newPassenger = {
                id: nextPassengerId,
                name: name,
                email: email,
                password: password // In a real app, this should be hashed.
            };
            passengerTable.add(newPassenger);
            io:println("Passenger Registered: ", newPassenger);
            nextPassengerId += 1;
            return <http:Created>{ body: newPassenger, headers: {"Location": string `/passengers/${newPassenger.id}`} };
        }
    }

    // Logs in a passenger.
    // POST /passengers/login
    // Payload: { "email": "...", "password": "..." }
    resource function post login(@http:Payload json payload) returns http:Ok|http:Unauthorized|error {
        var credentials = payload.cloneWithType(LoginRequest);
        if credentials is error {
            return <http:Unauthorized>{ body: "Invalid login payload. Requires email and password." };
        }

        // Find passenger by email.
        var foundPassenger = from var p in passengerTable
                              where p.email == credentials.email
                              select p;

        // In Ballerina, iterating even for one result is standard.
        foreach var p in foundPassenger {
            if p.password == credentials.password {
                io:println("Login successful for: ", p.email);
                return <http:Ok>{ body: {"message": "Login successful", "passengerId": p.id} };
            }
        }

        io:println("Login failed for: ", credentials.email);
        return <http:Unauthorized>{ body: "Invalid email or password" };
    }

    // Gets passenger details by ID.
    // GET /passengers/{id}
    resource function get [int id]() returns Passenger|http:NotFound|error {
        Passenger? passenger = passengerTable[id];
        if passenger is () {
            return <http:NotFound>{ body: string `Passenger with ID ${id} not found` };
        }
        return passenger;
    }
}
