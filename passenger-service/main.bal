import ballerina/http;
import ballerina/io;
import ballerina/sql;
import ballerina/time;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;
import ballerinax/kafka;

// --- Configuration ---

configurable string dbHost = "localhost";
configurable int dbPort = 5432;
configurable string dbName = "passenger_db";
configurable string dbUser = "postgres";
configurable string dbPassword = "postgres";
configurable string kafkaBootstrapServers = "localhost:9096";

// --- Records for Data Structures ---

type LoginRequest record {|
    string email;
    string password;
|};

// Represents a passenger in the system.
type Passenger record {|
    int id;
    string name;
    string email;
    string password;
|};

// --- Database Client ---

final postgresql:Client dbClient = check new (
    host = dbHost,
    port = dbPort,
    database = dbName,
    username = dbUser,
    password = dbPassword
);

// --- Kafka Producer ---

final kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, {
    clientId: "passenger-service-producer",
    acks: kafka:ACKS_ALL,
    retryCount: 3
});

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

        // Insert into database
        sql:ExecutionResult result = check dbClient->execute(`
            INSERT INTO passengers (name, email, password) 
            VALUES (${name}, ${email}, ${password})
        `);
        
        int|string? lastInsertId = result.lastInsertId;
        if lastInsertId is int {
            Passenger newPassenger = {
                id: lastInsertId,
                name: name,
                email: email,
                password: password
            };
            io:println("Passenger Registered: ", newPassenger);
            
            // Publish PassengerRegistered event to Kafka
            json event = {
                eventType: "PassengerRegistered",
                passengerId: newPassenger.id,
                name: newPassenger.name,
                email: newPassenger.email,
                timestamp: time:utcToString(time:utcNow())
            };
            
            check kafkaProducer->send({
                topic: "passenger-events",
                value: event.toJsonString().toBytes()
            });
            
            return <http:Created>{ body: newPassenger, headers: {"Location": string `/passengers/${newPassenger.id}`} };
        } else {
            return <http:BadRequest>{ body: "Failed to register passenger" };
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

        // Find passenger by email and password
        stream<Passenger, sql:Error?> passengerStream = dbClient->query(
            `SELECT id, name, email, password FROM passengers 
             WHERE email = ${credentials.email} AND password = ${credentials.password}`
        );
        
        Passenger[] passengers = check from Passenger passenger in passengerStream select passenger;
        
        if passengers.length() > 0 {
            Passenger p = passengers[0];
            io:println("Login successful for: ", p.email);
            return <http:Ok>{ body: {"message": "Login successful", "passengerId": p.id} };
        }

        io:println("Login failed for: ", credentials.email);
        return <http:Unauthorized>{ body: "Invalid email or password" };
    }

    // Gets passenger details by ID.
    // GET /passengers/{id}
    resource function get [int id]() returns Passenger|http:NotFound|error {
        stream<Passenger, sql:Error?> passengerStream = dbClient->query(
            `SELECT id, name, email, password FROM passengers WHERE id = ${id}`
        );
        
        Passenger[] passengers = check from Passenger passenger in passengerStream select passenger;
        
        if passengers.length() > 0 {
            return passengers[0];
        }
        
        return <http:NotFound>{ body: string `Passenger with ID ${id} not found` };
    }
}
