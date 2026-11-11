# hstore — Key-Value Data Type
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Sometimes you need to store flexible key-value pairs — product attributes, user preferences, configuration settings — without creating a column for each one. hstore is a lightweight key-value data type built right into PostgreSQL. It is simpler than JSONB, faster for basic key-value operations, and perfect for metadata and tags. Let us learn how to use it.


---

## 2. Core Technical Concepts & Mechanisms

### hstore vs JSONB
hstore stores a set of key-value pairs where both keys and values are text strings. Think of it as a simple dictionary or hash map inside a single column. It existed long before JSONB and is still useful when you only need flat key-value storage without nesting.

| hstore | JSONB |
| :--- | :--- |
| Flat key-value pairs only | Full JSON structure |
| Keys and values are text | Supports nested objects |
| No nesting or arrays | Supports arrays, numbers, booleans |
| Simpler syntax | More complex operators |
| Faster for simple lookups | Better for hierarchical data |
| Smaller storage for flat data | Industry standard format |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### hstore Operators Reference
Here is a reference of all hstore operators. The arrow extracts a value, the question mark checks existence, the at-greater-than checks containment, and the double-pipe merges.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a reference of all hstore operators. The arrow extracts a value, the question mark checks existence, the at-greater-tha... |


---

## 3. Hands-On Commands & psql Output

### Installing hstore
**Explanation:** Install hstore — it is a trusted contrib extension. No restart needed.

```sql
postgres=# -- Install (trusted — non-superuser can install):
postgres=# CREATE EXTENSION hstore;
postgres=# -- Verify:
\dx hstore
  Name  | Version |  Schema  |     Description
postgres=# --------+---------+----------+---------------------
 hstore | 1.8     | public   | data type for
        |         |          | (key, value) pairs
postgres=# -- Basic hstore literal:
postgres=# SELECT 'color => red, size => large'::hstore;
postgres=# -- "color"=>"red", "size"=>"large"
postgres=# -- Keys and values are always text:
postgres=# SELECT 'price => 29.99, stock => 100'::hstore;
postgres=# -- "price"=>"29.99", "stock"=>"100"
postgres=# -- (stored as text strings, not numbers)
```

### Practical: Products with Flexible Attributes
**Explanation:** Create a table with an hstore column. Let us build a products table where different products have different attributes — a shirt has size and color, a laptop has RAM and storage.

```sql
postgres=# CREATE TABLE products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    category text,
    attributes hstore
);
postgres=# INSERT INTO products (name, category, attributes) VALUES
('Cotton T-Shirt', 'Clothing',
  'color => blue, size => L, material => cotton'),
('Running Shoes', 'Footwear',
  'color => black, size => 10, brand => Nike'),
('Laptop Pro', 'Electronics',
  'ram => 16GB, storage => 512GB, cpu => i7'),
('Wireless Mouse', 'Electronics',
  'color => white, dpi => 1600, wireless => true');
postgres=# SELECT name, attributes FROM products;
postgres=# -- Cotton T-Shirt | "color"=>"blue","size"=>"L",...
postgres=# -- Laptop Pro     | "cpu"=>"i7","ram"=>"16GB",...
```

### Accessing Values — -> and ? Operators
**Explanation:** Access values with the arrow operator. A single arrow extracts one value by key. The question mark checks if a key exists. These are the most common hstore operations.

```sql
postgres=# -- Get a single value by key:
postgres=# SELECT name, attributes -> 'color' AS color
postgres-# FROM products;
postgres=# -- Cotton T-Shirt | blue
postgres=# -- Running Shoes  | black
postgres=# -- Laptop Pro     | NULL (no 'color' key)
postgres=# -- Wireless Mouse | white
postgres=# -- Check if a key exists:
postgres=# SELECT name FROM products
postgres-# WHERE attributes ? 'color';
postgres=# -- Cotton T-Shirt, Running Shoes, Wireless Mouse
postgres=# -- Check if ANY of these keys exist:
postgres=# SELECT name FROM products
postgres-# WHERE attributes ?| ARRAY['ram', 'cpu'];
postgres=# -- Laptop Pro, (and any others with ram or cpu)
postgres=# -- Check if ALL of these keys exist:
postgres=# SELECT name FROM products
postgres-# WHERE attributes ?& ARRAY['color', 'size'];
postgres=# -- Cotton T-Shirt, Running Shoes
```

