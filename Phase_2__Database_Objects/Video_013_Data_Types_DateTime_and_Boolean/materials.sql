-- =============================================
-- PostgreSQL Mastery: Data Types Part 2 — Date/Time & Boolean
-- Phase 2: Database Objects | Classes 14-15
-- =============================================
-- DATE, TIME, TIMESTAMP, TIMESTAMPTZ, INTERVAL, BOOLEAN
-- =============================================

-- === DATE/TIME TYPES ===

-- DATE          = date only (4 bytes)       → 2026-11-03
-- TIME          = time only (8 bytes)       → 14:30:00
-- TIMESTAMP     = date+time, NO timezone    → 2026-11-03 14:30:00
-- TIMESTAMPTZ   = date+time WITH timezone   → 2026-11-03 14:30:00+05:30
-- INTERVAL      = duration (16 bytes)       → 3 days 2 hours

-- RULE: ALWAYS use TIMESTAMPTZ, not TIMESTAMP!
-- TIMESTAMPTZ stores as UTC, displays in session timezone.

-- === DATE ===

CREATE TABLE events (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100),
    event_date DATE
);

-- Always use ISO format: YYYY-MM-DD
INSERT INTO events (name, event_date) VALUES ('Conference', '2026-12-15');
INSERT INTO events (name, event_date) VALUES ('Today', CURRENT_DATE);

-- Date arithmetic
SELECT '2026-12-31'::DATE - '2026-11-03'::DATE AS days_between;  -- 58

-- Add interval to date
SELECT '2026-11-03'::DATE + INTERVAL '30 days' AS future_date;
SELECT '2026-11-03'::DATE + INTERVAL '3 months' AS three_months_later;

-- === TIMESTAMP vs TIMESTAMPTZ ===

-- TIMESTAMP: no timezone awareness (AVOID for real apps)
SELECT '2026-11-03 14:30:00'::TIMESTAMP AS no_tz;

-- TIMESTAMPTZ: timezone-aware (ALWAYS use this!)
SELECT NOW();  -- shows time in your session timezone

-- Change session timezone
SET timezone = 'Asia/Kolkata';
SELECT NOW();  -- shows IST (+05:30)

SET timezone = 'America/New_York';
SELECT NOW();  -- shows EST (-05:00), same UTC moment

-- AT TIME ZONE: convert between timezones
SET timezone = 'UTC';
SELECT NOW() AT TIME ZONE 'Asia/Kolkata' AS india_time;
SELECT NOW() AT TIME ZONE 'Asia/Tokyo' AS tokyo_time;
SELECT NOW() AT TIME ZONE 'America/New_York' AS ny_time;

-- === INTERVAL ===

SELECT INTERVAL '3 days';
SELECT INTERVAL '2 hours 30 minutes';
SELECT INTERVAL '1 year 6 months';

-- Add/subtract intervals
SELECT CURRENT_DATE + INTERVAL '90 days' AS deadline;
SELECT NOW() - INTERVAL '7 days' AS one_week_ago;

-- Subtract timestamps to get interval
SELECT '2026-12-31'::TIMESTAMP - '2026-11-03'::TIMESTAMP AS duration;

-- === USEFUL DATE/TIME FUNCTIONS ===

-- Current date/time
SELECT CURRENT_DATE;         -- today's date
SELECT CURRENT_TIME;         -- current time
SELECT CURRENT_TIMESTAMP;    -- current date+time+tz (same as NOW())
SELECT NOW();                -- current date+time+tz

-- EXTRACT: pull parts from a date
SELECT EXTRACT(YEAR FROM CURRENT_DATE) AS yr;
SELECT EXTRACT(MONTH FROM CURRENT_DATE) AS mo;
SELECT EXTRACT(DAY FROM CURRENT_DATE) AS dy;
SELECT EXTRACT(DOW FROM CURRENT_DATE) AS day_of_week;  -- 0=Sun, 6=Sat
SELECT EXTRACT(HOUR FROM NOW()) AS hr;

-- DATE_TRUNC: truncate to precision
SELECT DATE_TRUNC('month', NOW()) AS month_start;
SELECT DATE_TRUNC('year', NOW()) AS year_start;
SELECT DATE_TRUNC('hour', NOW()) AS hour_start;

-- AGE: human-readable difference
SELECT AGE('2026-11-03'::DATE, '1995-06-15'::DATE);
-- Result: 31 years 4 mons 18 days

