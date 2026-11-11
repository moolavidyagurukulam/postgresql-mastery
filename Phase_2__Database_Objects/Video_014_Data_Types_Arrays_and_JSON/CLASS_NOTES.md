# Data Types Part 3: Arrays & JSON
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 16, Class 17
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Today we cover two powerful PostgreSQL features that many other databases do not have ... arrays and JSON. ... Arrays let you store multiple values in a single column. JSON and JSONB let you store flexible, document-style data. These features are what make PostgreSQL unique ... it combines the reliability of a relational database with the flexibility of a document store. ... Let us dive in!


---

## 2. Core Technical Concepts & Mechanisms

### What are Arrays?
Let us start with arrays. ... In most databases, one column holds one value. But in PostgreSQL, a column can hold an array of values. ... Why is this useful? Imagine a products table where each product has multiple tags. Without arrays, you need a separate tags table and a join. With arrays, you store the tags right in the product row. ... Any data type can be an array. INTEGER array, TEXT array, even BOOLEAN array. You declare it by adding square brackets after the type name.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | A column that holds a list of values |
| **Syntax** | INTEGER[], TEXT[], VARCHAR(100)[] |
| **Example** | tags TEXT[] → {'electronics','sale','new'} |
| **Any type** | Works with integers, text, dates, booleans, etc. |
| **Use when** | Small lists that belong to the row (tags, skills, colors) |

**Notes:**
- No separate table needed for simple lists!

### JSON vs JSONB — Always Use JSONB
Now let us move to JSON. ... PostgreSQL has two JSON types: JSON and JSONB. ... JSON stores the data as plain text. It preserves formatting, white space, and duplicate keys. Every time you query it, PostgreSQL has to parse the text. ... JSONB stores the data in a binary format. It is faster to query, supports indexing, and is what you should use 99 percent of the time. ... Think of it this way. JSON is for storing. JSONB is for storing AND querying. Always use JSONB unless you have a specific reason to keep the original formatting.

| JSON | JSONB (recommended) |
| :--- | :--- |
| Stored as plain text | Stored as binary (pre-parsed) |
| Preserves formatting & key order | No formatting preserved |
| Allows duplicate keys | No duplicate keys (last wins) |
| Slower to query (parsed every time) | FASTER to query |
| Cannot be indexed | Supports GIN indexes |
|  | Use this 99% of the time! |

### JSONB Operators Cheat Sheet
Here is a cheat sheet of all the JSONB operators you need to know.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a cheat sheet of all the JSONB operators you need to know |

### When to Use Arrays vs JSONB vs Columns
When should you use arrays and JSON? ... Use arrays for: short lists that belong to the row ... tags, skills, colors, phone numbers. Keep arrays small. If the list grows large or needs its own attributes, use a separate table instead. ... Use JSONB for: flexible or schema-less data. User settings, API responses, metadata that varies per row. JSONB is great when different rows have different structures. ... Do NOT use JSONB for everything. If the data has a consistent structure, use regular columns. They are faster and easier to index.

| Use Arrays / JSONB | Use Regular Columns |
| :--- | :--- |
| Arrays: tags, skills, colors (short lists) | Data has consistent structure |
| JSONB: user settings, API responses | You query/filter on it frequently |
| JSONB: metadata that varies per row | You need foreign key constraints |
| JSONB: schema-less / flexible data | Performance is critical |
| JSONB: nested documents | The data fits relational modeling |


---

## 3. Hands-On Commands & psql Output

### Creating & Inserting Arrays
**Explanation:** Let me create a table with an array column and insert some data. ... The tags column is TEXT array. To insert array values, use curly braces inside single quotes. ... You can also use the ARRAY constructor with square brackets. Both work the same way.

```sql
practice=# CREATE TABLE products (id SERIAL PRIMARY KEY, name VARCHAR(100), tags TEXT[]);
CREATE TABLE

-- Insert with curly brace syntax
practice=# INSERT INTO products (name, tags) VALUES ('Laptop', '{electronics,computers,sale}');
INSERT 0 1

-- Insert with ARRAY constructor
practice=# INSERT INTO products (name, tags) VALUES ('Headphones', ARRAY['electronics','audio','wireless']);
INSERT 0 1

practice=# INSERT INTO products (name, tags) VALUES ('Notebook', ARRAY['stationery','paper']);
INSERT 0 1

practice=# SELECT * FROM products;
 id |    name     |            tags
----+-------------+-----------------------------
  1 | Laptop      | {electronics,computers,sale}
  2 | Headphones  | {electronics,audio,wireless}
  3 | Notebook    | {stationery,paper}
```

### Querying Arrays
**Explanation:** Querying arrays is where it gets interesting. ... Use square brackets to access a specific element. tags subscript 1 gets the first element. Note ... PostgreSQL arrays start at index 1, not 0. ... To check if an array contains a value, use the ANY operator. WHERE electronics equals ANY tags finds all products tagged with electronics. ... You can also use the contains operator, at sign greater than. WHERE tags contains ARRAY electronics. ... The unnest function expands an array into rows. Very useful for joins and aggregation.

