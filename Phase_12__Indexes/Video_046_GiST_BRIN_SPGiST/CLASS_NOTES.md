# GiST, BRIN & SP-GiST — Specialized Index Types
**Series:** PostgreSQL Mastery | **Phase:** Phase 12: Indexes | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover three more index types. GiST handles geometric data, range types, and full-text search with ranking. BRIN is a tiny index for huge tables where data is physically sorted. SP-GiST handles partitioned data like IP addresses and phone numbers. Each has a narrow sweet spot where it outperforms B-Tree dramatically. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### GiST — Generalized Search Tree
GiST — Generalized Search Tree — is a framework for building indexes on complex data types. It supports geometric data like points, boxes, circles, and polygons. It supports range types — integer ranges, date ranges, timestamp ranges. And it supports full-text search with ranking. The key difference from GIN: GiST handles overlap and proximity queries — does this circle overlap that box? Which ranges overlap this date range?

| Term | Meaning / Explanation |
| :--- | :--- |
| **Geometric** | Points, boxes, circles, polygons — overlap, contains, distance |
| **Range Types** | int4range, daterange, tsrange — overlap (&&), contains (@>) |
| **Full-Text** | tsvector — supports ranking (ts_rank), unlike GIN |
| **Operators** | &&(overlap), @>(contains), <->(distance), <<(left of) |
| **vs GIN** | GiST: lossy, smaller, supports proximity. GIN: exact, faster search |

**Notes:**
- GiST is lossy: may need to recheck the table row
- Essential for PostGIS (spatial data)

### BRIN — Block Range Index
Now BRIN — Block Range Index. BRIN is the smallest index type. Instead of indexing every row, it stores the minimum and maximum values for each range of physical table pages. If your table has data inserted in order — like timestamps in a log table — BRIN knows that pages 1 to 100 contain dates from January, pages 101 to 200 contain February, and so on. When you search for a specific date, it skips entire page ranges. BRIN is tiny — often 1000 times smaller than B-Tree.

| Term | Meaning / Explanation |
| :--- | :--- |
| **How** | Stores MIN/MAX per block range (default 128 pages) |
| **Size** | Tiny — often 0.1% of B-Tree size on same column |
| **Best for** | Large tables where data is physically ordered (e.g., timestamps) |
| **Requirement** | Data must be naturally correlated with physical order |
| **Not for** | Randomly ordered data (random inserts, frequent updates) |

**Notes:**
- Perfect for: log tables, time-series, append-only data
- pages_per_range: default 128, tune based on table size

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### SP-GiST — Space-Partitioned GiST
SP-GiST — Space-Partitioned Generalized Search Tree — is for data that can be divided into non-overlapping partitions. Think of IP address lookups, phone number prefixes, or quadtree spatial data. SP-GiST builds a tree where each branch divides the space into distinct regions. It is a niche index type — you will rarely create one manually, but some extensions use it internally.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Tree that divides data into non-overlapping partitions |
| **Data Types** | INET (IP addresses), text (prefix searches), points |
| **Structures** | Radix tree, quad-tree, k-d tree internally |
| **Use Case** | IP range lookups, phone number prefix matching |
| **How Common** | Rare — most use cases covered by B-Tree or GiST |

**Notes:**
- CREATE INDEX ... USING spgist (column)
- Used internally by some PostGIS operations

### Index Type Decision Framework
Here is the complete decision framework for choosing an index type. B-Tree is the default — use it unless you have a specific reason not to. Hash for equality-only on large values. GIN for searching inside arrays, JSONB, or full-text. GiST for geometric data, range types, or full-text with ranking. BRIN for huge sorted tables. SP-GiST for IP addresses and prefix searches.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the complete decision framework for choosing an index type |
| **B-Tree is the default** | use it unless you have a specific reason not to |
| **Hash for equality** | only on large values |
| **GIN for searching inside arrays** | JSONB, or full-text |
| **GiST for geometric data** | range types, or full-text with ranking |
| **Point 6** | BRIN for huge sorted tables |
| **Point 7** | SP-GiST for IP addresses and prefix searches |

### GIN vs GiST for Full-Text Search
For full-text search, both GIN and GiST work. GIN is faster for searches and exact — it finds all matching documents immediately. GiST is smaller and supports ranking with ts_rank natively. For most applications, GIN is the better choice for full-text because search speed matters more than index size. Use GiST for full-text only if you need ranking in the index scan or if index size is critical.

| GIN (Preferred) | GiST (Alternative) |
| :--- | :--- |
| Faster search (exact matches) | Slower search (lossy, rechecks rows) |
| Larger index size | Smaller index size |
| Slower to build and update | Faster to build and update |
| Better for read-heavy workloads | Better for write-heavy workloads |
| Most common choice | Supports ts_rank in index scan |

### Practice Exercises
Practice exercises: create a GiST index on a date range column, test overlap queries, try an exclusion constraint, create a BRIN index on a large ordered table, and compare BRIN vs B-Tree sizes.

