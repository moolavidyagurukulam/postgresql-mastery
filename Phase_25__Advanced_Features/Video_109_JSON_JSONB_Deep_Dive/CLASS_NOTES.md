# JSON & JSONB — Deep Dive
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Almost every modern application deals with JSON — APIs return it, configuration files use it, and frontend frameworks expect it. PostgreSQL can store JSON natively and query it with powerful operators. Today we learn the two JSON data types, the operators to extract data, and the functions that create and transform JSON. Let us dive in.


---

## 2. Core Technical Concepts & Mechanisms

### json vs jsonb
PostgreSQL has two JSON types. json stores the exact text as-is — preserving whitespace, duplicate keys, and key order. jsonb stores a decomposed binary format — it removes whitespace, removes duplicate keys keeping the last value, and does not preserve key order. jsonb is almost always what you want because it supports indexing and is faster for queries.

| json (text storage) | jsonb (binary storage) |
| :--- | :--- |
| Stores exact input text | Decomposed binary format |
| Preserves whitespace | Strips whitespace |
| Preserves duplicate keys | Removes duplicates (keeps last) |
| Preserves key order | Does not preserve key order |
| Slower to query (must reparse) | Fast queries (pre-parsed) |
| Cannot be indexed for searches | Supports GIN indexing ✓ |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### JSONB Operators Reference
Here is a complete reference of all jsonb operators.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a complete reference of all jsonb operators |


---

## 3. Hands-On Commands & psql Output

### json vs jsonb — See the Difference
**Explanation:** Let us see the difference. Watch what happens to whitespace and duplicate keys with json versus jsonb.

```sql
postgres=# -- json preserves everything:
postgres=# SELECT '{"name": "Alice",  "name": "Bob"}'::json;
             json
postgres=# ----------------------------------
 {"name": "Alice",  "name": "Bob"}
postgres=# -- jsonb: strips whitespace, keeps last duplicate:
postgres=# SELECT '{"name": "Alice",  "name": "Bob"}'::jsonb;
      jsonb
postgres=# -----------------
 {"name": "Bob"}
postgres=# -- jsonb does not preserve key order:
postgres=# SELECT '{"z": 1, "a": 2, "m": 3}'::jsonb;
         jsonb
postgres=# -----------------------
 {"a": 2, "m": 3, "z": 1}
```

### Creating a Table with JSONB
**Explanation:** Let us create a table with a jsonb column and insert some data. We will use a products table where the attributes vary per product — this is the classic semi-structured data use case.

```sql
postgres=# CREATE TABLE products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    category text NOT NULL,
    attrs jsonb NOT NULL DEFAULT '{}'
);
postgres=# INSERT INTO products (name, category, attrs) VALUES
('Laptop Pro', 'electronics',
 '{"brand": "TechCo", "cpu": "i7", "ram_gb": 16,
  "storage": "512GB SSD", "colors": ["silver", "black"]}'),
('Running Shoes', 'sports',
 '{"brand": "SportX", "size": 10, "waterproof": true,
  "colors": ["red", "blue", "white"]}'),
('Coffee Maker', 'kitchen',
 '{"brand": "BrewCo", "capacity_cups": 12,
  "features": ["timer", "auto-shutoff", "grinder"]}'),
('Headphones', 'electronics',
 '{"brand": "AudioMax", "type": "over-ear",
  "wireless": true, "battery_hours": 30}');
```

### Extraction Operators: -> and ->>
**Explanation:** The arrow operator extracts a value by key and returns jsonb. The double-arrow operator extracts it as text. For nested access, use the hash-arrow and hash-double-arrow operators with a path array.

