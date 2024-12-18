-- ====================================================================================
-- Schema for the Indian Railways Database
-- ====================================================================================

-- Assumptions:
-- - Time format follows GMT, ISO8601 format is ensured for date and time values.
-- - No explicit checks for availability of seat in the train (only handled at booking level).

-- Design Assumptions:
-- - Insert and update are to be performed on tables, not on views
-- - Query the views, not tables (for privacy of passengers) unless it must be.
-- ====================================================================================

-- Table to represent the trains in the Indian Railways system
CREATE TABLE IF NOT EXISTS "trains" (
    "train_name" TEXT,                   -- Name of the train (Primary key)
    "station1" TEXT NOT NULL,            -- Starting station
    "station2" TEXT NOT NULL,            -- Ending station
    CHECK("station1" != "station2"),     -- Ensure a train doesn't start and end at the same station
    PRIMARY KEY("train_name"),           -- Primary key based on train name

    -- Foreign key reference to the stations table for both departure and arrival stations
    FOREIGN KEY("station1") REFERENCES "stations"("station_name") ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY("station2") REFERENCES "stations"("station_name") ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Table to represent the train routes between stations
CREATE TABLE IF NOT EXISTS "train_routes" (
    "train_name" TEXT,                  -- Train name (foreign key to trains)
    "station" TEXT,                     -- Station where the train will stop
    PRIMARY KEY("train_name", "station"),-- Composite primary key (train name + station)

    -- Foreign key references to the trains table and stations table
    FOREIGN KEY("train_name") REFERENCES "trains"("train_name") ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY("station") REFERENCES "stations"("station_name") ON UPDATE CASCADE ON DELETE CASCADE
);

-- View to show train stops with active passengers
CREATE VIEW IF NOT EXISTS "train_stops" AS
SELECT "train_routes"."train_name", "station", "expected_departure_time"
FROM "train_routes"
JOIN "passenger_tickets" ON "passenger_tickets"."train_name" = "train_routes"."train_name"
AND "departure_station" = "station";

-- Table for representing passengers (unique ID for each passenger)
CREATE TABLE IF NOT EXISTS "passenger_table" (
    "id" INTEGER,                       -- Unique ID for passenger (like Aadhaar)
    "first_name" TEXT NOT NULL,         -- First name of the passenger
    "last_name" TEXT,                   -- Last name of the passenger (optional)
    "date_of_birth" TEXT NOT NULL,      -- Date of birth (should be in ISO8601 format)
    "email" TEXT,                       -- Email address (optional)
    "phone_number" CHAR(10) NOT NULL    -- 10-digit phone number

    CHECK("phone_number" REGEXP '^[6-9][0-9]{9}$'),
    CHECK(strftime('%Y-%m-%d', "date_of_birth") = "date_of_birth"), -- Enforces ISO8601 date format
    PRIMARY KEY("id")                   -- Primary key for passenger ID
);

-- View to show active passengers (those with tickets)
CREATE VIEW IF NOT EXISTS "passengers" AS
SELECT "id", "first_name", "last_name", "date_of_birth", "email",
       '******' || SUBSTR("phone_number", -4) AS "phone_number" -- Shows only last 4-digits of the phone number
FROM "passenger_table"
WHERE "passenger_table"."id" IN (
    SELECT "passenger_id"
    FROM "passenger_tickets"
);

-- Table to represent tickets booked by passengers
CREATE TABLE IF NOT EXISTS "tickets" (
    "id" INTEGER,                      -- Unique ticket ID
    "train_name" TEXT,                  -- Name of the train
    "passenger_id" INTEGER,             -- Passenger ID (foreign key)
    "departure_station" TEXT,           -- Station of departure
    "arrival_station" TEXT,             -- Station of arrival
    "expected_departure_time" TEXT NOT NULL, -- Departure time in ISO8601 format
    "expected_arrival_time" TEXT DEFAULT NULL, -- Arrival time in ISO8601 format (nullable)
    "coach_code" VARCHAR(2) NOT NULL,   -- Coach code
    "seat" INTEGER NOT NULL,            -- Seat number
    "fare" DECIMAL(10, 2) NOT NULL CHECK("fare" > 0), -- Ticket fare (must be positive)

    -- Ensures ISO8601 format and valid time logic
    CHECK(strftime('%Y-%m-%d %H:%M:%S', "expected_departure_time") = "expected_departure_time"),
    CHECK("expected_arrival_time" IS NULL
          OR strftime('%Y-%m-%d %H:%M:%S', "expected_arrival_time") = "expected_arrival_time"
          AND "expected_arrival_time" > "expected_departure_time"),
    PRIMARY KEY("id"),                  -- Primary key for ticket ID

    -- Foreign keys linking the ticket to the passenger, train routes, and coach
    FOREIGN KEY("passenger_id") REFERENCES "passenger_table"("id") ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY("train_name", "departure_station") REFERENCES "train_routes"("train_name", "station")
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY("train_name", "arrival_station") REFERENCES "train_routes"("train_name", "station")
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY("coach_code") REFERENCES "coaches"("code") ON UPDATE CASCADE ON DELETE RESTRICT
);

-- View to represent active passenger tickets
CREATE VIEW IF NOT EXISTS "passenger_tickets" AS
SELECT "tickets"."id", "passenger_id",
       "first_name" || ' ' || COALESCE("last_name", '') AS "name",
       '******' || SUBSTR("phone_number", -4) AS "phone_number",
       "train_name", "departure_station", "arrival_station",
       "expected_departure_time", COALESCE("expected_arrival_time", '') AS "expected_arrival_time",
       "coach_code" AS "coach", "seat", "fare"
FROM "tickets"
JOIN "passenger_table" ON "tickets"."passenger_id" = "passenger_table"."id"
WHERE DATETIME("now", "5 hours", "30 minutes") < "expected_departure_time"
OR "expected_arrival_time" IS NULL
OR DATETIME("now", "5 hours", "30 minutes") < "expected_arrival_time";

-- Table to represent stations in the Indian Railways
CREATE TABLE IF NOT EXISTS "stations" (
    "station_name" TEXT,                -- Unique station name
    PRIMARY KEY("station_name")         -- Primary key for station name
);

-- Table to represent available coaches (codes for each coach)
CREATE TABLE IF NOT EXISTS "coaches" (
    "code" VARCHAR(2),                  -- Unique coach code
    PRIMARY KEY("code")                 -- Primary key for coach code
);

-- Trigger to validate passenger's date of birth (age should be between 3 and 130)
CREATE TRIGGER IF NOT EXISTS "passenger_insert"
BEFORE INSERT ON "passenger_table"
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, "Invalid date of birth")
    WHERE NEW."date_of_birth" > DATE("now", "-3 years")
    OR "date_of_birth" < DATE("now", "-130 years");
