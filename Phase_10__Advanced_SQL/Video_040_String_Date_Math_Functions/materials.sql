-- =============================================
-- PostgreSQL Mastery: String, Date & Math Functions
-- Phase 10: Advanced SQL | Classes 80-82
-- =============================================
-- Essential built-in functions for text, dates,
-- numbers, and conditional logic.
-- =============================================

-- === STRING FUNCTIONS ===

-- Case conversion
SELECT UPPER('hello world');        -- HELLO WORLD
SELECT LOWER('HELLO WORLD');        -- hello world
SELECT INITCAP('hello world');      -- Hello World

-- Length
SELECT LENGTH('PostgreSQL');        -- 10
SELECT CHAR_LENGTH('PostgreSQL');   -- 10 (same)
SELECT OCTET_LENGTH('PostgreSQL');  -- 10 (bytes, differs for UTF-8)

-- Trim whitespace
SELECT TRIM('  hello  ');           -- 'hello'
SELECT LTRIM('  hello');            -- 'hello'
SELECT RTRIM('hello  ');            -- 'hello'
SELECT TRIM(BOTH 'x' FROM 'xxxhelloxxx');  -- 'hello'

-- Substring and position
SELECT SUBSTRING('PostgreSQL' FROM 1 FOR 4);  -- Post
SELECT SUBSTRING('PostgreSQL' FROM 8);        -- SQL
SELECT LEFT('PostgreSQL', 4);                 -- Post
SELECT RIGHT('PostgreSQL', 3);                -- SQL
SELECT POSITION('SQL' IN 'PostgreSQL');       -- 8

-- Concatenation
SELECT CONCAT('Hello', ' ', 'World');     -- Hello World
SELECT 'Hello' || ' ' || 'World';        -- Hello World
SELECT CONCAT_WS(', ', 'Alice', 'Bob');   -- Alice, Bob (with separator)

-- Replace and translate
SELECT REPLACE('Hello World', 'World', 'PG');  -- Hello PG
SELECT TRANSLATE('hello', 'helo', 'HELO');     -- HELLO (char-by-char)

-- Split
SELECT SPLIT_PART('user@example.com', '@', 1);  -- user
SELECT SPLIT_PART('user@example.com', '@', 2);  -- example.com
SELECT SPLIT_PART('a/b/c/d', '/', 3);           -- c

-- Repeat and pad
SELECT REPEAT('ha', 3);                          -- hahaha
SELECT LPAD('42', 5, '0');                        -- 00042
SELECT RPAD('hello', 10, '.');                    -- hello.....

-- Reverse
SELECT REVERSE('PostgreSQL');                     -- LQSergtsoP

-- Regular expression
SELECT REGEXP_REPLACE('Phone: 123-456-7890', '[^0-9]', '', 'g');
-- 1234567890 (strip non-digits)

SELECT REGEXP_MATCHES('Email: user@test.com', '([a-z]+)@([a-z]+)', 'g');
-- {user,test}

-- === PATTERN MATCHING ===

-- LIKE: % = any chars, _ = one char
SELECT 'PostgreSQL' LIKE 'Post%';        -- true
SELECT 'PostgreSQL' LIKE 'P_st%';        -- true
SELECT 'PostgreSQL' LIKE 'post%';        -- false (case-sensitive)

-- ILIKE: case-insensitive
SELECT 'PostgreSQL' ILIKE 'post%';       -- true

-- ~ (POSIX regex)
SELECT 'PostgreSQL' ~ '^Post';           -- true
SELECT 'PostgreSQL' ~* '^post';          -- true (case-insensitive)

-- === DATE/TIME FUNCTIONS ===

-- Current date and time
SELECT NOW();                     -- timestamp with timezone
SELECT CURRENT_TIMESTAMP;         -- same as NOW()
SELECT CURRENT_DATE;              -- just the date
SELECT CURRENT_TIME;              -- just the time

