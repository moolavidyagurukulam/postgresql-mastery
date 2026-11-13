# String, Date & Math Functions — Essential Data Tools
**Series:** PostgreSQL Mastery | **Phase:** Phase 10: Advanced SQL | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover the essential built-in functions you will use every day: string functions for text manipulation, date and time functions for working with timestamps, and math functions for calculations. These are the utility belt of SQL — you will reach for them in almost every query. Let us begin.

### Why Built-in Functions Matter
Why do we need built-in functions? Because raw data is messy. Names come in different cases, dates arrive as strings in weird formats, and numbers need rounding for reports. Instead of fixing this in application code, PostgreSQL can clean, transform, and format data right in the query. This is faster — the database processes millions of rows without sending them to your application first.


---

## 2. Core Technical Concepts & Mechanisms

### Why Built-in Functions Matter
Why do we need built-in functions? Because raw data is messy. Names come in different cases, dates arrive as strings in weird formats, and numbers need rounding for reports. Instead of fixing this in application code, PostgreSQL can clean, transform, and format data right in the query. This is faster — the database processes millions of rows without sending them to your application first.

| Term | Meaning / Explanation |
| :--- | :--- |
| **String Functions** | Clean text — case, trim, extract, replace, split |
| **Date Functions** | Parse, format, calculate ages, truncate, extract parts |
| **Math Functions** | Round, clamp, absolute value, random, modulo |
| **Conditional** | COALESCE, NULLIF, CASE WHEN for NULL handling |
| **Why in SQL?** | Process millions of rows without leaving the database |

**Notes:**
- Functions work in SELECT, WHERE, ORDER BY, GROUP BY, and more

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Function Quick Reference
Here is a quick reference of the most important functions organized by category. This is in your downloadable materials — bookmark it.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a quick reference of the most important functions organized by category |
| **Point 2** | This is in your downloadable materials — bookmark it |

### SQL Functions vs Application Code
When should you use functions in SQL versus your application code? Use SQL functions when processing many rows — the database is faster because data stays in the server. Use application code when the logic is complex, needs state across rows, or involves business rules that change often. A good rule: if it is data transformation, do it in SQL. If it is business logic, do it in application code.

| Do in SQL | Do in Application |
| :--- | :--- |
| String cleaning (TRIM, LOWER) | Complex business rules |
| Date grouping (DATE_TRUNC) | Multi-step workflows |
| NULL handling (COALESCE) | External API calls |
| Formatting for reports (TO_CHAR) | User-facing formatting |
| Simple calculations (ROUND, SUM) | Localization (i18n) |
| Pattern matching (LIKE, regex) | State-dependent logic |

### Practice Exercises
Practice exercises: try each category of functions. Clean up messy strings, calculate ages, format dates for reports, use COALESCE for nulls, extract email domains, validate patterns with regex, and combine functions in real-world scenarios.

- 1. UPPER/LOWER/INITCAP on employee names
- 2. SPLIT_PART to extract email domains
- 3. LPAD to format order numbers as ORD-00042
- 4. EXTRACT(YEAR FROM date) for grouping by year
- 5. DATE_TRUNC('month', date) for monthly reports
- 6. TO_CHAR for formatted date output
- 7. ROUND, CEIL, FLOOR on salary calculations
- 8. COALESCE for NULL handling in reports
- 9. Combine: clean name + validate email + format date


---

## 3. Hands-On Commands & psql Output

### String Functions — Case, Length, Trim
**Explanation:** String functions manipulate text. The most commonly used ones are UPPER, LOWER, and INITCAP for changing case. LENGTH for counting characters. TRIM, LTRIM, RTRIM for removing whitespace. LEFT and RIGHT for grabbing characters from either end. These are your first tools for cleaning up messy data.

```sql
practice=# SELECT UPPER('hello world');
 HELLO WORLD

practice=# SELECT LOWER('HELLO WORLD');
 hello world

practice=# SELECT INITCAP('hello world');
 Hello World

practice=# SELECT LENGTH('PostgreSQL');
 10

practice=# SELECT TRIM('  hello  '), LENGTH(TRIM('  hello  '));
  btrim | length
 -------+--------
  hello |      5

practice=# SELECT LEFT('PostgreSQL', 4), RIGHT('PostgreSQL', 3);
 left | right
------+-------
 Post | SQL
```

