import ballerina/http;
import ballerina/io;
import ballerina/time;

// --- Records for Data Structures ---

type NotificationRequest record {|
    int passengerId;
    string message;
|};

type Notification record {|
    readonly int id;
    int passengerId;
    string message;
    string timestamp;
|};

// --- In-Memory Data Store ---

table<Notification> key(id) notificationTable = table [];
int nextNotificationId = 1;

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

        lock {
            Notification newNotification = {
                id: nextNotificationId,
                passengerId: notificationRequest.passengerId,
                message: notificationRequest.message,
                timestamp: time:utcToString(time:utcNow())
            };
            notificationTable.add(newNotification);
            io:println("Notification Created: ", newNotification);
            nextNotificationId += 1;
            return <http:Created>{ body: newNotification };
        }
    }

    // Gets all notifications for a specific passenger.
    // GET /notifications/passenger/{id}
    resource function get passenger/[int id]() returns Notification[] {
        return from var notif in notificationTable
               where notif.passengerId == id
               select notif;
    }
}
