import ballerina/http;
import ballerina/io;
import ballerina/time;
import ballerina/sql;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;
import ballerinax/kafka;

// --- Configuration ---

configurable string dbHost = "localhost";
configurable int dbPort = 5432;
configurable string dbName = "ticketing_db";
configurable string dbUser = "postgres";
configurable string dbPassword = "postgres";
configurable string kafkaBootstrapServers = "localhost:9096";

// --- Records for Data Structures ---

type TicketStatus "CREATED"|"PAID"|"VALIDATED"|"EXPIRED";

type TicketRequest record {|
    int passengerId;
    int tripId;
    decimal price;
|};

// Represents a ticket purchased by a passenger.
type Ticket record {|
    int id;
    int passengerId;
    int tripId;
    decimal price;
    string status;
    string purchasedAt;
|};

// --- Database Client ---

final postgresql:Client dbClient = check new (
    host = dbHost,
    port = dbPort,
    database = dbName,
    username = dbUser,
    password = dbPassword
);

// --- HTTP Client for Inter-Service Communication ---
final http:Client paymentServiceClient = check new("http://localhost:9093");
final http:Client notificationServiceClient = check new("http://localhost:9094");

// --- Kafka Producer ---

final kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, {
    clientId: "ticketing-service-producer",
    acks: kafka:ACKS_ALL,
    retryCount: 3
});

// --- Service Implementation ---

service /tickets on new http:Listener(9092) {

    // Buys a new ticket for a trip.
    // This internally calls the Payment Service.
    // POST /tickets/buy
    // Payload: { "passengerId": ..., "tripId": ..., "price": ... }
    resource function post buy(@http:Payload json payload) returns http:Created|http:InternalServerError|http:BadRequest|error {
        var ticketRequest = payload.cloneWithType(TicketRequest);
        if ticketRequest is error {
            return <http:BadRequest>{ body: "Invalid ticket request payload" };
        }

        // 1. Create the ticket with "CREATED" status.
        string purchasedAt = time:utcToString(time:utcNow());
        sql:ExecutionResult result = check dbClient->execute(`
            INSERT INTO tickets (passenger_id, trip_id, price, status, purchased_at) 
            VALUES (${ticketRequest.passengerId}, ${ticketRequest.tripId}, ${ticketRequest.price}, 'CREATED', ${purchasedAt})
        `);
        
        int|string? lastInsertId = result.lastInsertId;
        if lastInsertId !is int {
            return <http:BadRequest>{ body: "Failed to create ticket" };
        }
        
        int ticketId = lastInsertId;
        io:println("Ticket Created (Pending Payment): ID ", ticketId);

        // 2. Call Payment Service to process the payment.
        json paymentPayload = {
            ticketId: ticketId,
            amount: ticketRequest.price
        };
        http:Response|error paymentResponse = paymentServiceClient->/payments.post(paymentPayload);

        if paymentResponse is http:Response && paymentResponse.statusCode == 200 {
            // 3. Update ticket status to "PAID" on successful payment.
            _ = check dbClient->execute(`UPDATE tickets SET status = 'PAID' WHERE id = ${ticketId}`);
            io:println("Ticket Paid: ID ", ticketId);

             // 4. Send a notification.
            json notificationPayload = {
                passengerId: ticketRequest.passengerId,
                message: string `Your ticket for trip ${ticketRequest.tripId} has been confirmed.`
            };
            http:Response|error notifResponse = notificationServiceClient->/notifications.post(notificationPayload);
            if notifResponse is error {
                io:println("Error sending notification: ", notifResponse);
            }

            Ticket newTicket = {
                id: ticketId,
                passengerId: ticketRequest.passengerId,
                tripId: ticketRequest.tripId,
                price: ticketRequest.price,
                status: "PAID",
                purchasedAt: purchasedAt
            };
            
            // Publish TicketPurchased event to Kafka
            json ticketEvent = {
                eventType: "TicketPurchased",
                ticketId: ticketId,
                passengerId: ticketRequest.passengerId,
                tripId: ticketRequest.tripId,
                price: ticketRequest.price,
                timestamp: purchasedAt
            };
            
            check kafkaProducer->send({
                topic: "ticket-events",
                value: ticketEvent.toJsonString().toBytes()
            });
            
            return <http:Created>{ body: newTicket };
        } else {
            // Handle payment failure.
            io:println("Payment failed for ticket ID: ", ticketId);
            if paymentResponse is error {
                 return <http:InternalServerError>{ body: "Payment service is unavailable: " + paymentResponse.toString() };
            } else {
                 return <http:InternalServerError>{ body: "Payment was declined by the payment service." };
            }
        }
    }

    // Validates a ticket (e.g., when boarding a bus).
    // POST /tickets/{id}/validate
    resource function post [int id]/validate() returns http:Ok|http:NotFound|http:Conflict|error {
        stream<Ticket, sql:Error?> ticketStream = dbClient->query(`SELECT id, passenger_id as passengerId, trip_id as tripId, price, status, purchased_at as purchasedAt FROM tickets WHERE id = ${id}`);
        Ticket[] tickets = check from Ticket ticket in ticketStream select ticket;
        
        if tickets.length() == 0 {
            return <http:NotFound>{ body: string `Ticket with ID ${id} not found` };
        }
        
        Ticket ticket = tickets[0];
        if ticket.status == "PAID" {
            _ = check dbClient->execute(`UPDATE tickets SET status = 'VALIDATED' WHERE id = ${id}`);
            io:println("Ticket Validated: ID ", id);

            // Send notification about validation.
            json notificationPayload = {
                passengerId: ticket.passengerId,
                message: string `Your ticket ${ticket.id} was successfully validated.`
            };
            http:Response|error notifRes = notificationServiceClient->/notifications.post(notificationPayload);
            if notifRes is error {
                io:println("Error sending notification: ", notifRes);
            }

            ticket.status = "VALIDATED";
            
            // Publish TicketValidated event to Kafka
            json validationEvent = {
                eventType: "TicketValidated",
                ticketId: id,
                passengerId: ticket.passengerId,
                tripId: ticket.tripId,
                timestamp: time:utcToString(time:utcNow())
            };
            
            check kafkaProducer->send({
                topic: "ticket-events",
                value: validationEvent.toJsonString().toBytes()
            });
            
            return <http:Ok>{ body: ticket };
        } else {
            string message = string `Ticket cannot be validated. Current status: ${ticket.status}`;
            io:println(message);
            return <http:Conflict>{ body: message };
        }
    }

    // Gets a ticket's details by ID.
    // GET /tickets/{id}
    resource function get [int id]() returns Ticket|http:NotFound|error {
        stream<Ticket, sql:Error?> ticketStream = dbClient->query(`SELECT id, passenger_id as passengerId, trip_id as tripId, price, status, purchased_at as purchasedAt FROM tickets WHERE id = ${id}`);
        Ticket[] tickets = check from Ticket ticket in ticketStream select ticket;
        
        if tickets.length() == 0 {
            return <http:NotFound>{ body: string `Ticket with ID ${id} not found` };
        }
        return tickets[0];
    }

    // Gets all tickets (for admin/reporting purposes).
    // GET /tickets
    resource function get all() returns Ticket[]|error {
        stream<Ticket, sql:Error?> ticketStream = dbClient->query(`SELECT id, passenger_id as passengerId, trip_id as tripId, price, status, purchased_at as purchasedAt FROM tickets`);
        Ticket[] tickets = check from Ticket ticket in ticketStream select ticket;
        return tickets;
    }
}