```sql
postgres=# -- -> returns jsonb (quoted):
postgres=# SELECT name, attrs->'brand' AS brand_jsonb
postgres-# FROM products;
    name     | brand_jsonb
postgres=# -------------+-------------
 Laptop Pro  | "TechCo"
postgres=# -- ->> returns text (unquoted):
postgres=# SELECT name, attrs->>'brand' AS brand_text
postgres-# FROM products;
    name     | brand_text
postgres=# -------------+------------
 Laptop Pro  | TechCo
postgres=# -- -> with integer for arrays (0-based):
postgres=# SELECT name, attrs->'colors'->0 AS first_color
postgres-# FROM products WHERE category = 'electronics';
    name     | first_color
postgres=# -------------+-------------
 Laptop Pro  | "silver"
```

### Path Operators: #> and #>>
**Explanation:** For deeper nesting, use the hash-arrow operators. They take an array of keys as a path and drill down into the JSON structure. This is cleaner than chaining multiple arrow operators.

```sql
postgres=# -- Sample nested JSON:
postgres=# SELECT '{"server": {"host": "localhost",
    "ports": {"http": 8080, "https": 443}}}'::jsonb
    #> '{server,ports,http}' AS port_jsonb;
 port_jsonb
postgres=# -----------
 8080
postgres=# -- #>> returns text:
postgres=# SELECT '{"server": {"host": "localhost",
    "ports": {"http": 8080, "https": 443}}}'::jsonb
    #>> '{server,host}' AS host_text;
 host_text
postgres=# -----------
 localhost
postgres=# -- From our products table:
postgres=# SELECT name, attrs#>>'{colors,0}' AS first_color
postgres-# FROM products;
     name      | first_color
postgres=# ---------------+-------------
 Laptop Pro    | silver
 Running Shoes | red
```

### Containment Operator: @>
**Explanation:** The containment operator at-sign greater-than checks if the left jsonb contains the right jsonb. This is one of the most useful operators — it can be indexed with GIN and is very fast for filtering.

```sql
postgres=# -- Does attrs contain {"brand": "TechCo"}?
postgres=# SELECT name FROM products
postgres-# WHERE attrs @> '{"brand": "TechCo"}';
    name
postgres=# -----------
 Laptop Pro
postgres=# -- Check for nested values:
postgres=# SELECT name FROM products
postgres-# WHERE attrs @> '{"wireless": true}';
    name
postgres=# -----------
 Headphones
postgres=# -- Check if array contains an element:
postgres=# SELECT name FROM products
postgres-# WHERE attrs @> '{"colors": ["red"]}';
     name
postgres=# --------------
 Running Shoes
postgres=# -- Reverse: <@ (is contained by)
postgres=# SELECT '{"a": 1}'::jsonb <@ '{"a": 1, "b": 2}'::jsonb;
postgres=# -- t (left is contained by right)
```

### Existence Operators: ?, ?|, ?&
**Explanation:** The existence operators check if a key exists. Question mark checks for a single key. Question mark pipe checks if any of the keys exist. Question mark ampersand checks if all keys exist.

```sql
postgres=# -- ? : key exists?
postgres=# SELECT name FROM products
postgres-# WHERE attrs ? 'wireless';
    name
postgres=# -----------
 Headphones
postgres=# -- ?| : ANY of these keys exist?
postgres=# SELECT name FROM products
postgres-# WHERE attrs ?| array['wireless', 'waterproof'];
     name
postgres=# --------------
 Running Shoes
 Headphones
postgres=# -- ?& : ALL of these keys exist?
postgres=# SELECT name FROM products
postgres-# WHERE attrs ?& array['brand', 'cpu', 'ram_gb'];
    name
postgres=# -----------
 Laptop Pro
```

### JSON Creation Functions
**Explanation:** Now let us look at JSON creation functions. jsonb_build_object creates a jsonb object from key-value pairs. jsonb_build_array creates an array. jsonb_agg aggregates rows into a JSON array. These are essential for building API responses directly in SQL.