-- Extract parts
SELECT EXTRACT(YEAR FROM NOW());       -- 2024
SELECT EXTRACT(MONTH FROM NOW());      -- 1
SELECT EXTRACT(DAY FROM NOW());        -- 15
SELECT EXTRACT(HOUR FROM NOW());       -- 10
SELECT EXTRACT(DOW FROM NOW());        -- 0-6 (0=Sunday)
SELECT EXTRACT(DOY FROM NOW());        -- day of year (1-366)
SELECT EXTRACT(WEEK FROM NOW());       -- ISO week number
SELECT EXTRACT(EPOCH FROM NOW());      -- seconds since 1970-01-01

-- DATE_PART (same as EXTRACT, different syntax)
SELECT DATE_PART('year', NOW());
SELECT DATE_PART('month', NOW());

-- Truncate to precision
SELECT DATE_TRUNC('year', NOW());      -- 2024-01-01 00:00:00
SELECT DATE_TRUNC('month', NOW());     -- 2024-01-01 00:00:00
SELECT DATE_TRUNC('day', NOW());       -- 2024-01-15 00:00:00
SELECT DATE_TRUNC('hour', NOW());      -- 2024-01-15 10:00:00

-- Age between dates
SELECT AGE(NOW(), '1990-05-15');       -- X years Y months Z days
SELECT AGE('2024-01-15', '2023-06-15'); -- 7 mons 0 days

-- Date arithmetic
SELECT NOW() + INTERVAL '7 days';
SELECT NOW() - INTERVAL '3 months';
SELECT NOW() + INTERVAL '1 year 2 months';
SELECT CURRENT_DATE + 30;               -- add 30 days (integer)
SELECT CURRENT_DATE - CURRENT_DATE;     -- 0 (integer days)

-- Formatting
SELECT TO_CHAR(NOW(), 'YYYY-MM-DD');         -- 2024-01-15
SELECT TO_CHAR(NOW(), 'DD Mon YYYY');        -- 15 Jan 2024
SELECT TO_CHAR(NOW(), 'Day, DD Month YYYY'); -- Monday, 15 January 2024
SELECT TO_CHAR(NOW(), 'HH24:MI:SS');         -- 10:30:45
SELECT TO_CHAR(NOW(), 'Dy DD Mon');          -- Mon 15 Jan

-- Parsing
SELECT TO_DATE('15-01-2024', 'DD-MM-YYYY');
SELECT TO_TIMESTAMP('2024-01-15 10:30', 'YYYY-MM-DD HH24:MI');

-- Number formatting
SELECT TO_CHAR(1234567.89, '9,999,999.99');  -- 1,234,567.89
SELECT TO_CHAR(42, '000');                    -- 042

-- Timezone
SELECT NOW() AT TIME ZONE 'UTC';
SELECT NOW() AT TIME ZONE 'America/New_York';

-- Make a timestamp
SELECT MAKE_DATE(2024, 6, 15);               -- 2024-06-15
SELECT MAKE_TIMESTAMP(2024, 6, 15, 10, 30, 0); -- 2024-06-15 10:30:00

-- === MATH FUNCTIONS ===

-- Rounding
SELECT ROUND(3.14159);          -- 3
SELECT ROUND(3.14159, 2);       -- 3.14
SELECT CEIL(4.1);               -- 5 (round up)
SELECT FLOOR(4.9);              -- 4 (round down)
SELECT TRUNC(4.567, 1);         -- 4.5 (truncate, not round)

-- Absolute value
SELECT ABS(-42);                -- 42

-- Power and roots
SELECT POWER(2, 10);            -- 1024
SELECT SQRT(144);               -- 12
SELECT CBRT(27);                -- 3 (cube root)

-- Modulo (remainder)
SELECT MOD(17, 5);              -- 2

-- Signs
SELECT SIGN(-42);               -- -1
SELECT SIGN(0);                 -- 0
SELECT SIGN(42);                -- 1

