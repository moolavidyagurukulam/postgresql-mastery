# Data Types Part 2: Date/Time & Boolean
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 14, Class 15
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In Part 1 of Data Types, we mastered numbers and text. Today in Part 2, we tackle two types that silently cause more application bugs than almost anything else: Date/Time types and Booleans!. Imagine launching an online flash sale in India where users in London and New York see orders logged 5 hours in the future or missing completely from daily reports!. By the end of this class, you will know DATE, TIME, TIMESTAMP vs TIMESTAMPTZ, how PostgreSQL stores UTC internally, INTERVAL math, AT TIME ZONE, and SQL's tricky three-valued Boolean logic (TRUE, FALSE, NULL). Let us dive in! Timezones and NULL boolean checks cause some of the sneakiest production bugs in software history, yet just three core PostgreSQL rules eliminate them permanently.

### The Problem: Broken Timezones & Tricky Booleans
Here is a classic production disaster that happens to almost every global application. Your database server runs in Virginia using Eastern Time, an API server logs orders in UTC, and a customer checks out from Mumbai. If you save order_time as a plain TIMESTAMP instead of TIMESTAMPTZ, PostgreSQL strips off the timezone! Suddenly reports say a customer bought an item five hours AFTER it shipped!. And on the boolean side, passing string yes or NULL breaks fragile filters unless you understand three-valued logic. Let us master both cleanly today. Notice how subtle timezone bugs are during testing: if your laptop and local database both share the same timezone, everything appears healthy until your first customer signs in from another continent.

- Global App: Server in US-East, API in UTC, User in Mumbai (IST)
- Mistake: Storing orders in TIMESTAMP (drops timezone context!)
- Bug: Orders appear placed 5 hours AFTER delivery in reports
- Solution: Always store real events in TIMESTAMPTZ (UTC under the hood)
- Boolean Trap: TRUE vs FALSE vs NULL (Unknown) breaks WHERE checks
- Today: Master DATE, TIME, TIMESTAMPTZ, INTERVAL & BOOLEAN


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Broken Timezones & Tricky Booleans
Here is a classic production disaster that happens to almost every global application. Your database server runs in Virginia using Eastern Time, an API server logs orders in UTC, and a customer checks out from Mumbai. If you save order_time as a plain TIMESTAMP instead of TIMESTAMPTZ, PostgreSQL strips off the timezone! Suddenly reports say a customer bought an item five hours AFTER it shipped!. And on the boolean side, passing string yes or NULL breaks fragile filters unless you understand three-valued logic. Let us master both cleanly today. Notice how subtle timezone bugs are during testing: if your laptop and local database both share the same timezone, everything appears healthy until your first customer signs in from another continent.

- Global App: Server in US-East, API in UTC, User in Mumbai (IST)
- Mistake: Storing orders in TIMESTAMP (drops timezone context!)
- Bug: Orders appear placed 5 hours AFTER delivery in reports
- Solution: Always store real events in TIMESTAMPTZ (UTC under the hood)
- Boolean Trap: TRUE vs FALSE vs NULL (Unknown) breaks WHERE checks
- Today: Master DATE, TIME, TIMESTAMPTZ, INTERVAL & BOOLEAN

### Date/Time Types Overview
PostgreSQL gives us five core date and time data types, each built for a clear job. DATE holds just calendar day, month, and year—ideal for birthdays or invoice due dates. TIME holds only clock time without a date—useful for store opening hours. TIMESTAMP stores date and time with NO timezone awareness; avoid it for real events. TIMESTAMPTZ stores an exact instant in UTC and converts automatically to your session timezone—this is your gold standard!. Finally, INTERVAL represents a duration, like 3 days or 2 hours 30 minutes, for clean date math. Compare those five types side by side before running queries: DATE and TIME isolate calendar or clock portions cleanly, while TIMESTAMPTZ anchors global timestamps unambiguously to coordinated UTC.

