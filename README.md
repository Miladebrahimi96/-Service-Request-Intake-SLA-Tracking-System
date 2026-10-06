# Service Request Intake & SLA Tracking System

A self-hosted service request management system built with **Appsmith, n8n, and PostgreSQL**.

The system replaces a spreadsheet-based service request process with a structured workflow for request intake, validation, duplicate detection, SLA calculation, queue management, audit tracking, and automated SLA escalation.

---

## Architecture

```text
┌──────────────┐
│   Appsmith   │
│              │
│ Request Form │
│ Request Queue│
└──────┬───────┘
       │
       │ HTTP
       ▼
┌──────────────┐
│     n8n      │
│              │
│ Validation   │
│ Normalization│
│ Duplicate    │
│ SLA          │
│ Automation   │
└──────┬───────┘
       │
       │ PostgreSQL
       ▼
┌──────────────────────┐
│      PostgreSQL      │
│                      │
│ service_requests     │
│ request_events       │
└──────────────────────┘

Scheduled n8n workflow
        │
        ▼
SLA monitoring
        │
        ▼
SLA breach escalation
```

### Components

- **Appsmith** — Internal UI for request submission and queue management.
- **n8n** — Workflow orchestration, validation, SLA calculation, duplicate detection, and scheduled escalation.
- **PostgreSQL** — Persistent source of truth for requests and audit events.
- **Docker Compose** — Local/self-hosted deployment.

---

## Features

### Request Intake

The request form collects:

- Requester name
- Requester email
- Department
- Request title
- Description
- Declared priority

Supported departments:

- Finance
- IT
- HR
- Operations
- Sales
- Legal

Supported priorities:

| Priority | SLA |
|---|---|
| P1 | 4 clock hours |
| P2 | 1 business day |
| P3 | 3 business days |
| P4 | 5 business days |

---

## Validation

Requests are validated before being persisted.

Validation includes:

- Required fields
- Email format
- Valid priority (`P1`–`P4`)

Invalid requests fail before database insertion.

---

## Duplicate Detection

Duplicate requests are identified using:

```text
requester_email + normalized_title
```

Normalization includes:

- Trimming whitespace
- Lowercasing email
- Lowercasing title
- Collapsing repeated whitespace

For example:

```text
"  Laptop   Access "
```

becomes:

```text
"laptop access"
```

The system performs an application-level duplicate check to return a friendly `409 Conflict` response.

PostgreSQL also enforces:

```sql
UNIQUE (requester_email, normalized_title)
```

This provides a database-level consistency guarantee in case of concurrent requests.

---

## Request IDs

Each request receives a unique identifier:

```text
REQ-2026-000001
REQ-2026-000002
REQ-2026-000003
```

The request number is generated using a PostgreSQL sequence.

---

## SLA Calculation

All timestamps are stored as UTC using PostgreSQL `TIMESTAMPTZ`.

### P1

P1 uses clock hours:

```text
created_at + 4 hours
```

Weekends do not affect P1.

### P2–P4

P2–P4 use business days.

- Saturday and Sunday are excluded.
- The SLA ends at `17:00 UTC` on the final business day.
- Public holidays are not currently configured.

Current interpretation:

```text
P2 → end of next business day
P3 → end of third business day
P4 → end of fifth business day
```

### Example

If a P3 request is created on Monday:

```text
Monday → created
Tuesday → business day 1
Wednesday → business day 2
Thursday → business day 3
Thursday 17:00 UTC → due
```

If a P3 request is created on Friday:

```text
Monday → business day 1
Tuesday → business day 2
Wednesday → business day 3
Wednesday 17:00 UTC → due
```

### SLA Status

The queue displays:

- 🟢 **ON TRACK** — more than 24 hours remaining
- 🟡 **AT RISK** — due within 24 hours
- 🔴 **BREACHED** — due time has passed

---

## Request Queue

The Appsmith queue provides:

### Filters

Status:

- All
- Open
- In Progress
- Completed
- Resolved
- Cancelled

Department:

- All
- Finance
- IT
- HR
- Operations
- Sales
- Legal

The filters can be combined.

### Request Management

Operators can update:

- Status
- Assignment

When a request is completed or resolved, `resolved_at` is recorded.

---

## Audit Trail

Request history is stored separately from the current request state.

### Current state

```text
service_requests
```

### Historical events

```text
request_events
```

Example events:

```text
REQUEST_CREATED
REQUEST_UPDATED
SLA_BREACHED
```

This allows the system to preserve an operational history while keeping the main request table focused on current state.

---

## SLA Monitoring & Escalation

A separate n8n workflow runs on a schedule.

Current configuration:

```text
Every 5 minutes
```

It searches for active requests where:

```text
status IN ('Open', 'In Progress')
AND due_at <= NOW()
AND escalated_at IS NULL
```

Breached requests are marked as escalated and an audit event is created.

The condition:

```text
escalated_at IS NULL
```

makes the escalation operation idempotent.

A request therefore cannot be repeatedly escalated on every scheduled execution.

---

# Project Structure

```text
service-request-system/
│
├── appsmith/
│   └── service-request-app.json
│
├── n8n/
│   ├── Service Request - Intake.json
│   └── SLA Monitoring & Escalation.json
│
├── docker-compose.yml
├── schema.sql
├── .env.example
└── .gitignore
```

---

# Prerequisites

- Docker
- Docker Compose
- Git

No Node.js installation is required.

---