-- TO_CHAR: format dates as strings
SELECT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS') AS formatted;
SELECT TO_CHAR(NOW(), 'Day, DD Mon YYYY') AS human_readable;

-- === BOOLEAN ===

-- Values: TRUE, FALSE, NULL
-- TRUE can be: TRUE, 't', 'true', 'y', 'yes', 'on', '1'
-- FALSE can be: FALSE, 'f', 'false', 'n', 'no', 'off', '0'
-- Recommended: always use TRUE and FALSE

CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100),
    is_active   BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false
);

INSERT INTO users (name, is_active, is_verified)
VALUES ('Ravi', true, true),
       ('Priya', true, false),
       ('Arjun', false, false);

-- Query booleans (no need for = TRUE)
SELECT * FROM users WHERE is_active;          -- active users
SELECT * FROM users WHERE NOT is_active;      -- inactive users
SELECT * FROM users WHERE is_active AND is_verified;  -- active AND verified

-- Boolean with NULL
INSERT INTO users (name, is_active) VALUES ('Test', NULL);
SELECT * FROM users WHERE is_active IS NULL;

-- === COMMON ERRORS ===

-- ERROR: date/time field value out of range: "13/32/2026"
-- FIX: Use ISO format YYYY-MM-DD

-- ERROR: invalid input syntax for type boolean: "yes"
-- FIX: Use TRUE or FALSE, not string 'yes'

-- TIP: TIMESTAMP without TZ = timezone bugs
-- ALWAYS use TIMESTAMPTZ for real applications

-- === PRACTICE EXERCISES ===

-- Exercise 1:
CREATE TABLE bookings (
    id         SERIAL PRIMARY KEY,
    guest_name VARCHAR(100),
    check_in   DATE,
    check_out  DATE,
    booked_at  TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO bookings (guest_name, check_in, check_out)
VALUES ('Ravi', '2026-12-20', '2026-12-25');
INSERT INTO bookings (guest_name, check_in, check_out)
VALUES ('Priya', '2027-01-10', '2027-01-15');

-- Exercise 2: Days between check_in and check_out
SELECT guest_name, check_out - check_in AS nights FROM bookings;

-- Exercise 3: EXTRACT and DATE_TRUNC
SELECT guest_name, EXTRACT(MONTH FROM check_in) AS check_in_month FROM bookings;
SELECT DATE_TRUNC('month', check_in) AS month_start FROM bookings;

-- Exercise 4: Boolean column
ALTER TABLE bookings ADD COLUMN is_confirmed BOOLEAN DEFAULT false;
UPDATE bookings SET is_confirmed = true WHERE guest_name = 'Ravi';
SELECT * FROM bookings WHERE is_confirmed;

-- Exercise 5: Time in different timezones
SELECT NOW() AT TIME ZONE 'UTC' AS utc,
       NOW() AT TIME ZONE 'Asia/Kolkata' AS india,
       NOW() AT TIME ZONE 'America/New_York' AS new_york;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS events, users, bookings;

-- =============================================
-- Next Class: Data Types — Arrays & JSON
-- =============================================

-- === ANSWER KEY ===
-- 1. Create bookings table with TIMESTAMPTZ DEFAULT NOW()
CREATE TABLE bookings (id SERIAL, guest_name VARCHAR(80), check_in DATE, check_out DATE, booked_at TIMESTAMPTZ DEFAULT NOW());

-- 2. Nights between check_in and check_out
SELECT guest_name, check_out - check_in AS nights FROM bookings;

-- 3. EXTRACT month & DATE_TRUNC to month
SELECT EXTRACT(MONTH FROM check_in) AS m, DATE_TRUNC('month', check_in) AS month_start FROM bookings;

-- 4. Add is_confirmed BOOLEAN & filter cleanly
ALTER TABLE bookings ADD COLUMN is_confirmed BOOLEAN DEFAULT false;
UPDATE bookings SET is_confirmed = true WHERE id = 1;
SELECT * FROM bookings WHERE is_confirmed;

-- 5. Compare current time across 3 timezones
SELECT NOW() AT TIME ZONE 'UTC' AS utc, NOW() AT TIME ZONE 'Asia/Kolkata' AS ist, NOW() AT TIME ZONE 'America/New_York' AS est;
