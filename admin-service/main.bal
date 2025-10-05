import ballerina/http;
import ballerina/io;

// --- HTTP Clients for Inter-Service Communication ---

final http:Client transportServiceClient = check new("http://localhost:9091");
final http:Client ticketingServiceClient = check new("http://localhost:9092");
final http:Client notificationServiceClient = check new("http://localhost:9094");

// --- Admin Service (acts as a facade/gateway for admin tasks) ---

service /admin on new http:Listener(9095) {

    // --- Route & Trip Management (Proxy to Transport Service) ---

    // Creates a new route via the Transport Service.
    // POST /admin/routes
    resource function post routes(@http:Payload json payload) returns http:Response|error {
        return transportServiceClient->/transport/routes.post(payload);
    }

    // Creates a new trip via the Transport Service.
    // POST /admin/trips
    resource function post trips(@http:Payload json payload) returns http:Response|error {
        return transportServiceClient->/transport/trips.post(payload);
    }

    // --- Reporting ---

    // Generates a simple ticket sales report.
    // GET /admin/reports/sales
    resource function get reports/sales() returns json|http:InternalServerError|error {
        // Fetch all tickets from the Ticketing Service.
        json tickets = check ticketingServiceClient->/tickets/all.get();

        // In a real app, this would be a proper record type.
        if tickets is json[] {
            int totalTickets = tickets.length();
            decimal totalRevenue = 0;
            foreach var item in tickets {
                if item is map<json> {
                    // Filter for paid or validated tickets.
                    if item["status"] == "PAID" || item["status"] == "VALIDATED" {
                        json priceJson = item["price"];
                        if priceJson is decimal {
                            totalRevenue += priceJson;
                        } else if priceJson is int {
                            totalRevenue += <decimal>priceJson;
                        } else if priceJson is float {
                            totalRevenue += <decimal>priceJson;
                        }
                    }
                }
            }
            io:println("Generated Sales Report.");
            return {
                totalTicketsSold: totalTickets,
                totalRevenue: totalRevenue
            };
        }
        return <http:InternalServerError>{ body: "Could not fetch data from ticketing service." };
    }

    // --- Service Disruptions ---

    // Publishes a service disruption notification.
    // This creates a notification for a "system" passenger (e.g., ID -1).
    // All clients could poll for notifications for this special ID.
    // POST /admin/disruptions
    // Payload: { "message": "..." }
    resource function post disruptions(@http:Payload json payload) returns http:Response|error {
        map<json> payloadMap = check payload.ensureType();
        json messageJson = payloadMap["message"];
        
        json notificationPayload = {
            // Use a special passengerId for system-wide announcements
            passengerId: -1,
            message: messageJson
        };
        io:println("Admin published a disruption: ", messageJson);
        return notificationServiceClient->/notifications.post(notificationPayload);
    }
}
