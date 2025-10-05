import ballerina/http;
import ballerina/io;

// --- Records for Data Structures ---

// Represents a transport route.
type Route record {|
    readonly int id;
    string origin;
    string destination;
    string transportType; // "Bus" or "Train"
|};

// Represents a specific trip on a route.
type Trip record {|
    readonly int id;
    int routeId;
    string departureTime;
    string arrivalTime;
    decimal price;
|};

// --- In-Memory Data Store ---

table<Route> key(id) routeTable = table [
    {id: 1, origin: "Windhoek CBD", destination: "Katutura", transportType: "Bus"},
    {id: 2, origin: "Eros Airport", destination: "Klein Windhoek", transportType: "Bus"}
];
int nextRouteId = 3;

table<Trip> key(id) tripTable = table [
    {id: 101, routeId: 1, departureTime: "2025-10-05T08:00:00Z", arrivalTime: "2025-10-05T08:45:00Z", price: 15.50},
    {id: 102, routeId: 1, departureTime: "2025-10-05T09:00:00Z", arrivalTime: "2025-10-05T09:45:00Z", price: 15.50},
    {id: 201, routeId: 2, departureTime: "2025-10-05T10:00:00Z", arrivalTime: "2025-10-05T10:20:00Z", price: 25.00}
];
int nextTripId = 202;

// --- Service Implementation ---

service /transport on new http:Listener(9091) {

    // --- Route Management ---

    // Gets all available routes.
    // GET /transport/routes
    resource function get routes() returns Route[] {
        return routeTable.toArray();
    }

    // Creates a new route (for admins).
    // POST /transport/routes
    resource function post routes(@http:Payload json payload) returns http:Created|http:BadRequest|error {
        var route = payload.cloneWithType(Route);
        if route is error {
            return <http:BadRequest>{ body: "Invalid route payload" };
        }

        lock {
            Route newRoute = {
                id: nextRouteId,
                origin: route.origin,
                destination: route.destination,
                transportType: route.transportType
            };
            routeTable.add(newRoute);
            io:println("New Route Created: ", newRoute);
            nextRouteId += 1;
            return <http:Created>{ body: newRoute };
        }
    }

    // --- Trip Management ---

    // Gets all trips, optionally filtered by routeId.
    // GET /transport/trips?routeId={id}
    resource function get trips(int? routeId) returns Trip[] {
        if routeId is () {
            return tripTable.toArray();
        } else {
            return from var trip in tripTable where trip.routeId == routeId select trip;
        }
    }

    // Creates a new trip for a route (for admins).
    // POST /transport/trips
    resource function post trips(@http:Payload json payload) returns http:Created|http:BadRequest|error {
        var trip = payload.cloneWithType(Trip);
        if trip is error {
            return <http:BadRequest>{ body: "Invalid trip payload" };
        }

        lock {
            Trip newTrip = {
                id: nextTripId,
                routeId: trip.routeId,
                departureTime: trip.departureTime,
                arrivalTime: trip.arrivalTime,
                price: trip.price
            };
            tripTable.add(newTrip);
            io:println("New Trip Created: ", newTrip);
            nextTripId += 1;
            return <http:Created>{ body: newTrip };
        }
    }
}