### Filtering by Key-Value Pairs
**Explanation:** Filter by value — use the arrow operator in WHERE clauses. You can find all blue products, all products with a specific brand, or any combination of key-value conditions.

```sql
postgres=# -- Find blue products:
postgres=# SELECT name FROM products
postgres-# WHERE attributes -> 'color' = 'blue';
postgres=# -- Cotton T-Shirt
postgres=# -- Find electronics with 16GB RAM:
postgres=# SELECT name FROM products
postgres-# WHERE category = 'Electronics'
postgres-# AND attributes -> 'ram' = '16GB';
postgres=# -- Laptop Pro
postgres=# -- Contains operator (@>) — check for key-value pair:
postgres=# SELECT name FROM products
postgres-# WHERE attributes @> 'color => black';
postgres=# -- Running Shoes
postgres=# -- Contains multiple pairs:
postgres=# SELECT name FROM products
postgres-# WHERE attributes @> 'color => blue, size => L';
postgres=# -- Cotton T-Shirt
postgres=# -- Contained by (<@) — reverse of @>:
postgres=# SELECT name FROM products
postgres-# WHERE 'color => blue' <@ attributes;
postgres=# -- Cotton T-Shirt
```

### Modifying hstore Data
**Explanation:** Modify hstore values. The concatenation operator merges or updates key-value pairs. The delete operator removes keys. You can also use hstore functions for more complex modifications.

```sql
postgres=# -- Add/update keys with || (merge):
postgres=# UPDATE products
postgres=# SET attributes = attributes || 'weight => 200g'
postgres-# WHERE name = 'Cotton T-Shirt';
postgres=# -- Update existing key:
postgres=# UPDATE products
postgres=# SET attributes = attributes || 'color => red'
postgres-# WHERE name = 'Cotton T-Shirt';
postgres=# -- color changed from blue to red
postgres=# -- Delete a key:
postgres=# UPDATE products
postgres=# SET attributes = delete(attributes, 'weight')
postgres-# WHERE name = 'Cotton T-Shirt';
postgres=# -- Delete multiple keys:
postgres=# UPDATE products
postgres=# SET attributes = delete(attributes, ARRAY['weight', 'material'])
postgres-# WHERE name = 'Cotton T-Shirt';
postgres=# -- Remove a key with - operator:
postgres=# UPDATE products
postgres=# SET attributes = attributes - 'dpi'
postgres-# WHERE name = 'Wireless Mouse';
```

### hstore Functions
**Explanation:** Useful hstore functions. akeys and avals return arrays of all keys and values. each expands key-value pairs into rows. hstore_to_json converts to JSON format. These let you work with hstore data in flexible ways.

```sql
postgres=# -- Get all keys as array:
postgres=# SELECT akeys(attributes) FROM products
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- {cpu,ram,storage}
postgres=# -- Get all values as array:
postgres=# SELECT avals(attributes) FROM products
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- {i7,16GB,512GB}
postgres=# -- Expand to rows (key, value):
postgres=# SELECT (each(attributes)).* FROM products
postgres-# WHERE name = 'Laptop Pro';
postgres=# --  key     | value
postgres=# --  cpu     | i7
postgres=# --  ram     | 16GB
postgres=# --  storage | 512GB
postgres=# -- Convert to JSON:
postgres=# SELECT hstore_to_json(attributes) FROM products
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- {"cpu": "i7", "ram": "16GB", "storage": "512GB"}
postgres=# -- Count of key-value pairs:
postgres=# SELECT name, array_length(akeys(attributes), 1) AS num_attrs
postgres-# FROM products;
```

