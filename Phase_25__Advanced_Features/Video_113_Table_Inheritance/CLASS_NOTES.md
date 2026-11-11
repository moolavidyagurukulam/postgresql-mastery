# Table Inheritance
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Table inheritance is a unique PostgreSQL feature — you will not find it in MySQL, SQL Server, or Oracle. It lets a child table inherit all columns and constraints from a parent table, while also adding its own columns. A query on the parent table automatically includes rows from all child tables. Let us learn how this works and when to use it.


---

## 2. Core Technical Concepts & Mechanisms

### Inheritance Limitations
Important limitation — the parent's PRIMARY KEY and UNIQUE constraints are NOT inherited. Each child table needs its own. Also, foreign keys referencing the parent do not see child rows. These are the biggest gotchas with table inheritance.

| What IS Inherited | What is NOT Inherited |
| :--- | :--- |
| Column definitions | PRIMARY KEY constraints |
| Column defaults | UNIQUE constraints |
| CHECK constraints | FOREIGN KEY constraints |
| NOT NULL constraints | Indexes |
|  | Triggers (must create on each child) |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Inheritance vs Partitioning
Table inheritance versus declarative partitioning. Partitioning was introduced in PostgreSQL 10 and is the modern replacement for most inheritance use cases. Partitioning has automatic tuple routing, global indexes in newer versions, and better query optimization.

| Table Inheritance | Declarative Partitioning |
| :--- | :--- |
| Children can have extra columns | Partitions have same columns |
| No automatic row routing | Automatic row routing (PG 11+) |
| No global primary key | Global primary key support |
| Manual constraint management | Automatic constraint exclusion |
| Flexible but complex | Simpler and faster |
| Good for: type hierarchies | Good for: large table splitting |

### When to Use Table Inheritance
When should you actually use table inheritance? It is best for type hierarchies where different subtypes have different columns. For partitioning large tables by date or range, use declarative partitioning instead.

- 1 -- Yes → table inheritance (vehicles → cars, trucks, motorcycles)
- 2 -- No → use declarative partitioning instead
- 3 -- No → use partitioning (inheritance cannot enforce global PK)
- 4 -- No → use partitioning (FK cannot reference parent+children)
- 5 -- Yes → multiple inheritance from a mixin table


---

## 3. Hands-On Commands & psql Output

### Basic Table Inheritance
**Explanation:** The idea is simple. You have a parent table that defines the common columns. Child tables inherit those columns and can add their own. When you query the parent, you see rows from the parent AND all children. When you query a child, you see only that child's rows.

```sql
postgres=# -- Parent table:
postgres=# CREATE TABLE vehicles (
    id serial PRIMARY KEY,
    make text NOT NULL,
    model text NOT NULL,
    year int NOT NULL,
    price numeric(10,2)
);
postgres=# -- Child tables inherit all parent columns:
postgres=# CREATE TABLE cars (
    doors int DEFAULT 4,
    trunk_liters int
) INHERITS (vehicles);
postgres=# CREATE TABLE trucks (
    payload_kg int,
    bed_length_ft numeric(4,1)
) INHERITS (vehicles);
postgres=# CREATE TABLE motorcycles (
    engine_cc int,
    style text  -- sport, cruiser, touring
) INHERITS (vehicles);
```

### Insert and Query Inherited Tables
**Explanation:** Let us insert data and see how queries work. Rows inserted into a child table are visible both from the child and from the parent.

```sql
postgres=# INSERT INTO cars (make, model, year, price, doors, trunk_liters)
postgres-# VALUES ('Toyota', 'Camry', 2024, 28000, 4, 480),
       ('BMW', '330i', 2024, 43000, 4, 480);
postgres=# INSERT INTO trucks (make, model, year, price, payload_kg)
postgres-# VALUES ('Ford', 'F-150', 2024, 35000, 1400);
postgres=# INSERT INTO motorcycles (make, model, year, price, engine_cc, style)
postgres-# VALUES ('Honda', 'CBR600', 2024, 12000, 600, 'sport');
postgres=# -- Query parent → sees ALL rows:
postgres=# SELECT make, model, year, price FROM vehicles;
  make  |  model  | year |  price
postgres=# --------+---------+------+---------
 Toyota | Camry   | 2024 | 28000
 BMW    | 330i    | 2024 | 43000
 Ford   | F-150   | 2024 | 35000
 Honda  | CBR600  | 2024 | 12000
postgres=# -- Query child → sees ONLY that child:
postgres=# SELECT * FROM cars;
  make  | model | year | price  | doors | trunk_liters
postgres=# --------+-------+------+--------+-------+--------------
 Toyota | Camry | 2024 | 28000  |   4   | 480
```

### The ONLY Keyword — Exclude Children
**Explanation:** The ONLY keyword restricts a query to just the parent table, excluding children. This is important when you want to query or modify only the parent.

```sql
postgres=# -- Without ONLY: parent + all children
postgres=# SELECT count(*) FROM vehicles;
 count
postgres=# -------
     4
postgres=# -- With ONLY: just the parent table
postgres=# SELECT count(*) FROM ONLY vehicles;
 count
postgres=# -------
     0
postgres=# -- (We inserted into children, not the parent)
postgres=# -- Insert directly into parent:
postgres=# INSERT INTO vehicles (make, model, year, price)
postgres-# VALUES ('Generic', 'Vehicle', 2024, 10000);
postgres=# SELECT count(*) FROM ONLY vehicles;
 count
postgres=# -------
     1
postgres=# -- ONLY works with UPDATE and DELETE too:
postgres=# DELETE FROM ONLY vehicles WHERE make = 'Generic';
```

