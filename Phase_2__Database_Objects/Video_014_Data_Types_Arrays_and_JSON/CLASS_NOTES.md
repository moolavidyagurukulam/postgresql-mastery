# Data Types Part 3: Arrays & JSON
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 16, Class 17
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In Part 3 of Data Types, we explore two flagship PostgreSQL features that blur the line between SQL and NoSQL: Arrays and JSONB!. Imagine saving custom product tags like electronics, audio, wireless, or saving varying mobile app user preferences, without creating dozens of awkward extra columns or spinning up a second database like MongoDB. Today you will learn 1-based PostgreSQL Array indexing, ANY and unnest queries, JSON vs JSONB internals, every arrow and containment operator, GIN indexing for speed, and when NOT to overuse JSONB! Let us begin! Arrays and binary JSONB turn PostgreSQL into an astonishingly versatile multi-model engine without managing separate NoSQL clusters for simple lists or flexible metadata.

### The Problem: Dynamic Lists & Changing Schemas
Imagine you are designing tables for an e-commerce site. Every product has 3 to 5 search tags like wireless and audio, and every user has 20 custom app settings like dark mode, newsletter toggles, and webhook preferences that keep changing every sprint. If you spin up six tiny join tables or keep running ALTER TABLE migrations every week, development slows to a crawl! But if you dump everything into a plain TEXT blob, you lose fast searching and indexing!. PostgreSQL gives you two killer built-in solutions: native Arrays for short lists, and binary JSONB for indexed flexible documents.

- Lists Problem: Every product needs 3-5 tags — creating extra JOIN tables adds complexity
- Schema Problem: User preferences or API payloads gain new fields every sprint
- Bad Fix: Dumping raw comma-strings or plain TEXT kills fast SQL filtering
- PG Solution 1 (Arrays): Store typed lists (TEXT[], INT[]) right inside one row
- PG Solution 2 (JSONB): Binary JSON with fast operators & GIN indexes
- Today: Learn WHERE, WHEN & HOW to use Arrays vs JSONB vs normal columns


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Dynamic Lists & Changing Schemas
Imagine you are designing tables for an e-commerce site. Every product has 3 to 5 search tags like wireless and audio, and every user has 20 custom app settings like dark mode, newsletter toggles, and webhook preferences that keep changing every sprint. If you spin up six tiny join tables or keep running ALTER TABLE migrations every week, development slows to a crawl! But if you dump everything into a plain TEXT blob, you lose fast searching and indexing!. PostgreSQL gives you two killer built-in solutions: native Arrays for short lists, and binary JSONB for indexed flexible documents.

- Lists Problem: Every product needs 3-5 tags — creating extra JOIN tables adds complexity
- Schema Problem: User preferences or API payloads gain new fields every sprint
- Bad Fix: Dumping raw comma-strings or plain TEXT kills fast SQL filtering
- PG Solution 1 (Arrays): Store typed lists (TEXT[], INT[]) right inside one row
- PG Solution 2 (JSONB): Binary JSON with fast operators & GIN indexes
- Today: Learn WHERE, WHEN & HOW to use Arrays vs JSONB vs normal columns

### What are Arrays?
Let us start with PostgreSQL Arrays! In traditional SQL databases, every column holds strictly one atomic value, so storing three product tags or four user phone numbers forces you to create an entire extra child table and write JOINs everywhere. PostgreSQL lets you store a typed list right inside one column using square brackets after any data type, such as INTEGER[], TEXT[], or DATE[]! Use arrays whenever you have small, simple lists belonging strictly to that row like product tags, employee skills, or favorite colors, without extra attributes per item. Notice what arrays also enforce automatically: unlike dumping comma-separated values into TEXT, a TEXT[] or INTEGER[] column validates element types cleanly and indexes fast with GIN.

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
Now let us move to JSON. PostgreSQL has two JSON types: JSON and JSONB. JSON stores the data as plain text. It preserves formatting, white space, and duplicate keys. Every time you query it, PostgreSQL has to parse the text. JSONB stores the data in a binary format. It is faster to query, supports indexing, and is what you should use 99 percent of the time. Think of it this way. JSON is for storing. JSONB is for storing AND querying. Always use JSONB unless you have a specific reason to keep the original formatting. When interviews ask why PostgreSQL beat standalone document stores for many teams, pre-parsed binary JSONB with ACID transactions and GIN indexing is the exact reason.

