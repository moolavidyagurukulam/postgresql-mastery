# Data Types Part 1: Numeric & Text
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 12, Class 13
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Today we start our four-part deep dive into PostgreSQL Data Types, starting with Numeric and Text types!. Think about running an online electronics store: every column in your database, item count, product price, invoice total, product title, and customer review, demands an exact data type. Pick the wrong type and customer bills lose paise to float rounding errors, IDs hit overflow crashes at 2.1 billion orders, or strings silently waste space. By the end of this class, you will know exact byte sizes, ranges, SERIAL vs IDENTITY, NUMERIC vs REAL, and CHAR vs VARCHAR vs TEXT inside PostgreSQL 16! Choosing data types thoughtfully on day one saves teams months of painful table rewrites later, improves cache density, and protects every financial calculation from quiet rounding errors.

### The Problem: Which Data Type?
Choosing the wrong column data type is one of the hardest database mistakes to fix later once millions of customer rows sit in production. Look at three bugs that hit real engineering teams every week. Bug one: a developer stores product prices as REAL floating point, and suddenly ten cents plus twenty cents prints zero point three zero zero zero zero zero zero one on customer invoices! Bug two: an app uses 4-byte INTEGER for clickstream events and crashes completely at 2.1 billion rows! Bug three: CHAR(100) pads tiny names with wasted spaces. Today you learn the exact PostgreSQL rules for integers, NUMERIC, SERIAL, IDENTITY, and text.

- Real Bug 1: Using REAL/FLOAT for price → invoices show $0.30000001!
- Real Bug 2: Using INT for huge event IDs → server crashes at 2.1B rows!
- Real Bug 3: Using CHAR(100) for names → wastes space with trailing spaces
- Solution: Exact decimal math (NUMERIC) & right-sized integers
- Surprise Fact: In PostgreSQL, VARCHAR and TEXT run at the SAME speed
- Today: Master Integers, NUMERIC vs REAL, SERIAL/IDENTITY & Text types


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Which Data Type?
Choosing the wrong column data type is one of the hardest database mistakes to fix later once millions of customer rows sit in production. Look at three bugs that hit real engineering teams every week. Bug one: a developer stores product prices as REAL floating point, and suddenly ten cents plus twenty cents prints zero point three zero zero zero zero zero zero one on customer invoices! Bug two: an app uses 4-byte INTEGER for clickstream events and crashes completely at 2.1 billion rows! Bug three: CHAR(100) pads tiny names with wasted spaces. Today you learn the exact PostgreSQL rules for integers, NUMERIC, SERIAL, IDENTITY, and text.

- Real Bug 1: Using REAL/FLOAT for price → invoices show $0.30000001!
- Real Bug 2: Using INT for huge event IDs → server crashes at 2.1B rows!
- Real Bug 3: Using CHAR(100) for names → wastes space with trailing spaces
- Solution: Exact decimal math (NUMERIC) & right-sized integers
- Surprise Fact: In PostgreSQL, VARCHAR and TEXT run at the SAME speed
- Today: Master Integers, NUMERIC vs REAL, SERIAL/IDENTITY & Text types

### Integer Types
Let us start with integer types. PostgreSQL has three sizes. SMALLINT uses 2 bytes and stores numbers from minus 32 thousand to plus 32 thousand. Use it for small counters or status codes. INTEGER uses 4 bytes and stores numbers up to about 2.1 billion. This is your default choice for most whole numbers. BIGINT uses 8 bytes and stores numbers up to about 9.2 quintillion. Use it for very large counters, like social media post IDs or financial transaction IDs. If you insert a number that is too large for the type, PostgreSQL gives an out of range error. Pay special attention to storage sizing: using SMALLINT where values never pass thirty thousand cuts storage in half versus INTEGER, and choosing BIGINT early prevents painful schema locks when traffic explodes past two billion rows.