| Term | Meaning / Explanation |
| :--- | :--- |
| **DATE** | Calendar date only (YYYY-MM-DD) — birthdays, holidays, due dates |
| **TIME** | Time of day only (HH:MM:SS) — daily store opening/closing hours |
| **TIMESTAMP** | Date + time WITHOUT timezone — avoid for multi-region events |
| **TIMESTAMPTZ** | Stores UTC & displays in session TZ — USE THIS BY DEFAULT! |
| **INTERVAL** | Span of time ('7 days', '2 hours') for date arithmetic |

### How TIMESTAMPTZ Works Internally (DBA Secret!)
Here is one of the biggest Aha moments in PostgreSQL: how does TIMESTAMPTZ actually work internally?. Many developers assume TIMESTAMP WITH TIME ZONE takes extra bytes to store '+05:30' next to every row. It does NOT! Both TIMESTAMP and TIMESTAMPTZ take exactly 8 bytes!. When you insert into TIMESTAMPTZ, PostgreSQL uses your session TimeZone setting to convert the moment into universal UTC and stores that exact global instant. When a colleague in London runs SELECT, PostgreSQL converts that same UTC instant to London local time!. That guarantees two servers across Mumbai and Frankfurt always agree on WHICH event happened first! Only use plain TIMESTAMP for timezone-agnostic local wall-clock rules like 'every store opens at 9:00 AM local time'.

> **Definition:** Contrary to its name, TIMESTAMPTZ does NOT save the timezone name inside the row!

| Term | Meaning / Explanation |
| :--- | :--- |
| **8-Byte Storage** | Converts input using session TimeZone and saves microseconds since 2000-01-01 UTC |
| **Read Behavior** | On SELECT, converts UTC back into the viewer's current session TimeZone |
| **When to Use** | Orders, logins, payments, logs — 99% of real business timestamps! |
| **Plain TIMESTAMP** | Only for wall-clock schedules ('9 AM store open anywhere') without UTC conversion |

### Boolean Three-Valued Logic (TRUE, FALSE, NULL Trap!)
Before wrapping up Booleans, memorize this table, it prevents silent bugs in customer filters everywhere!. Remember a PostgreSQL BOOLEAN column has THREE possible states: TRUE, FALSE, and NULL (unknown). Suppose you want every user who is NOT active, including legacy imported rows where is_active was left NULL. If you write WHERE is_active <> true or WHERE NOT is_active, SQL treats NULL <> true as NULL, NOT TRUE, so those NULL users silently disappear!. Always use IS NOT TRUE, IS FALSE, or IS DISTINCT FROM true whenever a nullable boolean column participates in a negative filter! Bookmark this three-valued truth table carefully! Comparing NULL with standard equals or not-equals ALWAYS yields UNKNOWN, never true — which is why IS NULL and IS NOT TRUE exist in SQL.

| Filter Query | is_active = TRUE | is_active = FALSE | is_active IS NULL |
| :--- | :--- | :--- | :--- |
| WHERE is_active | INCLUDED | Excluded | Excluded |
| WHERE NOT is_active | Excluded | INCLUDED | Excluded |
| WHERE is_active <> true | Excluded | INCLUDED | Excluded (TRAP!) |
| WHERE is_active IS NOT TRUE | Excluded | INCLUDED | INCLUDED (Safe!) |
| WHERE is_active IS DISTINCT FROM true | Excluded | INCLUDED | INCLUDED (Standard!) |


---

## 3. Hands-On Commands & psql Output

### DATE Type — Date Only
**Explanation:** Let us begin with the DATE type, which stores a calendar year, month, and day in just 4 bytes with zero clock time attached. Think of birthdays, public holidays, hire dates, and invoice due dates. Always write date literals using the ISO 8601 format, YYYY dash MM dash DD, such as 2026-12-15. Why is that critical? Because 03/04/2026 means March 4th in the US and April 3rd in India or Europe, causing silent data corruption when teams collaborate globally! Notice also two super handy tricks: CURRENT_DATE fetches today's date immediately, and subtracting one DATE from another returns an exact integer count of days! Checking date subtraction right in SQL also keeps SLA countdowns, age validations, and invoice due-date alerts rock solid without brittle date-library dependencies in every service.