| JSON | JSONB (recommended) |
| :--- | :--- |
| Stored as plain text | Stored as binary (pre-parsed) |
| Preserves formatting & key order | No formatting preserved |
| Allows duplicate keys | No duplicate keys (last wins) |
| Slower to query (parsed every time) | FASTER to query |
| Cannot be indexed | Supports GIN indexes |
|  | Use this 99% of the time! |

### JSONB Operators Cheat Sheet
Save this JSONB Operators Cheat Sheet in your class notes, because these seven operators handle ninety-five percent of real JSON engineering in PostgreSQL 16! Use single arrow to extract a nested JSON object so you can keep chaining, and double arrow to pull clean TEXT for WHERE filters or display. Use hash-arrow or hash-double-arrow with path arrays for deep nested JSON lookups. Use at-greater-than containment and question-mark key checks together with GIN indexes for millisecond lookups, and use double pipe to merge objects or minus to remove keys cleanly.

| Term | Meaning / Explanation |
| :--- | :--- |
| **->** | Extract JSON object/field as JSON (use to chain nested keys) |
| **->>** | Extract value as plain TEXT (use in WHERE comparisons) |
| **@>** | Containment check — fast with GIN index (settings @> '{"theme":"dark"}') |
| **?** | Key existence check — true if top-level key exists |
| **|| and -** | || merges/adds JSONB keys; - removes a key cleanly |

### When to Use Arrays vs JSONB vs Columns
One of the most important architectural decisions in PostgreSQL is knowing when NOT to cram everything into JSONB or Arrays! Use Arrays for tiny fixed-meaning lists like 3 to 10 tags or skills, and use JSONB for genuinely flexible per-row metadata, feature flags, or raw external API webhook payloads whose shape varies between customers. Never use JSONB as a lazy replacement for core business tables! Whenever every row shares predictable fields like customer_id, total_amount, or created_at, especially when you need foreign keys, NOT NULL integrity, or fast sorting, regular normalized SQL columns win on storage, speed, and data safety every single time.

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
**Explanation:** Let us create a products table with tags TEXT[] and examine the two clean insertion syntaxes in PostgreSQL! First is the curly-brace string literal, '{electronics,computers,sale}' inside single quotes, which you will often see in pg_dump backups and CSV imports. Notice how spaces or embedded quotes require extra escaping there. Second is the cleaner SQL-standard ARRAY constructor using square brackets, ARRAY['electronics','audio','wireless'], which reads clearly inside application SQL and handles embedded commas effortlessly. Let us insert three products and inspect the stored lists! Try running SELECT * FROM products right after both inserts so you see both curly-brace literals and ARRAY constructors stored cleanly inside the exact same format.

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
**Explanation:** Now look how expressive querying PostgreSQL arrays becomes in SQL! First, access an element by bracket index, like tags[1] for first_tag. Crucial rule for programmers coming from Python or Java: SQL arrays start at index 1, never zero! Here ANY checks whether 'sale' matches any item inside tags. Second, use the array contains operator at-greater-than at-greater-than containment to find every product whose tags list contains electronics, and better yet, @> can use fast GIN indexes! Third, call unnest(tags) whenever you need to expand one array row into multiple relational rows for counting or grouping.

```sql
-- 1. Element by index (1-based!) + ANY() check
practice=# SELECT name, tags[1] AS first_tag FROM products WHERE 'sale' = ANY(tags);
  name  |  first_tag
--------+-------------
 Laptop | electronics

-- 2. Contains operator (@>): fast & GIN-indexable
practice=# SELECT name FROM products WHERE tags @> ARRAY['electronics'];
    name
------------
 Laptop
 Headphones

-- 3. Unnest: expand array elements into rows
practice=# SELECT name, unnest(tags) AS tag FROM products WHERE id = 1;
  name  |     tag
--------+-------------
 Laptop | electronics
 Laptop | computers
 Laptop | sale
```

