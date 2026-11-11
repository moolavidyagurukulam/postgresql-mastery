# OS Tuning & pgbench Benchmarking
**Series:** PostgreSQL Mastery | **Phase:** Phase 21: Performance Tuning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! Picture this: you tuned your postgresql.conf perfectly with 8GB shared buffers and fast checkpoint timing. Yet during peak flash-sale traffic, your server suddenly freezes, latency spikes to 10 seconds, and the Linux kernel kills your database process! Why? Because the underlying operating system kernel was never tuned for database workloads. In this class, we tune Linux kernel parameters and learn how to benchmark our throughput using pgbench.

### Why OS Kernel Tuning is Mandatory
Why does OS tuning matter? By default, general-purpose Linux kernels are tuned for desktop responsiveness or web proxies — aggressively swapping memory to disk, buffering huge amounts of dirty pages, and allowing memory overcommit. Without tuning, the Linux Out-Of-Memory killer can abruptly terminate the postmaster process, causing unexpected downtime and crash recovery.

- Default vm.swappiness (60): Swaps database memory to disk prematurely
- Dirty Ratio Spikes: High dirty page limits cause multi-second disk I/O stalls
- OOM Killer Risk: Unrestricted overcommit can kill postmaster unexpectedly
- Huge Pages: Standard 4KB pages create massive CPU TLB translation overhead


---

## 2. Core Technical Concepts & Mechanisms

### Why OS Kernel Tuning is Mandatory
Why does OS tuning matter? By default, general-purpose Linux kernels are tuned for desktop responsiveness or web proxies — aggressively swapping memory to disk, buffering huge amounts of dirty pages, and allowing memory overcommit. Without tuning, the Linux Out-Of-Memory killer can abruptly terminate the postmaster process, causing unexpected downtime and crash recovery.

- Default vm.swappiness (60): Swaps database memory to disk prematurely
- Dirty Ratio Spikes: High dirty page limits cause multi-second disk I/O stalls
- OOM Killer Risk: Unrestricted overcommit can kill postmaster unexpectedly
- Huge Pages: Standard 4KB pages create massive CPU TLB translation overhead

### When to Run OS Tuning & pgbench
Where and when should you benchmark with pgbench? Always run pgbench in a dedicated staging environment before deploying schema changes, after hardware upgrades, or when comparing filesystem types. Never run unthrottled stress benchmarks on a live production cluster with real users.

| Stage | Recommended Action | Goal |
| :--- | :--- | :--- |
| Server Provisioning | Apply sysctl.conf kernel settings | Prevent swapping & OOM terminations |
| Pre-Production Staging | Run pgbench -c 50 -j 8 -T 300 | Establish baseline transactions per second |
| Live Production | Monitor pg_stat_database & sar | Verify real query latency without synthetic load |

### Linux Kernel Tuning Areas
Linux is the most common OS for PostgreSQL in production. There are several kernel parameters that significantly affect database performance. The most important ones control memory management — how the operating system handles dirty pages, swap behavior, and huge pages. We will cover each one with its recommended value.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Virtual Memory (vm.*)** | Controls dirty page flushing, swap behavior, memory overcommit |
| **Huge Pages** | 2MB pages instead of 4KB — reduces TLB misses for large shared_buffers |
| **I/O Scheduler** | How the kernel orders disk I/O requests |
| **Filesystem** | Mount options, filesystem choice, and read-ahead settings |

**Notes:**
- These settings apply to Linux production servers
- Windows uses different mechanisms (usually less tuning needed)
- All changes require root/sudo access

### Huge Pages — Reduce TLB Misses
Huge pages are a significant optimization for servers with large shared_buffers. Normal memory pages are 4 kilobytes. The CPU maintains a translation lookaside buffer — TLB — that maps virtual addresses to physical pages. With 8 GB of shared_buffers using 4 KB pages, that is 2 million pages. The TLB cannot hold that many entries, causing constant TLB misses. With 2 MB huge pages, 8 GB is only 4,096 pages — the TLB handles that easily.

| Normal Pages (4KB) | Huge Pages (2MB) |
| :--- | :--- |
| 8GB shared_buffers = 2,097,152 pages | 8GB shared_buffers = 4,096 pages |
| TLB can cache ~1,000-4,000 entries | TLB easily caches all entries |
| Constant TLB misses → extra memory lookups | Near-zero TLB misses |
| Each miss: ~10-30 nanoseconds penalty | 5-10% overall performance improvement |
| Millions of misses per second = significant overhead | Memory is pinned (never swapped!) |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### pgbench Options
pgbench has several useful options beyond the basics. Select-only mode measures read performance. Custom scripts let you benchmark your actual queries. The number of clients should match your expected concurrency.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | pgbench has several useful options beyond the basics |
| **Select** | only mode measures read performance |
| **Point 3** | Custom scripts let you benchmark your actual queries |
| **Point 4** | The number of clients should match your expected concurrency |