| Term | Meaning / Explanation |
| :--- | :--- |
| **SMALLINT** | 2 bytes | Range: -32,768 to +32,767 (tiny counters, codes) |
| **INTEGER** | 4 bytes | Range: ~±2.1 billion (DEFAULT choice for most ints) |
| **BIGINT** | 8 bytes | Range: ±9.2 quintillion (orders, logs, event IDs) |
| **Overflow Rule** | Exceeding the limit throws an immediate 'out of range' error |

### Decimal / Floating Point Types
Now let us talk about decimal numbers. NUMERIC, also called DECIMAL, stores exact decimal values. You specify precision and scale. NUMERIC 10 comma 2 means 10 total digits with 2 after the decimal point. This is the ONLY correct type for money and financial data. It is exact. no rounding errors. REAL uses 4 bytes and has about 6 decimal digits of precision. DOUBLE PRECISION uses 8 bytes with about 15 digits. These are floating-point types. They are fast but INEXACT. Never use REAL or DOUBLE PRECISION for money! You will get rounding errors like 0.1 plus 0.2 equals 0.30000000000000004. Remember this golden rule for interviews and code reviews alike: whenever money, percentages, tax rates, or exact decimal invoices appear in requirements, write NUMERIC(p, s) instinctively every single time.

| Term | Meaning / Explanation |
| :--- | :--- |
| **NUMERIC(p,s)** | Exact decimal math (e.g. NUMERIC(10,2)) — REQUIRED for money |
| **REAL** | 4-byte binary float (~6 digits precision) — fast but inexact |
| **DOUBLE** | 8-byte binary float (~15 digits) — scientific/GPS data only |
| **Money Rule** | NEVER use REAL or DOUBLE for currency — rounding bugs occur |

### Auto-Increment Types
Here is your clear comparison of PostgreSQL's four auto-increment options. SMALLSERIAL uses 2 bytes and goes up to 32,767, only for tiny internal status lookup tables. SERIAL uses 4 bytes up to 2.1 billion and appears across older tutorials and codebases. BIGSERIAL scales to 9.2 quintillion, safer for fast-growing order, click, and audit log tables. In PostgreSQL 16, prefer GENERATED ALWAYS AS IDENTITY: it follows the strict SQL standard, blocks accidental manual ID overrides, and manages permissions much more cleanly!. Also remember the sequence gap rule: if an INSERT fails or rolls back, the sequence number already incremented, seeing IDs jump from 4 to 6 is normal and harmless.

| Term | Meaning / Explanation |
| :--- | :--- |
| **SMALLSERIAL** | 2-byte auto-increment (1 to 32,767) — lookup tables only |
| **SERIAL** | 4-byte auto-increment (up to 2.1B) — classic PG shortcut |
| **BIGSERIAL** | 8-byte auto-increment (up to 9.2e18) — high-volume tables |
| **IDENTITY** | GENERATED ALWAYS AS IDENTITY — modern SQL standard (PG 10+) |
| **Gap Rule** | Rolled-back inserts still advance the sequence (gaps are normal) |

### Text Types
Now let us switch to text types. PostgreSQL has three text types. CHAR n is a fixed-length type. CHAR 10 always stores exactly 10 characters, padded with spaces if shorter. It is rarely used in practice. VARCHAR n is variable-length with a limit. VARCHAR 100 stores up to 100 characters. This is the most commonly used text type. TEXT is variable-length with no limit. It can store strings of any size. Here is the important part. In PostgreSQL, VARCHAR and TEXT have the SAME performance. There is no speed difference. VARCHAR with a limit is useful when you want to enforce a maximum length, like email addresses. TEXT is fine when you do not need a limit.

| Term | Meaning / Explanation |
| :--- | :--- |
| **CHAR(n)** | Fixed-length, space-padded to n chars (rarely needed in PG) |
| **VARCHAR(n)** | Variable-length with max limit (e.g. email VARCHAR(255)) |
| **TEXT** | Variable-length with NO length cap (descriptions, logs, JSON) |
| **Speed Myth** | VARCHAR(n) and TEXT use identical storage & have SAME speed |