### Creating hstore Values
**Explanation:** Create hstore from different sources — from arrays, from rows, and from two parallel arrays. You can also convert between hstore and other formats like JSON and records.

```sql
postgres=# -- From text literal:
postgres=# SELECT 'a => 1, b => 2, c => 3'::hstore;
postgres=# -- From two arrays (keys + values):
postgres=# SELECT hstore(
    ARRAY['color', 'size', 'weight'],
    ARRAY['red', 'M', '150g']
);
postgres=# -- "color"=>"red", "size"=>"M", "weight"=>"150g"
postgres=# -- From a set of key-value pairs:
postgres=# SELECT hstore(ARRAY[
    ['color', 'red'],
    ['size', 'M'],
    ['weight', '150g']
]);
postgres=# -- From record:
postgres=# SELECT hstore(ROW('Alice', 30, 'admin'));
postgres=# -- "f1"=>"Alice", "f2"=>"30", "f3"=>"admin"
postgres=# -- NULL values are supported:
postgres=# SELECT 'color => red, size => NULL'::hstore;
postgres=# -- "color"=>"red", "size"=>NULL
```

### Indexing hstore Columns
**Explanation:** Index hstore columns for fast queries. A GIN index supports the containment, existence, and key-value operators. A B-tree index on a specific extracted key also works for targeted searches.

```sql
postgres=# -- GIN index (supports @>, ?, ?|, ?&):
postgres=# CREATE INDEX idx_products_attrs ON products
postgres-# USING gin (attributes);
postgres=# -- Now these queries use the index:
postgres=# SELECT name FROM products
postgres-# WHERE attributes @> 'color => blue';
postgres=# -- Uses GIN index
postgres=# SELECT name FROM products
postgres-# WHERE attributes ? 'ram';
postgres=# -- Uses GIN index
postgres=# -- Expression index on a specific key:
postgres=# CREATE INDEX idx_products_color
postgres-# ON products ((attributes -> 'color'));
postgres=# -- Fast lookup by specific key value:
postgres=# SELECT name FROM products
postgres-# WHERE attributes -> 'color' = 'blue';
postgres=# -- Uses expression index
postgres=# -- EXPLAIN to verify:
postgres=# EXPLAIN SELECT name FROM products
postgres-# WHERE attributes @> 'color => blue';
postgres=# -- Bitmap Index Scan using idx_products_attrs
```

### Use Case: User Preferences
**Explanation:** A practical use case — user preferences. Each user has different settings stored as hstore. No need to create a column for every possible preference.

```sql
postgres=# CREATE TABLE user_settings (
    user_id int PRIMARY KEY,
    preferences hstore DEFAULT ''::hstore
);
postgres=# -- Set preferences:
postgres=# INSERT INTO user_settings VALUES
(1, 'theme => dark, lang => en, notifications => on'),
(2, 'theme => light, lang => fr, font_size => 16'),
(3, 'theme => dark, lang => es, timezone => UTC');
postgres=# -- Get one preference:
postgres=# SELECT preferences -> 'theme' AS theme
postgres-# FROM user_settings WHERE user_id = 1;
postgres=# -- dark
postgres=# -- Update one preference:
postgres=# UPDATE user_settings
postgres=# SET preferences = preferences || 'font_size => 14'
postgres-# WHERE user_id = 1;
postgres=# -- Find all users with dark theme:
postgres=# SELECT user_id FROM user_settings
postgres-# WHERE preferences @> 'theme => dark';
postgres=# -- 1, 3
```

### Use Case: Tags & Metadata
**Explanation:** Another use case — tagging systems. Store tags as hstore keys with values indicating the tag type or weight. This makes tag queries fast with GIN indexes.

