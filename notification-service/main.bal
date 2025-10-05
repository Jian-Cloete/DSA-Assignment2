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
configurable string dbName = "notification_db";
configurable string dbUser = "postgres";
configurable string dbPassword = "postgres";
configurable string kafkaBootstrapServers = "localhost:9096";

// --- Records for Data Structures ---

type NotificationRequest record {|
    int passengerId;
    string message;
|};

type Notification record {|
    int id;
    int passengerId;
    string message;
    string timestamp;
|};

// --- Database Client ---

final postgresql:Client dbClient = check new (
    host = dbHost,
    port = dbPort,
    database = dbName,
    username = dbUser,
    password = dbPassword
);

// --- Kafka Consumer ---

listener kafka:Listener kafkaListener = check new (kafkaBootstrapServers, {
    groupId: "notification-service-group",
    topics: ["passenger-events", "ticket-events", "transport-events"]
});

// Kafka Event Consumer Service
service on kafkaListener {
    remote function onConsumerRecord(kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord kafkaRecord in records {
            byte[] value = kafkaRecord.value;
            string eventString = check string:fromBytes(value);
            json event = check eventString.fromJsonString();
            
            io:println("Received event: ", event);
            
            // Process event based on type
            json|error eventType = event.eventType;
            if eventType is string {
                check processEvent(eventType, event);
            }
        }
    }
}

// Process different event types
function processEvent(string eventType, json event) returns error? {
    match eventType {
        "PassengerRegistered" => {
            int passengerId = check event.passengerId;
            string name = check event.name;
            string timestamp = time:utcToString(time:utcNow());
            
            _ = check dbClient->execute(`
                INSERT INTO notifications (passenger_id, message, timestamp) 
                VALUES (${passengerId}, 
                        ${"Welcome " + name + "! Your registration is complete."},
                        ${timestamp})
            `);
            io:println("Created welcome notification for passenger ", passengerId);
        }
        "TicketPurchased" => {
            int passengerId = check event.passengerId;
            int ticketId = check event.ticketId;
            int tripId = check event.tripId;
            string timestamp = time:utcToString(time:utcNow());
            
            _ = check dbClient->execute(`
                INSERT INTO notifications (passenger_id, message, timestamp) 
                VALUES (${passengerId}, 
                        ${"Your ticket #" + ticketId.toString() + " for trip #" + tripId.toString() + " has been purchased successfully."},
                        ${timestamp})
            `);
            io:println("Created purchase notification for passenger ", passengerId);
        }
        "TicketValidated" => {
            int passengerId = check event.passengerId;
            int ticketId = check event.ticketId;
            string timestamp = time:utcToString(time:utcNow());
            
            _ = check dbClient->execute(`
                INSERT INTO notifications (passenger_id, message, timestamp) 
                VALUES (${passengerId}, 
                        ${"Your ticket #" + ticketId.toString() + " has been validated. Enjoy your trip!"},
                        ${timestamp})
            `);
            io:println("Created validation notification for passenger ", passengerId);
        }
        "RouteCreated" => {
            string origin = check event.origin;
            string destination = check event.destination;
            io:println("New route created: ", origin, " to ", destination);
            // Could create system-wide announcement here
        }
        "TripCreated" => {
            int routeId = check event.routeId;
            io:println("New trip created for route: ", routeId);
            // Could notify interested passengers
        }
        _ => {
            io:println("Unknown event type: ", eventType);
        }
    }
}

// --- Service Implementation ---

service /notifications on new http:Listener(9094) {

    // Creates a new notification.
    // POST /notifications
    // Payload: { "passengerId": ..., "message": "..." }
    resource function post .(@http:Payload json payload) returns http:Created|http:BadRequest|error {
        var notificationRequest = payload.cloneWithType(NotificationRequest);
        if notificationRequest is error {
            return <http:BadRequest>{ body: "Invalid notification payload" };
        }

        string timestamp = time:utcToString(time:utcNow());
        sql:ExecutionResult result = check dbClient->execute(`
            INSERT INTO notifications (passenger_id, message, timestamp) 
            VALUES (${notificationRequest.passengerId}, ${notificationRequest.message}, ${timestamp})
        `);
        
        int|string? lastInsertId = result.lastInsertId;
        if lastInsertId is int {
            Notification newNotification = {
                id: lastInsertId,
                passengerId: notificationRequest.passengerId,
                message: notificationRequest.message,
                timestamp: timestamp
            };
            io:println("Notification Created: ", newNotification);
            return <http:Created>{ body: newNotification };
        } else {
            return <http:BadRequest>{ body: "Failed to create notification" };
        }
    }

    // Gets all notifications for a specific passenger.
    // GET /notifications/passenger/{id}
    resource function get passenger/[int id]() returns Notification[]|error {
        stream<Notification, sql:Error?> notifStream = dbClient->query(
            `SELECT id, passenger_id as passengerId, message, timestamp FROM notifications WHERE passenger_id = ${id}`
        );
        Notification[] notifications = check from Notification notif in notifStream select notif;
        return notifications;
    }
}