### pgbench Pitfalls — Do It Right
Benchmarking has pitfalls. Here are the most common mistakes beginners make when using pgbench.

| Common Mistakes | Best Practices |
| :--- | :--- |
| Scale too small (fits entirely in cache) | Scale > shared_buffers (test real I/O) |
| Duration too short (< 30 seconds) | Duration: 60-300 seconds minimum |
| Running on the same machine as other apps | Dedicated server for benchmarking |
| Not warming up before measuring | Run a warm-up pass first, discard results |
| Comparing results across different hardware | Compare only on the same hardware |
| Changing two parameters at once | Change ONE parameter, measure, then next |

### Phase 21 Review — Performance Tuning
Here is the Phase 21 review — everything we covered across all four classes of Performance Tuning.

| Topic | Key Takeaway |
| :--- | :--- |
| shared_buffers | 25% of RAM — most impactful single parameter |
| work_mem | Per-operation, not per-query — set conservative, boost per-session |
| maintenance_work_mem | 1-2GB for fast VACUUM and CREATE INDEX |
| effective_cache_size | 50-75% of RAM — planner hint, not allocation |
| max_wal_size | 4-16GB to reduce checkpoint frequency |
| checkpoint_timeout | 15-30min with completion_target 0.9 |
| wal_compression | zstd — reduce WAL volume 30-50% |
| max_connections | 100-200 with pgBouncer for more concurrency |
| random_page_cost | 1.1 for SSD — enables index scan decisions |
| vm.swappiness | 1 — keep database memory in RAM |
| Huge pages | Reduce TLB misses for large shared_buffers |
| pgbench | Measure before and after every change |

### Production Tuning Checklist
Here is your final summary for Phase 21. The complete tuning checklist for a production PostgreSQL server on Linux with SSD storage.

- 1. shared_buffers = 25% of RAM (requires restart)
- 2. effective_cache_size = 50-75% of RAM
- 3. work_mem = 32-64MB globally, higher per-session for reports
- 4. maintenance_work_mem = 1-2GB
- 5. max_wal_size = 8GB, checkpoint_timeout = 15min
- 6. wal_compression = zstd
- 7. random_page_cost = 1.1 (SSD)
- 8. effective_io_concurrency = 200 (SSD)
- 9. max_connections = 100 + pgBouncer pool_size = cores × 2
- 10. huge_pages = on (configure vm.nr_hugepages)
- 11. vm.swappiness = 1, vm.dirty_ratio = 5
- 12. pgbench: measure BEFORE and AFTER each change


---

## 3. Hands-On Commands & psql Output

### vm.swappiness — Prevent Swapping PostgreSQL Memory
**Explanation:** vm.swappiness controls how aggressively the kernel swaps memory to disk. The default is 60, which means the kernel starts swapping relatively early. For a database server, you want PostgreSQL's shared_buffers to stay in RAM — never swapped. Set swappiness to 1 — nearly disabled but still available as a last resort.

```sql
# Check current swappiness:
sysctl vm.swappiness
# vm.swappiness = 60  (default — too aggressive for DB)
# Set to 1 (nearly disable swap):
sysctl -w vm.swappiness=1
# Make permanent (survives reboot):
echo 'vm.swappiness = 1' >> /etc/sysctl.d/99-postgresql.conf
sysctl -p /etc/sysctl.d/99-postgresql.conf
# Why 1, not 0?
# 0 = completely disable swap → OOM killer may kill PostgreSQL
# 1 = swap only as absolute last resort → safer
# Monitor swap usage:
free -h
#              total   used    free   shared  buff/cache  available
# Mem:          32G    12G     2G      8G       18G        19G
# Swap:          8G     0B     8G
# Swap used = 0B — good!
# If swap is being used, check what is swapping:
cat /proc/$(pgrep -f 'postgres' | head -1)/status | grep VmSwap
```

### Dirty Page Flushing — vm.dirty_ratio
**Explanation:** vm.dirty_ratio and vm.dirty_background_ratio control when the OS writes dirty pages to disk. dirty_background_ratio is when the background flusher starts writing — default 10% of RAM. dirty_ratio is when ALL processes must stop and write — default 20%. For a database, lower these to avoid I/O storms when the OS flushes a large amount of dirty data at once.

