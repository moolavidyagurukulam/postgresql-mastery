# Tablespaces
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 11
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In Class 10, we learned how Schemas organize database objects logically like folders. Today we cover Tablespaces, how PostgreSQL organizes where your tables, indexes, and temporary sort files live physically on disk!. Imagine running a production server whose main 1 terabyte NVMe SSD is 95 percent full while huge cold audit logs sit right alongside your hottest customer payment indexes. By the end of this class, you will know how tablespaces work under the hood via OS symlinks, how to create and assign them safely, when to tune temp_tablespaces, why cloud RDS behaves differently, and how to move or drop tablespaces without downtime surprises. Let us get started!

### The Problem: One Disk for Everything?
Imagine this Friday-afternoon production emergency! Your PostgreSQL server has grown to 950 gigabytes on a 1 terabyte primary drive, and you are one busy weekend away from a complete disk-full outage. Or picture a second problem: 600 gigabytes of rarely read compliance logs are eating up your expensive NVMe flash SSD while hot customer checkout indexes fight for disk I/O! By default, PostgreSQL stores everything inside one PGDATA folder. Tablespaces let a DBA map specific large tables, hot indexes, temporary sort directories, or entire databases onto separate mounted physical volumes cleanly!

- Real Crisis: Primary 1 TB drive is 95% full and still growing daily
- Cost & Speed Problem: Cold 500 GB audit logs sitting on pricey NVMe SSD
- Default Behavior: PG puts every table and index into one PGDATA folder
- What Tablespaces Do: Map specific objects onto separate mounted drives
- Result: Hot indexes on NVMe SSD + archive tables on large HDD
- Today: CREATE, USE, QUERY, and SAFELY MANAGE tablespaces


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Mental Model
Before creating a tablespace, let us keep one clear distinction sharp in your mind from Classes 9 and 10. Schemas organize your database objects logically by team or business namespace, for example sales dot orders versus inventory dot items. Tablespaces organize objects physically by storage disk or mounted directory on your operating system! Think of a library: schema is the subject section like History or Science, whereas tablespace is which physical floor or storage building holds the shelves. Both are independent: two tables inside the very same sales schema can live on two completely different physical drives. Let us see what real problem this solves!

- Completed: Cluster, Databases (Class 09) & Logical Schemas (Class 10)
- Logical Organization = Schemas (by team / namespace inside a database)
- Physical Organization = Tablespaces (by SSD, NVMe, HDD, or mounted drive)
- Important Fact: One table can sit in schema 'sales' while living on a separate SSD!

### The Problem: One Disk for Everything?
Imagine this Friday-afternoon production emergency! Your PostgreSQL server has grown to 950 gigabytes on a 1 terabyte primary drive, and you are one busy weekend away from a complete disk-full outage. Or picture a second problem: 600 gigabytes of rarely read compliance logs are eating up your expensive NVMe flash SSD while hot customer checkout indexes fight for disk I/O! By default, PostgreSQL stores everything inside one PGDATA folder. Tablespaces let a DBA map specific large tables, hot indexes, temporary sort directories, or entire databases onto separate mounted physical volumes cleanly!

- Real Crisis: Primary 1 TB drive is 95% full and still growing daily
- Cost & Speed Problem: Cold 500 GB audit logs sitting on pricey NVMe SSD
- Default Behavior: PG puts every table and index into one PGDATA folder
- What Tablespaces Do: Map specific objects onto separate mounted drives
- Result: Hot indexes on NVMe SSD + archive tables on large HDD
- Today: CREATE, USE, QUERY, and SAFELY MANAGE tablespaces

### What is a Tablespace?
So what exactly is a tablespace? A tablespace is a named pointer inside PostgreSQL that maps a logical name to a real physical folder path on your server's filesystem. Every fresh PostgreSQL cluster already ships with two built-in tablespaces. First is pg_default, which holds all normal user tables, indexes, and databases inside your main PGDATA base directory unless you override it. Second is pg_global, which stores cluster-wide shared catalogs like user roles and database listings. Whenever you mount a new fast NVMe drive or large archive volume, creating a custom tablespace creates a clean symbolic link from PGDATA into that directory.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Named directory on disk where PG stores data files |
| **Schema** | Organizes objects LOGICALLY (by name) |
| **Tablespace** | Organizes objects PHYSICALLY (by disk) |
| **pg_default** | Default — stores user data in data directory |
| **pg_global** | Cluster-wide shared system data |

