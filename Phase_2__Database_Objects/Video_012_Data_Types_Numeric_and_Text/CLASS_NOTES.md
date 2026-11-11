# Data Types Part 1: Numeric & Text
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 12, Class 13
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Today we begin learning data types. Data types are fundamental ... every column in every table has a data type that controls what kind of data it can hold. ... In this class, we cover numeric types and text types. These are the two most common categories you will use in almost every table you create. ... Let us dive in!

### The Problem: Which Data Type?
Here is the problem. You are designing a table. You need a column for price. Do you use INTEGER? FLOAT? NUMERIC? DECIMAL? ... You need a column for a user's name. CHAR? VARCHAR? TEXT? What is the difference? ... Choosing the wrong data type causes real problems. Use FLOAT for money and you get rounding errors. Use CHAR 100 for names and you waste storage. ... Today we learn exactly which type to use for each situation.

- Price column: INTEGER? FLOAT? NUMERIC? DECIMAL?
- Name column: CHAR? VARCHAR? TEXT?
- Wrong type = rounding errors, wasted space, bugs
- FLOAT for money → rounding problems!
- CHAR(100) for names → wastes storage!
- Today: Learn EXACTLY which type to use and when


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Which Data Type?
Here is the problem. You are designing a table. You need a column for price. Do you use INTEGER? FLOAT? NUMERIC? DECIMAL? ... You need a column for a user's name. CHAR? VARCHAR? TEXT? What is the difference? ... Choosing the wrong data type causes real problems. Use FLOAT for money and you get rounding errors. Use CHAR 100 for names and you waste storage. ... Today we learn exactly which type to use for each situation.

- Price column: INTEGER? FLOAT? NUMERIC? DECIMAL?
- Name column: CHAR? VARCHAR? TEXT?
- Wrong type = rounding errors, wasted space, bugs
- FLOAT for money → rounding problems!
- CHAR(100) for names → wastes storage!
- Today: Learn EXACTLY which type to use and when

### Integer Types
Let us start with integer types. PostgreSQL has three sizes. ... SMALLINT uses 2 bytes and stores numbers from minus 32 thousand to plus 32 thousand. Use it for small counters or status codes. ... INTEGER uses 4 bytes and stores numbers up to about 2.1 billion. This is your default choice for most whole numbers. ... BIGINT uses 8 bytes and stores numbers up to about 9.2 quintillion. Use it for very large counters, like social media post IDs or financial transaction IDs. ... If you insert a number that is too large for the type, PostgreSQL gives an out of range error.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL** | three sizes |
| **SMALLINT** | 2 bytes and stores numbers from minus 32 thousand to plus 32 thousand |
| **INTEGER** | 4 bytes and stores numbers up to about 2 |
| **This** | your default choice for most whole numbers |
| **BIGINT** | 8 bytes and stores numbers up to about 9 |
| **If you insert a number that** | too large for the type, PostgreSQL gives an out of range error |

### Decimal / Floating Point Types
Now let us talk about decimal numbers. ... NUMERIC, also called DECIMAL, stores exact decimal values. You specify precision and scale. NUMERIC 10 comma 2 means 10 total digits with 2 after the decimal point. This is the ONLY correct type for money and financial data. It is exact ... no rounding errors. ... REAL uses 4 bytes and has about 6 decimal digits of precision. DOUBLE PRECISION uses 8 bytes with about 15 digits. These are floating-point types. They are fast but INEXACT. ... Never use REAL or DOUBLE PRECISION for money! You will get rounding errors like 0.1 plus 0.2 equals 0.30000000000000004.

| Term | Meaning / Explanation |
| :--- | :--- |
| **This** | the ONLY correct type for money and financial data |
| **REAL** | 4 bytes and has about 6 decimal digits of precision |
| **DOUBLE PRECISION** | 8 bytes with about 15 digits |
| **These** | floating-point types |
| **They** | fast but INEXACT |
| **Never** | REAL or DOUBLE PRECISION for money! You will get rounding errors like 0 |

### Auto-Increment Types
Here is the quick reference for auto-increment types.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the quick reference for auto-increment types |

### Text Types
Now let us switch to text types. PostgreSQL has three text types. ... CHAR n is a fixed-length type. CHAR 10 always stores exactly 10 characters, padded with spaces if shorter. It is rarely used in practice. ... VARCHAR n is variable-length with a limit. VARCHAR 100 stores up to 100 characters. This is the most commonly used text type. ... TEXT is variable-length with no limit. It can store strings of any size. ... Here is the important part. In PostgreSQL, VARCHAR and TEXT have the SAME performance. There is no speed difference. VARCHAR with a limit is useful when you want to enforce a maximum length, like email addresses. TEXT is fine when you do not need a limit.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL** | three text types |
| **CHAR n** | a fixed-length type |
| **VARCHAR n** | variable-length with a limit |
| **This** | the most commonly used text type |
| **TEXT** | variable-length with no limit |
| **It can** | strings of any size |
| **Here** | the important part |
| **There** | no speed difference |

