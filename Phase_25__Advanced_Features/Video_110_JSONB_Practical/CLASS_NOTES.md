# JSONB Practical — Modify, Index & Patterns
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we learned to read and extract from JSONB. But what about modifying it? Adding a key, changing a value, deleting a field, or merging objects? And how do we make JSONB queries fast with GIN indexes? Today we cover all of that plus real-world patterns that you will use in production.


---

## 2. Core Technical Concepts & Mechanisms

### JSONB Modification Reference
Here is a complete reference table for all jsonb modification operations.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a complete reference table for all jsonb modification operations |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### JSONB Index Decision Framework
Which index strategy should you choose? Here is a decision framework.

- 1 -- GIN with default jsonb_ops — supports @>, ?, ?|, ?&
- 2 -- GIN with jsonb_path_ops — smaller, slightly faster
- 3 -- B-tree expression index on (attrs->>'key')
- 4 -- B-tree on ((attrs->>'key')::int) with partial index
- 5 -- GIN on to_tsvector('english', attrs->>'field')
- 6 -- Combine GIN for general + B-tree for hot keys

### JSONB vs Separate Columns
Another important consideration — when to use JSONB versus separate columns. JSONB is excellent for flexible, varying attributes, but regular columns are better for data you frequently query, join on, or enforce constraints on.

| Use JSONB When | Use Columns When |
| :--- | :--- |
| Schema varies per row | Schema is stable and known |
| New attributes added often | Frequently used in WHERE/JOIN |
| Third-party data (APIs, webhooks) | Need CHECK or NOT NULL constraints |
| Audit trails and event data | Need foreign key references |
| User preferences and settings | Heavy aggregation (SUM, AVG) |
| Rarely joined or aggregated | Need strong data types |


---

## 3. Hands-On Commands & psql Output

### The || Merge Operator
**Explanation:** The double-pipe operator merges two jsonb values. If a key exists in both, the right side wins. This is the primary way to add or update keys in a jsonb column.

```sql
postgres=# -- Add a new key:
postgres=# UPDATE products
postgres=# SET attrs = attrs || '{"warranty_years": 2}'
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- Update an existing key:
postgres=# UPDATE products
postgres=# SET attrs = attrs || '{"ram_gb": 32}'
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- Verify:
postgres=# SELECT attrs->>'ram_gb', attrs->>'warranty_years'
postgres-# FROM products WHERE name = 'Laptop Pro';
 ram_gb | warranty_years
postgres=# --------+----------------
 32     | 2
postgres=# -- Merge two objects:
postgres=# SELECT '{"a": 1, "b": 2}'::jsonb ||
       '{"b": 99, "c": 3}'::jsonb;
postgres=# -- {"a": 1, "b": 99, "c": 3}  (b overwritten)
```

### The - Remove Operator
**Explanation:** The minus operator removes keys or array elements. Use it with a text key name to remove that key, or with an integer to remove an array element by index.

```sql
postgres=# -- Remove a key:
postgres=# UPDATE products
postgres=# SET attrs = attrs - 'warranty_years'
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- Remove multiple keys:
postgres=# SELECT '{"a": 1, "b": 2, "c": 3}'::jsonb
       - 'a' - 'c';
postgres=# -- {"b": 2}
postgres=# -- Remove by text array:
postgres=# SELECT '{"a": 1, "b": 2, "c": 3}'::jsonb
       - array['a', 'c'];
postgres=# -- {"b": 2}
postgres=# -- Remove array element by index:
postgres=# SELECT '["red", "blue", "green"]'::jsonb - 1;
postgres=# -- ["red", "green"]  (removed index 1 = "blue")
postgres=# -- Remove nested key with #- path:
postgres=# SELECT '{"a": {"b": 1, "c": 2}}'::jsonb #- '{a,b}';
postgres=# -- {"a": {"c": 2}}
```

### jsonb_set — Update at Path
**Explanation:** jsonb_set is the function for updating values at specific paths — including nested paths. It takes the target jsonb, a path array, the new value, and an optional create_if_missing flag.

```sql
postgres=# -- Update a nested value:
postgres=# SELECT jsonb_set(
    '{"server": {"host": "old.com", "port": 5432}}'::jsonb,
    '{server,host}',
    '"new.com"'::jsonb
);
postgres=# -- {"server": {"host": "new.com", "port": 5432}}
postgres=# -- Add a new nested key (create_if_missing = true):
postgres=# SELECT jsonb_set(
    '{"server": {"host": "new.com"}}'::jsonb,
    '{server,port}',
    '8080'::jsonb,
    true  -- create if missing
);
postgres=# -- {"server": {"host": "new.com", "port": 8080}}
postgres=# -- Update in a table:
postgres=# UPDATE products
postgres=# SET attrs = jsonb_set(attrs, '{brand}', '"TechCo Pro"')
postgres-# WHERE name = 'Laptop Pro';
```

### Modifying Arrays in JSONB
**Explanation:** To add an element to an array inside jsonb, use the double-pipe operator on the extracted array, or use jsonb_insert which lets you specify the exact position.

