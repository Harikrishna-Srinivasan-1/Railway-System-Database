-- Date of creation is on 2024-12-18 12:00:00.
-- Disclaimer: Output will vary as time goes.
-- Data given here doesn't align with real-time data.

-- Inserting into "stations"
-- These are the stations served by the trains
INSERT INTO "stations" ("station_name") VALUES
('New Delhi'),
('Mumbai'),
('Chennai'),
('Bangalore'),
('Kolkata');

-- Inserting standard coach type
-- Refer to: 'https://en.wikipedia.org/wiki/Express_trains_in_India#cite_note-Class2-56'
-- These are the coach types available for booking in the trains
INSERT INTO "coaches"
VALUES
('A'), ('B'), ('C'), ('D'), ('E'), ('EA'), ('EV'), ('F'), ('GS'), ('H'), ('J'), ('M'), ('S'), ('UR');

-- Inserting into "trains"
-- These are the trains that operate between specific stations
INSERT INTO "trains" ("train_name", "station1", "station2") VALUES
('Rajdhani Express', 'New Delhi', 'Mumbai'),
('Shatabdi Express', 'Kolkata', 'Chennai'),
('Duronto Express', 'Mumbai', 'Chennai'),
('Vande Bharat', 'New Delhi', 'Chennai');

-- Inserting into "train_routes"
-- These are the train routes that map the train to the stations it passes through
INSERT INTO "train_routes" ("train_name", "station") VALUES
('Rajdhani Express', 'New Delhi'),
('Rajdhani Express', 'Mumbai'),
('Shatabdi Express', 'Kolkata'),
('Shatabdi Express', 'Chennai'),
('Duronto Express', 'Mumbai'),
('Duronto Express', 'Bangalore'),
('Duronto Express', 'Chennai'),
('Vande Bharat', 'New Delhi'),
('Vande Bharat', 'Chennai');

-- Inserting into "passenger_table"
-- These are the passengers who are booked in the system, including details like email and phone number
INSERT INTO "passenger_table" ("id", "first_name", "last_name", "date_of_birth", "email", "phone_number") VALUES
(1, 'Rajesh', 'Kumar', '1990-01-01', 'rajesh.kumar@gmail.com', '9876543210'),
(2, 'Anita', 'Sharma', '1985-07-15', 'anita.sharma@yahoo.com', '9876543211'),
(3, 'Ravi', 'Verma', '1998-05-20', 'ravi.verma@gmail.com', '9876543212'),
(4, 'Neha', 'Gupta', '2000-03-25', 'neha.gupta@harvard.edu', '9876543213');

-- Inserting into "tickets"
-- These are the ticket bookings made for passengers, including departure and arrival times, seats, and fares
INSERT INTO "tickets" ("train_name", "passenger_id", "departure_station", "arrival_station", "expected_departure_time", "expected_arrival_time", "coach_code", "seat", "fare") VALUES
('Rajdhani Express', 1, 'New Delhi', 'Mumbai', '2024-12-17 17:15:00', '2024-12-18 12:30:00', 'A', 12, 1500.00),
('Shatabdi Express', 2, 'Kolkata', 'Chennai', '2024-12-18 15:00:00', '2024-12-19 17:14:00', 'C', 10, 1400.00),
('Duronto Express', 3, 'Mumbai', 'Chennai', '2024-12-18 01:45:00', '2024-12-18 23:00:00', 'D', 15, 1100.00),
('Vande Bharat', 4, 'New Delhi', 'Chennai', '2024-12-17 05:20:00', '2024-12-18 15:55:00', 'B', 8, 2600.00);

-- Inserting an invalid email format (will be set to NULL by the email validation trigger)
-- The email provided does not follow a valid format, so it will be set to NULL
INSERT INTO "passenger_table" ("id", "first_name", "last_name", "date_of_birth", "email", "phone_number") VALUES
(5, 'John', 'Doe', '1987-08-14', 'invalid-email', '9876543214');

-- Trying to insert a passenger with a date of birth that is too recent (less than 3 years old)
-- Should fail because the date of birth is after 2021-12-18 (too young)
INSERT INTO "passenger_table" ("id", "first_name", "last_name", "date_of_birth", "email", "phone_number") VALUES
(6, 'Geetha', NULL, '2022-12-19', '', '9876543215');

-- Trying to book the same seat twice on the same train, which will fail due to overlapping times
-- The seat 15 in coach 'D' of 'Duronto Express' is already booked for another time slot
INSERT INTO "tickets" ("train_name", "passenger_id", "departure_station", "arrival_station", "expected_departure_time", "expected_arrival_time", "coach_code", "seat", "fare") VALUES
('Duronto Express', 2, 'Bangalore', 'Chennai', '2024-12-18 17:35:00', '2024-12-18 23:00:00', 'D', 15, 950.00);

-- Inserting an expired ticket, which should be automatically deleted after insertion due to the trigger
-- This ticket has a departure time in the past, so it will not be valid and should be cleared automatically
INSERT INTO "tickets" ("train_name", "passenger_id", "departure_station", "arrival_station", "expected_departure_time", "expected_arrival_time", "coach_code", "seat", "fare") VALUES
('Rajdhani Express', 3, 'New Delhi', 'Mumbai', '2023-11-01 01:10:00', '2023-11-01 18:32:00', 'A', 5, 1500.00);

-- Query to find stations that 'Vande Bharat' travels through
-- This will list all stations associated with 'Vande Bharat' train
SELECT "Station" FROM "train_routes"
WHERE "train_name" = 'Vande Bharat';

-- Find all passengers who have pending journey (i.e., they have booked a valid ticket for future travel)
SELECT * FROM "passengers";

-- Find all valid tickets (i.e., tickets where the expected departure time is in the future)
SELECT * FROM "passenger_tickets";

-- Query to find stations and their respective departure times for 'Duronto Express' train
-- This will list stations where 'Duronto Express' stops, along with the departure times
SELECT "Station", "expected_departure_time" AS "Expected Departure Time" FROM "train_stops"
WHERE "train_name" = 'Duronto Express';

-- Changing train name from 'Shatabdi Express' to 'Jana Shatabdi'
-- This is useful if a train's name needs to be updated
UPDATE "trains"
SET "train_name" = 'Jana Shatabdi'
WHERE "train_name" = 'Shatabdi Express';

-- Query to see changes in tickets as a result of the train name update
SELECT * FROM "tickets"
WHERE "train_name" = 'Jana Shatabdi';

-- Trying to change the passenger seat with passenger id = 3 in 'Duronto Express'
-- This change will only succeed if there is no conflicting booking for the same seat and time
UPDATE "tickets"
SET "seat" = 14
WHERE "passenger_id" = 3
AND "train_name" = 'Duronto Express'
AND "expected_departure_time" = '2024-12-18 01:45:00';

-- See changes reflected in both tickets table and the passenger_tickets view
SELECT * FROM "tickets"
WHERE "passenger_id" = 3
AND "train_name" = 'Duronto Express'
AND "expected_departure_time" = '2024-12-18 01:45:00';

SELECT * FROM "passenger_tickets"
WHERE "passenger_id" = 3
AND "train_name" = 'Duronto Express'
AND "expected_departure_time" = '2024-12-18 01:45:00';