END;

-- Trigger to validate passenger's date of birth during update
CREATE TRIGGER IF NOT EXISTS "passenger_update"
BEFORE UPDATE ON "passenger_table"
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, "Invalid date of birth")
    WHERE NEW."date_of_birth" > DATE("now", "-3 years")
    OR "date_of_birth" < DATE("now", "-130 years");
END;

-- Trigger to check the validity of email format (basic pattern matching)
CREATE TRIGGER IF NOT EXISTS "passenger_email_check_insert"
AFTER INSERT ON "passenger_table"
WHEN NEW."email" NOT LIKE "__%@__%.__%" -- Basic email validation pattern
BEGIN
    UPDATE "passenger_table"
    SET "email" = NULL
    WHERE "id" = NEW."id";
END;

-- Trigger to check the validity of email format (basic pattern matching) during update
CREATE TRIGGER IF NOT EXISTS "passenger_email_check_update"
AFTER UPDATE ON "passenger_table"
WHEN NEW."email" NOT LIKE "__%@__%.__%" -- Basic email validation pattern
BEGIN
    UPDATE "passenger_table"
    SET "email" = NULL
    WHERE "id" = NEW."id";
END;

-- Trigger to check seat availability during ticket insert (overlapping time check)
CREATE TRIGGER IF NOT EXISTS "seat_allocation_check_insert"
BEFORE INSERT ON "tickets"
FOR EACH ROW
BEGIN
    -- Ensure no seat overlap during specified time period
    SELECT RAISE(ABORT, "Seat already booked during the specified time period")
    WHERE EXISTS (
        SELECT 1
        FROM "tickets"
        WHERE "tickets"."train_name" = NEW."train_name"
          AND "tickets"."coach_code" = NEW."coach_code"
          AND "tickets"."seat" = NEW."seat"
          AND (NEW."expected_departure_time" != "tickets"."expected_arrival_time")
          AND (NEW."expected_arrival_time" != "tickets"."expected_departure_time")
          AND ( -- overlapping time periods
              (NEW."expected_departure_time" BETWEEN "tickets"."expected_departure_time" AND "tickets"."expected_arrival_time")
              OR -- overlapping time (e.g., OLD: 11 AM to 2 PM, NEW: 9 AM to 1 PM)
              (NEW."expected_arrival_time" BETWEEN "tickets"."expected_departure_time" AND "tickets"."expected_arrival_time")
              OR -- overlapping time (e.g., OLD: 2 PM to 3 PM, NEW: 9 AM to 5 PM)
              ("tickets"."expected_departure_time" BETWEEN NEW."expected_departure_time" AND NEW."expected_arrival_time")
          )
    );
