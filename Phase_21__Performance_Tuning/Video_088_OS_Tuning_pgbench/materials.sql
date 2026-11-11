-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- OS Tuning & pgbench Benchmarking (Classes 180-181)
-- Phase 21: Performance Tuning
-- ============================================================

-- ============================================================
-- 1. LINUX KERNEL TUNING
-- ============================================================

-- All commands run as root (sudo)

-- vm.swappiness (prevent database memory from being swapped):
-- sysctl -w vm.swappiness=1

-- vm.dirty_ratio (control dirty page flushing):
-- sysctl -w vm.dirty_ratio=5
-- sysctl -w vm.dirty_background_ratio=2

-- vm.overcommit_memory (prevent OOM killer):
-- sysctl -w vm.overcommit_memory=2
-- sysctl -w vm.overcommit_ratio=90

-- Huge pages:
-- Calculate needed: shared_buffers_bytes / (2 * 1024 * 1024) + overhead
-- sysctl -w vm.nr_hugepages=4400

-- Verify huge pages:
-- grep Huge /proc/meminfo

-- Save all settings:
-- echo 'vm.swappiness = 1' > /etc/sysctl.d/99-postgresql.conf
-- echo 'vm.dirty_ratio = 5' >> /etc/sysctl.d/99-postgresql.conf
-- echo 'vm.dirty_background_ratio = 2' >> /etc/sysctl.d/99-postgresql.conf
-- echo 'vm.nr_hugepages = 4400' >> /etc/sysctl.d/99-postgresql.conf
-- echo 'vm.overcommit_memory = 2' >> /etc/sysctl.d/99-postgresql.conf
-- echo 'vm.overcommit_ratio = 90' >> /etc/sysctl.d/99-postgresql.conf
-- sysctl -p /etc/sysctl.d/99-postgresql.conf

-- ============================================================
-- 2. FILESYSTEM & I/O SCHEDULER
-- ============================================================

-- Check I/O scheduler:
-- cat /sys/block/sda/queue/scheduler

-- Set mq-deadline (best for databases):
-- echo mq-deadline > /sys/block/sda/queue/scheduler

-- Mount options (/etc/fstab):
-- /dev/sda1 /data ext4 defaults,noatime 0 2
-- noatime: don't update access timestamps (reduces writes)

-- Read-ahead:
-- blockdev --getra /dev/sda        # check current
-- blockdev --setra 4096 /dev/sda   # set to 2MB

-- ============================================================
-- 3. POSTGRESQL HUGE PAGES CONFIG
-- ============================================================

-- postgresql.conf:
-- huge_pages = on   (or 'try' for safer fallback)

-- Verify after restart:
SHOW huge_pages;

-- ============================================================
-- 4. pgbench — INITIALIZATION
-- ============================================================

-- Create test database:
-- createdb pgbench_test

-- Initialize with scale factor 100 (~1.6 GB):
-- pgbench -i -s 100 pgbench_test

-- Check scale factor and size:
SELECT setting FROM pg_settings WHERE name = 'server_version';
-- SELECT pg_size_pretty(pg_database_size('pgbench_test'));

-- ============================================================
-- 5. pgbench — BASIC BENCHMARKS
-- ============================================================

-- Read-write benchmark (default TPC-B):
-- pgbench -c 10 -j 2 -T 60 -P 5 pgbench_test

-- Read-only benchmark:
-- pgbench -c 10 -j 2 -T 60 -S -P 5 pgbench_test

-- With per-statement latency report:
-- pgbench -c 10 -j 2 -T 60 -r pgbench_test

-- ============================================================
-- 6. pgbench — CONNECTION SWEET SPOT
-- ============================================================

-- Test increasing client counts:
-- pgbench -c 1 -j 1 -T 30 pgbench_test
-- pgbench -c 5 -j 2 -T 30 pgbench_test
-- pgbench -c 10 -j 2 -T 30 pgbench_test
-- pgbench -c 20 -j 4 -T 30 pgbench_test
-- pgbench -c 50 -j 4 -T 30 pgbench_test
-- pgbench -c 100 -j 4 -T 30 pgbench_test

-- Record TPS for each → find the peak
-- Peak TPS ≈ optimal pool_size for pgBouncer

-- ============================================================
-- 7. pgbench — CUSTOM SCRIPTS
-- ============================================================

-- Create custom workload file (my_workload.sql):
--
-- \set customer_id random(1, 1000)
-- \set amount random(1, 500)
--
-- SELECT o.id, o.amount, c.name
-- FROM orders o
-- JOIN customers c ON o.customer_id = c.id
-- WHERE o.customer_id = :customer_id
-- ORDER BY o.order_date DESC
-- LIMIT 20;
--
-- INSERT INTO orders (customer_id, amount, status, order_date)
-- VALUES (:customer_id, :amount, 'pending', CURRENT_DATE);

-- Run custom script:
-- pgbench -c 10 -j 2 -T 60 -f my_workload.sql trigger_lab

-- ============================================================
-- 8. pgbench — COMPARING CONFIGURATIONS
-- ============================================================

-- Workflow:
-- 1. Baseline: pgbench -c 10 -T 60 pgbench_test → record TPS
-- 2. Change parameter in postgresql.conf
-- 3. Restart/reload PostgreSQL
-- 4. Re-bench: pgbench -c 10 -T 60 pgbench_test → record TPS
-- 5. Compare: improvement = (new_tps - old_tps) / old_tps × 100%

-- Parameters to benchmark:
-- shared_buffers: 128MB vs 4GB vs 8GB
-- work_mem: 4MB vs 32MB vs 128MB
-- random_page_cost: 4.0 vs 1.1
-- effective_io_concurrency: 1 vs 200
-- synchronous_commit: on vs off

-- ============================================================
-- COMPLETE PRODUCTION CONFIG (32GB SERVER, SSD, LINUX)
-- ============================================================

-- postgresql.conf:
-- shared_buffers = '8GB'
-- effective_cache_size = '24GB'
-- work_mem = '32MB'
-- maintenance_work_mem = '2GB'
-- autovacuum_work_mem = '512MB'
-- max_wal_size = '8GB'
-- min_wal_size = '1GB'
-- checkpoint_timeout = '15min'
-- checkpoint_completion_target = 0.9
-- wal_compression = 'zstd'
-- wal_level = 'replica'
-- max_connections = 100
-- random_page_cost = 1.1
-- effective_io_concurrency = 200
-- maintenance_io_concurrency = 10
-- huge_pages = 'on'
-- track_io_timing = on
-- idle_in_transaction_session_timeout = '5min'
-- statement_timeout = '60s'
-- log_temp_files = 0

-- /etc/sysctl.d/99-postgresql.conf:
-- vm.swappiness = 1
-- vm.dirty_ratio = 5
-- vm.dirty_background_ratio = 2
-- vm.nr_hugepages = 4400
-- vm.overcommit_memory = 2
-- vm.overcommit_ratio = 90

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Initialize pgbench with scale 10.
--    Run a 60-second benchmark. Record TPS and latency.
-- 2. Change shared_buffers from 128MB to 1GB.
--    Re-run pgbench. Compare TPS.
-- 3. Run pgbench with -S (select-only).
--    Change random_page_cost from 4.0 to 1.1. Compare.
-- 4. Find the connection sweet spot: test -c 1, 5, 10, 20, 50, 100.
--    Plot TPS vs clients. Where does TPS peak?
-- 5. Write a custom pgbench script using your own queries.
--    Benchmark with -f and -r to see per-statement latency.