### Modifying Arrays
**Explanation:** Modifying PostgreSQL arrays is clean and atomic using built-in array functions without pulling lists out to Python or Node.js! To push a new tag onto an existing list, call array_append(tags, 'premium'), which updates Laptop cleanly from two tags or three tags without overwriting siblings. To strip a discontinued tag across rows, call array_remove(tags, 'sale'), which removes every occurrence cleanly in one UPDATE statement. And whenever your report needs item counts, call array_length(tags, 1) passing dimension 1 for standard 1D arrays, returning 3 tags for Laptop and 2 for Notebook. Notice how safely PostgreSQL handles empty results or missing values in array_remove too: if the tag isn't present on a row, PostgreSQL updates zero elements cleanly without throwing an error.

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
**Explanation:** Now let us see JSONB in action on a real user settings table!. We create app_users with settings JSONB, then store two completely different JSON documents: Ravi prefers dark mode with English and SMS off, while Priya uses light mode with Hindi and SMS enabled, even with nested notification sub-objects inside!. When PostgreSQL inserts JSONB, it immediately validates that the JSON syntax is valid, removes extra whitespace, preserves key lookup performance in binary format, and rejects malformed JSON before bad data ever enters your table. Remember one practical difference too: because JSONB stores pre-parsed keys for fast lookups, it may reorder object keys alphabetically and collapse extra spacing cleanly.

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
**Explanation:** Querying JSONB uses intuitive operators once you remember two simple rules! First, single arrow single arrow stays inside JSON and returns a JSON value with quotes around strings like '"dark"', whereas double arrow double arrow extracts plain unquoted TEXT so you can compare settings double-arrow 'theme' equals 'dark' cleanly in WHERE clauses! Second, for nested objects, chain arrows left to right: settings single-arrow notifications double-arrow email grabs 'true' cleanly for both Ravi and Priya. Third, for blazing-fast production queries, use containment at-greater-than at-greater-than containment because PostgreSQL accelerates it directly with a GIN index!

```sql
-- -> returns JSON value; ->> returns plain TEXT (for WHERE)
practice=# SELECT name, settings->'theme' AS raw_json FROM app_users WHERE settings->>'theme' = 'dark';
 name | raw_json
------+----------
 Ravi | "dark"

-- Nested access: chain -> into ->>
practice=# SELECT name, settings->'notifications'->>'email' AS email_notif FROM app_users;
 name  | email_notif
-------+-------------
 Ravi  | true
 Priya | true

-- Containment (@>) — uses GIN index!
practice=# SELECT name FROM app_users WHERE settings @> '{"theme": "dark"}';
 name
------
 Ravi
```

### Deep Nesting (#>>) & Expanding Arrays (jsonb_array_elements)
**Explanation:** Here are two real-world JSONB techniques you will reach for constantly with REST API payloads and webhooks! First, instead of chaining five arrows in a row on deeply nested objects, use the hash-double-greater-than path operator passing a key path array '{notifications,sms}' to jump straight down to any nested field and extract clean TEXT directly! Second, what if a column stores a JSON array of shopping cart line items? Pass that column to jsonb_array_elements, and PostgreSQL expands every JSON array item into its own queryable SQL row that you can filter, cast to INT or NUMERIC, or SUM cleanly!

```sql
-- Chained path extraction: #>> jumps deep into nested objects as TEXT
practice=# SELECT name, settings #>> '{notifications,sms}' AS sms_enabled FROM app_users;
 name  | sms_enabled
-------+-------------
 Ravi  | false
 Priya | true

-- Expand a JSON array inside a column into searchable SQL rows
practice=# SELECT elem->>'item' AS item, (elem->>'qty')::INT AS qty FROM jsonb_array_elements('[{"item":"Phone","qty":1},{"item":"Case","qty":2}]'::JSONB) AS elem;
 item  | qty
-------+-----
 Phone |   1
 Case  |   2
```