**Notes:**
- You can point tablespaces to any directory on any mounted disk

### How Tablespaces Work Under the Hood (OS Symlinks)
So how does PostgreSQL actually implement tablespaces behind the scenes? It is remarkably clean and worth every DBA knowing!. First, you create an empty folder on a second mounted disk and give ownership to the postgres operating system user. Second, when you run CREATE TABLESPACE, PostgreSQL records the tablespace in pg_tablespace and creates an operating system symbolic link inside your main data directory under pg_tblspc using the tablespace's numeric OID. Third, inside your target folder, PostgreSQL creates a version-stamped subfolder like PG_16 followed by database OIDs to store table and index segment files. Because PG depends on that mount, NEVER delete or unmount a tablespace disk while PostgreSQL is running, if that folder vanishes, queries touching it fail immediately!

> **Definition:** Inside $PGDATA/pg_tblspc/, PostgreSQL stores an OS symbolic link pointing to your custom disk path.

| Term | Meaning / Explanation |
| :--- | :--- |
| **1. Create Dir** | OS folder created and owned by postgres user (chmod 700 / chown) |
| **2. Symlink** | $PGDATA/pg_tblspc/<oid> points directly to your target directory |
| **3. Subdir** | PG creates PG_16_<catver>/<db_oid>/ inside that target mount |
| **4. Recovery** | Disk unmounted = PG refuses startup cleanly until mount is restored! |

### When to Use Tablespaces
When should you use tablespaces?. Use case 1. Performance. Put indexes and hot tables on fast SSDs. Archive data on cheaper HDDs. Use case 2. Disk space management. When your primary disk is full, create a tablespace on another disk to spread the data. Use case 3. Separation of concerns. Keep WAL files, indexes, and table data on separate physical disks to reduce I/O contention. When should you NOT use tablespaces?. For most small to medium applications, the default pg_default tablespace is perfectly fine. Do not overcomplicate your setup unless you have a real performance or storage need. Think of storage tiers like desk drawers versus basement storage cabinets: keep active everyday index lookups within arm's reach on NVMe flash, and push multi-year compliance logs down to lower-cost bulk disks.

| Good Use Cases | When NOT Needed |
| :--- | :--- |
| Indexes on fast SSD, data on HDD | Small to medium databases |
| Primary disk full — spread to another | Single-disk servers |
| Separate I/O for tables vs indexes | Cloud managed databases (RDS, etc.) |
| Archive old data to cheap storage | Don't overcomplicate without a reason |
| Large databases with mixed workloads | Default pg_default is fine for most apps |

### temp_tablespaces & Cloud-Managed Reality
Here are two real-world DBA secrets about tablespaces that tutorials often skip. First, PostgreSQL supports a setting called temp_tablespaces! Whenever large analytics queries exceed work_mem and spill temporary sort or hash files to disk, or when ETL jobs build temporary tables, setting temp_tablespaces to a fast scratch NVMe drive protects your main data disk from sudden space spikes!. Second, know cloud-managed reality: on AWS RDS, Aurora, Azure, or Google Cloud SQL, you cannot SSH in to mkdir folders or run CREATE TABLESPACE LOCATION! Cloud providers manage disk striping transparently behind high-IOPS EBS or NVMe volumes. Before requesting custom EBS volumes on AWS RDS, Azure, or GCP Cloud SQL, always verify whether managed single-disk RAID striping already distributes I/O automatically without adding tablespace operational overhead.

> **Definition:** Direct heavy sort/hash spill files to NVMe — and know cloud RDS restrictions!

| Term | Meaning / Explanation |
| :--- | :--- |
| **temp_tablespaces** | Stores temporary tables + huge ORDER BY / JOIN disk spill files |
| **Session Config** | SET temp_tablespaces = 'fast_nvme'; isolates temp I/O spikes! |
| **AWS RDS / Cloud** | Custom OS directory paths are blocked on RDS / Aurora / Cloud SQL |
| **Cloud Advice** | Scale IOPS/GP3 volumes on cloud instead of OS tablespaces |

