# Connection & Disk I/O Tuning
**Series:** PostgreSQL Mastery | **Phase:** Phase 21: Performance Tuning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous classes we tuned memory and WAL settings. Now we tune two more critical areas: connection management and disk I/O. Every PostgreSQL connection consumes memory — roughly 5 to 10 megabytes each. When your application opens hundreds of connections, that memory adds up fast. And disk I/O parameters determine how PostgreSQL interacts with your storage — SSD or spinning disk, these settings make a huge difference. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### pgBouncer Pooling Modes
pgBouncer has three pooling modes. Transaction pooling is the most common and recommended — it assigns a PostgreSQL connection for the duration of a transaction, then returns it to the pool. Session pooling keeps the connection for the entire client session. Statement pooling returns the connection after each statement — fastest but breaks multi-statement transactions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | pgBouncer has three pooling modes |
| **Point 2** | Transaction pooling is the most common and recommended — it assigns a PostgreSQL connection for the duration of a transaction, then returns it to the pool |
| **Point 3** | Session pooling keeps the connection for the entire client session |
| **Point 4** | Statement pooling returns the connection after each statement — fastest but breaks multi-statement transactions |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### I/O Settings by Storage Type
Here is a decision framework to choose the right I/O settings based on your storage type.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework to choose the right I/O settings based on your storage type |

### Beginner Trap: max_connections = 1000
A common beginner trap: setting max_connections to 1000 because your application 'needs' 1000 connections. Your application does not need 1000 active database connections. It needs 1000 concurrent users, which is very different. With pgBouncer in transaction mode, 1000 users can share 50 PostgreSQL connections because most requests are short — under 50 milliseconds — and the rest of the time the application is doing other things.

| The Wrong Way | The Right Way |
| :--- | :--- |
| max_connections = 1000 | max_connections = 100 |
| Each connection: ~5MB overhead | pgBouncer: pool_size = 50 |
| 1000 × 5MB = 5GB just for connections | pgBouncer: max_client_conn = 1000 |
| work_mem applies to each: 1000 × 32MB | 50 × 5MB = 250MB for connections |
| Context switching kills performance | Less contention = faster queries |
| pgbench TPS drops 50-70% | App sees 1000 connections via pgBouncer |


---

## 3. Hands-On Commands & psql Output

### max_connections — The Hidden Memory Cost
**Explanation:** max_connections sets the maximum number of simultaneous client connections. The default is 100. Each connection consumes memory for session state, work_mem allocations, and backend process overhead. The formula is simple: total connection memory equals max_connections times the per-connection cost. Setting max_connections to 1000 on a 32 GB server is a disaster waiting to happen.

```sql
postgres=# -- Check current setting:
postgres=# SHOW max_connections;
 max_connections
postgres=# -----------------
 100
postgres=# -- Each connection costs (approximate):
postgres=# -- Backend process overhead:     ~5 MB
postgres=# -- work_mem (if sorting):       32 MB (your setting)
postgres=# -- maintenance_work_mem (if VACUUM): 2 GB (but only maintenance)
postgres=# -- temp_buffers:                 32 MB
postgres=# -- Worst case with 100 connections all sorting:
postgres=# -- 100 × (5 MB + 32 MB) = 3.7 GB
postgres=# -- That is manageable on a 32 GB server
postgres=# -- With 1000 connections all sorting:
postgres=# -- 1000 × (5 MB + 32 MB) = 37 GB
postgres=# -- MORE than total RAM! → swapping → crash
postgres=# -- Rule: keep max_connections between 100-300
postgres=# -- Use a connection pooler for more concurrency
```

### Optimal Pool Size — Less Is More
**Explanation:** How many PostgreSQL connections should your pool have? A good starting formula is 2 to 3 times the number of CPU cores. A server with 8 cores handles about 16 to 24 active queries efficiently. More connections than that causes context switching overhead — queries actually get slower, not faster. This is counterintuitive but proven by benchmarks.

