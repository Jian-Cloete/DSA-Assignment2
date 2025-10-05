-- Transport Service Database Schema

CREATE TABLE IF NOT EXISTS routes (
    id SERIAL PRIMARY KEY,
    origin VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    transport_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS trips (
    id SERIAL PRIMARY KEY,
    route_id INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    departure_time VARCHAR(255) NOT NULL,
    arrival_time VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_trips_route_id ON trips(route_id);

-- Insert sample data
INSERT INTO routes (id, origin, destination, transport_type) VALUES 
    (1, 'Windhoek CBD', 'Katutura', 'Bus'),
    (2, 'Eros Airport', 'Klein Windhoek', 'Bus')
ON CONFLICT (id) DO NOTHING;

INSERT INTO trips (id, route_id, departure_time, arrival_time, price) VALUES 
    (101, 1, '2025-10-05T08:00:00Z', '2025-10-05T08:45:00Z', 15.50),
    (102, 1, '2025-10-05T09:00:00Z', '2025-10-05T09:45:00Z', 15.50),
    (201, 2, '2025-10-05T10:00:00Z', '2025-10-05T10:20:00Z', 25.00)
ON CONFLICT (id) DO NOTHING;

-- Update sequences
SELECT setval('routes_id_seq', (SELECT MAX(id) FROM routes));
SELECT setval('trips_id_seq', (SELECT MAX(id) FROM trips));