### Tablespace Decision Guide by Workload
Use this quick decision table before creating custom tablespaces in any environment! For eighty percent of small-to-medium apps, Docker containers, or single-volume cloud instances like AWS RDS or Cloud SQL, leave everything in pg_default, because multiple tablespaces add backup and recovery complexity for zero speed gain on one disk. Where should you use tablespaces? On large bare-metal or multi-EBS database servers, place hot B-tree indexes on high-IOPS NVMe SSDs, offload cold multi-terabyte audit archives onto cheaper HDD volumes, and route massive analytical GROUP BY sort spills to dedicated temp_tablespaces. Look across every workload row in this guide: complexity only pays off when you genuinely have distinct physical storage tiers with measurable IOPS or capacity bottlenecks.

| Workload / Scenario | Recommended Tablespace | Why |
| :--- | :--- | :--- |
| Small / Medium App DB | pg_default (default) | Simple backups, zero symlink risk |
| Heavy B-Tree Indexes | fast_ssd / NVMe tablespace | Keeps hot index reads super fast |
| 500GB Cold Audit Logs | archive_hdd tablespace | Saves costly NVMe storage space |
| Massive Analytics Sorts | SET temp_tablespaces | Stops sort spills filling PGDATA |
| AWS RDS / Managed Cloud | None (use Cloud Storage) | OS paths restricted by cloud host |


---

## 3. Hands-On Commands & psql Output

### CREATE TABLESPACE
**Explanation:** Let us walk carefully through creating a tablespace step by step. Step 1 happens at the operating system level BEFORE opening psql: create the directory, here sudo mkdir minus p slash mnt slash fast_ssd slash pg_data, and immediately change ownership to the postgres user with sudo chown postgres colon postgres on Linux. Without postgres ownership, PostgreSQL refuses access for security!. Step 2 happens inside psql as a superuser: run CREATE TABLESPACE fast_ssd LOCATION followed by the exact folder path in single quotes. On Windows, create an empty folder like D backslash pg_data and grant the PostgreSQL service account full control before running CREATE TABLESPACE. Finally, verify your setup with backslash d b, showing pg_default, pg_global, and your brand-new fast_ssd tablespace! Remember one classic Linux setup mistake too: always run chown minus R postgres colon postgres on the new folder before running CREATE TABLESPACE, otherwise PostgreSQL immediately fails with permission denied because the server runs as the postgres user, not root.

```sql
-- Step 1: Create directory on disk (Linux)
$ sudo mkdir -p /mnt/fast_ssd/pg_data
$ sudo chown postgres:postgres /mnt/fast_ssd/pg_data

-- Step 2: Create the tablespace in PostgreSQL
postgres=# CREATE TABLESPACE fast_ssd LOCATION '/mnt/fast_ssd/pg_data';
CREATE TABLESPACE

-- Windows example:
-- CREATE TABLESPACE fast_ssd LOCATION 'D:\pg_data';

-- List all tablespaces
postgres=# \db
       Name       |  Owner   |      Location
------------------+----------+---------------------
 fast_ssd         | postgres | /mnt/fast_ssd/pg_data
 pg_default       | postgres |
 pg_global        | postgres |
```

### Using Tablespaces
**Explanation:** Now that fast_ssd exists, let us see all the practical ways to use tablespaces!. First, place a specific high-traffic table onto SSD storage by adding TABLESPACE fast_ssd at the end of CREATE TABLE big_logs. Second, and even more common in production, place heavy B-tree indexes onto fast NVMe storage using CREATE INDEX idx_logs_created ON big_logs TABLESPACE fast_ssd, while leaving bulk historical rows on cheaper disks!. Third, set the default destination for an entire database with ALTER DATABASE practice SET default_tablespace equals fast_ssd, so every new table created there lands on fast_ssd automatically without repeating the clause. Notice the syntax consistency across PostgreSQL objects: whether you pass TABLESPACE during CREATE DATABASE, CREATE TABLE, or CREATE INDEX, moving large B-tree indexes onto faster storage works seamlessly at the DDL level.

```sql
-- Create a table on a specific tablespace
practice=# CREATE TABLE big_logs (id SERIAL, message TEXT, created_at TIMESTAMP DEFAULT now()) TABLESPACE fast_ssd;
CREATE TABLE

-- Create an index on a specific tablespace
practice=# CREATE INDEX idx_logs_created ON big_logs (created_at) TABLESPACE fast_ssd;
CREATE INDEX

-- Set default tablespace for a database
practice=# ALTER DATABASE practice SET default_tablespace = 'fast_ssd';
ALTER DATABASE

-- Move an existing table to a different tablespace
practice=# ALTER TABLE big_logs SET TABLESPACE pg_default;
ALTER TABLE
-- NOTE: Moving rewrites the entire table — takes time + locks!
```