### String Functions — Concat, Replace, Split, Pad
**Explanation:** CONCAT joins strings together, and the double-pipe operator does the same thing. REPLACE swaps one substring for another. SUBSTRING extracts part of a string by position and length. SPLIT_PART splits by a delimiter and returns the Nth piece — very useful for parsing emails, file paths, or CSV data. LPAD and RPAD pad strings to a fixed width — perfect for aligned output and codes.

```sql
practice=# SELECT CONCAT('Hello', ' ', 'World');
 Hello World
practice=# SELECT 'Hello' || ' ' || 'World';
 Hello World

practice=# SELECT REPLACE('Hello World', 'World', 'PostgreSQL');
 Hello PostgreSQL

practice=# SELECT SUBSTRING('PostgreSQL' FROM 1 FOR 4);
 Post

practice=# SELECT SPLIT_PART('user@example.com', '@', 2);
 example.com

-- LPAD/RPAD: pad to fixed width
practice=# SELECT LPAD('42', 5, '0');
 00042
practice=# SELECT RPAD('hello', 10, '.');
 hello.....
```

### Beginner Trap: NULL in String Operations
**Explanation:** Beginner trap with strings: the double-pipe operator returns NULL if ANY operand is NULL. This is different from CONCAT which treats NULL as empty string. Also, LENGTH counts characters not bytes — multibyte UTF-8 characters are counted as one character. And POSITION is one-based, not zero-based like in most programming languages.

```sql
-- || returns NULL if ANY part is NULL
practice=# SELECT 'Hello' || NULL || 'World';
 (NULL)

-- CONCAT treats NULL as empty string
practice=# SELECT CONCAT('Hello', NULL, 'World');
 HelloWorld

-- Use CONCAT when data might have NULLs!
-- Use || only when you're sure values are NOT NULL

-- POSITION is 1-based (not 0-based like Python!)
practice=# SELECT POSITION('SQL' IN 'PostgreSQL');
 8
-- Returns 0 if not found (not -1)
practice=# SELECT POSITION('xyz' IN 'PostgreSQL');
 0
```

### Pattern Matching — LIKE, ILIKE, Regex
**Explanation:** Pattern matching goes beyond simple functions. LIKE uses percent for any characters and underscore for a single character. ILIKE is the case-insensitive version — a PostgreSQL extension not found in standard SQL. For advanced patterns, PostgreSQL supports POSIX regular expressions with the tilde operator. The tilde-star is case-insensitive regex.

```sql
-- LIKE: % = any chars, _ = one char
practice=# SELECT name FROM employees WHERE name LIKE 'A%';
 Alice
 Arjun

-- ILIKE: case-insensitive (PG extension!)
practice=# SELECT name FROM employees WHERE name ILIKE 'a%';
 Alice
 Arjun

-- ~ is POSIX regex, ~* is case-insensitive regex
practice=# SELECT name FROM employees WHERE name ~ '^[A-M]';
 Alice
 Bob
 Carol
 Deepak

-- Extract with regex: REGEXP_MATCHES
practice=# SELECT (REGEXP_MATCHES('Call 555-1234', '(\d{3}-\d{4})'))[1];
 555-1234
```

### Date/Time Functions — NOW, EXTRACT, DATE_TRUNC
**Explanation:** Date and time functions are essential for any application. NOW and CURRENT_TIMESTAMP give you the current time with timezone. CURRENT_DATE gives just the date. EXTRACT pulls out a specific part — year, month, day, hour, dow for day of week. DATE_TRUNC truncates to a specific precision — great for grouping by month or year in reports.

```sql
practice=# SELECT NOW();
 2024-01-15 10:30:45.123456+05:30

practice=# SELECT CURRENT_DATE, CURRENT_TIME;
 2024-01-15 | 10:30:45.123456+05:30

practice=# SELECT EXTRACT(YEAR FROM NOW());
 2024
practice=# SELECT EXTRACT(MONTH FROM NOW());
 1
practice=# SELECT EXTRACT(DOW FROM NOW());
 1  (Monday; 0=Sunday in EXTRACT)

-- DATE_TRUNC: truncate to precision
practice=# SELECT DATE_TRUNC('month', NOW());
 2024-01-01 00:00:00+05:30
practice=# SELECT DATE_TRUNC('hour', NOW());
 2024-01-15 10:00:00+05:30
```

### Date Arithmetic, AGE, and Formatting
**Explanation:** Date arithmetic with INTERVAL is powerful. You can add or subtract days, months, or years from any date or timestamp. AGE calculates the interval between two dates. TO_CHAR formats dates and numbers as strings for reports. TO_DATE and TO_TIMESTAMP parse strings into date and timestamp values. MAKE_DATE builds a date from year, month, day integers.