### Which Type to Use? — Decision Guide
Keep this practical decision guide right next to you whenever you design a new PostgreSQL table! For primary keys and unique identifiers, choose INTEGER or BIGINT paired with GENERATED ALWAYS AS IDENTITY or BIGSERIAL. For money, prices, tax, and accounting balances, always choose NUMERIC(p,s), never REAL or DOUBLE PRECISION. For ordinary counts and inventory, use INTEGER or SMALLINT. For emails or codes needing a hard max character guard, use VARCHAR(n), and for articles, comments, or long notes, use TEXT knowing PostgreSQL stores both identically at equal speed!

| Term | Meaning / Explanation |
| :--- | :--- |
| **IDs & Keys** | INTEGER/BIGINT with GENERATED ALWAYS AS IDENTITY or BIGSERIAL |
| **Money & Tax** | ALWAYS NUMERIC(p,s) — never REAL or DOUBLE PRECISION |
| **Counters** | INTEGER for standard counts; SMALLINT for tiny enums/ages |
| **Bounded Text** | VARCHAR(n) when you want a strict max length (email, phone) |
| **Long Text** | TEXT for articles, notes, comments (zero speed penalty vs VARCHAR) |


---

## 3. Hands-On Commands & psql Output

### Integer Types in Action
**Explanation:** Let us test PostgreSQL integer limits live in psql so you see exact error messages before they ever hit production!. First, we create int_demo with SMALLINT (2 bytes), INTEGER (4 bytes), and BIGINT (8 bytes), and insert 100, 1 million, and 9 trillion, all succeed cleanly. Next, watch what happens when we try inserting 50,000 into SMALLINT: PostgreSQL immediately protects your data with ERROR: smallint out of range, because SMALLINT stops at 32,767!. And trying to insert 3 billion into regular INTEGER triggers ERROR: integer out of range because signed 4-byte integers top out near 2.14 billion. Remember: never silently truncate, PostgreSQL rejects overflows loudly!

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
**Explanation:** Look at why this slide alone saves financial applications from embarrassing bugs!. When we compute 0.1 plus 0.2 using NUMERIC, PostgreSQL performs exact base-10 decimal arithmetic and returns crisp 0.3, matching every accounting ledger to the exact cent. Now run the exact same addition using 0.1 and 0.2 cast to REAL floating point: look at the output. 0.30000001192092896! Why? Binary IEEE-754 floats cannot represent one-tenth exactly in binary, so across millions of invoices those tiny fractions drift by real money!. And notice below: declaring price NUMERIC(10, 2) means 10 total digits allowed, with 2 digits after the decimal, inserting a 11-digit price safely raises ERROR: numeric field overflow.

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

### How NUMERIC Precision (p,s) Rounds & Validates
**Explanation:** Let us look at two subtle numeric details that trip up developers every day!. First, notice what NUMERIC(6, 2) actually validates: 6 total digits, 2 decimal digits, which leaves only 4 integer digits (up to 9999.99). Extra decimal places round cleanly, 123.456 becomes 123.46, whereas exceeding 4 integer digits like 10000.00 throws an immediate numeric field overflow error!. Second, watch integer division at the bottom: in SQL, 5 divided by 2 performs integer division and silently gives 2 instead of 2.5! Always cast at least one operand with ::NUMERIC when calculating averages, tax rates, or percentages! Watch that integer division reminder carefully too: whenever you divide counts to compute conversion rates or averages in analytics queries, casting the numerator to NUMERIC prevents silent truncation.