```sql
postgres=# -- Build an object:
postgres=# SELECT jsonb_build_object(
    'name', 'Alice',
    'age', 30,
    'active', true
);
postgres=# -- {"age": 30, "name": "Alice", "active": true}
postgres=# -- Build an array:
postgres=# SELECT jsonb_build_array(1, 'two', true, null);
postgres=# -- [1, "two", true, null]
postgres=# -- Aggregate rows into JSON array:
postgres=# SELECT jsonb_agg(
    jsonb_build_object('name', name, 'category', category)
) FROM products;
postgres=# -- [{"name": "Laptop Pro", "category": "electronics"},
postgres=# --  {"name": "Running Shoes", "category": "sports"}, ...]
```

### Converting Rows to JSON
**Explanation:** The row_to_json and to_jsonb functions convert entire rows or values to JSON. This is a quick way to return query results as JSON objects for an API.

```sql
postgres=# -- Convert a row to jsonb:
postgres=# SELECT to_jsonb(p) FROM products p WHERE id = 1;
postgres=# -- {"id": 1, "name": "Laptop Pro", "category": "electronics",
postgres=# --  "attrs": {"brand": "TechCo", ...}}
postgres=# -- row_to_json (returns json, not jsonb):
postgres=# SELECT row_to_json(p) FROM products p WHERE id = 1;
postgres=# -- Convert specific columns:
postgres=# SELECT to_jsonb(row(name, category))
postgres-# FROM products WHERE id = 1;
postgres=# -- {"f1": "Laptop Pro", "f2": "electronics"}
postgres=# -- Better: use jsonb_build_object for named keys:
postgres=# SELECT jsonb_build_object(
    'product', name,
    'type', category,
    'details', attrs
) FROM products WHERE id = 1;
```

### Expanding JSON — jsonb_each, jsonb_array_elements
**Explanation:** jsonb_each and jsonb_each_text expand a JSON object into rows — one row per key-value pair. jsonb_array_elements expands an array into rows. These set-returning functions are essential for unnesting JSON data.

```sql
postgres=# -- Expand object into key-value rows:
postgres=# SELECT key, value
postgres-# FROM products,
     jsonb_each(attrs)
postgres-# WHERE name = 'Headphones';
      key       |    value
postgres=# ----------------+-----------
 battery_hours  | 30
 brand          | "AudioMax"
 type           | "over-ear"
 wireless       | true
postgres=# -- Expand array into rows:
postgres=# SELECT name, color
postgres-# FROM products,
     jsonb_array_elements_text(attrs->'colors') AS color
postgres-# WHERE attrs ? 'colors';
     name      | color
postgres=# ---------------+--------
 Laptop Pro    | silver
 Laptop Pro    | black
 Running Shoes | red
 Running Shoes | blue
 Running Shoes | white
```

### Inspection Functions
**Explanation:** jsonb_object_keys returns just the top-level keys. jsonb_typeof tells you the type of a JSON value — object, array, string, number, boolean, or null. jsonb_pretty formats JSON for human reading.

```sql
postgres=# -- Get all keys from a jsonb value:
postgres=# SELECT jsonb_object_keys(attrs)
postgres-# FROM products WHERE name = 'Laptop Pro';
 jsonb_object_keys
postgres=# -------------------
 brand
 colors
 cpu
 ram_gb
 storage
postgres=# -- Check the type of a value:
postgres=# SELECT jsonb_typeof(attrs->'ram_gb') FROM products
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- number
postgres=# SELECT jsonb_typeof(attrs->'colors') FROM products
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- array
postgres=# -- Pretty-print:
postgres=# SELECT jsonb_pretty(attrs) FROM products
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- {
postgres=# --     "brand": "TechCo",
postgres=# --     "cpu": "i7",
postgres=# --     "ram_gb": 16,
postgres=# --     ...
```

### Filtering with JSONB in WHERE
**Explanation:** Filtering with jsonb in WHERE clauses. You can filter by extracting values with the arrow operators, or by using containment with at-sign greater-than. The containment operator is much faster when you have a GIN index.