```sql
-- Add/subtract intervals
practice=# SELECT NOW() + INTERVAL '7 days';
 2024-01-22 10:30:45
practice=# SELECT NOW() - INTERVAL '3 months';
 2023-10-15 10:30:45
practice=# SELECT CURRENT_DATE + 30;
 2024-02-14  (adding integer = days)

-- AGE: interval between two dates
practice=# SELECT AGE(NOW(), '1990-05-15');
 33 years 8 mons 0 days

-- TO_CHAR: format for display
practice=# SELECT TO_CHAR(NOW(), 'DD Mon YYYY, HH24:MI');
 15 Jan 2024, 10:30

-- TO_DATE: parse string to date
practice=# SELECT TO_DATE('15-01-2024', 'DD-MM-YYYY');
 2024-01-15

-- MAKE_DATE: build from integers
practice=# SELECT MAKE_DATE(2024, 3, 15);
 2024-03-15
```

### Beginner Trap: Date Gotchas
**Explanation:** Beginner trap with dates: EXTRACT with DOW returns 0 for Sunday and 6 for Saturday — this is different from ISODOW which returns 7 for Sunday. Also, adding INTERVAL '1 month' to January 31 gives February 28 or 29 — PostgreSQL adjusts, it does not error. And NOW returns the same value throughout a transaction — it is the transaction start time, not wall clock time. Use clock_timestamp if you need the actual current time.

```sql
-- DOW: 0=Sunday, ISODOW: 7=Sunday
practice=# SELECT EXTRACT(DOW FROM DATE '2024-01-14');
 0  (Sunday)
practice=# SELECT EXTRACT(ISODOW FROM DATE '2024-01-14');
 7  (Sunday in ISO)

-- Month overflow: PG adjusts, doesn't error
practice=# SELECT DATE '2024-01-31' + INTERVAL '1 month';
 2024-02-29 00:00:00

-- NOW() is frozen within a transaction!
practice=# BEGIN;
practice=*# SELECT NOW();  -- returns same value
practice=*# SELECT pg_sleep(2);
practice=*# SELECT NOW();  -- SAME value as before!
practice=*# COMMIT;

-- Use clock_timestamp() for wall-clock time
```

### Math Functions
**Explanation:** Math functions handle numeric calculations. ROUND rounds to N decimal places. CEIL rounds up, FLOOR rounds down. ABS gives absolute value. POWER and SQRT handle exponents and square roots. MOD gives the remainder of division. GREATEST and LEAST pick the largest or smallest value from a list — useful for clamping values to a range.

```sql
practice=# SELECT ROUND(3.14159, 2);
 3.14
practice=# SELECT CEIL(4.1), FLOOR(4.9);
  ceil | floor
 ------+-------
     5 |     4

practice=# SELECT ABS(-42);
 42
practice=# SELECT POWER(2, 10), SQRT(144);
 1024 | 12
practice=# SELECT MOD(17, 5);
 2

-- GREATEST/LEAST: clamp values to a range
practice=# SELECT GREATEST(10, 20, 5), LEAST(10, 20, 5);
 20 | 5

-- Clamp salary between 30000 and 150000:
practice=# SELECT LEAST(GREATEST(salary, 30000), 150000) FROM employees;
```

### Conditional: COALESCE, NULLIF, CASE
**Explanation:** Conditional expressions round out your toolkit. COALESCE returns the first non-null value — essential for handling NULL in reports and calculations. NULLIF returns NULL if two values are equal — the classic trick to avoid division by zero. And CASE WHEN is SQL's if-else — it evaluates conditions in order and returns the first matching result.

```sql
-- COALESCE: first non-NULL value
practice=# SELECT COALESCE(NULL, NULL, 'fallback');
 fallback

-- Common use: default for missing data
practice=# SELECT name, COALESCE(department, 'Unassigned') AS dept
FROM employees;
  name  |    dept
--------+------------
 Alice  | Engineering
 Frank  | Unassigned

-- NULLIF: avoid division by zero
practice=# SELECT 100.0 / NULLIF(0, 0);
 (NULL)  -- instead of ERROR!

-- CASE WHEN: SQL's if-else
practice=# SELECT name, salary,
  CASE WHEN salary > 100000 THEN 'Senior'
       WHEN salary > 80000  THEN 'Mid'
       ELSE 'Junior' END AS level
FROM employees;
```