```sql
practice=# CREATE TABLE events (id SERIAL, name VARCHAR(100), event_date DATE);
CREATE TABLE

-- Insert dates (ISO format: YYYY-MM-DD recommended)
practice=# INSERT INTO events (name, event_date) VALUES ('Conference', '2026-12-15');
INSERT 0 1
practice=# INSERT INTO events (name, event_date) VALUES ('Today', CURRENT_DATE);
INSERT 0 1

-- Date arithmetic
practice=# SELECT '2026-12-31'::DATE - '2026-11-03'::DATE AS days_between;
 days_between
--------------
           58

-- Add 30 days to a date
practice=# SELECT '2026-11-03'::DATE + INTERVAL '30 days' AS future_date;
     future_date
---------------------
 2026-12-03 00:00:00
```

### TIMESTAMP vs TIMESTAMPTZ
**Explanation:** Now compare TIMESTAMP versus TIMESTAMPTZ in live psql queries, because this trips up more engineers than almost anything else in PostgreSQL! Plain TIMESTAMP without timezone ignores where on Earth the event happened: if you insert 14:30, PostgreSQL simply stores 14:30 forever, no matter which timezone queries it later. TIMESTAMPTZ, short for timestamp with time zone, converts your input to coordinated UTC on disk, then translates it automatically into each viewer's local session TimeZone on SELECT! When our Asia Kolkata session sees 20:00:00+05:30 and New York switches timezone and reads 09:30:00-05:00, both see the exact same real-world instant cleanly. Seeing 20:00 in Asia Kolkata and 09:30 in America New York prove the exact same instant makes TIMESTAMPTZ click permanently for every developer.

```sql
-- TIMESTAMP: no timezone awareness
practice=# SELECT '2026-11-03 14:30:00'::TIMESTAMP AS no_tz;
        no_tz
---------------------
 2026-11-03 14:30:00

-- TIMESTAMPTZ: timezone-aware (stored as UTC)
practice=# SET timezone = 'Asia/Kolkata';
SET
practice=# SELECT NOW();
              now
-------------------------------
 2026-11-03 20:00:00.123+05:30

-- Same moment, different timezone display
practice=# SET timezone = 'America/New_York';
SET
practice=# SELECT NOW();
              now
-------------------------------
 2026-11-03 09:30:00.123-05:00
-- Same UTC moment, displayed in New York time
```

### AT TIME ZONE — Convert Between Timezones
**Explanation:** Even when you store every order or login safely in TIMESTAMPTZ, reporting dashboards often need to display one fixed instant across multiple regional offices inside the very same SQL query. That is where AT TIME ZONE shines! Start in UTC where NOW reads 14:30 UTC. Simply run NOW AT TIME ZONE 'Asia/Kolkata' to see 20:00 Indian time, or AT TIME ZONE 'Asia/Tokyo' to see 23:30 Japan time! One subtle detail worth remembering: AT TIME ZONE on a TIMESTAMPTZ strips the offset display and returns a plain TIMESTAMP localized to that requested city, ready for charts or PDF invoices.

```sql
practice=# SET timezone = 'UTC';
SET

-- Current time in UTC
practice=# SELECT NOW() AS utc_now;
           utc_now
-------------------------------
 2026-11-03 14:30:00.000+00:00

-- Convert to India time
practice=# SELECT NOW() AT TIME ZONE 'Asia/Kolkata' AS india_time;
      india_time
---------------------
 2026-11-03 20:00:00

-- Convert to Tokyo time
practice=# SELECT NOW() AT TIME ZONE 'Asia/Tokyo' AS tokyo_time;
      tokyo_time
---------------------
 2026-11-03 23:30:00
```

### INTERVAL — Duration of Time
**Explanation:** Now meet INTERVAL, one of PostgreSQL's cleanest superpowers for representing an elapsed span or duration of time like '3 days', '2 hours 30 minutes', or '1 year 6 months'! Instead of converting durations into fragile seconds in application code and breaking on daylight saving changes or 28-day versus 31-day months, PostgreSQL handles calendar math natively! Look how readable your SQL becomes: CURRENT_DATE plus INTERVAL '90 days' calculates a contract deadline cleanly across year boundaries, and subtracting two TIMESTAMPTZ timestamps directly returns an exact human-readable INTERVAL telling you how many days or hours elapsed. You can also combine units cleanly inside one interval literal, such as '1 year 2 months 3 days', making contract renewals and trial extensions readable to anyone maintaining your query.

