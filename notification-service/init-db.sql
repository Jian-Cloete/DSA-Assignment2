-- Notification Service Database Schema

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    passenger_id INTEGER NOT NULL,
    message TEXT NOT NULL,
    timestamp VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for passenger lookups
CREATE INDEX IF NOT EXISTS idx_notifications_passenger_id ON notifications(passenger_id);

