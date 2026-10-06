CREATE TABLE service_requests (
    id BIGSERIAL PRIMARY KEY,

    request_id VARCHAR(30) NOT NULL UNIQUE,

    requester_name VARCHAR(150) NOT NULL,
    requester_email VARCHAR(255) NOT NULL,

    department VARCHAR(50) NOT NULL,

    title TEXT NOT NULL,
    normalized_title TEXT NOT NULL,

    description TEXT NOT NULL,

    declared_priority VARCHAR(2) NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'Open',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    due_at TIMESTAMPTZ NOT NULL,

    resolved_at TIMESTAMPTZ,

    assigned_to VARCHAR(255),

    escalated_at TIMESTAMPTZ,

    CONSTRAINT valid_priority
        CHECK (declared_priority IN ('P1', 'P2', 'P3', 'P4')),

    CONSTRAINT valid_status
        CHECK (
            status IN (
                'Open',
                'In Progress',
                'Completed',
                'Resolved',
                'Cancelled'
            )
        ),

    CONSTRAINT unique_requester_title
        UNIQUE (requester_email, normalized_title)
);


CREATE TABLE request_events (
    id BIGSERIAL PRIMARY KEY,

    request_id VARCHAR(30) NOT NULL,

    event_type VARCHAR(50) NOT NULL,

    old_status VARCHAR(30),

    new_status VARCHAR(30),

    metadata JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_request
        FOREIGN KEY (request_id)
        REFERENCES service_requests(request_id)
        ON DELETE CASCADE
);


CREATE INDEX idx_service_requests_status
    ON service_requests(status);

CREATE INDEX idx_service_requests_department
    ON service_requests(department);

CREATE INDEX idx_service_requests_due_at
    ON service_requests(due_at);

CREATE INDEX idx_service_requests_created_at
    ON service_requests(created_at);

CREATE INDEX idx_request_events_request_id
    ON request_events(request_id);