-- Min/max from a list
SELECT GREATEST(10, 20, 5, 15); -- 20
SELECT LEAST(10, 20, 5, 15);    -- 5

-- Random
SELECT RANDOM();                -- 0.0 to 1.0
SELECT FLOOR(RANDOM() * 100 + 1)::INT;  -- random 1-100

-- Logarithms
SELECT LN(2.718281828);         -- ~1.0 (natural log)
SELECT LOG(100);                -- 2.0 (base 10)
SELECT LOG(2, 1024);            -- 10.0 (base 2)

-- PI and trigonometry
SELECT PI();                     -- 3.14159265358979
SELECT SIN(PI()/2);             -- 1.0
SELECT COS(0);                  -- 1.0

-- === CONDITIONAL EXPRESSIONS ===

-- COALESCE: first non-NULL value
SELECT COALESCE(NULL, NULL, 'default');     -- default
SELECT COALESCE(NULL, 42, 99);             -- 42

-- Common use: handle missing data
SELECT name, COALESCE(department, 'Unassigned') AS dept
FROM employees;

-- NULLIF: returns NULL if values are equal
SELECT NULLIF(10, 10);   -- NULL
SELECT NULLIF(10, 20);   -- 10

-- Avoid division by zero
SELECT 100.0 / NULLIF(0, 0);  -- NULL instead of ERROR

-- CASE WHEN: SQL's if-else
SELECT name, salary,
  CASE
    WHEN salary >= 100000 THEN 'Senior'
    WHEN salary >= 80000  THEN 'Mid-level'
    ELSE 'Junior'
  END AS level
FROM employees;

-- Simple CASE (match a single value)
SELECT name, department,
  CASE department
    WHEN 'Engineering' THEN 'Tech'
    WHEN 'HR'          THEN 'People'
    WHEN 'Sales'       THEN 'Revenue'
    ELSE 'Other'
  END AS category
FROM employees;

-- === REAL-WORLD EXAMPLES ===

-- Extract email domain
SELECT SPLIT_PART('user@example.com', '@', 2) AS domain;

-- Format salary with commas
SELECT name, TO_CHAR(salary, '9,99,999') AS formatted_salary
FROM employees;

-- Group orders by month
-- SELECT DATE_TRUNC('month', order_date) AS month,
--   COUNT(*), SUM(amount)
-- FROM orders GROUP BY 1 ORDER BY 1;

-- Calculate age in years
-- SELECT name, EXTRACT(YEAR FROM AGE(hire_date)) AS years_employed
-- FROM employees;

-- === PRACTICE EXERCISES ===

-- Exercise 1: Upper/lower/initcap
SELECT UPPER(name), LOWER(department), INITCAP(name)
FROM employees;

-- Exercise 2: Concatenate name and department
SELECT CONCAT(name, ' (', department, ')') AS label
FROM employees;

-- Exercise 3: Current date parts
SELECT EXTRACT(YEAR FROM NOW()) AS year,
  EXTRACT(MONTH FROM NOW()) AS month,
  EXTRACT(DOW FROM NOW()) AS day_of_week;

-- Exercise 4: Date truncation
SELECT DATE_TRUNC('month', NOW());

-- Exercise 5: Format current date
SELECT TO_CHAR(NOW(), 'Day, DD Month YYYY, HH24:MI');

-- Exercise 6: Math operations
SELECT name, salary,
  ROUND(salary / 12, 2) AS monthly,
  CEIL(salary / 365.25) AS daily
FROM employees;

-- Exercise 7: COALESCE and CASE
SELECT name,
  COALESCE(department, 'Unknown') AS dept,
  CASE WHEN salary > 90000 THEN 'High' ELSE 'Standard' END AS tier
FROM employees;

-- =============================================
-- Next Class: LATERAL & GENERATE_SERIES
-- =============================================