```sql
-- NUMERIC(6, 2): max 6 total digits, 2 after decimal (max 9999.99)
practice=# SELECT 123.456::NUMERIC(6, 2) AS rounded, 123.454::NUMERIC(6, 2) AS exact;
 rounded | exact
---------+--------
  123.46 | 123.45

-- What happens if integer digits exceed 4 (6 - 2 = 4)?
practice=# SELECT 10000.00::NUMERIC(6, 2);
ERROR: numeric field overflow
DETAIL: A field with precision 6, scale 2 must round to an absolute value less than 10^4.

-- Integer division trap in SQL: INT / INT drops decimals!
practice=# SELECT 5 / 2 AS int_div, 5::NUMERIC / 2 AS dec_div;
 int_div |        dec_div
---------+------------------------
       2 | 2.5000000000000000
```

### Auto-Increment: SERIAL & IDENTITY
**Explanation:** Now let us examine auto-incrementing primary keys in PostgreSQL. Traditionally, PostgreSQL offered SERIAL and BIGSERIAL, which automatically create a backing sequence and increment IDs 1, 2, 3 without your app passing a number. Remember the rule of scale: SMALLSERIAL stops at 32 thousand, SERIAL stops around 2.1 billion, and BIGSERIAL handles 9.2 quintillion rows! In modern PostgreSQL 10 through 16, the SQL standard GENERATED ALWAYS AS IDENTITY is even better because it prevents accidental manual ID overwrites. Whenever a table might grow past a few hundred million rows over its lifetime, choose BIGINT with IDENTITY right from day one.

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
**Explanation:** Let us run a live text demo in psql to prove how PostgreSQL handles CHAR, VARCHAR, and TEXT!. We create text_demo with code CHAR(5), name VARCHAR(50), and bio TEXT, then insert 'AB', 'Ravi Kumar', and a bio. Wait, look at the CHAR(5) quirk: even though CHAR(5) physically pads 'AB' with 3 trailing spaces on disk, PostgreSQL's length function ignores trailing spaces on CHAR types and prints 2!. Meanwhile, VARCHAR(50) strictly rejects strings longer than 50 characters with value too long for type character varying(50), while TEXT happily accepts a 10,000-character string with zero speed penalty! Notice especially how CHAR(5) stores hidden trailing padding inside raw byte storage, which can surprise string equality or concatenation checks unless you switch cleanly to VARCHAR(n) or TEXT.

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

### Hidden Gotchas: CHAR Space Padding vs UTF-8 Bytes
**Explanation:** Here are two subtle string traps that prove why DBAs avoid CHAR(n) and trust PostgreSQL's UTF-8 VARCHAR and TEXT!. Look at query 1: when you join 'AB' cast as CHAR(5) with an exclamation mark, those hidden trailing spaces suddenly show up right inside your UI string as 'AB !', and octet_length confirms 5 bytes wasted!. Now look at query 2 for Indian Rupee symbol '₹100': how many characters is '₹100'? Four! Yet octet_length shows 6 bytes because UTF-8 uses 3 bytes for '₹'. Thankfully in PostgreSQL, VARCHAR(4) counts characters, NOT bytes, so '₹100' fits cleanly without breaking!

```sql
-- 1. CHAR(5) DOES waste space & breaks string concatenation!
practice=# SELECT ('AB'::CHAR(5) || '!') AS padded_join, octet_length('AB'::CHAR(5)) AS bytes;
 padded_join | bytes
-------------+-------
 AB   !      |     5

-- 2. VARCHAR(n) counts CHARACTERS, not BYTES (UTF-8 multi-byte safe)
practice=# SELECT char_length('₹100') AS chars, octet_length('₹100') AS utf8_bytes;
 chars | utf8_bytes
-------+------------
     4 |          6

-- Lesson: Use TEXT or VARCHAR(n); avoid CHAR(n) in modern PostgreSQL!
```

