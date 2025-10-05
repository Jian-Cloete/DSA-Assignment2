-- Ticketing Service Database Schema

CREATE TABLE IF NOT EXISTS tickets (
    id SERIAL PRIMARY KEY,
    passenger_id INTEGER NOT NULL,
    trip_id INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'CREATED',
    purchased_at VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_status CHECK (status IN ('CREATED', 'PAID', 'VALIDATED', 'EXPIRED'))
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_tickets_passenger_id ON tickets(passenger_id);
CREATE INDEX IF NOT EXISTS idx_tickets_trip_id ON tickets(trip_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);

