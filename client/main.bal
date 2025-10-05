import ballerina/io;
import ballerina/http;

// --- HTTP Clients for each Service ---
final http:Client passengerClient = check new("http://localhost:9090");
final http:Client transportClient = check new("http://localhost:9091");
final http:Client ticketingClient = check new("http://localhost:9092");
final http:Client notificationClient = check new("http://localhost:9094");
final http:Client adminClient = check new("http://localhost:9095");

public function main() returns error? {
    io:println("--- Smart Public Transport Client Simulation ---");
    io:println("----------------------------------------------\n");

    // === 1. Passenger Registers and Logs In ===
    io:println("Step 1: Registering a new passenger 'Alice'...");
    json registerPayload = { name: "Alice", email: "alice@example.com", password: "password123" };
    http:Response registerRes = check passengerClient->/passengers/register.post(registerPayload);
    io:println("Registration Response: ", (check registerRes.getJsonPayload()).toJsonString());

    io:println("\nStep 2: Alice logs in...");
    json loginPayload = { email: "alice@example.com", password: "password123" };
    http:Response loginRes = check passengerClient->/passengers/login.post(loginPayload);
    json loginBody = check loginRes.getJsonPayload();
    map<json> loginMap = check loginBody.ensureType();
    int passengerId = check loginMap["passengerId"].ensureType();
    io:println(string `Login successful! Passenger ID: ${passengerId}`);

    // === 2. Passenger Browses and Buys a Ticket ===
    io:println("\nStep 3: Fetching available transport routes...");
    json routes = check transportClient->/transport/routes;
    io:println("Available Routes: ", routes.toJsonString());

    io:println("\nStep 4: Fetching trips for Route ID 1...");
    json trips = check transportClient->/transport/trips(routeId = 1);
    io:println("Available Trips on Route 1: ", trips.toJsonString());

    io:println("\nStep 5: Alice buys a ticket for Trip ID 101...");
    json ticketPayload = { passengerId: passengerId, tripId: 101, price: 15.50 };
    http:Response buyRes = check ticketingClient->/tickets/buy.post(ticketPayload);
    json ticketBody = check buyRes.getJsonPayload();
    map<json> ticketMap = check ticketBody.ensureType();
    int ticketId = check ticketMap["id"].ensureType();
    io:println(string `Ticket purchased successfully! Ticket ID: ${ticketId}`);
    io:println("Ticket Details: ", ticketBody.toJsonString());

    // === 3. Passenger Checks Notifications and Validates Ticket ===
    io:println("\nStep 6: Checking notifications for Alice...");
    json notifications = check notificationClient->/notifications/passenger/[passengerId];
    io:println("Alice's Notifications: ", notifications.toJsonString());

    io:println(string `\nStep 7: Validating Ticket ID ${ticketId} at the bus terminal...`);
    http:Response validateRes = check ticketingClient->/tickets/[ticketId]/validate.post({});
    io:println("Validation Response: ", (check validateRes.getJsonPayload()).toJsonString());

    io:println("\nStep 8: Checking ticket status after validation...");
    json updatedTicket = check ticketingClient->/tickets/[ticketId];
    io:println("Updated Ticket Status: ", updatedTicket.toJsonString());


    // === 4. Admin Performs Actions ===
    io:println("\n--- Admin Simulation ---");
    io:println("\nStep 9: Admin generates a sales report...");
    json salesReport = check adminClient->/admin/reports/sales;
    io:println("Sales Report: ", salesReport.toJsonString());

    io:println("\nStep 10: Admin publishes a service disruption notice...");
    json disruptionPayload = { message: "Route 2 is experiencing delays due to heavy traffic." };
    http:Response disruptionRes = check adminClient->/admin/disruptions.post(disruptionPayload);
    json disruptionBody = check disruptionRes.getJsonPayload();
    io:println("Disruption message published: ", disruptionBody.toJsonString());

    io:println("\n--- Simulation Complete ---");
}
