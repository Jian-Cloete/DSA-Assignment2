import ballerina/http;
import ballerina/io;
import ballerina/time;

// --- Records for Data Structures ---

type TicketStatus "CREATED"|"PAID"|"VALIDATED"|"EXPIRED";

type TicketRequest record {|
    int passengerId;
    int tripId;
    decimal price;
|};

// Represents a ticket purchased by a passenger.
type Ticket record {|
    readonly int id;
    int passengerId;
    int tripId;
    decimal price;
    TicketStatus status;
    string purchasedAt;
|};

// --- In-Memory Data Store ---

table<Ticket> key(id) ticketTable = table [];
int nextTicketId = 1;

// --- HTTP Client for Inter-Service Communication ---
final http:Client paymentServiceClient = check new("http://localhost:9093");
final http:Client notificationServiceClient = check new("http://localhost:9094");

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
        Ticket newTicket;
        lock {
            newTicket = {
                id: nextTicketId,
                passengerId: ticketRequest.passengerId,
                tripId: ticketRequest.tripId,
                price: ticketRequest.price,
                status: "CREATED",
                purchasedAt: time:utcToString(time:utcNow())
            };
            ticketTable.add(newTicket);
            nextTicketId += 1;
        }
        io:println("Ticket Created (Pending Payment): ", newTicket);

        // 2. Call Payment Service to process the payment.
        json paymentPayload = {
            ticketId: newTicket.id,
            amount: newTicket.price
        };
        http:Response|error paymentResponse = paymentServiceClient->/payments.post(paymentPayload);

        if paymentResponse is http:Response && paymentResponse.statusCode == 200 {
            // 3. Update ticket status to "PAID" on successful payment.
            lock {
                newTicket.status = "PAID";
                ticketTable.put(newTicket);
            }
            io:println("Ticket Paid: ", newTicket);

             // 4. Send a notification.
            json notificationPayload = {
                passengerId: newTicket.passengerId,
                message: string `Your ticket for trip ${newTicket.tripId} has been confirmed.`
            };
            http:Response|error notifResponse = notificationServiceClient->/notifications.post(notificationPayload);
            if notifResponse is error {
                io:println("Error sending notification: ", notifResponse);
            }

            return <http:Created>{ body: newTicket };
        } else {
            // Handle payment failure.
            io:println("Payment failed for ticket ID: ", newTicket.id);
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
        Ticket? ticket = ticketTable[id];
        if ticket is () {
            return <http:NotFound>{ body: string `Ticket with ID ${id} not found` };
        }

        if ticket.status == "PAID" {
            lock {
                ticket.status = "VALIDATED";
                ticketTable.put(ticket);
            }
            io:println("Ticket Validated: ", ticket);

            // Send notification about validation.
            json notificationPayload = {
                passengerId: ticket.passengerId,
                message: string `Your ticket ${ticket.id} was successfully validated.`
            };
            http:Response|error notifRes = notificationServiceClient->/notifications.post(notificationPayload);
            if notifRes is error {
                io:println("Error sending notification: ", notifRes);
            }

            return <http:Ok>{ body: ticket };
        } else {
            string message = string `Ticket cannot be validated. Current status: ${ticket.status}`;
            io:println(message);
            return <http:Conflict>{ body: message };
        }
    }

    // Gets a ticket's details by ID.
    // GET /tickets/{id}
    resource function get [int id]() returns Ticket|http:NotFound {
        Ticket? ticket = ticketTable[id];
        if ticket is () {
            return { body: string `Ticket with ID ${id} not found` };
        }
        return ticket;
    }

    // Gets all tickets (for admin/reporting purposes).
    // GET /tickets
    resource function get all() returns Ticket[] {
        return ticketTable.toArray();
    }
}