### Common Data Type Errors
**Explanation:** Common data type errors. Error 1: integer out of range. You tried to insert a number too large for the column type. If you need bigger numbers, use BIGINT instead of INTEGER. Error 2: value too long for character varying. Your string exceeds the VARCHAR limit. Either increase the limit or truncate the input. Error 3: numeric field overflow. Your number has more digits than the NUMERIC precision allows. Increase the precision. Error 4: invalid input syntax. You tried to insert a string into a numeric column, or a non-number into an integer. Check your data. Learning to read these four error messages quickly — integer out of range, value too long, numeric field overflow, and invalid input syntax — cuts debugging time to seconds.

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
Common data type errors. Error 1: integer out of range. You tried to insert a number too large for the column type. If you need bigger numbers, use BIGINT instead of INTEGER. Error 2: value too long for character varying. Your string exceeds the VARCHAR limit. Either increase the limit or truncate the input. Error 3: numeric field overflow. Your number has more digits than the NUMERIC precision allows. Increase the precision. Error 4: invalid input syntax. You tried to insert a string into a numeric column, or a non-number into an integer. Check your data. Learning to read these four error messages quickly — integer out of range, value too long, numeric field overflow, and invalid input syntax — cuts debugging time to seconds.

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

Practice time!. Exercise 1. Create a table called employees with id SERIAL PRIMARY KEY, name VARCHAR 100, age SMALLINT, salary NUMERIC 10 comma 2. Insert 3 rows. Exercise 2. Try inserting a SMALLINT overflow value. See the error. Exercise 3. Create a table with a TEXT column. Insert a string with 5000 characters using the repeat function. Exercise 4. Compare NUMERIC and REAL for money. Run SELECT 0.1 plus 0.2 cast to both types. Exercise 5. Create a table using GENERATED ALWAYS AS IDENTITY instead of SERIAL. Insert 3 rows and verify the auto-increment.

1. Exercise 1: CREATE TABLE employees (SERIAL, VARCHAR, SMALLINT, NUMERIC) → INSERT 3
2. Exercise 2: Try SMALLINT overflow (INSERT 50000) → see error
3. Exercise 3: TEXT column → INSERT repeat('x', 5000)
4. Exercise 4: Compare NUMERIC vs REAL: SELECT 0.1 + 0.2 for both
5. Exercise 5: Create table with GENERATED ALWAYS AS IDENTITY → INSERT 3 rows


---


### Answer Key — Practice Solutions

`sql
-- 1. Create employees table & insert 3 rows
CREATE TABLE employees (id SERIAL PRIMARY KEY, name VARCHAR(100), age SMALLINT, salary NUMERIC(10,2));

-- 2. SMALLINT overflow test (max 32,767)
INSERT INTO employees (name, age) VALUES ('Test', 50000);
-- ERROR: smallint out of range

-- 3. TEXT column with 5,000 characters
INSERT INTO articles (content) VALUES (repeat('x', 5000));

-- 4. NUMERIC (exact) vs REAL (binary float)
SELECT 0.1::NUMERIC + 0.2::NUMERIC AS exact_sum, 0.1::REAL + 0.2::REAL AS float_sum;

-- 5. Modern SQL standard auto-increment
CREATE TABLE tasks (id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, title VARCHAR(200) NOT NULL);
`

---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. Integer types: SMALLINT 2 bytes, INTEGER 4 bytes, BIGINT 8 bytes. INTEGER is your default. Decimal types: NUMERIC for exact math and money. REAL and DOUBLE PRECISION for fast but inexact scientific calculations. Auto-increment: SERIAL and BIGSERIAL, or GENERATED ALWAYS AS IDENTITY for new code. Text types: VARCHAR n for limited-length strings, TEXT for unlimited. In PostgreSQL, both have the same performance. CHAR is rarely needed. Rule of thumb: when in doubt, use INTEGER for numbers, NUMERIC for money, and VARCHAR for text. In our next class, we cover Date, Time, and Boolean types! Keep the three defaults fresh: INTEGER or BIGINT IDENTITY for IDs, NUMERIC for money, and VARCHAR or TEXT for strings — zero guessing needed.

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