### Which Type to Use? — Decision Guide
Here is a practical guide for choosing the right data type. ... For IDs and counters, use INTEGER or BIGINT with SERIAL or IDENTITY. ... For money, ALWAYS use NUMERIC. Never REAL or DOUBLE PRECISION. ... For ages, quantities, and small numbers, use INTEGER. ... For names, emails, and short text, use VARCHAR with a reasonable limit. ... For long content like descriptions or blog posts, use TEXT. ... For fixed-length codes like country codes or currency codes, you CAN use CHAR, but VARCHAR works just as well.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a practical guide for choosing the right data type |
| **For IDs and counters** | use INTEGER or BIGINT with SERIAL or IDENTITY |
| **Point 3** | For money, ALWAYS use NUMERIC |
| **Point 4** | Never REAL or DOUBLE PRECISION |
| **For ages, quantities** | and small numbers, use INTEGER |
| **For names, emails** | and short text, use VARCHAR with a reasonable limit |
| **Point 7** | For long content like descriptions or blog posts, use TEXT |
| **For fixed** | length codes like country codes or currency codes, you CAN use CHAR, but VARCHAR works just as well |


---

## 3. Hands-On Commands & psql Output

### Integer Types in Action
**Explanation:** Let me demonstrate. I will create a table with all three integer types and show what happens when you exceed the limits.

```sql
practice=# CREATE TABLE int_demo (small_val SMALLINT, regular_val INTEGER, big_val BIGINT);
CREATE TABLE

practice=# INSERT INTO int_demo VALUES (100, 1000000, 9000000000000);
INSERT 0 1

-- ERROR: SMALLINT overflow
practice=# INSERT INTO int_demo (small_val) VALUES (50000);
ERROR:  smallint out of range

-- ERROR: INTEGER overflow
practice=# INSERT INTO int_demo (regular_val) VALUES (3000000000);
ERROR:  integer out of range

practice=# SELECT * FROM int_demo;
 small_val | regular_val |   big_val
-----------+-------------+---------------
       100 |     1000000 | 9000000000000
```

### NUMERIC vs REAL — Why It Matters
**Explanation:** Let me show you the difference between NUMERIC and REAL. Watch what happens with money calculations.

```sql
-- NUMERIC: exact arithmetic (CORRECT for money)
practice=# SELECT 0.1::NUMERIC + 0.2::NUMERIC AS exact_result;
 exact_result
--------------
          0.3

-- REAL: floating-point (WRONG for money!)
practice=# SELECT 0.1::REAL + 0.2::REAL AS float_result;
    float_result
--------------------
 0.30000001192092896

-- NUMERIC with precision: 10 total digits, 2 decimal
practice=# CREATE TABLE products (id SERIAL, name VARCHAR(100), price NUMERIC(10,2));
CREATE TABLE
practice=# INSERT INTO products (name, price) VALUES ('Laptop', 999.99);
INSERT 0 1

-- Precision overflow
practice=# INSERT INTO products (name, price) VALUES ('Jet', 99999999.999);
ERROR:  numeric field overflow
```

### Auto-Increment: SERIAL & IDENTITY
**Explanation:** Now let us talk about auto-incrementing numbers. ... SERIAL is a shortcut that creates an INTEGER column with an auto-incrementing sequence. You do not need to provide a value ... PostgreSQL fills it in automatically. 1, 2, 3, 4, and so on. ... BIGSERIAL is the same but uses BIGINT for larger ranges. ... In newer PostgreSQL, the preferred way is GENERATED ALWAYS AS IDENTITY. It is the SQL standard and gives you more control. But SERIAL still works perfectly fine and you will see it everywhere.

```sql
-- SERIAL: auto-increment shortcut (common, works great)
practice=# CREATE TABLE orders (id SERIAL PRIMARY KEY, item VARCHAR(100));
CREATE TABLE
practice=# INSERT INTO orders (item) VALUES ('Keyboard');
practice=# INSERT INTO orders (item) VALUES ('Mouse');
practice=# SELECT * FROM orders;
 id |   item
----+----------
  1 | Keyboard
  2 | Mouse

-- IDENTITY: SQL standard way (preferred in new code)
practice=# CREATE TABLE invoices (id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, total NUMERIC(10,2));
CREATE TABLE
practice=# INSERT INTO invoices (total) VALUES (150.00);
INSERT 0 1
```

### Text Types in Action
**Explanation:** Let me demonstrate the text types.

```sql
practice=# CREATE TABLE text_demo (code CHAR(5), name VARCHAR(50), bio TEXT);
CREATE TABLE

practice=# INSERT INTO text_demo VALUES ('AB', 'Ravi Kumar', 'A software developer from India');
INSERT 0 1

-- CHAR(5) pads 'AB' to 'AB   ' (3 trailing spaces)
practice=# SELECT code, length(code), char_length(code) FROM text_demo;
 code  | length | char_length
-------+--------+-------------
 AB    |      2 |           2

-- VARCHAR limit enforcement
practice=# INSERT INTO text_demo (name) VALUES ('This name is way too long and exceeds fifty characters limit easily');
ERROR:  value too long for type character varying(50)

-- TEXT has no limit
practice=# INSERT INTO text_demo (bio) VALUES (repeat('x', 10000));
INSERT 0 1
```

