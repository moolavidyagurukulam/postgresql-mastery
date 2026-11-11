# Data Types Part 2: Date/Time & Boolean
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 14, Class 15
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In our last class, we covered numeric and text data types. Today we tackle two more essential categories ... date and time types, and the boolean type. ... Almost every application deals with dates ... when was the order placed? When does the subscription expire? How long did the task take? ... And boolean is everywhere too ... is the user active? Is the item in stock? ... Let us learn these types inside out!


---

## 2. Core Technical Concepts & Mechanisms

### Date/Time Types Overview
PostgreSQL has five date and time types. ... DATE stores just the date. Year, month, day. No time. ... TIME stores just the time. Hours, minutes, seconds. No date. ... TIMESTAMP stores both date and time together, without timezone information. ... TIMESTAMPTZ, short for TIMESTAMP WITH TIME ZONE, stores date and time AND converts to UTC for storage. This is the MOST IMPORTANT one ... always use TIMESTAMPTZ for real applications. ... INTERVAL stores a duration of time. 3 days, 2 hours, 30 minutes. Very useful for date arithmetic.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL** | five date and time types |
| **DATE** | just the date |
| **TIME** | just the time |
| **TIMESTAMP** | both date and time together, without timezone information |
| **This** | the MOST IMPORTANT one |
| **INTERVAL** | a duration of time |


---

## 3. Hands-On Commands & psql Output

### DATE Type — Date Only
**Explanation:** Let me demonstrate the DATE type first. ... You can insert dates in several formats. The ISO format year dash month dash day is the safest and recommended. ... PostgreSQL also gives you useful functions. CURRENT_DATE returns today's date. You can subtract dates to get the number of days between them. You can add intervals to dates.

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
**Explanation:** Now TIMESTAMP and TIMESTAMPTZ. ... TIMESTAMP stores date and time without any timezone awareness. Whatever you insert is stored as-is. ... TIMESTAMPTZ is timezone-aware. PostgreSQL converts the value to UTC for storage, and converts it back to your session timezone when you query it. ... This is critical. If your users are in different timezones, TIMESTAMPTZ handles it correctly. TIMESTAMP does not. ... Always prefer TIMESTAMPTZ for real applications. Use plain TIMESTAMP only when timezone does not matter, like for log entries on a single-timezone system.

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
**Explanation:** The AT TIME ZONE expression lets you convert between timezones. ... SELECT NOW AT TIME ZONE UTC shows the current time in UTC. ... SELECT a timestamp AT TIME ZONE Asia slash Kolkata converts it to Indian Standard Time. ... This is extremely useful when you need to display times in different timezones for users around the world.

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
**Explanation:** INTERVAL is a very useful type. It represents a duration ... a span of time. ... You can write intervals in natural language. INTERVAL 3 days. INTERVAL 2 hours 30 minutes. INTERVAL 1 year 6 months. ... Intervals are great for date arithmetic. Add an interval to a timestamp to get a future date. Subtract to get a past date. ... You can also subtract two timestamps to get an interval automatically.

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

### Useful Date/Time Functions
**Explanation:** PostgreSQL has many useful date and time functions. ... CURRENT_DATE gives today's date. NOW or CURRENT_TIMESTAMP gives the current date and time with timezone. ... EXTRACT pulls a specific part from a date ... year, month, day, hour, minute. ... DATE_TRUNC truncates a timestamp to a specific precision ... useful for grouping by month or year. ... AGE calculates the difference between two dates in a human-readable format.

```sql
practice=# SELECT CURRENT_DATE AS today, NOW() AS right_now;
    today    |           right_now
------------+-------------------------------
 2026-11-03 | 2026-11-03 14:30:00.000+00:00

-- EXTRACT: pull parts from a date
practice=# SELECT EXTRACT(YEAR FROM CURRENT_DATE) AS yr, EXTRACT(MONTH FROM CURRENT_DATE) AS mo, EXTRACT(DOW FROM CURRENT_DATE) AS day_of_week;
  yr  | mo | day_of_week
------+----+-------------
 2026 | 11 |           2

-- DATE_TRUNC: truncate to month/year
practice=# SELECT DATE_TRUNC('month', NOW()) AS month_start;
       month_start
------------------------
 2026-11-01 00:00:00+00

-- AGE: human-readable difference
practice=# SELECT AGE('2026-11-03'::DATE, '1995-06-15'::DATE) AS age;
          age
------------------------
 31 years 4 mons 18 days
```