### Moving Objects Out & Safely Dropping a Tablespace
**Explanation:** What if later you need to move tables back or decommission an old storage disk? Here are the exact verified PostgreSQL 16 commands. To move one table, run ALTER TABLE big_logs SET TABLESPACE pg_default. Be warned: PostgreSQL physically copies every byte of that table while holding an ACCESS EXCLUSIVE lock, meaning reads and writes on that table pause until copying finishes! Always schedule huge moves during low-traffic windows. To evacuate an entire disk fast, PostgreSQL provides two huge shortcuts: ALTER TABLE ALL IN TABLESPACE fast_ssd SET TABLESPACE pg_default, and the same for INDEX ALL!. Once every database has zero objects inside fast_ssd, run DROP TABLESPACE IF EXISTS fast_ssd safely. Notice how cleanly psql shows errors too: trying to drop a tablespace that still holds even one index fails safely until you either move or drop those objects first.

```sql
-- Move one table to another tablespace (WARNING: acquires ACCESS EXCLUSIVE lock!)
practice=# ALTER TABLE big_logs SET TABLESPACE pg_default;
ALTER TABLE

-- Move EVERY table/index inside fast_ssd back to pg_default in one command
practice=# ALTER TABLE ALL IN TABLESPACE fast_ssd SET TABLESPACE pg_default;
ALTER TABLE
practice=# ALTER INDEX ALL IN TABLESPACE fast_ssd SET TABLESPACE pg_default;
ALTER INDEX

-- Now tablespace is empty in ALL databases — safe to drop!
practice=# DROP TABLESPACE IF EXISTS fast_ssd;
DROP TABLESPACE
```

### Querying Tablespace Information
**Explanation:** Let us run three essential DBA catalog queries to monitor tablespace storage across a live cluster. First, select tablename and tablespace from pg_tables to discover exactly which disk holds each table. Notice a blank or NULL entry simply means the table lives in pg_default! Second, select spcname and pg_size_pretty of pg_tablespace_size from pg_tablespace to see exact human-readable gigabytes consumed per tablespace volume before disks approach eighty percent full. Third, call pg_tablespace_location passing the tablespace oid to print the exact operating system directory path mapped to every custom tablespace. Adding these three pg_tables, pg_tablespace, and pg_tablespace_location queries into your weekly disk-monitoring checklist prevents unpleasant surprises during peak traffic or monthly batch jobs.

```sql
-- Which tablespace is a table on?
practice=# SELECT tablename, tablespace FROM pg_tables WHERE schemaname = 'public';
 tablename | tablespace
-----------+------------
 big_logs  |
-- NULL or blank = pg_default

-- Tablespace sizes
practice=# SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) AS size FROM pg_tablespace;
  spcname   |  size
------------+---------
 pg_default | 23 MB
 pg_global  | 565 kB
 fast_ssd   | 0 bytes

-- Tablespace locations
practice=# SELECT spcname, pg_tablespace_location(oid) FROM pg_tablespace;
  spcname   |    pg_tablespace_location
------------+---------------------------
 pg_default |
 pg_global  |
 fast_ssd   | /mnt/fast_ssd/pg_data
```

### Common Tablespace Errors
**Explanation:** Common tablespace errors. Error 1. directory does not exist. You must create the directory on the operating system first before creating the tablespace. Error 2. could not set permissions on directory. The directory exists but the postgres OS user does not own it. chown postgres that directory. Error 3. tablespace is not empty. You cannot drop a tablespace that has objects in it. Move or drop the objects first. Important note. moving a table to a different tablespace requires an exclusive lock and rewrites the entire table. For large tables, this takes time and blocks writes. Plan it during maintenance windows.