# Setup

## 1. Clone the repository

```bash
git clone git@github.com:Miladebrahimi96/-Service-Request-Intake-SLA-Tracking-System.git
cd -Service-Request-Intake-SLA-Tracking-System
```

## 2. Create environment configuration

```bash
cp .env.example .env
```

Review the values in `.env` before starting the stack.

---

## 3. Start the services

```bash
docker compose up -d
```

Check the containers:

```bash
docker compose ps
```

The stack contains:

```text
PostgreSQL
n8n
Appsmith
```

---

# Database Setup

The PostgreSQL database is exposed on:

```text
localhost:5433
```

Inside the Docker network, PostgreSQL is available as:

```text
postgres:5432
```

The database schema is available in:

```text
schema.sql
```

To apply the schema:

```bash
docker exec -i service-request-postgres \
  psql -U automation -d service_requests < schema.sql
```

---

# n8n Setup

Open:

```text
http://localhost:5678
```

Import:

```text
n8n/Service Request - Intake.json
n8n/SLA Monitoring & Escalation.json
```

The first workflow handles:

```text
Webhook
   ↓
Validation
   ↓
Normalization
   ↓
Duplicate Detection
   ↓
SLA Calculation
   ↓
Request + Audit Persistence
   ↓
Response
```

The second workflow handles:

```text
Schedule Trigger
   ↓
Find SLA Issues
   ↓
Escalate SLA Issues
```

After importing the workflows, verify that the PostgreSQL credentials are configured for the local PostgreSQL instance.

---

# Appsmith Setup

Open:

```text
http://localhost:8080
```

Import:

```text
appsmith/service-request-app.json
```

The exported application contains the request intake and queue UI.

After importing, configure the PostgreSQL datasource using:

```text
Host: postgres
Port: 5432
Database: service_requests
Username: automation
Password: <value from .env>
```

The n8n webhook should use the Docker service hostname:

```text
http://n8n:5678/webhook/service-requests
```

Do not use:

```text
http://localhost:5678
```

from inside the Appsmith container.

---

# Testing

## 1. Create a request

Submit a request using:

```text
Requester: Test User
Email: test@example.com
Department: IT
Title: Laptop Access
Priority: P3
```

Expected result:

```text
success: true
request_id: REQ-2026-XXXXXX
status: Open
```

---

## 2. Duplicate request

Submit the exact same request again.

Expected:

```text
HTTP 409
```

Example:

```json
{
  "success": false,
  "error": "DUPLICATE_REQUEST"
}
```

No second request should be created.

---

## 3. Normalization test

Submit:

```text
Email: TEST@example.com
Title:   Laptop    Access
```

after creating:

```text
Email: test@example.com
Title: Laptop Access
```

The second request should be detected as a duplicate.

---

## 4. Invalid priority

Send:

```text
P5
```

Expected:

```text
Invalid priority
```

No database row should be created.

---

## 5. Queue filtering

Verify:

- Status filtering
- Department filtering
- Combined status + department filtering

---

## 6. Status update

Change a request from:

```text
Open
```

to:

```text
In Progress
```

and assign an operator.

Verify the request and audit event are updated.

---

## 7. SLA breach

Create or use a request whose `due_at` has passed.

Run the SLA monitoring workflow.

Verify:

```text
escalated_at IS NOT NULL
```

and that a:

```text
SLA_BREACHED
```

event exists in `request_events`.

---

# Useful Database Queries

### Requests

```sql
SELECT *
FROM service_requests
ORDER BY created_at DESC;
```

### Audit trail

```sql
SELECT
    id,
    request_id,
    event_type,
    old_status,
    new_status,
    metadata,
    created_at
FROM request_events
ORDER BY created_at DESC;
```

### SLA breaches

```sql
SELECT
    request_id,
    declared_priority,
    due_at,
    escalated_at
FROM service_requests
WHERE escalated_at IS NOT NULL
ORDER BY escalated_at DESC;
```

---

# Design Decisions

## Why n8n?

n8n provides a visual orchestration layer between the UI, database, and scheduled automation.

This keeps workflow logic outside the frontend and makes the automation easier to inspect, modify, and operate.

## Why PostgreSQL?

PostgreSQL provides:

- Relational data modeling
- Constraints
- Unique indexes
- Transactions
- Querying/filtering
- Persistent storage
- Audit history

It is the source of truth for the system.

## Why separate audit events?

The request table represents the current state of a request.

The event table represents how that state changed over time.

This makes operational history queryable without overwriting previous events.

## Why scheduled SLA monitoring?

Instead of creating an individual timer for every request, the system periodically reconciles database state.

Advantages:

- Simple
- Recoverable
- Easy to monitor
- Database remains the source of truth
- Idempotent escalation

---

# Production Improvements

For a production deployment, the following could be added:

- Authentication and role-based access control
- Slack/email notifications for SLA breaches
- Configurable business timezone
- Public holiday calendar
- Configurable SLA policies
- Better concurrency handling around duplicate creation
- Centralized secrets management
- Database migrations
- Automated tests
- Monitoring and alerting
- Backup and restore procedures

---

# Assumptions

The assessment does not specify a business timezone.

This implementation currently treats the SLA business-day cutoff as:

```text
17:00 UTC
```

Public holidays are not considered because they were explicitly excluded from the requirements.

P1 is based on continuous clock hours, while P2–P4 use business days.

---

# License

This project was created as a technical assessment / demonstration project.