```sql
postgres=# -- Append to array using || and jsonb_set:
postgres=# UPDATE products
postgres=# SET attrs = jsonb_set(
    attrs,
    '{colors}',
    (attrs->'colors') || '"gold"'::jsonb
)
postgres-# WHERE name = 'Laptop Pro';
postgres=# -- colors: ["silver", "black", "gold"]
postgres=# -- jsonb_insert: insert at specific position:
postgres=# SELECT jsonb_insert(
    '["a", "b", "d"]'::jsonb,
    '{2}',          -- insert at index 2
    '"c"'::jsonb    -- the value
);
postgres=# -- ["a", "b", "c", "d"]
postgres=# -- Insert AFTER a position:
postgres=# SELECT jsonb_insert(
    '["a", "b", "d"]'::jsonb,
    '{1}',
    '"x"'::jsonb,
    true  -- after = true
);
postgres=# -- ["a", "b", "x", "d"]
```

### GIN Index on JSONB
**Explanation:** Now the critical part — indexing JSONB for fast queries. GIN supports two operator classes for jsonb. The default jsonb_ops supports containment, existence, and key-value queries. The alternative jsonb_path_ops only supports containment but is smaller and sometimes faster.

```sql
postgres=# -- Default GIN (jsonb_ops): supports @>, ?, ?|, ?&
postgres=# CREATE INDEX idx_products_attrs
postgres-# ON products USING GIN (attrs);
postgres=# -- Now these queries use the index:
postgres=# SELECT name FROM products
postgres-# WHERE attrs @> '{"brand": "TechCo"}';
postgres=# -- ✓ Bitmap Index Scan
postgres=# SELECT name FROM products
postgres-# WHERE attrs ? 'wireless';
postgres=# -- ✓ Bitmap Index Scan
postgres=# -- jsonb_path_ops: only @>, smaller index:
postgres=# CREATE INDEX idx_products_attrs_path
postgres-# ON products USING GIN (attrs jsonb_path_ops);
postgres=# -- ✓ Supports: attrs @> '{"brand": "TechCo"}'
postgres=# -- ✗ Does NOT support: attrs ? 'wireless'
```

### Expression Index on Specific Key
**Explanation:** You can also create a B-tree or expression index on a specific extracted value. This is useful when you frequently filter or sort by one particular JSON key.

```sql
postgres=# -- B-tree index on a specific key:
postgres=# CREATE INDEX idx_products_brand
postgres-# ON products ((attrs->>'brand'));
postgres=# -- Now this is fast:
postgres=# SELECT name FROM products
postgres-# WHERE attrs->>'brand' = 'TechCo';
postgres=# -- Uses idx_products_brand
postgres=# -- Numeric expression index:
postgres=# CREATE INDEX idx_products_ram
postgres-# ON products (((attrs->>'ram_gb')::int))
postgres-# WHERE attrs ? 'ram_gb';  -- partial index
postgres=# -- Fast range query:
postgres=# SELECT name FROM products
postgres-# WHERE (attrs->>'ram_gb')::int >= 16
postgres-# AND attrs ? 'ram_gb';
```

### Pattern 1: Application Settings
**Explanation:** Let us look at real-world pattern number one: storing application settings. Each user has different settings, and new settings can be added without schema changes.

```sql
postgres=# CREATE TABLE user_settings (
    user_id int PRIMARY KEY REFERENCES users(id),
    settings jsonb NOT NULL DEFAULT '{
        "theme": "light",
        "language": "en",
        "notifications": true,
        "items_per_page": 25
    }'
);
postgres=# -- Update one setting:
postgres=# UPDATE user_settings
postgres=# SET settings = settings || '{"theme": "dark"}'
postgres-# WHERE user_id = 1;
postgres=# -- Read one setting with fallback:
postgres=# SELECT coalesce(
    settings->>'theme', 'light'
) AS theme
postgres-# FROM user_settings WHERE user_id = 1;
postgres=# -- Add a new setting (no ALTER TABLE needed):
postgres=# UPDATE user_settings
postgres=# SET settings = settings || '{"font_size": 14}'
postgres-# WHERE user_id = 1;
```

### Pattern 2: Audit Trail
**Explanation:** Pattern two: audit trail with JSONB. Store the old and new values of any change as JSONB. This works for any table — the JSON structure adapts to whatever columns changed.

```sql
postgres=# CREATE TABLE audit_log (
    id bigserial PRIMARY KEY,
    table_name text NOT NULL,
    record_id int NOT NULL,
    action text NOT NULL,  -- INSERT, UPDATE, DELETE
    old_data jsonb,
    new_data jsonb,
    changed_by text NOT NULL,
    changed_at timestamptz DEFAULT now()
);
postgres=# -- Index for querying specific records:
postgres=# CREATE INDEX idx_audit_record
postgres-# ON audit_log (table_name, record_id);
postgres=# -- Find all changes to a product:
postgres=# SELECT action, old_data->>'name', new_data->>'name',
       changed_at
postgres-# FROM audit_log
postgres-# WHERE table_name = 'products' AND record_id = 1
postgres-# ORDER BY changed_at DESC;
```