```sql
-- ERROR: directory does not exist
postgres=# CREATE TABLESPACE test LOCATION '/does/not/exist';
ERROR:  directory "/does/not/exist" does not exist
-- FIX: Create the directory first on the OS

-- ERROR: could not set permissions
-- FIX: sudo chown postgres:postgres /path/to/dir

-- ERROR: tablespace not empty, cannot drop
postgres=# DROP TABLESPACE fast_ssd;
ERROR:  tablespace "fast_ssd" is not empty
-- FIX: Move objects out first, then drop

-- WARNING: Moving tables LOCKS the table and rewrites all data!
-- Plan large moves during maintenance windows
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Tablespace Errors
Common tablespace errors. Error 1. directory does not exist. You must create the directory on the operating system first before creating the tablespace. Error 2. could not set permissions on directory. The directory exists but the postgres OS user does not own it. chown postgres that directory. Error 3. tablespace is not empty. You cannot drop a tablespace that has objects in it. Move or drop the objects first. Important note. moving a table to a different tablespace requires an exclusive lock and rewrites the entire table. For large tables, this takes time and blocks writes. Plan it during maintenance windows.

```sql
-- ERROR: directory does not exist
CREATE TABLESPACE test LOCATION '/does/not/exist';
ERROR:  directory "/does/not/exist" does not exist
-- FIX: Create the directory first on the OS

-- ERROR: could not set permissions
-- FIX: sudo chown postgres:postgres /path/to/dir

-- ERROR: tablespace not empty, cannot drop
DROP TABLESPACE fast_ssd;
ERROR:  tablespace "fast_ssd" is not empty
-- FIX: Move objects out first, then drop

-- WARNING: Moving tables LOCKS the table and rewrites all data!
-- Plan large moves during maintenance windows
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice exercises. Exercise 1. List all existing tablespaces with backslash db. Check their sizes. Exercise 2. If you have a second disk or directory available, create a tablespace. Create a table on it. Query the tablespace info. Exercise 3. Check which tablespace your existing tables are on using the pg_tables query. Exercise 4. Move a table between tablespaces using ALTER TABLE SET TABLESPACE. These exercises work best on a system where you can create directories. If you are on a managed cloud database, tablespaces may not be available. that is normal. Try every exercise safely in your test cluster so moving an index via ALTER INDEX SET TABLESPACE feels second nature before you need it on a live production drive.

1. Exercise 1: \db → list tablespaces and check sizes
2. Exercise 2: Create a tablespace (if you have a second disk/dir)
3. Exercise 3: Query pg_tables to see tablespace per table
4. Exercise 4: ALTER TABLE ... SET TABLESPACE to move data
5. Note: Cloud DBs (RDS, etc.) may not support custom tablespaces


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. A tablespace is a physical location on disk where PostgreSQL stores data. Two defaults: pg_default for user data, pg_global for system data. CREATE TABLESPACE needs: a directory owned by the postgres OS user. Use tablespaces for: putting indexes on fast SSDs, spreading data across disks, and separating I/O workloads. Moving objects between tablespaces locks the table and rewrites all data. Plan carefully. For most small setups, the default tablespace is perfectly fine. In our next class, we start learning data types. beginning with numeric types! Master pg_default, pg_global, custom CREATE TABLESPACE mounts, and temp_tablespaces, and you will make confident physical storage decisions across bare metal and cloud databases alike.

- **Tablespace = named physical location on disk**
- **Defaults: pg_default (user data), pg_global (system)**
- **CREATE TABLESPACE name LOCATION '/path/to/dir';**
- **Directory must exist + owned by postgres OS user**
- **Use: indexes on SSD, archive on HDD, spread I/O**
- **ALTER TABLE ... SET TABLESPACE = locks + full rewrite**
- **For small/medium apps: default pg_default is fine**


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


## Answer Key ? Tablespace Practice Solutions
1. **List Tablespaces & Sizes:** `\db+` or `SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) FROM pg_tablespace;`
2. **Create Tablespace & Table:** Create OS directory owned by `postgres`, then `CREATE TABLESPACE fast_ssd LOCATION '/mnt/fast_ssd/pg_data';` and `CREATE TABLE t1 (id INT) TABLESPACE fast_ssd;`
3. **Check Tablespace Per Table:** `SELECT tablename, COALESCE(tablespace, 'pg_default') FROM pg_tables WHERE schemaname = 'public';`
4. **Move Table Between Tablespaces:** `ALTER TABLE t1 SET TABLESPACE pg_default;` *(takes an `ACCESS EXCLUSIVE` lock while copying)*.
5. **Cloud Databases (RDS / Azure / GCP):** Custom OS disk paths are usually restricted; use managed storage classes / IOPS tiers instead.