### Practical: Monthly Sales Report
**Explanation:** Let us put it all together with a practical example. Imagine you need a monthly sales report with formatted output. You combine DATE_TRUNC for grouping, TO_CHAR for formatting, ROUND for clean numbers, and COALESCE for handling NULLs. This is how real-world queries look — multiple functions working together.

```sql
practice=# SELECT
  TO_CHAR(DATE_TRUNC('month', sale_date), 'Mon YYYY')
    AS month,
  COUNT(*) AS orders,
  ROUND(SUM(amount), 2) AS revenue,
  ROUND(AVG(amount), 2) AS avg_order,
  INITCAP(COALESCE(region, 'unknown')) AS region
FROM sales
GROUP BY DATE_TRUNC('month', sale_date), region
ORDER BY 1, 5;
  month   | orders | revenue  | avg_order | region
----------+--------+----------+-----------+--------
 Jan 2024 |     45 | 12500.00 |    277.78 | North
 Jan 2024 |     38 | 10200.00 |    268.42 | South
 Feb 2024 |     52 | 15800.00 |    303.85 | North

-- Combines: DATE_TRUNC, TO_CHAR, ROUND, COALESCE, INITCAP
```

### Practical: Data Cleaning Query
**Explanation:** Another practical example: cleaning and validating user data. TRIM whitespace, standardize case with LOWER, validate email format with regex, extract domain with SPLIT_PART, and calculate account age with AGE. These patterns come up constantly in real applications.

```sql
practice=# SELECT
  INITCAP(TRIM(name)) AS clean_name,
  LOWER(TRIM(email)) AS clean_email,
  SPLIT_PART(LOWER(email), '@', 2) AS domain,
  EXTRACT(YEAR FROM AGE(signup_date)) || ' years'
    AS account_age,
  CASE
    WHEN email ~* '^[a-z0-9.]+@[a-z0-9.]+\.[a-z]{2,}$'
    THEN 'Valid'
    ELSE 'Invalid'
  END AS email_status
FROM users;
  clean_name | clean_email       | domain      | account_age | email_status
 -----------+-------------------+-------------+-------------+-------------
  Alice Roy  | alice@example.com | example.com | 3 years     | Valid
  Bob Singh  | bob@bad           | bad         | 1 years     | Invalid
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: NULL in String Operations
Beginner trap with strings: the double-pipe operator returns NULL if ANY operand is NULL. This is different from CONCAT which treats NULL as empty string. Also, LENGTH counts characters not bytes — multibyte UTF-8 characters are counted as one character. And POSITION is one-based, not zero-based like in most programming languages.

```sql
-- || returns NULL if ANY part is NULL
SELECT 'Hello' || NULL || 'World';
 (NULL)

-- CONCAT treats NULL as empty string
SELECT CONCAT('Hello', NULL, 'World');
 HelloWorld

-- Use CONCAT when data might have NULLs!
-- Use || only when you're sure values are NOT NULL

-- POSITION is 1-based (not 0-based like Python!)
SELECT POSITION('SQL' IN 'PostgreSQL');
 8
-- Returns 0 if not found (not -1)
SELECT POSITION('xyz' IN 'PostgreSQL');
 0
```

### Beginner Trap: Date Gotchas
Beginner trap with dates: EXTRACT with DOW returns 0 for Sunday and 6 for Saturday — this is different from ISODOW which returns 7 for Sunday. Also, adding INTERVAL '1 month' to January 31 gives February 28 or 29 — PostgreSQL adjusts, it does not error. And NOW returns the same value throughout a transaction — it is the transaction start time, not wall clock time. Use clock_timestamp if you need the actual current time.

```sql
-- DOW: 0=Sunday, ISODOW: 7=Sunday
SELECT EXTRACT(DOW FROM DATE '2024-01-14');
 0  (Sunday)
SELECT EXTRACT(ISODOW FROM DATE '2024-01-14');
 7  (Sunday in ISO)

-- Month overflow: PG adjusts, doesn't error
SELECT DATE '2024-01-31' + INTERVAL '1 month';
 2024-02-29 00:00:00

-- NOW() is frozen within a transaction!
BEGIN;
SELECT NOW();  -- returns same value
SELECT pg_sleep(2);
SELECT NOW();  -- SAME value as before!
COMMIT;