```sql
-- Access element by index (starts at 1!)
practice=# SELECT name, tags[1] AS first_tag FROM products;
    name     | first_tag
-------------+-------------
 Laptop      | electronics
 Headphones  | electronics
 Notebook    | stationery

-- Find products with a specific tag (ANY)
practice=# SELECT name FROM products WHERE 'sale' = ANY(tags);
  name
--------
 Laptop

-- Contains operator (@>)
practice=# SELECT name FROM products WHERE tags @> ARRAY['electronics'];
    name
------------
 Laptop
 Headphones

-- Unnest: expand array into rows
practice=# SELECT name, unnest(tags) AS tag FROM products WHERE id = 1;
  name  |     tag
--------+-------------
 Laptop | electronics
 Laptop | computers
 Laptop | sale
```

### Modifying Arrays
**Explanation:** You can also modify arrays. ... Use array_append to add an element. ... Use array_remove to remove one. ... Use array_cat to merge two arrays. ... You can update a specific element by index. UPDATE products SET tags subscript 3 equals new_value.

```sql
-- Append an element
practice=# UPDATE products SET tags = array_append(tags, 'premium') WHERE name = 'Laptop';
UPDATE 1

-- Remove an element
practice=# UPDATE products SET tags = array_remove(tags, 'sale') WHERE name = 'Laptop';
UPDATE 1

-- Check array length
practice=# SELECT name, array_length(tags, 1) AS tag_count FROM products;
    name     | tag_count
-------------+-----------
 Laptop      |         3
 Headphones  |         3
 Notebook    |         2
```

### Creating & Inserting JSONB
**Explanation:** Let me create a table with a JSONB column and insert some data. ... The settings column is JSONB. We can insert any valid JSON object.

```sql
practice=# CREATE TABLE app_users (id SERIAL PRIMARY KEY, name VARCHAR(100), settings JSONB);
CREATE TABLE

practice=# INSERT INTO app_users (name, settings) VALUES ('Ravi', '{"theme": "dark", "language": "en", "notifications": {"email": true, "sms": false}}');
INSERT 0 1

practice=# INSERT INTO app_users (name, settings) VALUES ('Priya', '{"theme": "light", "language": "hi", "notifications": {"email": true, "sms": true}}');
INSERT 0 1

practice=# SELECT name, settings FROM app_users;
 name  |                          settings
-------+-----------------------------------------------------------
 Ravi  | {"theme": "dark", "language": "en", "notifications": ...}
 Priya | {"theme": "light", "language": "hi", "notifications": ...}
```

### Querying JSONB — Operators
**Explanation:** Querying JSONB uses special operators. ... The arrow operator, dash greater than, gets a JSON object by key. It returns JSON. ... The double arrow, dash dash greater than, gets the value as TEXT. This is what you usually want for comparisons. ... For nested objects, chain the arrows. settings arrow notifications arrow email gets the nested email value. ... The at sign greater than operator checks containment. WHERE settings contains the JSON object theme dark finds users with dark theme.

```sql
-- -> returns JSON object/value
practice=# SELECT name, settings->'theme' AS theme FROM app_users;
 name  | theme
-------+--------
 Ravi  | "dark"
 Priya | "light"

-- ->> returns TEXT (use for comparisons)
practice=# SELECT name FROM app_users WHERE settings->>'theme' = 'dark';
 name
------
 Ravi

-- Nested access: -> then ->>
practice=# SELECT name, settings->'notifications'->>'email' AS email_notif FROM app_users;
 name  | email_notif
-------+-------------
 Ravi  | true
 Priya | true

-- Containment (@>) — does settings contain this?
practice=# SELECT name FROM app_users WHERE settings @> '{"theme": "dark"}';
 name
------
 Ravi
```

### Modifying JSONB
**Explanation:** You can modify JSONB data with special functions. ... jsonb_set updates a specific key. Pass the path as an array, and the new value as JSONB. ... The concatenation operator, double pipe, merges two JSONB objects. This is great for adding new keys. ... The minus operator removes a key. settings minus theme removes the theme key. ... These operations create a new JSONB value. They do not modify in place.

```sql
-- Update a specific key with jsonb_set
practice=# UPDATE app_users SET settings = jsonb_set(settings, '{theme}', '"blue"') WHERE name = 'Ravi';
UPDATE 1

-- Add a new key with || (concatenation)
practice=# UPDATE app_users SET settings = settings || '{"font_size": 14}' WHERE name = 'Ravi';
UPDATE 1

-- Remove a key with - operator
practice=# UPDATE app_users SET settings = settings - 'font_size' WHERE name = 'Ravi';
UPDATE 1

-- Check if a key exists (? operator)
practice=# SELECT name FROM app_users WHERE settings ? 'language';
 name
-------
 Ravi
 Priya
```