### BOOLEAN Type — TRUE, FALSE, NULL
**Explanation:** The BOOLEAN type is simple but powerful. It stores one of three values: TRUE, FALSE, or NULL. ... TRUE can be written as TRUE, t, yes, y, on, or 1. FALSE can be written as FALSE, f, no, n, off, or 0. ... But the recommended way is to use TRUE and FALSE keywords. ... Boolean columns are perfect for flags. is_active, is_verified, in_stock, is_published. ... In WHERE clauses, you do not need to write WHERE is_active equals TRUE. Just write WHERE is_active. PostgreSQL understands it.

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
**Explanation:** A common mistake with boolean. ... Some beginners try to insert the string yes into a boolean column. This gives an error: invalid input syntax for type boolean. Use TRUE or FALSE, not yes or no as strings. ... Another gotcha ... boolean can be NULL. A NULL boolean is neither true nor false. It is unknown. WHERE is_active will not return NULL rows. If you need to include them, use WHERE is_active IS NOT FALSE or WHERE is_active IS NULL.

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
**Explanation:** Common date, time, and boolean errors. ... Error 1: date field value out of range. You used a wrong date format like month slash day slash year. Always use ISO format: year dash month dash day. ... Error 2: invalid input syntax for type boolean. You tried yes or 1 as a string. Use TRUE or FALSE. ... Error 3: timezone confusion. If you store timestamps without timezone and your server changes timezone, all your times are wrong. Always use TIMESTAMPTZ.

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

### Common Errors
Common date, time, and boolean errors. ... Error 1: date field value out of range. You used a wrong date format like month slash day slash year. Always use ISO format: year dash month dash day. ... Error 2: invalid input syntax for type boolean. You tried yes or 1 as a string. Use TRUE or FALSE. ... Error 3: timezone confusion. If you store timestamps without timezone and your server changes timezone, all your times are wrong. Always use TIMESTAMPTZ.

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

Practice time! ... Exercise 1 ... Create a table called bookings with: id SERIAL, guest_name VARCHAR, check_in DATE, check_out DATE, booked_at TIMESTAMPTZ DEFAULT NOW. Insert 2 bookings. ... Exercise 2 ... Calculate the number of days between check_in and check_out. ... Exercise 3 ... Use EXTRACT to get the month from the check_in dates. Use DATE_TRUNC to truncate to month. ... Exercise 4 ... Add a column is_confirmed BOOLEAN DEFAULT false. Update one booking to confirmed. Query only confirmed bookings. ... Exercise 5 ... Display the current time in three different timezones using AT TIME ZONE.

1. Exercise 1: CREATE TABLE bookings (DATE, TIMESTAMPTZ) → INSERT 2
2. Exercise 2: Calculate days between check_in and check_out
3. Exercise 3: EXTRACT(MONTH FROM check_in), DATE_TRUNC('month', ...)
4. Exercise 4: Add is_confirmed BOOLEAN → UPDATE → query WHERE is_confirmed
5. Exercise 5: NOW() AT TIME ZONE for UTC, India, New York


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... DATE for dates, TIME for times, TIMESTAMP for both. Always prefer TIMESTAMPTZ over plain TIMESTAMP for timezone safety. ... INTERVAL for durations and date arithmetic. ... Useful functions: CURRENT_DATE, NOW, EXTRACT, DATE_TRUNC, AGE, AT TIME ZONE. ... BOOLEAN stores TRUE, FALSE, or NULL. Use TRUE and FALSE, not strings. In WHERE, just write WHERE is_active, not WHERE is_active equals TRUE. ... Always use ISO date format: year dash month dash day. ... In our next class, we cover Arrays and JSON data types!

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