```sql
-- Interval examples
practice=# SELECT INTERVAL '3 days';
 interval
----------
 3 days

practice=# SELECT INTERVAL '2 hours 30 minutes';
  interval
-----------
 02:30:00

-- Add interval to get future date
practice=# SELECT CURRENT_DATE + INTERVAL '90 days' AS deadline;
       deadline
---------------------
 2027-02-01 00:00:00

-- Subtract timestamps to get interval
practice=# SELECT '2026-12-31'::TIMESTAMP - '2026-11-03'::TIMESTAMP AS duration;
 duration
----------
 58 days
```

### Real Business SQL: Expiry Checks & Monthly Grouping
**Explanation:** Watch how INTERVAL, AGE, and DATE_TRUNC solve three real business tasks in one clean SQL line each! Task one: calculating a 30-day free trial renewal or SLA deadline simply takes CURRENT_DATE plus INTERVAL '30 days'. Task two: building an HR employee tenure report showing exact years, months, and days simply passes end date and start date into AGE, returning '2 years 9 mons 16 days' cleanly! Task three: when finance wants monthly revenue charts, DATE_TRUNC('month', ordered_at) resets every order timestamp in that month down to the first day at midnight so GROUP BY works cleanly without slow substring hacks!

```sql
-- Subscription expiring in 7 days (clean INTERVAL arithmetic)
practice=# SELECT CURRENT_DATE + INTERVAL '30 days' AS renewal_date;
    renewal_date
---------------------
 2026-12-12 00:00:00

-- Human-readable age / tenure between two dates
practice=# SELECT AGE('2026-12-31'::DATE, '2024-03-15'::DATE) AS tenure;
       tenure
---------------------
 2 years 9 mons 16 days

-- Group orders into clean monthly buckets with DATE_TRUNC
practice=# SELECT DATE_TRUNC('month', '2026-11-12 14:30:00+05:30'::TIMESTAMPTZ) AS billing_month;
 2026-11-01 00:00:00+05:30
```

### Useful Date/Time Functions
**Explanation:** Let us put our everyday Date and Time functions side by side right inside psql so you see their exact outputs! First, CURRENT_DATE returns today's calendar date, whereas NOW returns the exact TIMESTAMPTZ when the current transaction began, which guarantees all rows inserted inside one transaction share an identical timestamp. Second, EXTRACT pulls individual numeric components like YEAR 2026 or MONTH 11 (or DOW for day of week from Sunday zero through Saturday six) for analytics filters. Third, DATE_TRUNC rounds any timestamp down cleanly to hour, day, week, or month boundaries for clean SQL aggregation.

```sql
practice=# SELECT CURRENT_DATE AS today, NOW() AS right_now;
   today    |          right_now
------------+------------------------------
 2026-11-03 | 2026-11-03 14:30:00.00+00

-- EXTRACT: pull year, month, day-of-week (0=Sun..6=Sat)
practice=# SELECT EXTRACT(YEAR FROM CURRENT_DATE) AS yr, EXTRACT(MONTH FROM CURRENT_DATE) AS mo;
  yr  | mo
------+----
 2026 | 11

-- DATE_TRUNC: bucket timestamps to month/day/hour
practice=# SELECT DATE_TRUNC('month', NOW()) AS month_start;
      month_start
------------------------
 2026-11-01 00:00:00+00
```

### BOOLEAN Type — TRUE, FALSE, NULL
**Explanation:** The BOOLEAN type stores a simple true-or-false flag in just 1 byte, plus optional NULL for unknown. It is ideal for status flags like is_active, is_verified, in_stock, or email_opt_in. Notice PostgreSQL accepts flexible inputs like true, t, yes, on, or 1 on input, and displays compact t or f in psql tables, though writing explicit keywords TRUE and FALSE keeps your SQL portable and readable. Even cleaner, inside WHERE clauses you never need clunky equals TRUE comparisons: simply write WHERE is_active for active users, or WHERE NOT is_active to filter disabled accounts! Using clear positive column names like is_active, is_verified, and has_paid makes boolean queries read almost like plain English sentences inside every SQL report.