### Pattern 3: API Response Builder
**Explanation:** Pattern three: building API responses directly in SQL. Use jsonb_build_object and jsonb_agg to return nested JSON that your API can send directly to the frontend — no application-layer transformation needed.

```sql
postgres=# -- Build a complete API response in one query:
postgres=# SELECT jsonb_build_object(
    'status', 'success',
    'count', count(*),
    'products', jsonb_agg(
        jsonb_build_object(
            'id', id,
            'name', name,
            'brand', attrs->>'brand',
            'category', category
        ) ORDER BY name
    )
) AS response
postgres-# FROM products
postgres-# WHERE category = 'electronics';
postgres=# -- Result:
postgres=# -- {"status": "success",
postgres=# --  "count": 2,
postgres=# --  "products": [
postgres=# --    {"id": 4, "name": "Headphones", ...},
postgres=# --    {"id": 1, "name": "Laptop Pro", ...}
postgres=# --  ]}
```

### Pattern 4: Event Data (Schema-Flexible)
**Explanation:** Pattern four: event data with varying schemas. Events from different sources have different structures. JSONB handles this naturally — no need to create a column for every possible field.

```sql
postgres=# CREATE TABLE events (
    id bigserial PRIMARY KEY,
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamptz DEFAULT now()
);
postgres=# CREATE INDEX idx_events_type ON events (event_type);
postgres=# CREATE INDEX idx_events_payload ON events USING GIN (payload);
postgres=# INSERT INTO events (event_type, payload) VALUES
('user_signup',
 '{"user_id": 42, "email": "alice@example.com",
  "source": "google_ads"}'),
('purchase',
 '{"user_id": 42, "order_id": 1001,
  "amount": 99.99, "currency": "USD"}'),
('page_view',
 '{"user_id": 42, "url": "/products/laptop",
  "referrer": "google.com"}');
postgres=# -- Find high-value purchases:
postgres=# SELECT payload FROM events
postgres-# WHERE event_type = 'purchase'
postgres-# AND (payload->>'amount')::numeric > 50;
```

### Beginner Trap: Shallow Merge
**Explanation:** A common beginner trap with JSONB modification — the double-pipe operator does a shallow merge, not a deep merge. If you have nested objects and merge at the top level, the entire nested object gets replaced, not merged.

```sql
postgres=# -- Shallow merge REPLACES nested objects entirely!
SELECT
  '{"server": {"host": "a.com", "port": 5432}}'::jsonb
  || '{"server": {"port": 8080}}'::jsonb;
postgres=# -- {"server": {"port": 8080}}
postgres=# -- host is GONE! The entire 'server' was replaced.
postgres=# -- Fix: use jsonb_set for nested updates:
postgres=# SELECT jsonb_set(
    '{"server": {"host": "a.com", "port": 5432}}'::jsonb,
    '{server,port}',
    '8080'::jsonb
);
postgres=# -- {"server": {"host": "a.com", "port": 8080}}
postgres=# -- host is preserved! Only port changed.
postgres=# -- Rule: || for top-level keys
postgres=# --       jsonb_set for nested paths
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Shallow Merge
A common beginner trap with JSONB modification — the double-pipe operator does a shallow merge, not a deep merge. If you have nested objects and merge at the top level, the entire nested object gets replaced, not merged.

```sql
-- Shallow merge REPLACES nested objects entirely!
SELECT
  '{"server": {"host": "a.com", "port": 5432}}'::jsonb
  || '{"server": {"port": 8080}}'::jsonb;
-- {"server": {"port": 8080}}
-- host is GONE! The entire 'server' was replaced.
-- Fix: use jsonb_set for nested updates:
SELECT jsonb_set(
    '{"server": {"host": "a.com", "port": 5432}}'::jsonb,
    '{server,port}',
    '8080'::jsonb
);
-- {"server": {"host": "a.com", "port": 8080}}
-- host is preserved! Only port changed.
-- Rule: || for top-level keys
--       jsonb_set for nested paths
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Modify JSONB with double-pipe to add or update keys, minus to remove keys, and jsonb_set for nested paths. GIN indexes with jsonb_ops support all operators while jsonb_path_ops only supports containment but is smaller. Expression indexes are great for frequently queried keys. Use JSONB for flexible schema data — settings, events, audit trails, and API responses. Remember that double-pipe is a shallow merge — use jsonb_set for nested updates. In the next class, we explore Foreign Data Wrappers — querying data from other databases.

- **|| merge: add/update top-level keys (shallow!)**
- **- remove: by key name or array index**
- **#- remove: by nested path**
- **jsonb_set: update nested paths safely**
- **jsonb_insert: add to arrays at position**
- **GIN jsonb_ops: @>, ?, ?|, ?& (default, recommended)**
- **GIN jsonb_path_ops: only @> (smaller index)**
- **Expression index: B-tree on (attrs->>'key')**
- **Patterns: settings, audit trail, API responses, events**
- **|| is shallow merge — jsonb_set for nested changes**
- **JSONB for flexible schema, columns for stable schema**
- **Next: Foreign Data Wrappers**


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
