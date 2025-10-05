-- Users
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('passenger','admin','validator')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Routes
CREATE TABLE IF NOT EXISTS routes (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  origin TEXT NOT NULL,
  destination TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Trips
CREATE TABLE IF NOT EXISTS trips (
  id SERIAL PRIMARY KEY,
  route_id INT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  departure_time TIMESTAMPTZ NOT NULL,
  arrival_time TIMESTAMPTZ NOT NULL,
  capacity INT NOT NULL DEFAULT 0,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_trips_route_time ON trips(route_id, departure_time);

-- Tickets
CREATE TABLE IF NOT EXISTS tickets (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  trip_id INT REFERENCES trips(id),
  ticket_type TEXT NOT NULL CHECK (ticket_type IN ('single','multi','pass')),
  status TEXT NOT NULL CHECK (status IN ('CREATED','PAID','VALIDATED','EXPIRED','CANCELLED')),
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  version BIGINT DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_tickets_user ON tickets(user_id);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
  id SERIAL PRIMARY KEY,
  ticket_id INT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('PENDING','COMPLETED','FAILED')),
  provider_ref TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  message TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'in-app',
  created_at TIMESTAMPTZ DEFAULT now(),
  delivered BOOLEAN DEFAULT FALSE
);