### Common Data Type Errors
**Explanation:** Common data type errors. ... Error 1: integer out of range. You tried to insert a number too large for the column type. If you need bigger numbers, use BIGINT instead of INTEGER. ... Error 2: value too long for character varying. Your string exceeds the VARCHAR limit. Either increase the limit or truncate the input. ... Error 3: numeric field overflow. Your number has more digits than the NUMERIC precision allows. Increase the precision. ... Error 4: invalid input syntax. You tried to insert a string into a numeric column, or a non-number into an integer. Check your data.

```sql
-- ERROR: integer out of range
practice=# SELECT 2147483648::INTEGER;
ERROR:  integer out of range
-- FIX: Use BIGINT instead

-- ERROR: value too long for VARCHAR
practice=# SELECT 'very long text...'::VARCHAR(5);
ERROR:  value too long for type character varying(5)
-- FIX: Increase limit or truncate input

-- ERROR: numeric field overflow
practice=# SELECT 99999999.999::NUMERIC(10,2);
ERROR:  numeric field overflow
-- FIX: Increase NUMERIC precision

-- ERROR: invalid input syntax
practice=# SELECT 'hello'::INTEGER;
ERROR:  invalid input syntax for type integer: "hello"
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Data Type Errors
Common data type errors. ... Error 1: integer out of range. You tried to insert a number too large for the column type. If you need bigger numbers, use BIGINT instead of INTEGER. ... Error 2: value too long for character varying. Your string exceeds the VARCHAR limit. Either increase the limit or truncate the input. ... Error 3: numeric field overflow. Your number has more digits than the NUMERIC precision allows. Increase the precision. ... Error 4: invalid input syntax. You tried to insert a string into a numeric column, or a non-number into an integer. Check your data.

```sql
-- ERROR: integer out of range
SELECT 2147483648::INTEGER;
ERROR:  integer out of range
-- FIX: Use BIGINT instead

-- ERROR: value too long for VARCHAR
SELECT 'very long text...'::VARCHAR(5);
ERROR:  value too long for type character varying(5)
-- FIX: Increase limit or truncate input

-- ERROR: numeric field overflow
SELECT 99999999.999::NUMERIC(10,2);
ERROR:  numeric field overflow
-- FIX: Increase NUMERIC precision

-- ERROR: invalid input syntax
SELECT 'hello'::INTEGER;
ERROR:  invalid input syntax for type integer: "hello"
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time! ... Exercise 1 ... Create a table called employees with id SERIAL PRIMARY KEY, name VARCHAR 100, age SMALLINT, salary NUMERIC 10 comma 2. Insert 3 rows. ... Exercise 2 ... Try inserting a SMALLINT overflow value. See the error. ... Exercise 3 ... Create a table with a TEXT column. Insert a string with 5000 characters using the repeat function. ... Exercise 4 ... Compare NUMERIC and REAL for money. Run SELECT 0.1 plus 0.2 cast to both types. ... Exercise 5 ... Create a table using GENERATED ALWAYS AS IDENTITY instead of SERIAL. Insert 3 rows and verify the auto-increment.

1. Exercise 1: CREATE TABLE employees (SERIAL, VARCHAR, SMALLINT, NUMERIC) → INSERT 3
2. Exercise 2: Try SMALLINT overflow (INSERT 50000) → see error
3. Exercise 3: TEXT column → INSERT repeat('x', 5000)
4. Exercise 4: Compare NUMERIC vs REAL: SELECT 0.1 + 0.2 for both
5. Exercise 5: Create table with GENERATED ALWAYS AS IDENTITY → INSERT 3 rows


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... Integer types: SMALLINT 2 bytes, INTEGER 4 bytes, BIGINT 8 bytes. INTEGER is your default. ... Decimal types: NUMERIC for exact math and money. REAL and DOUBLE PRECISION for fast but inexact scientific calculations. ... Auto-increment: SERIAL and BIGSERIAL, or GENERATED ALWAYS AS IDENTITY for new code. ... Text types: VARCHAR n for limited-length strings, TEXT for unlimited. In PostgreSQL, both have the same performance. CHAR is rarely needed. ... Rule of thumb: when in doubt, use INTEGER for numbers, NUMERIC for money, and VARCHAR for text. ... In our next class, we cover Date, Time, and Boolean types!

- **SMALLINT (2B), INTEGER (4B), BIGINT (8B) — default: INTEGER**
- **NUMERIC(p,s) = exact math, ALWAYS use for money**
- **REAL/DOUBLE PRECISION = fast but inexact, for science only**
- **SERIAL/BIGSERIAL = auto-increment (or IDENTITY for new code)**
- **VARCHAR(n) = variable text with limit, TEXT = no limit**
- **In PostgreSQL: VARCHAR and TEXT have SAME performance**
- **Rule: INTEGER for numbers, NUMERIC for money, VARCHAR for text**


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