```sql
practice=# CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(100), is_active BOOLEAN DEFAULT true, is_verified BOOLEAN DEFAULT false);
CREATE TABLE

practice=# INSERT INTO users (name, is_active, is_verified) VALUES ('Ravi', true, true), ('Priya', true, false), ('Arjun', false, false);
INSERT 0 3

-- Query with boolean (no need for = TRUE)
practice=# SELECT * FROM users WHERE is_active;
 id | name  | is_active | is_verified
----+-------+-----------+-------------
  1 | Ravi  | t         | t
  2 | Priya | t         | f

-- NOT active
practice=# SELECT * FROM users WHERE NOT is_active;
 id | name  | is_active | is_verified
----+-------+-----------+-------------
  3 | Arjun | f         | f
```

### Boolean Gotchas
**Explanation:** Watch out for two real production boolean traps that catch beginners off guard! First, 'yes' only works inside string literals cast carefully when valid, whereas garbage text like 'maybe' or invalid tokens triggers an immediate invalid input syntax error, and integers cannot implicitly cast without explicit SQL rules. Stick strictly to unquoted TRUE and FALSE. Second and most dangerous is three-valued logic with NULL! Look back at the truth table: WHERE NOT is_active and WHERE is_active not-equal true BOTH silently exclude NULL rows! If you want every user who is either FALSE or NULL, always write WHERE is_active IS NOT TRUE or WHERE is_active IS DISTINCT FROM true.

```sql
-- ERROR: 'yes' is NOT a valid boolean value
practice=# SELECT 'yes'::BOOLEAN;
ERROR:  invalid input syntax for type boolean: "yes"
-- FIX: use TRUE or FALSE
practice=# SELECT TRUE::BOOLEAN;
 bool
------
 t

-- NULL boolean: neither true nor false
practice=# INSERT INTO users (name, is_active) VALUES ('Test', NULL);
INSERT 0 1

-- WHERE is_active does NOT return NULL rows!
practice=# SELECT name, is_active FROM users WHERE is_active IS NULL;
 name | is_active
------+-----------
 Test |
```

### Common Errors
**Explanation:** Here are the three date, time, and boolean errors you are most likely to hit in daily work, along with their instant fixes. Error one: date/time field value out of range, like passing '13/32/2026'. Always standardize inputs to ISO YYYY dash MM dash DD before casting. Error two: invalid input syntax for type boolean when invalid strings sneak into ETL scripts. Standardize flags to true or false, or use NULLIF. Error three: silent timezone drift from choosing plain TIMESTAMP for global events. Always default to TIMESTAMPTZ unless storing a timezone-free schedule like store opening at 9 AM local time.

```sql
-- ERROR: date format wrong
practice=# SELECT '13/32/2026'::DATE;
ERROR:  date/time field value out of range: "13/32/2026"
-- FIX: Use ISO format YYYY-MM-DD

-- ERROR: boolean syntax
practice=# SELECT 'yes'::BOOLEAN;
ERROR:  invalid input syntax for type boolean: "yes"
-- FIX: Use TRUE or FALSE

-- TIP: Always use TIMESTAMPTZ, not TIMESTAMP
-- TIMESTAMP without TZ = timezone bugs waiting to happen
-- TIMESTAMPTZ = stores as UTC, displays in session TZ
```


---

## 5. Common Beginner Traps & How to Fix Them

### Boolean Three-Valued Logic (TRUE, FALSE, NULL Trap!)
Before wrapping up Booleans, memorize this table, it prevents silent bugs in customer filters everywhere!. Remember a PostgreSQL BOOLEAN column has THREE possible states: TRUE, FALSE, and NULL (unknown). Suppose you want every user who is NOT active, including legacy imported rows where is_active was left NULL. If you write WHERE is_active <> true or WHERE NOT is_active, SQL treats NULL <> true as NULL, NOT TRUE, so those NULL users silently disappear!. Always use IS NOT TRUE, IS FALSE, or IS DISTINCT FROM true whenever a nullable boolean column participates in a negative filter! Bookmark this three-valued truth table carefully! Comparing NULL with standard equals or not-equals ALWAYS yields UNKNOWN, never true — which is why IS NULL and IS NOT TRUE exist in SQL.

