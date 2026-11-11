-- =============================================
-- PostgreSQL Mastery: GiST, BRIN & SP-GiST
-- Phase 12: Indexes | Classes 94-96
-- =============================================
-- GiST for ranges/geometry, BRIN for sorted tables,
-- SP-GiST for partitioned data, exclusion constraints.
-- =============================================

-- === SETUP ===

-- === GiST ON RANGE TYPES ===

CREATE TABLE bookings (
    id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room    VARCHAR(20),
    period  DATERANGE
);

INSERT INTO bookings (room, period) VALUES
('101', '[2024-01-10, 2024-01-15)'),
('101', '[2024-01-20, 2024-01-25)'),
('102', '[2024-01-12, 2024-01-18)'),
('102', '[2024-01-22, 2024-01-28)'),
('103', '[2024-01-08, 2024-01-22)'),
('104', '[2024-01-01, 2024-01-31)');

-- GiST index on date range
CREATE INDEX idx_bookings_period ON bookings USING gist (period);

-- Overlap query: which bookings overlap Jan 11-14?
SELECT room, period FROM bookings
WHERE period && '[2024-01-11, 2024-01-14)'::DATERANGE;

-- Contains: which bookings contain Jan 12?
SELECT room, period FROM bookings
WHERE period @> '2024-01-12'::DATE;

-- Contained by: which bookings fall within Jan 1-20?
SELECT room, period FROM bookings
WHERE period <@ '[2024-01-01, 2024-01-20)'::DATERANGE;

-- === GiST EXCLUSION CONSTRAINT ===

-- Prevents overlapping ranges in the same group
-- Needs btree_gist extension for combining = with &&
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE room_bookings (
    id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room   VARCHAR(20),
    period DATERANGE,
    EXCLUDE USING gist (room WITH =, period WITH &&)
);

-- First booking: OK
INSERT INTO room_bookings (room, period)
VALUES ('101', '[2024-01-10, 2024-01-15)');

-- Same room, overlapping dates: BLOCKED!
-- INSERT INTO room_bookings (room, period)
-- VALUES ('101', '[2024-01-13, 2024-01-18)');
-- ERROR: conflicting key value violates exclusion constraint

-- Different room, same dates: OK (different room)
INSERT INTO room_bookings (room, period)
VALUES ('102', '[2024-01-13, 2024-01-18)');

-- Same room, non-overlapping: OK
INSERT INTO room_bookings (room, period)
VALUES ('101', '[2024-01-20, 2024-01-25)');

SELECT * FROM room_bookings ORDER BY room, period;

-- === GiST ON GEOMETRIC TYPES ===

CREATE TABLE locations (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50),
    pos  POINT
);

INSERT INTO locations (name, pos) VALUES
('Office',    '(40.7128, -74.0060)'),
('Warehouse', '(40.7580, -73.9855)'),
('Store',     '(40.7484, -73.9857)');

-- GiST index on point column
CREATE INDEX idx_locations_pos ON locations USING gist (pos);

-- Nearest neighbor query (KNN with <->)
SELECT name, pos,
  pos <-> '(40.7500, -73.9900)'::POINT AS distance
FROM locations
ORDER BY pos <-> '(40.7500, -73.9900)'::POINT
LIMIT 2;

-- === BRIN INDEX ===

-- BRIN: tiny index for large, physically sorted tables

CREATE TABLE access_log (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    log_time   TIMESTAMP NOT NULL,
    ip_address INET,
    path       VARCHAR(200),
    status     INT
);

-- Insert 500K rows in order (timestamps increase with id)
INSERT INTO access_log (log_time, ip_address, path, status)
SELECT
  '2024-01-01'::TIMESTAMP + (g || ' seconds')::INTERVAL,
  ('192.168.1.' || (g % 254 + 1))::INET,
  '/page/' || (g % 100),
  (ARRAY[200, 200, 200, 301, 404, 500])[FLOOR(RANDOM()*6+1)::INT]
FROM generate_series(1, 500000) g;

ANALYZE access_log;

-- BRIN index on log_time (data is naturally ordered)
CREATE INDEX idx_log_time_brin ON access_log USING brin (log_time);

-- B-Tree for comparison
CREATE INDEX idx_log_time_btree ON access_log (log_time);

-- Size comparison: BRIN is tiny!
SELECT
  pg_size_pretty(pg_relation_size('idx_log_time_brin')) AS brin_size,
  pg_size_pretty(pg_relation_size('idx_log_time_btree')) AS btree_size;
-- brin: ~48 kB   vs   btree: ~11 MB