-- Use clock_timestamp() for wall-clock time
```


---

## 6. Hands-On Practice Exercises & Verified Answer Key

### Practice Challenges

1. **String Standardization:** Transform `name` to uppercase, `department` to lowercase, and format names with `INITCAP()`.
2. **Safe Concatenation:** Concatenate `name` and `department` formatted as `Name (Dept)` using `CONCAT()` to ensure NULL values don't poison the output.
3. **Date Part Extraction & Truncation:** Extract year, month, and day-of-week from `NOW()`, and use `DATE_TRUNC('month', NOW())` to find the exact beginning of the current month.
4. **Date Formatting & Elapsed Age:** Format `NOW()` using `TO_CHAR()` into `'Day, DD Month YYYY, HH24:MI'` and calculate elapsed age using the `AGE()` function.
5. **Defaults & Categorization:** Use `COALESCE(department, 'Unassigned')` for missing departments and categorize employees into `'High'` or `'Standard'` salary tiers with a `CASE` expression.

---

### Verified Solutions & Explanations

#### Exercise 1: String Standardization
```sql
SELECT UPPER(name) AS upper_name,
       LOWER(department) AS lower_dept,
       INITCAP(name) AS initcap_name
FROM employees;
```
*Explanation:* Standardizes casing across text fields for consistent reporting and searches.

#### Exercise 2: Safe Concatenation
```sql
SELECT CONCAT(name, ' (', department, ')') AS label
FROM employees;
```
*Explanation:* The double-pipe operator (`||`) produces `NULL` if any operand is `NULL`. `CONCAT()` treats `NULL` as an empty string, safely assembling the formatted label.

#### Exercise 3: Date Parts & Truncation
```sql
SELECT EXTRACT(YEAR FROM NOW()) AS current_year,
       EXTRACT(MONTH FROM NOW()) AS current_month,
       DATE_TRUNC('month', NOW()) AS start_of_month;
```
*Explanation:* `EXTRACT()` pulls numeric units (year, month, day), while `DATE_TRUNC('month', ...)` zeroes out smaller fields (days, hours, minutes, seconds) to snap to the beginning of the month.

#### Exercise 4: Formatting & Elapsed Interval
```sql
SELECT TO_CHAR(NOW(), 'Day, DD Month YYYY, HH24:MI') AS human_readable_time,
       AGE(NOW(), NOW() - INTERVAL '3 years 4 months') AS sample_tenure;
```
*Explanation:* `TO_CHAR()` converts timestamps to formatted text. `AGE()` computes an exact calendar interval difference in years, months, and days.

#### Exercise 5: Defaults & Categorization
```sql
SELECT name,
       COALESCE(department, 'Unassigned') AS safe_department,
       CASE
         WHEN salary > 90000 THEN 'High'
         ELSE 'Standard'
       END AS compensation_tier
FROM employees;
```
*Explanation:* `COALESCE()` returns the first non-null argument, protecting against missing values. `CASE` provides conditional branching logic directly in SQL queries.


## 7. Key Takeaways & Cheat Sheet

Let us recap. String functions handle text: UPPER, LOWER, CONCAT, SPLIT_PART, REPLACE, SUBSTRING, LPAD, RPAD. Date functions handle time: NOW, EXTRACT, DATE_TRUNC, AGE, INTERVAL, TO_CHAR, MAKE_DATE. Math functions handle numbers: ROUND, CEIL, FLOOR, GREATEST, LEAST, MOD, RANDOM. Pattern matching: LIKE, ILIKE, tilde regex. Conditional expressions: COALESCE for NULLs, NULLIF for division safety, CASE WHEN for if-else logic. Beginner traps: double-pipe returns NULL with any NULL operand — use CONCAT instead. NOW is frozen in a transaction — use clock_timestamp for wall time. DOW returns 0 for Sunday, ISODOW returns 7. In the next class, we cover LATERAL joins and GENERATE_SERIES. See you there!

- **String: UPPER, LOWER, CONCAT, ||, SPLIT_PART, REPLACE**
- **String: SUBSTRING, POSITION, LEFT, RIGHT, TRIM, LPAD**
- **Pattern: LIKE, ILIKE, ~ (regex), ~* (case-insensitive)**
- **Date: NOW(), CURRENT_DATE, EXTRACT, DATE_TRUNC**
- **Date: AGE(), INTERVAL, TO_CHAR/TO_DATE, MAKE_DATE**
- **Math: ROUND, CEIL, FLOOR, ABS, MOD, POWER, SQRT**
- **Conditional: COALESCE, NULLIF, CASE WHEN**
- **Trap: || returns NULL with NULL — use CONCAT**
- **Trap: NOW() frozen in transaction — use clock_timestamp()**


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
