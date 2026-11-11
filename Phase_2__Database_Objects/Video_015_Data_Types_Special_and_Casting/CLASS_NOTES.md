# Data Types Part 4: Special Types & Casting
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 18, Class 19
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! This is the final data types class. Today we cover special types and type casting. ... Special types include UUID for unique identifiers, BYTEA for binary data, and network types like INET and CIDR for IP addresses. Then we learn type casting ... how to convert one data type to another. ... Let us finish data types strong!


---

## 2. Core Technical Concepts & Mechanisms

### UUID vs SERIAL — When to Use Each
When should you use UUID versus SERIAL?

| Use SERIAL / BIGSERIAL | Use UUID |
| :--- | :--- |
| Internal tables (not exposed to users) | IDs exposed in URLs or APIs |
| Performance matters (smaller, faster joins) | Security: unpredictable IDs |
| Sequential IDs are fine | Distributed systems / microservices |
| Single database system | Merging data from multiple databases |
| 4 bytes (INT) vs 16 bytes (UUID) | No central sequence needed |

### Special Types Reference
Here is a reference for all the special types we covered.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a reference for all the special types we covered |

### Implicit vs Explicit Casting
PostgreSQL sometimes casts types automatically. This is called implicit casting. ... For example, when you add an integer and a numeric, PostgreSQL automatically promotes the integer to numeric. ... But not all conversions are implicit. If you try to compare a text string with an integer directly, you may get an error. You need to explicitly cast one of them. ... The rule is: when in doubt, cast explicitly. It makes your code clearer and avoids surprises.

| Implicit (automatic) | Explicit (you must cast) |
| :--- | :--- |
| INTEGER + NUMERIC → NUMERIC | TEXT to INTEGER: '42'::INTEGER |
| SMALLINT + INTEGER → INTEGER | TEXT to DATE: '2026-01-01'::DATE |
| INTEGER in NUMERIC column → auto | TIMESTAMP to DATE: now()::DATE |
| Any type to TEXT (in concatenation) | INTEGER to BOOLEAN: not allowed! |
|  | TEXT to UUID: must be valid UUID format |


---

## 3. Hands-On Commands & psql Output

### UUID — Universally Unique Identifier
**Explanation:** Let us start with UUID. UUID stands for Universally Unique Identifier. It is a 128-bit number that looks like this ... a long string of hexadecimal characters separated by dashes. ... Why use UUIDs instead of SERIAL? ... SERIAL numbers are sequential and predictable. In a web application, a user could guess other user IDs by incrementing the number. UUIDs are random and unpredictable. ... UUIDs are also unique across databases. If you merge data from two databases, SERIAL IDs will clash. UUIDs will not. ... In PostgreSQL 16, you can generate UUIDs with gen_random_uuid without any extension. In older versions, you need the uuid-ossp extension.

```sql
-- Generate a random UUID (PG 13+, no extension needed)
practice=# SELECT gen_random_uuid();
           gen_random_uuid
--------------------------------------
 a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d

-- Use UUID as primary key
practice=# CREATE TABLE api_keys (id UUID DEFAULT gen_random_uuid() PRIMARY KEY, name VARCHAR(100), created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE

practice=# INSERT INTO api_keys (name) VALUES ('Production Key');
INSERT 0 1
practice=# INSERT INTO api_keys (name) VALUES ('Staging Key');
INSERT 0 1

practice=# SELECT * FROM api_keys;
                  id                  |      name       |         created_at
--------------------------------------+-----------------+----------------------------
 f47ac10b-58cc-4372-a567-0e02b2c3d479 | Production Key  | 2026-11-03 14:30:00+00
 6ba7b810-9dad-41d0-80b4-00c04fd430c8 | Staging Key     | 2026-11-03 14:30:01+00
```

### BYTEA — Binary Data
**Explanation:** BYTEA stores binary data ... raw bytes. Use it for small binary objects like hashes, encrypted values, or small files. ... For large files like images and videos, do NOT use BYTEA. Store those in the filesystem and keep the file path in the database. BYTEA is for small binary data only ... typically under a few megabytes. ... You insert BYTEA values using the hex format: backslash x followed by hex characters.