```sql
postgres=# -- Check CPU cores:
postgres=# -- Linux: nproc
postgres=# -- Windows: echo %NUMBER_OF_PROCESSORS%
postgres=# -- Formula: pool_size = CPU cores × 2 (+ a few for I/O waits)
postgres=# -- 8 cores → pool_size = 20
postgres=# -- 16 cores → pool_size = 40
postgres=# -- Counter-intuitive benchmark results:
postgres=# -- 8-core server, pgbench TPS (transactions per second):
postgres=# --   10 connections: 8,500 TPS
postgres=# --   20 connections: 9,200 TPS  ← sweet spot
postgres=# --   50 connections: 8,800 TPS
postgres=# --  100 connections: 7,200 TPS
postgres=# --  200 connections: 5,100 TPS  ← slower!
postgres=# --  500 connections: 2,800 TPS  ← much slower!
postgres=# -- Why? Context switching + lock contention
postgres=# -- Each extra connection fights for CPU and locks
postgres=# -- Fewer active connections = less contention = faster
postgres=# -- Match pool_size in pgBouncer to this optimal number
postgres=# -- max_connections in PG = pool_size + overhead (10-20)
```

### random_page_cost — SSD vs Spinning Disk
**Explanation:** Now let us move to disk I/O tuning. The most impactful parameter is random_page_cost. It tells the planner how expensive a random disk read is compared to a sequential read. The default is 4.0 — meaning random reads are 4 times more expensive. This was true for spinning disks. On SSD, random reads are almost as fast as sequential reads. Set it to 1.1 for SSD storage.

```sql
postgres=# -- Check current setting:
postgres=# SHOW random_page_cost;
 random_page_cost
postgres=# ------------------
 4
postgres=# SHOW seq_page_cost;
 seq_page_cost
postgres=# ---------------
 1
postgres=# -- Default ratio: random reads are 4x more expensive
postgres=# -- On HDD (spinning disk): correct — random = seek time
postgres=# -- On SSD: random ≈ sequential — set to 1.1
postgres=# -- Impact on planner:
postgres=# SET random_page_cost = 4.0;
postgres=# EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
postgres=# -- May choose: Seq Scan (thinks index random reads are costly)
postgres=# SET random_page_cost = 1.1;
postgres=# EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
postgres=# -- May choose: Index Scan (knows random reads are cheap on SSD)
RESET random_page_cost;
postgres=# -- For SSD storage, always set:
postgres=# -- random_page_cost = 1.1
postgres=# -- This is the single most important I/O parameter
```

### Linux I/O & Filesystem Settings
**Explanation:** On Linux, there are additional I/O scheduler and filesystem settings that impact PostgreSQL performance. The deadline or mq-deadline I/O scheduler is best for databases. For the filesystem, ext4 or XFS are recommended, and you should mount with the noatime option to avoid updating access timestamps on every read.

```sql
# Check current I/O scheduler:
cat /sys/block/sda/queue/scheduler
# [mq-deadline] none
# Set to mq-deadline (for databases):
echo mq-deadline > /sys/block/sda/queue/scheduler
# Filesystem mount options (fstab):
# /dev/sda1 /data ext4 defaults,noatime 0 2
#
# noatime: don't update access time on reads (reduces writes)
# ext4 or XFS recommended for PostgreSQL
# ZFS: can disable full_page_writes (ZFS has its own checksums)
# Read-ahead setting (for sequential scans):
blockdev --getra /dev/sda
# 256 (default = 128 KB)
# Increase for large sequential scans:
blockdev --setra 4096 /dev/sda
# Now 4096 sectors = 2 MB read-ahead
```

### Monitoring Connections & I/O
**Explanation:** Here is how to monitor connection usage and I/O performance to validate your settings.

```sql
-- Connection usage:
SELECT count(*) AS total,
  count(*) FILTER (WHERE state = 'active') AS active,
  count(*) FILTER (WHERE state = 'idle') AS idle,
  count(*) FILTER (WHERE state = 'idle in transaction') AS idle_txn
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- Connection slots used vs available:
SELECT max_conn, used, max_conn - used AS available
FROM (
  SELECT setting::int AS max_conn FROM pg_settings
  WHERE name = 'max_connections'
) mc,
(SELECT count(*) AS used FROM pg_stat_activity) ua;

-- I/O timing (enable track_io_timing = on):
SELECT relname,
  heap_blks_read, heap_blks_hit,
  ROUND(100.0 * heap_blks_hit /
    NULLIF(heap_blks_hit + heap_blks_read, 0), 2)
    AS cache_hit_pct
FROM pg_statio_user_tables
ORDER BY heap_blks_read DESC LIMIT 10;
```