### tableoid — Which Table Owns Each Row?
**Explanation:** You can find out which table a row actually lives in using the tableoid system column. This tells you the actual table for each row when querying the parent.

```sql
postgres=# -- Use tableoid to see which table each row is from:
postgres=# SELECT tableoid::regclass AS source_table,
       make, model
postgres-# FROM vehicles;
 source_table |  make  |  model
postgres=# --------------+--------+---------
 cars         | Toyota | Camry
 cars         | BMW    | 330i
 trucks       | Ford   | F-150
 motorcycles  | Honda  | CBR600
postgres=# -- Count by table:
postgres=# SELECT tableoid::regclass AS source_table,
       count(*)
postgres-# FROM vehicles
postgres-# GROUP BY tableoid;
 source_table | count
postgres=# --------------+-------
 cars         |     2
 trucks       |     1
 motorcycles  |     1
```

### Adding Constraints to Children
**Explanation:** This means you must create primary keys and indexes on each child table separately. The id sequence is shared because the default value expression is inherited, but uniqueness is not enforced across tables.

```sql
postgres=# -- Each child needs its own PRIMARY KEY:
postgres=# ALTER TABLE cars ADD PRIMARY KEY (id);
postgres=# ALTER TABLE trucks ADD PRIMARY KEY (id);
postgres=# ALTER TABLE motorcycles ADD PRIMARY KEY (id);
postgres=# -- Each child needs its own indexes:
postgres=# CREATE INDEX idx_cars_make ON cars (make);
postgres=# CREATE INDEX idx_trucks_make ON trucks (make);
postgres=# CREATE INDEX idx_motorcycles_make ON motorcycles (make);
postgres=# -- WARNING: id can duplicate across tables!
postgres=# -- cars.id=1 and trucks.id=1 can both exist
postgres=# -- The parent's sequence is shared, but
postgres=# -- uniqueness is NOT enforced globally
```

### Multiple Inheritance
**Explanation:** A child table can inherit from multiple parents. If the parents share column names, they must have the same data type. The child gets the merged set of all columns.

```sql
postgres=# CREATE TABLE auditable (
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by text
);
postgres=# CREATE TABLE taggable (
    tags text[] DEFAULT '{}'
);
postgres=# -- Inherit from both:
postgres=# CREATE TABLE documents (
    id serial PRIMARY KEY,
    title text NOT NULL,
    content text
) INHERITS (auditable, taggable);
postgres=# -- documents has: id, title, content,
postgres=# --   created_at, updated_at, created_by, tags
\d documents
    Column    |           Type
postgres=# --------------+--------------------------
 created_at   | timestamp with time zone
 updated_at   | timestamp with time zone
 created_by   | text
 tags         | text[]
 id           | integer
 title        | text
 content      | text
```

### ALTER TABLE — Add/Remove Inheritance
**Explanation:** You can add or remove inheritance after table creation. NO INHERIT detaches a child. INHERIT attaches a table as a child — but the table must already have all the parent's columns with matching types.

```sql
postgres=# -- Remove inheritance (keeps data and columns):
postgres=# ALTER TABLE cars NO INHERIT vehicles;
postgres=# -- Now cars is standalone:
postgres=# SELECT count(*) FROM vehicles;  -- no cars rows
postgres=# SELECT count(*) FROM cars;      -- cars still has data
postgres=# -- Re-attach:
postgres=# ALTER TABLE cars INHERIT vehicles;
postgres=# -- cars rows visible through vehicles again
postgres=# -- Attach an existing table as child:
postgres=# CREATE TABLE boats (
    id serial PRIMARY KEY,
    make text NOT NULL,
    model text NOT NULL,
    year int NOT NULL,
    price numeric(10,2),
    hull_type text
);
postgres=# ALTER TABLE boats INHERIT vehicles;
postgres=# -- boats must have all columns from vehicles
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Table inheritance lets child tables inherit columns and CHECK constraints from parents. Query the parent to see all rows; use ONLY to see just the parent. tableoid identifies which child owns each row. Primary keys, unique constraints, indexes, and foreign keys are NOT inherited — create them on each child. Use declarative partitioning instead for splitting large tables. Inheritance is best for type hierarchies with different columns per subtype. In the next class, we learn LISTEN and NOTIFY — real-time notifications between database sessions.

- **INHERITS (parent): child gets all parent columns**
- **Query parent: sees parent + all children rows**
- **ONLY parent: sees just parent rows**
- **tableoid::regclass: identifies source table per row**
- **NOT inherited: PK, UNIQUE, FK, indexes, triggers**
- **Multiple inheritance: INHERITS (parent1, parent2)**
- **ALTER TABLE child NO INHERIT parent: detach**
- **ALTER TABLE child INHERIT parent: attach**
- **Inheritance for type hierarchies (different columns)**
- **Partitioning for large table splitting (same columns)**
- **Next: LISTEN & NOTIFY**


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
