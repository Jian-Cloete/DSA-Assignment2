

# DSA-Assignment2 — Smart Public Transport Ticketing System

**Course:** DSA612S — Distributed Systems and Applications
**Assignment:** 2 (Group Project)
**Group Members:**

* Rejoice Kaulumah – 224061135
* Prince-Lee Shigwedha – 224029126
* Jian Cloete – 224063561
* Mitchum Winston Januarie – 221049924
* Kiami L. Q. Quinga – 224008714
* Kuze Mulanda – 224070770

---

## **Project Overview**

This project implements a **distributed ticketing system** for buses and trains in Windhoek City.

* Passengers can **register, login, buy tickets, and validate them**.
* Admins can **create/manage routes and trips, view ticket reports**.
* Notifications are sent for ticket validations and schedule changes.
* Ticket lifecycle: **CREATED → PAID → VALIDATED → EXPIRED**.

The system uses **Ballerina** for microservices and **PostgreSQL** for the database. Kafka and Docker are included in the project structure but are simulated for local testing.

---

## **Full Project Structure**

```
DSA-Assignment2/
├── admin-service/
│   ├── .devcontainer.json
│   ├── .gitignore
│   ├── Ballerina.toml
│   ├── Dependencies.toml
│   └── main.bal
├── client/
│   ├── .devcontainer.json
│   ├── .gitignore
│   ├── Ballerina.toml
│   ├── Dependencies.toml
│   └── main.bal
├── initdb/
│   └── 001_schema.sql
├── notification-service/
│   ├── .devcontainer.json
│   ├── .gitignore
│   ├── Ballerina.toml
│   ├── Dependencies.toml
│   └── main.bal
├── passenger-service/
│   ├── .devcontainer.json
│   ├── .gitignore
│   ├── Ballerina.toml
│   ├── Dependencies.toml
│   └── main.bal
├── payment-service/
│   ├── .devcontainer.json
│   ├── .gitignore
│   ├── Ballerina.toml
│   ├── Dependencies.toml
│   └── main.bal
├── ticketing-service/
│   ├── .devcontainer.json
│   ├── .gitignore
│   ├── Ballerina.toml
│   ├── Dependencies.toml
│   └── main.bal
├── transport-service/
│   ├── .devcontainer.json
│   ├── .gitignore
│   ├── Ballerina.toml
│   ├── Dependencies.toml
│   └── main.bal
└── docker-compose.kafka.yml
```

---

## **Setup Instructions**

### 1. Install PostgreSQL

* Install **Database Server 64-bit v18**
* Default port: `5432`
* Create the database using pgAdmin or `psql`:

```sql
CREATE DATABASE "001_schema";
\c 001_schema
\i 'C:/path/to/initdb/001_schema.sql';
```

### 2. Configure Ballerina Services

* Update each `main.bal` with the database connection:

```ballerina
postgresql:Client db = check new ({
    host: "localhost",
    port: 5432,
    name: "001_schema",
    username: "postgres",
    password: "YOUR_PASSWORD"
});
```

### 3. Run Services

* Open a terminal in each service folder and run:

```bash
bal run main.bal
```

* Recommended start order:
  `passenger → ticketing → payment → notification → transport → admin`

### 4. Test Endpoints
- Example curl commands for ticket flow (create → pay → validate):

```bash
# Create a ticket
curl -s -X POST http://localhost:8080/tickets/create \
-H "Content-Type: application/json" \
-d '{"user_id":1,"trip_id":1,"ticket_type":"single","price":10.0}' | jq

# Pay for the ticket
curl -s -X POST http://localhost:8080/tickets/pay \
-H "Content-Type: application/json" \
-d '{"ticket_id":1,"amount":10.0,"provider_ref":"sim"}' | jq

# Validate the ticket
curl -s -X POST http://localhost:8080/tickets/validate \
-H "Content-Type: application/json" \
-d '{"ticket_id":1}' | jq


* Flow: **register → create ticket → pay → validate → notifications → admin reports**

---

## **Technologies Used**

* **Ballerina** — microservices
* **PostgreSQL** — persistent storage
* **HTTP/REST APIs** — service communication
* **Docker Compose** — optional orchestration; Kafka events are simulated