### Indexing JSONB — GIN Index
**Explanation:** One of the biggest advantages of JSONB over JSON is indexing. ... You can create a GIN index on a JSONB column. This makes containment queries and key existence checks very fast, even on millions of rows. ... CREATE INDEX idx_settings ON app_users USING GIN settings. Now any query using the at sign greater than containment operator or the question mark key exists operator will use this index automatically.

```sql
-- Create GIN index on JSONB column
practice=# CREATE INDEX idx_settings ON app_users USING GIN (settings);
CREATE INDEX

-- These queries now use the index:
-- Containment (@>)
practice=# SELECT name FROM app_users WHERE settings @> '{"theme": "dark"}';

-- Key existence (?)
practice=# SELECT name FROM app_users WHERE settings ? 'language';

-- For specific key queries, use expression index:
practice=# CREATE INDEX idx_theme ON app_users ((settings->>'theme'));
CREATE INDEX
-- Now: WHERE settings->>'theme' = 'dark' uses the index
```

### Common Errors
**Explanation:** Common array and JSON errors. ... Error 1: malformed array literal. You used wrong syntax for array insertion. Remember ... curly braces in single quotes for array, or ARRAY constructor. ... Error 2: invalid input syntax for type json. Your JSON string is malformed. Check for missing quotes, commas, or brackets. ... Error 3: using arrow on TEXT instead of JSONB. Make sure the column type is JSONB, not TEXT. The arrow operators only work on JSON and JSONB columns.

```sql
-- ERROR: malformed array literal
practice=# INSERT INTO products (name, tags) VALUES ('Test', '[a,b,c]');
ERROR:  malformed array literal: "[a,b,c]"
-- FIX: Use '{a,b,c}' or ARRAY['a','b','c']

-- ERROR: invalid JSON
practice=# SELECT '{bad json}'::JSONB;
ERROR:  invalid input syntax for type json
-- FIX: Validate your JSON (keys need double quotes)

-- ERROR: operator does not exist: text -> text
-- FIX: Column must be JSON/JSONB type, not TEXT
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Errors
Common array and JSON errors. ... Error 1: malformed array literal. You used wrong syntax for array insertion. Remember ... curly braces in single quotes for array, or ARRAY constructor. ... Error 2: invalid input syntax for type json. Your JSON string is malformed. Check for missing quotes, commas, or brackets. ... Error 3: using arrow on TEXT instead of JSONB. Make sure the column type is JSONB, not TEXT. The arrow operators only work on JSON and JSONB columns.

```sql
-- ERROR: malformed array literal
INSERT INTO products (name, tags) VALUES ('Test', '[a,b,c]');
ERROR:  malformed array literal: "[a,b,c]"
-- FIX: Use '{a,b,c}' or ARRAY['a','b','c']

-- ERROR: invalid JSON
SELECT '{bad json}'::JSONB;
ERROR:  invalid input syntax for type json
-- FIX: Validate your JSON (keys need double quotes)

-- ERROR: operator does not exist: text -> text
-- FIX: Column must be JSON/JSONB type, not TEXT
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time! ... Exercise 1 ... Create a skills table with id, name, and skills TEXT array. Insert 3 rows with different skills. Query all people who have the skill PostgreSQL. ... Exercise 2 ... Use unnest to list all unique skills across all rows. ... Exercise 3 ... Create a configs table with id, app_name, and config JSONB. Insert 2 rows with different config structures. Query a specific nested key. ... Exercise 4 ... Add a GIN index on the config column. Use the containment operator to search. ... Exercise 5 ... Use jsonb_set to update a nested value. Use concatenation to add a new key.

1. Exercise 1: TEXT[] column → INSERT → WHERE 'PostgreSQL' = ANY(skills)
2. Exercise 2: SELECT DISTINCT unnest(skills) FROM ...
3. Exercise 3: JSONB column → INSERT → query nested keys with -> and ->>
4. Exercise 4: CREATE INDEX USING GIN → query with @> containment
5. Exercise 5: jsonb_set() to update, || to add new key


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... Arrays store multiple values in one column. Declare with TYPE square brackets. Query with subscript, ANY, contains, and unnest. ... JSON stores text, JSONB stores binary. Always use JSONB. ... JSONB operators: arrow for JSON value, double arrow for text, at sign greater than for containment, question mark for key existence. ... jsonb_set updates keys, double pipe merges, minus removes keys. ... GIN indexes make JSONB queries fast. ... Use arrays for small lists, JSONB for flexible data, and regular columns for structured data. ... In our next class, we cover special types: UUID, BYTEA, INET, and type casting!

- **Arrays: TYPE[] — use for tags, skills, short lists**
- **Query: tags[1], ANY(tags), @> contains, unnest()**
- **JSON (text) vs JSONB (binary) — ALWAYS use JSONB**
- **JSONB operators: -> (JSON), ->> (text), @> (contains), ? (exists)**
- **Modify: jsonb_set(), || (merge), - (remove key)**
- **GIN index on JSONB for fast containment queries**
- **Use JSONB for flexible data, regular columns for structured data**


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