-- EXPLAIN: BRIN scan
EXPLAIN SELECT * FROM access_log
WHERE log_time BETWEEN '2024-03-01' AND '2024-03-02';
-- Bitmap Heap Scan → Bitmap Index Scan on idx_log_time_brin

-- BRIN with custom pages_per_range
-- Smaller range = more precise but larger index
-- CREATE INDEX idx_log_brin_small
--   ON access_log USING brin (log_time) WITH (pages_per_range = 32);

-- Larger range = less precise but smaller index
-- CREATE INDEX idx_log_brin_large
--   ON access_log USING brin (log_time) WITH (pages_per_range = 256);

-- === BRIN — WHEN IT DOES NOT WORK ===

-- BRIN fails on randomly ordered data
-- If customer_id is random, BRIN can't skip any blocks
-- because every block contains the full range of values

EXPLAIN SELECT * FROM access_log
WHERE ip_address = '192.168.1.50'::INET;
-- BRIN on ip_address would be useless here
-- (IP addresses are distributed across all blocks)

-- Rule: BRIN only works when column value correlates
-- with physical row order (insertion order)

-- === SP-GiST INDEX ===

-- SP-GiST: space-partitioned index
-- Good for: INET (IP addresses), text (prefix), point

-- SP-GiST on INET column
CREATE INDEX idx_log_ip_spgist ON access_log USING spgist (ip_address);

-- IP range query
EXPLAIN SELECT * FROM access_log
WHERE ip_address << '192.168.1.0/28'::INET;
-- Uses SP-GiST for network containment

-- SP-GiST on text (prefix search)
-- CREATE INDEX idx_path_spgist ON access_log USING spgist (path);
-- Good for LIKE 'prefix%' queries

-- === FULL-TEXT: GIN vs GiST ===

CREATE TABLE articles (
    id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title   TEXT,
    search  TSVECTOR
);

INSERT INTO articles (title, search) VALUES
('PostgreSQL Indexes', to_tsvector('english', 'PostgreSQL index types explained')),
('Query Optimization', to_tsvector('english', 'optimize queries with EXPLAIN')),
('Database Design',    to_tsvector('english', 'normalize tables for database design'));

-- GIN: faster search, larger index
CREATE INDEX idx_articles_gin ON articles USING gin (search);

-- GiST: slower search, smaller index, supports ranking
CREATE INDEX idx_articles_gist ON articles USING gist (search);

-- Both support @@ operator
SELECT title FROM articles WHERE search @@ to_tsquery('index');

-- For most apps, GIN is the better choice for full-text
-- Use GiST only if index size is critical

-- === INDEX TYPE SUMMARY ===

-- B-Tree:  General purpose, =, <, >, BETWEEN, ORDER BY
-- Hash:    Equality only (=), smaller than B-Tree
-- GIN:     Arrays, JSONB, full-text (inside values)
-- GiST:    Geometry, ranges, exclusion, proximity
-- BRIN:    Huge sorted tables (tiny index)
-- SP-GiST: IP addresses, prefix, partitioned space

-- === PRACTICE EXERCISES ===

-- Exercise 1: Range overlap
SELECT room, period FROM bookings
WHERE period && '[2024-01-14, 2024-01-22)'::DATERANGE;

-- Exercise 2: Exclusion constraint test
-- Try inserting an overlapping booking into room_bookings

-- Exercise 3: BRIN vs B-Tree size
SELECT
  pg_size_pretty(pg_relation_size('idx_log_time_brin')),
  pg_size_pretty(pg_relation_size('idx_log_time_btree'));

-- Exercise 4: BRIN query
EXPLAIN ANALYZE SELECT COUNT(*) FROM access_log
WHERE log_time BETWEEN '2024-02-01' AND '2024-02-15';

-- Exercise 5: SP-GiST on INET
EXPLAIN SELECT * FROM access_log
WHERE ip_address << '192.168.1.0/28'::INET;

-- Exercise 6: GiST nearest neighbor
SELECT name, pos <-> '(40.7500, -73.9900)'::POINT AS dist
FROM locations ORDER BY dist LIMIT 1;

-- Exercise 7: Choose the right index type
-- Timestamp column (ordered inserts) → BRIN
-- JSONB column → GIN
-- Date range column → GiST
-- UUID column (equality only) → Hash or B-Tree
-- General purpose → B-Tree

-- === CLEANUP ===
DROP INDEX IF EXISTS idx_log_time_btree;
-- DROP TABLE IF EXISTS bookings, room_bookings, locations;
-- DROP TABLE IF EXISTS access_log, articles;
-- DROP EXTENSION IF EXISTS btree_gist;

-- =============================================
-- Next Class: Partial, Expression & Covering Indexes
-- =============================================
