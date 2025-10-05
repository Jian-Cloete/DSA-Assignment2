import ballerina/http;
import ballerina/io;

// This is a mock payment service.
// In a real system, this would integrate with a payment gateway.

type PaymentRequest record {|
    int ticketId;
    decimal amount;
|};

service /payments on new http:Listener(9093) {

    // Simulates processing a payment for a ticket.
    // It always succeeds for this demonstration.
    // POST /payments
    // Payload: { "ticketId": ..., "amount": ... }
    resource function post .(@http:Payload json payload) returns http:Ok|http:BadRequest|error {
        var paymentDetails = payload.cloneWithType(PaymentRequest);
        if paymentDetails is error {
            return <http:BadRequest>{ body: "Invalid payment payload" };
        }

        io:println(string `Processing payment of ${paymentDetails.amount} for ticket ${paymentDetails.ticketId}`);
        // Simulate a successful payment.
        io:println("Payment Approved for ticket: ", paymentDetails.ticketId);
        return <http:Ok>{ body: { "status": "SUCCESS", "ticketId": paymentDetails.ticketId } };
    }
}