- 1. Create a table with DATERANGE column
- 2. Add GiST index, search with && (overlap)
- 3. Create an exclusion constraint with GiST
- 4. Create a 500K-row log table (ordered timestamps)
- 5. Add BRIN index, compare size vs B-Tree
- 6. EXPLAIN a date range query with BRIN
- 7. Review the index type decision framework


---

## 3. Hands-On Commands & psql Output

### GiST on Range Types
**Explanation:** Let us see GiST in action with range types. Range types represent a range of values — like a booking from January 10th to January 15th. GiST indexes let you efficiently find overlapping ranges — which bookings overlap this date range? Without GiST, you would need to compare every booking against the search range.

```sql
-- Table with date ranges (bookings)
practice=# CREATE TABLE bookings (
  id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room    VARCHAR(20),
  period  DATERANGE
);

practice=# INSERT INTO bookings (room, period) VALUES
('101', '[2024-01-10, 2024-01-15)'),
('101', '[2024-01-20, 2024-01-25)'),
('102', '[2024-01-12, 2024-01-18)'),
('103', '[2024-01-08, 2024-01-22)');

-- GiST index on the range column
practice=# CREATE INDEX idx_bookings_period ON bookings USING gist (period);
CREATE INDEX

-- Find bookings that overlap Jan 11-14
practice=# SELECT room, period FROM bookings
WHERE period && '[2024-01-11, 2024-01-14)'::DATERANGE;
 room |         period
------+-------------------------
 101  | [2024-01-10,2024-01-15)
 102  | [2024-01-12,2024-01-18)
 103  | [2024-01-08,2024-01-22)
```

### GiST Exclusion Constraint
**Explanation:** GiST also handles exclusion constraints — a powerful feature that prevents overlapping ranges in the same group. For example, you can enforce that room 101 cannot have two bookings that overlap in time. This is database-level enforcement of scheduling conflicts — no application code needed.

```sql
-- Enable the btree_gist extension (needed for exclusion)
practice=# CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION

-- Create table with exclusion constraint
practice=# CREATE TABLE room_bookings (
  id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room   VARCHAR(20),
  period DATERANGE,
  EXCLUDE USING gist (room WITH =, period WITH &&)
);

practice=# INSERT INTO room_bookings (room, period)
VALUES ('101', '[2024-01-10, 2024-01-15)');
INSERT 0 1

-- Overlapping booking for same room → ERROR!
practice=# INSERT INTO room_bookings (room, period)
VALUES ('101', '[2024-01-13, 2024-01-18)');
ERROR:  conflicting key value violates exclusion
        constraint "room_bookings_room_period_excl"

-- Different room is fine
practice=# INSERT INTO room_bookings (room, period)
VALUES ('102', '[2024-01-13, 2024-01-18)');
INSERT 0 1
```

### BRIN in Action — Log Table
**Explanation:** Let us create a log table with timestamps inserted in order — the ideal case for BRIN. We will compare BRIN size against B-Tree size on the same column. The difference is dramatic. BRIN works because the data is naturally sorted by insertion time — each block range covers a narrow time window.

```sql
-- Create a log table with ordered timestamps
practice=# CREATE TABLE access_log (
  id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  log_time   TIMESTAMP,
  ip_address INET,
  path       VARCHAR(200)
);

practice=# INSERT INTO access_log (log_time, ip_address, path)
SELECT
  '2024-01-01'::TIMESTAMP + (g || ' seconds')::INTERVAL,
  ('192.168.1.' || (g % 254 + 1))::INET,
  '/page/' || (g % 100)
FROM generate_series(1, 500000) g;
INSERT 0 500000

-- BRIN index: tiny!
practice=# CREATE INDEX idx_log_time_brin ON access_log USING brin (log_time);
CREATE INDEX

-- B-Tree for comparison
practice=# CREATE INDEX idx_log_time_btree ON access_log (log_time);

-- Size comparison:
practice=# SELECT
  pg_size_pretty(pg_relation_size('idx_log_time_brin')) AS brin,
  pg_size_pretty(pg_relation_size('idx_log_time_btree')) AS btree;
  brin  |  btree
--------+---------
 48 kB  | 11 MB
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. GiST handles geometric data, range types, and exclusion constraints — use it for overlap and proximity queries. BRIN stores only min/max per block range — incredibly small, perfect for huge sorted tables like logs and time-series. SP-GiST handles space-partitioned data like IP addresses. Choose your index type based on data type and query patterns. B-Tree remains the default for 90 percent of cases. In the next class, we cover partial indexes, expression indexes, and covering indexes — advanced B-Tree features that make indexes even more targeted. See you there!

- **GiST: geometric, range, full-text with ranking**
- **GiST exclusion: EXCLUDE USING gist (...)**
- **BRIN: min/max per block range, tiny size**
- **BRIN: perfect for large, physically sorted data**
- **SP-GiST: IP addresses, prefix/partition searches**
- **B-Tree covers 90% of use cases**
- **GIN vs GiST for full-text: GIN faster, GiST smaller**
- **Match index type to data type + query pattern**


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
