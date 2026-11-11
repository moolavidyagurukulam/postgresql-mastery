-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Table Inheritance (Class 219)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. BASIC INHERITANCE
-- ============================================================

-- Parent table:
CREATE TABLE vehicles (
    id serial PRIMARY KEY,
    make text NOT NULL,
    model text NOT NULL,
    year int NOT NULL,
    price numeric(10,2)
);

-- Child tables:
CREATE TABLE cars (
    doors int DEFAULT 4,
    trunk_liters int
) INHERITS (vehicles);

CREATE TABLE trucks (
    payload_kg int,
    bed_length_ft numeric(4,1)
) INHERITS (vehicles);

CREATE TABLE motorcycles (
    engine_cc int,
    style text
) INHERITS (vehicles);

-- ============================================================
-- 2. INSERT AND QUERY
-- ============================================================

INSERT INTO cars (make, model, year, price, doors, trunk_liters)
VALUES ('Toyota', 'Camry', 2024, 28000, 4, 480),
       ('BMW', '330i', 2024, 43000, 4, 480);

INSERT INTO trucks (make, model, year, price, payload_kg)
VALUES ('Ford', 'F-150', 2024, 35000, 1400);

INSERT INTO motorcycles (make, model, year, price, engine_cc, style)
VALUES ('Honda', 'CBR600', 2024, 12000, 600, 'sport');

-- Query parent (sees ALL):
SELECT make, model, year, price FROM vehicles;

-- Query child (sees ONLY that child):
SELECT * FROM cars;

-- ============================================================
-- 3. ONLY — EXCLUDE CHILDREN
-- ============================================================

-- Just the parent table:
SELECT count(*) FROM ONLY vehicles;

-- ONLY works with UPDATE and DELETE:
-- DELETE FROM ONLY vehicles WHERE ...;
-- UPDATE ONLY vehicles SET ... WHERE ...;

-- ============================================================
-- 4. tableoid — IDENTIFY SOURCE TABLE
-- ============================================================

SELECT tableoid::regclass AS source_table, make, model
FROM vehicles;

SELECT tableoid::regclass AS source_table, count(*)
FROM vehicles GROUP BY tableoid;

-- ============================================================
-- 5. CONSTRAINTS ON CHILDREN
-- ============================================================

-- Each child needs its own PK:
ALTER TABLE cars ADD PRIMARY KEY (id);
ALTER TABLE trucks ADD PRIMARY KEY (id);
ALTER TABLE motorcycles ADD PRIMARY KEY (id);

-- Each child needs its own indexes:
CREATE INDEX idx_cars_make ON cars (make);
CREATE INDEX idx_trucks_make ON trucks (make);
CREATE INDEX idx_motorcycles_make ON motorcycles (make);

-- ============================================================
-- 6. MULTIPLE INHERITANCE
-- ============================================================

CREATE TABLE auditable (
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by text
);

CREATE TABLE taggable (
    tags text[] DEFAULT '{}'
);

CREATE TABLE documents (
    id serial PRIMARY KEY,
    title text NOT NULL,
    content text
) INHERITS (auditable, taggable);

-- ============================================================
-- 7. ADD / REMOVE INHERITANCE
-- ============================================================

-- Detach child:
ALTER TABLE cars NO INHERIT vehicles;

-- Re-attach:
ALTER TABLE cars INHERIT vehicles;

-- Attach existing table as child:
-- (table must have all parent columns)
-- ALTER TABLE existing_table INHERIT vehicles;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create the vehicles hierarchy above.
--    Insert data into each child table.
--    Query the parent to see all rows.

-- 2. Use ONLY to query just the parent.
--    Use tableoid to identify which table each row is from.

-- 3. Try inserting directly into the parent table.
--    How does it appear in ONLY vs without ONLY?

-- 4. Create an auditable mixin table.
--    Create a new table that inherits from it.
--    Verify the inherited columns.

-- 5. Detach a child with NO INHERIT.
--    Query the parent — child rows are gone.
--    Re-attach with INHERIT — child rows return.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS motorcycles;
-- DROP TABLE IF EXISTS trucks;
-- DROP TABLE IF EXISTS cars;
-- DROP TABLE IF EXISTS vehicles;
-- DROP TABLE IF EXISTS documents;
-- DROP TABLE IF EXISTS auditable;
-- DROP TABLE IF EXISTS taggable;