### Modifying JSONB
**Explanation:** PostgreSQL also gives you clean functions and operators to update JSONB fields in SQL without rewriting entire documents by hand! To update one deep or top-level key cleanly, call jsonb_set passing the document, key path '{theme}', and new JSON value '"blue"' as a JSON-encoded string. To merge or append brand-new keys onto an existing JSONB object, use the double-pipe concatenation operator double pipe, merging new key-value pairs smoothly while overwriting collisions. To strip an unwanted key cleanly, use minus minus, and use question mark question-mark to verify whether a top-level key exists! Keep in mind that SQL updates replace the whole JSONB value safely inside ACID MVCC concurrency, preventing half-written corrupted JSON objects even if power fails mid-update.

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
**Explanation:** Never skip indexing when querying JSONB on production tables past a few thousand rows, otherwise PostgreSQL has to read and unpack every single row on disk! By creating a GIN Generalized Inverted Index on settings with USING GIN, PostgreSQL indexes all keys and values inside each binary JSON document. Instantly, containment at-greater-than containment and key-existence question-mark filters drop from seconds down to milliseconds! Even better: if your application checks just ONE specific scalar field repeatedly inside WHERE, such as settings double-arrow 'theme' equals 'dark', adding a compact B-tree expression index on that exact expression stays smaller and even faster than a full GIN index.

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
**Explanation:** Here are the three classic Array and JSONB errors beginners encounter and how to solve each in seconds. Error one: malformed array literal when someone forgets curly braces inside quotes and passes square brackets like '[a,b,c]' as a string. Either write '{a,b,c}' or use the SQL ARRAY['a','b','c'] constructor. Error two: invalid input syntax for type json when single quotes or missing double quotes around JSON keys sneak in. Valid JSON strictly requires double quotes on every key and string value! Error three: operator does not exist text arrow text, simply convert that plain TEXT column to JSONB.

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
Here are the three classic Array and JSONB errors beginners encounter and how to solve each in seconds. Error one: malformed array literal when someone forgets curly braces inside quotes and passes square brackets like '[a,b,c]' as a string. Either write '{a,b,c}' or use the SQL ARRAY['a','b','c'] constructor. Error two: invalid input syntax for type json when single quotes or missing double quotes around JSON keys sneak in. Valid JSON strictly requires double quotes on every key and string value! Error three: operator does not exist text arrow text, simply convert that plain TEXT column to JSONB.

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

Practice time!. Exercise 1. Create a skills table with id, name, and skills TEXT array. Insert 3 rows with different skills. Query all people who have the skill PostgreSQL. Exercise 2. Use unnest to list all unique skills across all rows. Exercise 3. Create a configs table with id, app_name, and config JSONB. Insert 2 rows with different config structures. Query a specific nested key. Exercise 4. Add a GIN index on the config column. Use the containment operator to search. Exercise 5. Use jsonb_set to update a nested value. Use concatenation to add a new key. Running all five array and JSONB exercises inside psql—especially creating a GIN index and checking jsonb_set—cements every operator visually right away.

1. Exercise 1: TEXT[] column → INSERT → WHERE 'PostgreSQL' = ANY(skills)
2. Exercise 2: SELECT DISTINCT unnest(skills) FROM ...
3. Exercise 3: JSONB column → INSERT → query nested keys with -> and ->>
4. Exercise 4: CREATE INDEX USING GIN → query with @> containment
5. Exercise 5: jsonb_set() to update, || to add new key


---


### Answer Key — Practice Solutions

```sql
-- 1. Create skills table with TEXT[] and query 'PostgreSQL'
CREATE TABLE skills (id SERIAL, name TEXT, skills TEXT[]);
SELECT * FROM skills WHERE 'PostgreSQL' = ANY(skills);

-- 2. List all unique skills across rows
SELECT DISTINCT unnest(skills) AS skill FROM skills ORDER BY skill;

-- 3. Create configs table with JSONB and query nested key
CREATE TABLE configs (id SERIAL, app_name TEXT, config JSONB);
SELECT app_name, config->'db'->>'host' AS db_host FROM configs;

-- 4. Add GIN index and use @> containment operator
CREATE INDEX idx_configs_gin ON configs USING GIN (config);
SELECT * FROM configs WHERE config @> '{"env":"prod"}';

-- 5. Update nested value with jsonb_set & merge key with ||
UPDATE configs SET config = jsonb_set(config, '{db,port}', '5433') || '{"debug":false}'::jsonb WHERE id = 1;
```

---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. Arrays store multiple values in one column. Declare with TYPE square brackets. Query with subscript, ANY, contains, and unnest. JSON stores text, JSONB stores binary. Always use JSONB. JSONB operators: arrow for JSON value, double arrow for text, at sign greater than for containment, question mark for key existence. jsonb_set updates keys, double pipe merges, minus removes keys. GIN indexes make JSONB queries fast. Use arrays for small lists, JSONB for flexible data, and regular columns for structured data. In our next class, we cover special types: UUID, BYTEA, INET, and type casting! Remember the golden design rule at the bottom: normalize core relational tables cleanly, and bring in Arrays or JSONB thoughtfully whenever real flexibility adds genuine simplicity.

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