```sql
# Check current settings:
sysctl vm.dirty_ratio
# vm.dirty_ratio = 20  (20% of RAM = 6.4GB on 32GB server)
sysctl vm.dirty_background_ratio
# vm.dirty_background_ratio = 10  (10% = 3.2GB)
# Problem: on a 32GB server, the OS allows 6.4GB of dirty
# pages before forcing ALL processes to flush.
# When the flush happens, everything stalls.
# Recommended for database servers:
sysctl -w vm.dirty_ratio=5
sysctl -w vm.dirty_background_ratio=2
# Now:
# Background flush starts at 2% = 640MB
# Forced flush at 5% = 1.6GB
# Smaller flushes, more frequent, less I/O spikes
# Alternative: use absolute bytes instead of percentage:
# vm.dirty_bytes = 268435456        # 256MB
# vm.dirty_background_bytes = 67108864  # 64MB
# Make permanent:
echo 'vm.dirty_ratio = 5' >> /etc/sysctl.d/99-postgresql.conf
echo 'vm.dirty_background_ratio = 2' >> /etc/sysctl.d/99-postgresql.conf
```

### Setting Up Huge Pages on Linux
**Explanation:** Here is how to configure huge pages on Linux. You need to calculate the number of huge pages, reserve them, and then tell PostgreSQL to use them.

```sql
# Step 1: Find PostgreSQL's shared memory needs:
head -1 /proc/$(pgrep -f 'postgres -D' | head -1)/maps
# Shows the shared memory segment size
# Or calculate: shared_buffers + overhead
# 8GB shared_buffers ≈ 8.5GB with overhead
# Step 2: Calculate number of huge pages needed:
# 8.5GB / 2MB per huge page = 4352 pages (round up)
# Step 3: Reserve huge pages:
sysctl -w vm.nr_hugepages=4400
# (reserve a few extra for safety)
# Verify:
grep Huge /proc/meminfo
# HugePages_Total:    4400
# HugePages_Free:     4400
# HugePages_Rsvd:        0
# Hugepagesize:       2048 kB
# Step 4: postgresql.conf:
# huge_pages = on
# (Use 'on' not 'try' — fail if huge pages unavailable)
# Step 5: Restart PostgreSQL
sudo systemctl restart postgresql
# Make permanent:
echo 'vm.nr_hugepages = 4400' >> /etc/sysctl.d/99-postgresql.conf
```

### pgbench — Initialize Test Database
**Explanation:** First, initialize the pgbench database. The scale factor (-s) determines the size. Scale 1 creates about 16 megabytes. Scale 100 creates about 1.6 gigabytes. For meaningful benchmarks, use a scale factor that creates a database larger than your shared_buffers — this tests real I/O, not just cache.

```sql
# Create a test database:
createdb pgbench_test
# Initialize with scale factor 100 (~1.6 GB):
pgbench -i -s 100 pgbench_test
# Output:
# dropping old tables...
# creating tables...
# generating data (client-side)...
# 10000000 of 10000000 tuples (100%) done
# vacuuming...
# creating primary keys...
# done in 45.23 s
# Tables created:
# pgbench_accounts: 10,000,000 rows (scale × 100,000)
# pgbench_branches: 100 rows (scale)
# pgbench_tellers:  1,000 rows (scale × 10)
# pgbench_history:  empty (grows during benchmark)
# Check size:
psql pgbench_test -c "SELECT pg_size_pretty(pg_database_size('pgbench_test'));"
#  pg_size_pretty
# ----------------
#  1553 MB
```

### pgbench — Running a Baseline Benchmark
**Explanation:** Now run a baseline benchmark. The key flags are: -c for number of client connections, -j for number of threads, -T for duration in seconds, and -P for progress reporting interval. A 60-second test with 10 clients is a good starting point.

```sql
# Run 60-second benchmark with 10 clients, 2 threads:
pgbench -c 10 -j 2 -T 60 -P 5 pgbench_test
# Progress output every 5 seconds:
# progress: 5.0 s, 4523.2 tps, lat 2.210 ms, stddev 1.234
# progress: 10.0 s, 4489.1 tps, lat 2.228 ms, stddev 1.189
# progress: 15.0 s, 4501.7 tps, lat 2.221 ms, stddev 1.201
# ... (continues for 60 seconds)
# Final results:
# pgbench (PostgreSQL 16.x)
# transaction type: <builtin: TPC-B (sort of)>
# scaling factor: 100
# query mode: simple
# number of clients: 10
# number of threads: 2
# maximum number of seconds of test: 60
# number of transactions actually processed: 270345
# number of failed transactions: 0 (0.000%)
# latency average = 2.219 ms
# latency stddev = 1.198 ms
# initial connection time = 12.345 ms
# tps = 4505.72 (without initial connection time)
# Key metrics:
# TPS = 4505 (transactions per second)
# Latency avg = 2.2ms (time per transaction)
# Stddev = 1.2ms (consistency — lower is better)
```

