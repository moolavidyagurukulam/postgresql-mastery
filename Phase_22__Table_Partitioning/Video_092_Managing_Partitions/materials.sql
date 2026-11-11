-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Managing Partitions — ADD, DROP, ATTACH, DETACH (Classes 188-189)
-- Phase 22: Table Partitioning
-- ============================================================

-- ============================================================
-- 1. ADDING PARTITIONS
-- ============================================================

\c partition_lab

-- Add individual partitions:
CREATE TABLE orders_2027_01 PARTITION OF orders
    FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');

-- Automate for a full year:
DO $$
DECLARE
    m_start DATE; m_end DATE; p_name TEXT;
BEGIN
    FOR m IN 2..12 LOOP
        m_start := make_date(2027, m, 1);
        m_end   := m_start + '1 month'::interval;
        p_name  := 'orders_' || to_char(m_start, 'YYYY_MM');
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF orders
             FOR VALUES FROM (%L) TO (%L)',
            p_name, m_start, m_end
        );
    END LOOP;
END $$;

-- Verify:
SELECT child.relname
FROM pg_inherits i
JOIN pg_class child ON i.inhrelid = child.oid
JOIN pg_class parent ON i.inhparent = parent.oid
WHERE parent.relname = 'orders'
  AND child.relname LIKE 'orders_2027%'
ORDER BY child.relname;

-- ============================================================
-- 2. DROPPING PARTITIONS (Instant Data Removal)
-- ============================================================

SELECT COUNT(*) FROM orders_2025_01;

-- Instant drop:
DROP TABLE orders_2025_01;

-- Compare: DELETE would scan all rows, write WAL, need VACUUM
-- DROP TABLE is milliseconds regardless of row count

-- ============================================================
-- 3. ATTACH PARTITION
-- ============================================================

-- Create standalone table with data:
CREATE TABLE orders_2025_05_standalone (
    id          BIGINT,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    status      TEXT NOT NULL,
    order_date  DATE NOT NULL
);

INSERT INTO orders_2025_05_standalone
SELECT id, customer_id, amount, status, order_date
FROM generate_series(1, 50000) AS id,
     LATERAL (
         SELECT (random()*999+1)::int AS customer_id,
                (random()*500)::numeric(10,2) AS amount,
                'pending' AS status,
                '2025-05-01'::date + (random()*30)::int AS order_date
     ) sub;

-- Attach:
ALTER TABLE orders
    ATTACH PARTITION orders_2025_05_standalone
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');

-- ============================================================
-- 4. LOCK-FREE ATTACH (CHECK Constraint Trick)
-- ============================================================

-- Step 1: Add CHECK constraint:
-- ALTER TABLE orders_new
--     ADD CONSTRAINT chk_dates
--     CHECK (order_date >= '2025-06-01'
--        AND order_date < '2025-07-01')
--     NOT VALID;

-- Step 2: Validate (concurrent reads allowed):
-- ALTER TABLE orders_new VALIDATE CONSTRAINT chk_dates;

-- Step 3: ATTACH (skips scan because of CHECK):
-- ALTER TABLE orders
--     ATTACH PARTITION orders_new
--     FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

-- Step 4: Cleanup:
-- ALTER TABLE orders_new DROP CONSTRAINT chk_dates;

-- ============================================================
-- 5. DETACH PARTITION
-- ============================================================

-- Regular detach:
ALTER TABLE orders
    DETACH PARTITION orders_2025_02;

-- orders_2025_02 is now a standalone table:
SELECT COUNT(*) FROM orders_2025_02;

-- DETACH CONCURRENTLY (no lock on parent):
ALTER TABLE orders
    DETACH PARTITION orders_2025_03 CONCURRENTLY;
-- Cannot run inside a transaction block

-- ============================================================
-- 6. DEFAULT PARTITION — Moving Rows
-- ============================================================

-- Check rows in default that belong to a new range:
SELECT COUNT(*) FROM orders_default
WHERE order_date >= '2025-08-01'
  AND order_date < '2025-09-01';

-- Move rows before creating partition:
BEGIN;
  CREATE TEMP TABLE aug_rows AS
  SELECT * FROM orders_default
  WHERE order_date >= '2025-08-01'
    AND order_date < '2025-09-01';

  DELETE FROM orders_default
  WHERE order_date >= '2025-08-01'
    AND order_date < '2025-09-01';

  CREATE TABLE orders_2025_08 PARTITION OF orders
      FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');

  INSERT INTO orders SELECT * FROM aug_rows;

  DROP TABLE aug_rows;
COMMIT;

-- ============================================================
-- 7. AUTOMATED PARTITION LIFECYCLE
-- ============================================================

DO $$
DECLARE
    m_start DATE; m_end DATE; p_name TEXT;
    cutoff DATE := current_date - interval '2 years';
BEGIN
    -- Create 3 months ahead:
    FOR i IN 0..2 LOOP
        m_start := date_trunc('month',
            current_date + (i || ' month')::interval);
        m_end   := m_start + '1 month'::interval;
        p_name  := 'orders_' || to_char(m_start, 'YYYY_MM');
        IF NOT EXISTS (
            SELECT 1 FROM pg_class WHERE relname = p_name
        ) THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF orders
                 FOR VALUES FROM (%L) TO (%L)',
                p_name, m_start, m_end);
            RAISE NOTICE 'Created: %', p_name;
        END IF;
    END LOOP;

    -- Drop partitions older than 2 years:
    FOR p_name IN
        SELECT child.relname
        FROM pg_inherits i
        JOIN pg_class child ON i.inhrelid = child.oid
        JOIN pg_class parent ON i.inhparent = parent.oid
        WHERE parent.relname = 'orders'
          AND child.relname ~ '^orders_\d{4}_\d{2}$'
          AND to_date(
              substring(child.relname from '\d{4}_\d{2}'),
              'YYYY_MM') < cutoff
    LOOP
        EXECUTE 'DROP TABLE ' || p_name;
        RAISE NOTICE 'Dropped: %', p_name;
    END LOOP;
END $$;

-- ============================================================
-- 8. MIGRATION — Unpartitioned to Partitioned
-- ============================================================

-- Step 1: Create new partitioned table
-- CREATE TABLE orders_new (...) PARTITION BY RANGE (order_date);

-- Step 2: Create partitions
-- (use DO $$ loop for all months)

-- Step 3: Copy data
-- INSERT INTO orders_new SELECT * FROM orders;

-- Step 4: Recreate indexes
-- CREATE INDEX ON orders_new(customer_id);

-- Step 5: Swap names
-- BEGIN;
-- ALTER TABLE orders RENAME TO orders_old;
-- ALTER TABLE orders_new RENAME TO orders;
-- COMMIT;

-- Step 6: After testing, drop old:
-- DROP TABLE orders_old;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create 6 monthly partitions for the first half of 2028.
-- 2. Drop the oldest partition. How fast was it vs DELETE?
-- 3. Create a standalone table, fill it with data for one month,
--    then ATTACH it. Verify it appears in the partition list.
-- 4. DETACH a partition. Verify you can still query it as a
--    regular table, but it no longer appears in parent queries.
-- 5. Write a lifecycle script that creates 3 months ahead
--    and drops partitions older than 1 year.