END;

-- Trigger to check seat availability during ticket update (overlapping time check)
CREATE TRIGGER IF NOT EXISTS "seat_allocation_check_update"
BEFORE UPDATE ON "tickets"
FOR EACH ROW
BEGIN
    -- Ensure no seat overlap during specified time period when updating a ticket
    SELECT RAISE(ABORT, "Seat already booked during the specified time period")
    WHERE EXISTS (
        SELECT 1
        FROM "tickets"
        WHERE "tickets"."train_name" = NEW."train_name"
          AND "tickets"."coach_code" = NEW."coach_code"
          AND "tickets"."seat" = NEW."seat"
          AND (NEW."expected_departure_time" != "tickets"."expected_arrival_time")
          AND (NEW."expected_arrival_time" != "tickets"."expected_departure_time")
          AND (
                 NEW."expected_departure_time" BETWEEN "tickets"."expected_departure_time" AND "tickets"."expected_arrival_time"
              OR NEW."expected_arrival_time" BETWEEN "tickets"."expected_departure_time" AND "tickets"."expected_arrival_time"
              OR "tickets"."expected_departure_time" BETWEEN NEW."expected_departure_time" AND NEW."expected_arrival_time"
          )
    );
END;

-- Trigger to delete old tickets and remove passengers without active tickets when a new ticket is inserted
CREATE TRIGGER IF NOT EXISTS "clear_old_tickets_insert"
AFTER INSERT ON "tickets"
FOR EACH ROW
BEGIN
    -- Delete tickets that are past their departure time and have arrived (based on current time)
    DELETE FROM "tickets"
    WHERE DATETIME("now", "5 hours", "30 minutes") > "expected_departure_time"
    AND "expected_arrival_time" IS NOT NULL
    AND DATETIME("now", "5 hours", "30 minutes") > "expected_arrival_time";
END;

-- Trigger to delete old tickets and remove passengers without active tickets when a ticket is updated
CREATE TRIGGER IF NOT EXISTS "clear_old_tickets_update"
AFTER UPDATE ON "tickets"
FOR EACH ROW
BEGIN
    -- Delete tickets that are past their departure time and have arrived (based on current time)
    DELETE FROM "tickets"
    WHERE DATETIME("now", "5 hours", "30 minutes") > "expected_departure_time"
    AND "expected_arrival_time" IS NOT NULL
    AND DATETIME("now", "5 hours", "30 minutes") > "expected_arrival_time";
END;

-- Indexes for faster retrieval and improved performance on common queries

-- Index on email to quickly search passengers by email address
CREATE INDEX IF NOT EXISTS "email_index"
ON "passenger_table" ("email");

-- Index on passenger_id to quickly find tickets by passenger
CREATE INDEX IF NOT EXISTS "passenger_id_index"
ON "tickets" ("passenger_id");

-- Index on train, coach, and seat to quickly check for seat availability
CREATE INDEX IF NOT EXISTS "train_coach_seat_index"
ON "tickets" ("train_name", "coach_code", "seat");

-- Index on tickets for fast retrieval based on stations of departure and arrival
CREATE INDEX IF NOT EXISTS "tickets_station_index"
ON "tickets"("train_name", "departure_station", "arrival_station");

-- Index on tickets for faster retrieval based on expected departure and arrival times
CREATE INDEX IF NOT EXISTS "tickets_time_index"
ON "tickets"("train_name", "expected_departure_time", "expected_arrival_time");