### Custom pgbench Script — Real Workload
**Explanation:** Here is a custom pgbench script that benchmarks your actual workload instead of the default TPC-B. You write a SQL file with the queries your application runs most often and pass it with the -f flag.

```sql
# Create a custom benchmark script:
cat > my_workload.sql << 'EOF'
\set customer_id random(1, 1000)
\set amount random(1, 500)
postgres=# -- Simulate dashboard query:
postgres=# SELECT o.id, o.amount, c.name
postgres-# FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id
postgres-# WHERE o.customer_id = :customer_id
postgres-# ORDER BY o.order_date DESC
postgres-# LIMIT 20;
postgres=# -- Simulate order insert:
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
postgres-# VALUES (:customer_id, :amount, 'pending', CURRENT_DATE);
EOF
# Run with custom script:
pgbench -c 10 -j 2 -T 60 -f my_workload.sql trigger_lab
# Add -r to see per-statement latency:
pgbench -c 10 -j 2 -T 60 -r -f my_workload.sql trigger_lab
# Output includes:
# statement latencies in milliseconds and target:
#   0.342  SELECT o.id, o.amount, c.name ...
#   0.089  INSERT INTO orders ...
```

### Benchmarking a Configuration Change
**Explanation:** Here is a practical example: measuring the impact of changing shared_buffers. Run the benchmark before and after, and compare the results.

```sql
# Step 1: Baseline (shared_buffers = 128MB)
pgbench -c 10 -j 2 -T 60 pgbench_test
# tps = 3200 (baseline)
# Step 2: Change shared_buffers to 4GB
# Edit postgresql.conf: shared_buffers = '4GB'
sudo systemctl restart postgresql
# Step 3: Re-run benchmark
pgbench -c 10 -j 2 -T 60 pgbench_test
# tps = 4500 (+40% improvement!)
# Step 4: Try shared_buffers = 8GB
# Edit postgresql.conf: shared_buffers = '8GB'
sudo systemctl restart postgresql
pgbench -c 10 -j 2 -T 60 pgbench_test
# tps = 4650 (+3% over 4GB — diminishing returns)
# Step 5: Try random_page_cost = 1.1 (SSD)
# Edit postgresql.conf: random_page_cost = 1.1
sudo systemctl reload postgresql
pgbench -c 10 -j 2 -T 60 -S pgbench_test
# Read TPS: 45000 → 52000 (+15% on select-only)
```

### Finding the Connection Sweet Spot
**Explanation:** Here is the finding-the-sweet-spot approach. Test increasing numbers of client connections to find where TPS peaks. This tells you the optimal pool_size for your pgBouncer configuration.

```sql
# Test different client counts (8-core server):
pgbench -c 1 -j 1 -T 30 pgbench_test   # tps = 1,200
pgbench -c 5 -j 2 -T 30 pgbench_test   # tps = 5,800
pgbench -c 10 -j 2 -T 30 pgbench_test  # tps = 8,500
pgbench -c 20 -j 4 -T 30 pgbench_test  # tps = 9,200  ← PEAK
pgbench -c 50 -j 4 -T 30 pgbench_test  # tps = 8,800
pgbench -c 100 -j 4 -T 30 pgbench_test # tps = 7,200
pgbench -c 200 -j 4 -T 30 pgbench_test # tps = 5,100
pgbench -c 500 -j 4 -T 30 pgbench_test # tps = 2,800
# Peak TPS at 20 connections (8 cores × 2.5)
# After 20: more connections = SLOWER
# Set pgBouncer pool_size = 20
# Set max_connections = 30 (pool + overhead)
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `/etc/sysctl.d/99-postgresql.conf` — Complete Linux Kernel Config for PostgreSQL
Here is the complete Linux kernel configuration for a 32 GB PostgreSQL production server. Save these settings in a sysctl configuration file.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `vm.swappiness` | `1` | `[SETTING]` | Nearly disable swap (keep PG memory in RAM) |
| `vm.dirty_ratio` | `5` | `[SETTING]` | Force flush at 5% dirty memory (avoid I/O storms) |
| `vm.dirty_background_ratio` | `2` | `[SETTING]` | Background flush starts at 2% dirty memory |
| `vm.nr_hugepages` | `4400` | `[SETTING]` | Reserve huge pages for 8GB shared_buffers |
| `vm.overcommit_memory` | `2` | `[SETTING]` | Don't overcommit — prevent OOM killer from killing PG |
| `vm.overcommit_ratio` | `90` | `[SETTING]` | Allow commit up to 90% of RAM + swap |
| `kernel.sched_migration_cost_ns` | `5000000` | `[SETTING]` | Reduce CPU migration for database workloads |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


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