```sql
practice=# CREATE TABLE file_hashes (id SERIAL, filename VARCHAR(255), hash BYTEA);
CREATE TABLE

-- Insert binary data (hex format)
practice=# INSERT INTO file_hashes (filename, hash) VALUES ('report.pdf', '\xd41d8cd98f00b204e9800998ecf8427e');
INSERT 0 1

-- Or use digest() from pgcrypto extension
practice=# CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION
practice=# SELECT digest('hello world', 'sha256');
                              digest
------------------------------------------------------------------
 \xb94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9

-- BYTEA for small binary only!
-- Large files → store in filesystem, save path in DB
```

### INET & CIDR — Network Address Types
**Explanation:** PostgreSQL has built-in types for network addresses. ... INET stores an IP address with an optional subnet mask. It handles both IPv4 and IPv6. ... CIDR stores a network address. The difference is CIDR requires the host bits to be zero. ... MACADDR stores MAC addresses. ... These types are not just for storage. PostgreSQL can do network calculations. You can check if an IP is within a subnet using the double less than operator. This is incredibly useful for access control, geo-IP lookups, and network management.

```sql
practice=# CREATE TABLE access_log (id SERIAL, ip INET, network CIDR, visited_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE

practice=# INSERT INTO access_log (ip, network) VALUES ('192.168.1.100', '192.168.1.0/24');
INSERT 0 1
practice=# INSERT INTO access_log (ip, network) VALUES ('10.0.0.50', '10.0.0.0/8');
INSERT 0 1

-- Check if IP is in a subnet (<<  = contained within)
practice=# SELECT ip FROM access_log WHERE ip << '192.168.0.0/16';
      ip
---------------
 192.168.1.100

-- INET functions
practice=# SELECT host('192.168.1.100/24'::INET), masklen('192.168.1.100/24'::INET);
     host      | masklen
---------------+---------
 192.168.1.100 |      24
```

### Type Casting — Two Syntaxes
**Explanation:** Type casting means converting a value from one data type to another. ... PostgreSQL supports two syntaxes. The double colon syntax ... value colon colon type. For example, 42 colon colon TEXT converts the integer 42 to the string 42. ... The CAST function ... CAST open paren value AS type close paren. CAST 42 AS TEXT does the same thing. ... The double colon syntax is PostgreSQL-specific and shorter. The CAST syntax is SQL standard. Both work the same.

```sql
-- :: syntax (PostgreSQL shorthand, most common)
practice=# SELECT 42::TEXT AS num_to_text;
 num_to_text
-------------
 42

-- CAST() syntax (SQL standard)
practice=# SELECT CAST(42 AS TEXT) AS num_to_text;
 num_to_text
-------------
 42

-- Both produce the same result
-- :: is shorter and more common in PostgreSQL
-- CAST() is the SQL standard
```

### Common Casting Examples
**Explanation:** Here are the most common casting operations you will use. ... Text to integer: SELECT the string 100 cast to integer. ... Integer to numeric: useful when you need decimal precision from an integer. ... Text to date: SELECT a date string cast to date. ... Timestamp to date: truncates the time part. ... Text to boolean: use lowercase true or false. ... These come up constantly in real queries, especially when processing CSV imports or API data where everything starts as text.

```sql
-- Text to Integer
practice=# SELECT '100'::INTEGER + 50 AS result;
 result
--------
    150

-- Integer to Numeric (for decimal division)
practice=# SELECT 10::NUMERIC / 3 AS precise_div;
    precise_div
--------------------
 3.3333333333333333

-- Text to Date
practice=# SELECT '2026-12-25'::DATE AS christmas;
 christmas
------------
 2026-12-25

-- Timestamp to Date (strips time)
practice=# SELECT NOW()::DATE AS today;
   today
------------
 2026-11-03

-- Text to Boolean
practice=# SELECT 'true'::BOOLEAN, 'false'::BOOLEAN;
 bool | bool
------+------
 t    | f
```