```sql
postgres=# CREATE TABLE articles (
    id serial PRIMARY KEY,
    title text NOT NULL,
    tags hstore
);
postgres=# INSERT INTO articles (title, tags) VALUES
('PostgreSQL Tips', 'database => primary, sql => secondary'),
('Docker Guide', 'devops => primary, containers => primary'),
('Full-Stack App', 'database => secondary, web => primary');
postgres=# -- Find articles tagged with 'database':
postgres=# SELECT title FROM articles
postgres-# WHERE tags ? 'database';
postgres=# -- PostgreSQL Tips, Full-Stack App
postgres=# -- Find articles where database is primary tag:
postgres=# SELECT title FROM articles
postgres-# WHERE tags @> 'database => primary';
postgres=# -- PostgreSQL Tips
postgres=# -- All unique tag names across all articles:
postgres=# SELECT DISTINCT skeys(tags) AS tag FROM articles
postgres-# ORDER BY tag;
postgres=# -- containers, database, devops, sql, web
```

### Beginner Trap: Text Values & Duplicate Keys
**Explanation:** A beginner trap — remember that hstore values are always text strings. If you need to do numeric comparisons, you must cast the value. Also, hstore keys are unique within one value — duplicate keys keep only the last one.

```sql
postgres=# -- TRAP: values are text — cannot compare as numbers:
postgres=# SELECT name FROM products
postgres-# WHERE attributes -> 'dpi' > '1000';
postgres=# -- WRONG! '1600' > '1000' works but '900' > '1000'
postgres=# -- is also true (text comparison: '9' > '1')
postgres=# -- FIX: cast to integer:
postgres=# SELECT name FROM products
postgres-# WHERE (attributes -> 'dpi')::int > 1000;
postgres=# -- Correct numeric comparison
postgres=# -- TRAP: duplicate keys — last one wins:
postgres=# SELECT 'a => 1, b => 2, a => 3'::hstore;
postgres=# -- "a"=>"3", "b"=>"2" — first 'a' is overwritten!
postgres=# -- TRAP: NULL key is not allowed:
postgres=# -- SELECT hstore(NULL, 'value');
postgres=# -- ERROR
postgres=# -- But NULL values are fine:
postgres=# SELECT 'key => NULL'::hstore -> 'key';
postgres=# -- NULL
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Text Values & Duplicate Keys
A beginner trap — remember that hstore values are always text strings. If you need to do numeric comparisons, you must cast the value. Also, hstore keys are unique within one value — duplicate keys keep only the last one.

```sql
-- TRAP: values are text — cannot compare as numbers:
SELECT name FROM products
WHERE attributes -> 'dpi' > '1000';
-- WRONG! '1600' > '1000' works but '900' > '1000'
-- is also true (text comparison: '9' > '1')
-- FIX: cast to integer:
SELECT name FROM products
WHERE (attributes -> 'dpi')::int > 1000;
-- Correct numeric comparison
-- TRAP: duplicate keys — last one wins:
SELECT 'a => 1, b => 2, a => 3'::hstore;
-- "a"=>"3", "b"=>"2" — first 'a' is overwritten!
-- TRAP: NULL key is not allowed:
-- SELECT hstore(NULL, 'value');
-- ERROR
-- But NULL values are fine:
SELECT 'key => NULL'::hstore -> 'key';
-- NULL
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. hstore is a lightweight key-value data type — simpler and faster than JSONB for flat data. Access values with the arrow operator, check key existence with question mark, and use containment with at-greater-than. GIN indexes make hstore queries fast. Values are always text — cast for numeric comparisons. Use hstore for preferences, tags, and metadata. Use JSONB when you need nesting or non-text values. In the next class, we explore TimescaleDB for time-series data.

- **Lightweight key-value data type**
- **Keys and values are text strings**
- **-> : extract value by key**
- **? : check key existence**
- **@> : containment check**
- **|| : merge/update pairs**
- **GIN index for fast queries**
- **Expression index for specific key lookups**
- **Cast values for numeric comparison**
- **Use for: preferences, tags, metadata**
- **Next: TimescaleDB — Time-Series Data**


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