### track_io_timing — See Actual I/O Time
**Explanation:** track_io_timing is an important diagnostic parameter. When enabled, EXPLAIN ANALYZE shows actual I/O timing for each plan node — how long was spent reading from disk versus cache. The overhead is minimal on modern systems. Enable it on all production servers.

```sql
postgres=# -- Enable I/O timing:
postgres=# -- postgresql.conf: track_io_timing = on
postgres=# -- Or per-session:
postgres=# SET track_io_timing = on;
postgres=# EXPLAIN (ANALYZE, BUFFERS)
postgres=# SELECT * FROM orders WHERE customer_id = 42;
 Index Scan using idx_orders_customer_id on orders
   (actual time=0.023..0.089 rows=48 loops=1)
   Buffers: shared hit=4 read=2
   I/O Timings: shared read=0.156
   ←── 0.156ms spent on disk reads
postgres=# -- Without track_io_timing, you only see buffer counts
postgres=# -- WITH it, you see how much TIME was spent on I/O
postgres=# -- This helps distinguish:
postgres=# --   'slow because of many I/Os' vs
postgres=# --   'slow because of CPU work'
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `pgbouncer.ini — Connection Pooler` — pgBouncer Configuration — pgbouncer.ini
Here is a typical pgBouncer configuration. The key settings are pool_size (PostgreSQL connections per database), max_client_conn (total application connections), and pool_mode.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `[databases]` | `mydb = host=127.0.0.1 port=5432 dbname=mydb` | `[SETTING]` | Database connection string to PostgreSQL |
| `pool_mode` | `transaction` | `[SETTING]` | Recommended: connection shared per transaction |
| `default_pool_size` | `50` | `[SETTING]` | PG connections per database (start with CPU cores × 2) |
| `max_client_conn` | `1000` | `[SETTING]` | Max application connections to pgBouncer |
| `listen_port` | `6432` | `[SETTING]` | App connects to 6432 (pgBouncer), not 5432 (PG) |
| `server_idle_timeout` | `600` | `[SETTING]` | Close idle PG connections after 10 minutes |
| `reserve_pool_size` | `5` | `[SETTING]` | Extra connections for burst traffic |


### File: `postgresql.conf — Disk I/O Settings` — I/O Concurrency & Prefetching
effective_io_concurrency tells PostgreSQL how many concurrent I/O requests the disk subsystem can handle. On a single spinning disk, set it to 1 or 2. On SSD, set it to 200. On a RAID array, match it to the number of drives. This affects bitmap heap scans — PostgreSQL issues prefetch requests to keep the I/O pipeline full. You can apply these parameters without downtime by executing SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `effective_io_concurrency` | `200` | `[RELOAD]` (Live Reload `SIGHUP`) | Concurrent I/O requests for bitmap scans (default 1, SSD: 200) (Default: 1) |
| `maintenance_io_concurrency` | `10` | `[RELOAD]` (Live Reload `SIGHUP`) | I/O concurrency for VACUUM, CREATE INDEX (default 10) (Default: 10) |
| `random_page_cost` | `1.1` | `[RELOAD]` (Live Reload `SIGHUP`) | Random read cost relative to sequential (SSD: 1.1, HDD: 4.0) (Default: 4.0) |
| `seq_page_cost` | `1.0` | `[RELOAD]` (Live Reload `SIGHUP`) | Base unit — usually leave at default (Default: 1.0) |


### File: `postgresql.conf — Connection Timeouts` — Connection Safety Parameters
Another critical connection setting is idle_in_transaction_session_timeout. This automatically terminates sessions that sit idle inside an open transaction for too long. Without this, a forgotten BEGIN without COMMIT can block autovacuum for hours and hold locks that prevent other queries. You can apply these parameters without downtime by executing SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `idle_in_transaction_session_timeout` | `5min` | `[RELOAD]` (Live Reload `SIGHUP`) | Kill sessions idle in transaction > 5 minutes (default 0 = disabled!) (Default: 0) |
| `statement_timeout` | `60s` | `[RELOAD]` (Live Reload `SIGHUP`) | Kill queries running > 60 seconds (0 = disabled, careful with reports) (Default: 0) |
| `lock_timeout` | `10s` | `[RELOAD]` (Live Reload `SIGHUP`) | Fail if cannot acquire lock within 10 seconds (default 0 = wait forever) (Default: 0) |
| `tcp_keepalives_idle` | `60` | `[RELOAD]` (Live Reload `SIGHUP`) | Send TCP keepalive after 60 seconds idle (detect dead clients) (Default: OS default) |
| `tcp_keepalives_interval` | `10` | `[SETTING]` | Retry keepalive every 10 seconds |
| `tcp_keepalives_count` | `6` | `[SETTING]` | Drop connection after 6 failed keepalives (60 + 6×10 = 2 min total) |


### File: `postgresql.conf — Connection & I/O Settings` — Complete Connection & I/O Config — Production
Here is the complete connection and I/O configuration for a production server. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `max_connections` | `100` | **`[RESTART]`** (Postmaster Restart) | Keep low — use pgBouncer for more (restart required) (Default: 100) |
| `idle_in_transaction_session_timeout` | `5min` | `[RELOAD]` (Live Reload `SIGHUP`) | Kill idle-in-transaction after 5 minutes (Default: 0) |
| `statement_timeout` | `60s` | `[RELOAD]` (Live Reload `SIGHUP`) | Kill queries over 60 seconds (adjust for reports) (Default: 0) |
| `random_page_cost` | `1.1` | `[RELOAD]` (Live Reload `SIGHUP`) | For SSD storage (4.0 for spinning disk) (Default: 4.0) |
| `effective_io_concurrency` | `200` | `[RELOAD]` (Live Reload `SIGHUP`) | For SSD (2 for spinning disk) (Default: 1) |
| `maintenance_io_concurrency` | `10` | `[RELOAD]` (Live Reload `SIGHUP`) | I/O concurrency for VACUUM/CREATE INDEX (Default: 10) |
| `track_io_timing` | `on` | `[SETTING]` | Show I/O timing in EXPLAIN ANALYZE |
| `tcp_keepalives_idle` | `60` | `[RELOAD]` (Live Reload `SIGHUP`) | Detect dead client connections (Default: OS default) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: max_connections = 1000
A common beginner trap: setting max_connections to 1000 because your application 'needs' 1000 connections. Your application does not need 1000 active database connections. It needs 1000 concurrent users, which is very different. With pgBouncer in transaction mode, 1000 users can share 50 PostgreSQL connections because most requests are short — under 50 milliseconds — and the rest of the time the application is doing other things.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Keep max_connections low — 100 to 200 — and use pgBouncer in transaction mode for high concurrency. The optimal pool size is about 2 to 3 times your CPU core count. For SSD storage, set random_page_cost to 1.1 and effective_io_concurrency to 200. Enable idle_in_transaction_session_timeout to prevent forgotten transactions from blocking autovacuum. Enable track_io_timing for I/O diagnostics. On Linux, use the mq-deadline scheduler and mount with noatime. In the next class, we cover OS-level tuning and pgbench benchmarking.

- **max_connections: 100-200 (use pgBouncer for more concurrency)**
- **pgBouncer: transaction mode, pool_size = CPU cores × 2**
- **More connections ≠ more performance (context switching overhead)**
- **random_page_cost: 1.1 for SSD, 4.0 for HDD**
- **effective_io_concurrency: 200 for SSD, 2 for HDD**
- **idle_in_transaction_session_timeout: 5min (prevent zombie txns)**
- **statement_timeout: 60s for web apps (higher for batch jobs)**
- **track_io_timing: on (see I/O time in EXPLAIN ANALYZE)**
- **Linux: mq-deadline scheduler, noatime mount, ext4 or XFS**
- **Monitor: pg_stat_activity for connection usage**
- **Next: OS Tuning & pgbench Benchmarking**


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