```sql
postgres=# -- Filter by extracted value (text comparison):
postgres=# SELECT name FROM products
postgres-# WHERE attrs->>'brand' = 'TechCo';
postgres=# -- Filter by numeric value (must cast):
postgres=# SELECT name FROM products
postgres-# WHERE (attrs->>'ram_gb')::int >= 16;
postgres=# -- Filter by boolean:
postgres=# SELECT name FROM products
postgres-# WHERE (attrs->>'wireless')::boolean = true;
postgres=# -- Better: use containment (GIN-indexable):
postgres=# SELECT name FROM products
postgres-# WHERE attrs @> '{"wireless": true}';
postgres=# -- Containment with multiple conditions:
postgres=# SELECT name FROM products
postgres-# WHERE attrs @> '{"brand": "TechCo", "cpu": "i7"}';
```

### Beginner Trap: Quoted vs Unquoted
**Explanation:** A common beginner trap — the arrow operator returns jsonb, which includes the quotes. If you compare with equals, you must compare to a jsonb string, not a regular string. Use the double-arrow operator to get text, or cast properly.

```sql
postgres=# -- WRONG: -> returns jsonb '"TechCo"' not 'TechCo'
postgres=# SELECT name FROM products
postgres-# WHERE attrs->'brand' = 'TechCo';
postgres=# -- ERROR: operator does not exist: jsonb = text
postgres=# -- Fix 1: use ->> (returns text):
postgres=# SELECT name FROM products
postgres-# WHERE attrs->>'brand' = 'TechCo';
postgres=# -- ✓ Works!
postgres=# -- Fix 2: cast right side to jsonb:
postgres=# SELECT name FROM products
postgres-# WHERE attrs->'brand' = '"TechCo"'::jsonb;
postgres=# -- ✓ Works!
postgres=# -- Fix 3: use containment (best for indexed queries):
postgres=# SELECT name FROM products
postgres-# WHERE attrs @> '{"brand": "TechCo"}';
postgres=# -- ✓ Works and uses GIN index!
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Quoted vs Unquoted
A common beginner trap — the arrow operator returns jsonb, which includes the quotes. If you compare with equals, you must compare to a jsonb string, not a regular string. Use the double-arrow operator to get text, or cast properly.

```sql
-- WRONG: -> returns jsonb '"TechCo"' not 'TechCo'
SELECT name FROM products
WHERE attrs->'brand' = 'TechCo';
-- ERROR: operator does not exist: jsonb = text
-- Fix 1: use ->> (returns text):
SELECT name FROM products
WHERE attrs->>'brand' = 'TechCo';
-- ✓ Works!
-- Fix 2: cast right side to jsonb:
SELECT name FROM products
WHERE attrs->'brand' = '"TechCo"'::jsonb;
-- ✓ Works!
-- Fix 3: use containment (best for indexed queries):
SELECT name FROM products
WHERE attrs @> '{"brand": "TechCo"}';
-- ✓ Works and uses GIN index!
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. PostgreSQL has json that stores exact text and jsonb that stores binary — always use jsonb. The arrow operator extracts jsonb, double-arrow extracts text. The hash operators drill into nested paths. The at-sign greater-than containment operator is the fastest way to filter and supports GIN indexing. Use jsonb_build_object and jsonb_agg for creating JSON. Use jsonb_each and jsonb_array_elements for expanding. In the next class, we cover modifying JSONB, GIN indexing for JSONB, and real-world patterns.

- **Always use jsonb (not json) — binary, fast, indexable**
- **-> extracts as jsonb, ->> extracts as text**
- **#> / #>> for nested path access**
- **@> containment: fast, GIN-indexable**
- **? / ?| / ?& for key existence checks**
- **jsonb_build_object: create JSON from key-value pairs**
- **jsonb_agg: aggregate rows into JSON array**
- **jsonb_each: expand object into key-value rows**
- **jsonb_array_elements: expand array into rows**
- **jsonb_typeof: check value type**
- **->> returns text (no quotes), -> returns jsonb (quoted)**
- **Next: JSONB Practical — Modify, Index, Patterns**


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