### Common Casting Errors
**Explanation:** Common casting errors. ... Error 1: invalid input syntax. You tried to cast an invalid string. For example, hello to integer. PostgreSQL cannot convert a word to a number. ... Error 2: cannot cast type integer to uuid. Some types cannot be cast directly to others. UUID must come from a valid UUID string. ... Error 3: wrong date format. When casting text to date, use ISO format year dash month dash day. Other formats may be ambiguous.

```sql
-- ERROR: invalid input syntax
practice=# SELECT 'hello'::INTEGER;
ERROR:  invalid input syntax for type integer: "hello"

-- ERROR: cannot cast integer to uuid
practice=# SELECT 42::UUID;
ERROR:  cannot cast type integer to uuid

-- ERROR: invalid input for inet
practice=# SELECT 'not.an.ip'::INET;
ERROR:  invalid input syntax for type inet: "not.an.ip"

-- TIP: For safe casting, use a CASE or exception handling
-- Or validate data before casting
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Casting Errors
Common casting errors. ... Error 1: invalid input syntax. You tried to cast an invalid string. For example, hello to integer. PostgreSQL cannot convert a word to a number. ... Error 2: cannot cast type integer to uuid. Some types cannot be cast directly to others. UUID must come from a valid UUID string. ... Error 3: wrong date format. When casting text to date, use ISO format year dash month dash day. Other formats may be ambiguous.

```sql
-- ERROR: invalid input syntax
SELECT 'hello'::INTEGER;
ERROR:  invalid input syntax for type integer: "hello"

-- ERROR: cannot cast integer to uuid
SELECT 42::UUID;
ERROR:  cannot cast type integer to uuid

-- ERROR: invalid input for inet
SELECT 'not.an.ip'::INET;
ERROR:  invalid input syntax for type inet: "not.an.ip"

-- TIP: For safe casting, use a CASE or exception handling
-- Or validate data before casting
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time! ... Exercise 1 ... Create a table with a UUID primary key using gen_random_uuid as default. Insert 3 rows. ... Exercise 2 ... Create a table with an INET column. Insert some IP addresses. Query for IPs in the 192.168 subnet. ... Exercise 3 ... Practice casting: convert the string 42 to integer, add 8. Convert NOW to just a date. Convert the integer 100 to text and concatenate with a string. ... Exercise 4 ... Try some invalid casts and see the errors. Cast hello to integer. Cast 999 to boolean. ... Exercise 5 ... Use NUMERIC casting for precise division. Compare 10 divided by 3 as integer versus as numeric.

1. Exercise 1: UUID primary key with gen_random_uuid() → INSERT 3
2. Exercise 2: INET column → INSERT IPs → WHERE ip << '192.168.0.0/16'
3. Exercise 3: Cast '42'::INT + 8, NOW()::DATE, 100::TEXT || ' items'
4. Exercise 4: Try invalid casts → 'hello'::INT, see the errors
5. Exercise 5: Compare 10/3 vs 10::NUMERIC/3 for precise division


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... UUID ... 16-byte unique identifiers. Use gen_random_uuid in PG 16. Great for APIs and distributed systems. ... BYTEA ... raw binary data. Use for small binary only. ... INET and CIDR ... IP and network addresses with subnet operations. ... Type casting ... double colon syntax or CAST function. Use explicit casts when converting between types. ... Implicit casting happens automatically for compatible types. Explicit is needed for text to number, text to date, and similar conversions. ... And with that, Phase 2 Database Objects is complete! In Phase 3, we learn Database Design ... normalization, naming conventions, and best practices!

- **UUID: gen_random_uuid() — unique, unpredictable IDs**
- **BYTEA: binary data (small only — files go on filesystem)**
- **INET/CIDR: IP addresses with subnet operations (<<, >>)**
- **Casting: value::TYPE or CAST(value AS TYPE)**
- **Implicit: PG auto-converts compatible types**
- **Explicit: needed for TEXT→INT, TEXT→DATE, etc.**
- **Phase 2 complete! Next: Phase 3 — Database Design**


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
