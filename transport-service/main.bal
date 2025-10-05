import ballerina/http;
import ballerina/io;
import ballerina/sql;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;
import ballerinax/kafka;

// --- Configuration ---

configurable string dbHost = "localhost";
configurable int dbPort = 5432;
configurable string dbName = "transport_db";
configurable string dbUser = "postgres";
configurable string dbPassword = "postgres";
configurable string kafkaBootstrapServers = "localhost:9096";

// --- Records for Data Structures ---

// Represents a transport route.
type Route record {|
    int id;
    string origin;
    string destination;
    string transportType; // "Bus" or "Train"
|};

// Represents a specific trip on a route.
type Trip record {|
    int id;
    int routeId;
    string departureTime;
    string arrivalTime;
    decimal price;
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
    clientId: "transport-service-producer",
    acks: kafka:ACKS_ALL,
    retryCount: 3
});

// --- Service Implementation ---

service /transport on new http:Listener(9091) {

    // --- Route Management ---

    // Gets all available routes.
    // GET /transport/routes
    resource function get routes() returns Route[]|error {
        stream<Route, sql:Error?> routeStream = dbClient->query(`SELECT id, origin, destination, transport_type as transportType FROM routes`);
        Route[] routes = check from Route route in routeStream select route;
        return routes;
    }

    // Creates a new route (for admins).
    // POST /transport/routes
    resource function post routes(@http:Payload json payload) returns http:Created|http:BadRequest|error {
        var route = payload.cloneWithType(Route);
        if route is error {
            return <http:BadRequest>{ body: "Invalid route payload" };
        }

        sql:ExecutionResult result = check dbClient->execute(`
            INSERT INTO routes (origin, destination, transport_type) 
            VALUES (${route.origin}, ${route.destination}, ${route.transportType})
        `);
        
        int|string? lastInsertId = result.lastInsertId;
        if lastInsertId is int {
            Route newRoute = {
                id: lastInsertId,
                origin: route.origin,
                destination: route.destination,
                transportType: route.transportType
            };
            io:println("New Route Created: ", newRoute);
            
            // Publish RouteCreated event to Kafka
            json routeEvent = {
                eventType: "RouteCreated",
                routeId: lastInsertId,
                origin: newRoute.origin,
                destination: newRoute.destination,
                transportType: newRoute.transportType
            };
            
            check kafkaProducer->send({
                topic: "transport-events",
                value: routeEvent.toJsonString().toBytes()
            });
            
            return <http:Created>{ body: newRoute };
        } else {
            return <http:BadRequest>{ body: "Failed to create route" };
        }
    }

    // --- Trip Management ---

    // Gets all trips, optionally filtered by routeId.
    // GET /transport/trips?routeId={id}
    resource function get trips(int? routeId) returns Trip[]|error {
        stream<Trip, sql:Error?> tripStream;
        if routeId is () {
            tripStream = dbClient->query(`SELECT id, route_id as routeId, departure_time as departureTime, arrival_time as arrivalTime, price FROM trips`);
        } else {
            tripStream = dbClient->query(`SELECT id, route_id as routeId, departure_time as departureTime, arrival_time as arrivalTime, price FROM trips WHERE route_id = ${routeId}`);
        }
        Trip[] trips = check from Trip trip in tripStream select trip;
        return trips;
    }

    // Creates a new trip for a route (for admins).
    // POST /transport/trips
    resource function post trips(@http:Payload json payload) returns http:Created|http:BadRequest|error {
        var trip = payload.cloneWithType(Trip);
        if trip is error {
            return <http:BadRequest>{ body: "Invalid trip payload" };
        }

        sql:ExecutionResult result = check dbClient->execute(`
            INSERT INTO trips (route_id, departure_time, arrival_time, price) 
            VALUES (${trip.routeId}, ${trip.departureTime}, ${trip.arrivalTime}, ${trip.price})
        `);
        
        int|string? lastInsertId = result.lastInsertId;
        if lastInsertId is int {
            Trip newTrip = {
                id: lastInsertId,
                routeId: trip.routeId,
                departureTime: trip.departureTime,
                arrivalTime: trip.arrivalTime,
                price: trip.price
            };
            io:println("New Trip Created: ", newTrip);
            
            // Publish TripCreated event to Kafka
            json tripEvent = {
                eventType: "TripCreated",
                tripId: lastInsertId,
                routeId: newTrip.routeId,
                departureTime: newTrip.departureTime,
                arrivalTime: newTrip.arrivalTime,
                price: newTrip.price
            };
            
            check kafkaProducer->send({
                topic: "transport-events",
                value: tripEvent.toJsonString().toBytes()
            });
            
            return <http:Created>{ body: newTrip };
        } else {
            return <http:BadRequest>{ body: "Failed to create trip" };
        }
    }
}