### Common Errors
Here are the three date, time, and boolean errors you are most likely to hit in daily work, along with their instant fixes. Error one: date/time field value out of range, like passing '13/32/2026'. Always standardize inputs to ISO YYYY dash MM dash DD before casting. Error two: invalid input syntax for type boolean when invalid strings sneak into ETL scripts. Standardize flags to true or false, or use NULLIF. Error three: silent timezone drift from choosing plain TIMESTAMP for global events. Always default to TIMESTAMPTZ unless storing a timezone-free schedule like store opening at 9 AM local time.

```sql
-- ERROR: date format wrong
SELECT '13/32/2026'::DATE;
ERROR:  date/time field value out of range: "13/32/2026"
-- FIX: Use ISO format YYYY-MM-DD

-- ERROR: boolean syntax
SELECT 'yes'::BOOLEAN;
ERROR:  invalid input syntax for type boolean: "yes"
-- FIX: Use TRUE or FALSE

-- TIP: Always use TIMESTAMPTZ, not TIMESTAMP
-- TIMESTAMP without TZ = timezone bugs waiting to happen
-- TIMESTAMPTZ = stores as UTC, displays in session TZ
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time!. Exercise 1. Create a table called bookings with: id SERIAL, guest_name VARCHAR, check_in DATE, check_out DATE, booked_at TIMESTAMPTZ DEFAULT NOW. Insert 2 bookings. Exercise 2. Calculate the number of days between check_in and check_out. Exercise 3. Use EXTRACT to get the month from the check_in dates. Use DATE_TRUNC to truncate to month. Exercise 4. Add a column is_confirmed BOOLEAN DEFAULT false. Update one booking to confirmed. Query only confirmed bookings. Exercise 5. Display the current time in three different timezones using AT TIME ZONE. Spend ten minutes typing all five booking exercises yourself inside psql so AT TIME ZONE, DATE_TRUNC, and boolean filters become completely effortless.

1. Exercise 1: CREATE TABLE bookings (DATE, TIMESTAMPTZ) → INSERT 2
2. Exercise 2: Calculate days between check_in and check_out
3. Exercise 3: EXTRACT(MONTH FROM check_in), DATE_TRUNC('month', ...)
4. Exercise 4: Add is_confirmed BOOLEAN → UPDATE → query WHERE is_confirmed
5. Exercise 5: NOW() AT TIME ZONE for UTC, India, New York


---


### Answer Key — Practice Solutions

```sql
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
```

---

## 7. Key Takeaways & Cheat Sheet

Let us wrap up Class 13 cleanly! Use DATE for calendar days, TIME for clock times without dates, and always prefer TIMESTAMPTZ over plain TIMESTAMP so global user timezones stay rock-solid in UTC under the hood. Use INTERVAL for clean calendar durations like '30 days', pair NOW and CURRENT_DATE with EXTRACT, DATE_TRUNC, AGE, and AT TIME ZONE for reporting, and remember three-valued BOOLEAN logic where IS NOT TRUE handles NULLs safely. Always write dates in ISO format YYYY dash MM dash DD! Next up in Class 14, Arrays and JSONB.

- **DATE (date only), TIME (time only), TIMESTAMP (both)**
- **ALWAYS use TIMESTAMPTZ — not TIMESTAMP — for timezone safety**
- **INTERVAL for durations: '30 days', '2 hours 30 minutes'**
- **Functions: CURRENT_DATE, NOW(), EXTRACT, DATE_TRUNC, AGE**
- **AT TIME ZONE converts between timezones**
- **BOOLEAN: TRUE/FALSE/NULL — WHERE is_active (no = TRUE needed)**
- **Always use ISO format: YYYY-MM-DD**


---

## 8. Downloadable SQL Script Instructions

Every command demonstrated in this video is compiled into the companion `materials.sql` file.

To execute it directly in PostgreSQL:

```bash
# From your command line:
psql -U postgres -d postgres -f materials.sql

# Or from inside psql prompt:
postgres=# \i materials.sql
```
