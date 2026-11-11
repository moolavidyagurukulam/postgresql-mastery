# Tablespaces
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 11
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In our last class, we learned about schemas ... logical namespaces inside a database. Today we learn about tablespaces ... the physical locations where PostgreSQL stores data on disk. ... Schemas organize your objects logically. Tablespaces organize them physically. By the end of this class, you will understand when and how to use tablespaces. ... Let us begin!

### The Problem: One Disk for Everything?
Here is the scenario. You have a PostgreSQL server with two types of storage. A fast SSD for performance-critical data, and a large HDD for less frequently accessed data. ... By default, PostgreSQL stores everything in one location ... the data directory. But what if you want your most-used indexes on the SSD, and your archive tables on the HDD? ... Tablespaces let you control where PostgreSQL physically stores tables and indexes. You can put frequently accessed data on fast storage, and older data on slower, cheaper storage.

- Server has fast SSD + large HDD
- By default: everything stored in one data directory
- Want: hot indexes on SSD, archive tables on HDD
- Tablespaces = control WHERE data is stored on disk
- Put critical data on fast storage
- Today: CREATE, USE, and MANAGE tablespaces


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: One Disk for Everything?
Here is the scenario. You have a PostgreSQL server with two types of storage. A fast SSD for performance-critical data, and a large HDD for less frequently accessed data. ... By default, PostgreSQL stores everything in one location ... the data directory. But what if you want your most-used indexes on the SSD, and your archive tables on the HDD? ... Tablespaces let you control where PostgreSQL physically stores tables and indexes. You can put frequently accessed data on fast storage, and older data on slower, cheaper storage.

- Server has fast SSD + large HDD
- By default: everything stored in one data directory
- Want: hot indexes on SSD, archive tables on HDD
- Tablespaces = control WHERE data is stored on disk
- Put critical data on fast storage
- Today: CREATE, USE, and MANAGE tablespaces

### What is a Tablespace?
A tablespace is a named location on disk where PostgreSQL stores database files. ... Think of it this way. A schema organizes objects logically ... by name. A tablespace organizes objects physically ... by disk location. ... PostgreSQL creates two default tablespaces. pg_default stores regular user data. This is inside the data directory. pg_global stores cluster-wide shared data like system catalogs. ... You can create additional tablespaces that point to any directory on any mounted disk.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Named directory on disk where PG stores data files |
| **Schema** | Organizes objects LOGICALLY (by name) |
| **Tablespace** | Organizes objects PHYSICALLY (by disk) |
| **pg_default** | Default — stores user data in data directory |
| **pg_global** | Cluster-wide shared system data |

**Notes:**
- You can point tablespaces to any directory on any mounted disk

### When to Use Tablespaces
When should you use tablespaces? ... Use case 1 ... Performance. Put indexes and hot tables on fast SSDs. Archive data on cheaper HDDs. ... Use case 2 ... Disk space management. When your primary disk is full, create a tablespace on another disk to spread the data. ... Use case 3 ... Separation of concerns. Keep WAL files, indexes, and table data on separate physical disks to reduce I/O contention. ... When should you NOT use tablespaces? ... For most small to medium applications, the default pg_default tablespace is perfectly fine. Do not overcomplicate your setup unless you have a real performance or storage need.

| Good Use Cases | When NOT Needed |
| :--- | :--- |
| Indexes on fast SSD, data on HDD | Small to medium databases |
| Primary disk full — spread to another | Single-disk servers |
| Separate I/O for tables vs indexes | Cloud managed databases (RDS, etc.) |
| Archive old data to cheap storage | Don't overcomplicate without a reason |
| Large databases with mixed workloads | Default pg_default is fine for most apps |


---

## 3. Hands-On Commands & psql Output

### CREATE TABLESPACE
**Explanation:** To create a tablespace, first create a directory on disk and give ownership to the postgres operating system user. Then use CREATE TABLESPACE with the LOCATION option. ... On Linux: mkdir /mnt/fast_ssd/pg_data, then chown postgres that directory. Then in psql: CREATE TABLESPACE fast_ssd LOCATION slash mnt slash fast_ssd slash pg_data. ... On Windows, create a folder like D backslash pg_data and use that path. ... The directory must exist, be empty, and be owned by the PostgreSQL operating system user. Otherwise you get an error.

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
**Explanation:** Now let us use the tablespace. ... To create a table on a specific tablespace, add TABLESPACE at the end of CREATE TABLE. ... CREATE TABLE big_logs ... TABLESPACE fast_ssd. Now the data for big_logs is stored on the fast SSD. ... You can also create indexes on a different tablespace. CREATE INDEX ... TABLESPACE fast_ssd. This is very common ... putting indexes on fast SSDs while keeping table data on regular storage. ... You can even set a default tablespace for an entire database. ALTER DATABASE practice SET default_tablespace TO fast_ssd. Now every new table in that database goes to the fast SSD unless you specify otherwise.

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

### Querying Tablespace Information
**Explanation:** Here are some useful queries to check tablespace usage. ... To see which tablespace a table is on, query pg_tables. ... To check the size of each tablespace, use pg_tablespace_size. ... To see the physical location of each tablespace, query pg_tablespace. ... These are useful for monitoring disk usage across different storage devices.

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
**Explanation:** Common tablespace errors. ... Error 1 ... directory does not exist. You must create the directory on the operating system first before creating the tablespace. ... Error 2 ... could not set permissions on directory. The directory exists but the postgres OS user does not own it. chown postgres that directory. ... Error 3 ... tablespace is not empty. You cannot drop a tablespace that has objects in it. Move or drop the objects first. ... Important note ... moving a table to a different tablespace requires an exclusive lock and rewrites the entire table. For large tables, this takes time and blocks writes. Plan it during maintenance windows.

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
Common tablespace errors. ... Error 1 ... directory does not exist. You must create the directory on the operating system first before creating the tablespace. ... Error 2 ... could not set permissions on directory. The directory exists but the postgres OS user does not own it. chown postgres that directory. ... Error 3 ... tablespace is not empty. You cannot drop a tablespace that has objects in it. Move or drop the objects first. ... Important note ... moving a table to a different tablespace requires an exclusive lock and rewrites the entire table. For large tables, this takes time and blocks writes. Plan it during maintenance windows.

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

Practice exercises. ... Exercise 1 ... List all existing tablespaces with backslash db. Check their sizes. ... Exercise 2 ... If you have a second disk or directory available, create a tablespace. Create a table on it. Query the tablespace info. ... Exercise 3 ... Check which tablespace your existing tables are on using the pg_tables query. ... Exercise 4 ... Move a table between tablespaces using ALTER TABLE SET TABLESPACE. ... These exercises work best on a system where you can create directories. If you are on a managed cloud database, tablespaces may not be available ... that is normal.

1. Exercise 1: \db → list tablespaces and check sizes
2. Exercise 2: Create a tablespace (if you have a second disk/dir)
3. Exercise 3: Query pg_tables to see tablespace per table
4. Exercise 4: ALTER TABLE ... SET TABLESPACE to move data
5. Note: Cloud DBs (RDS, etc.) may not support custom tablespaces


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... A tablespace is a physical location on disk where PostgreSQL stores data. ... Two defaults: pg_default for user data, pg_global for system data. ... CREATE TABLESPACE needs: a directory owned by the postgres OS user. ... Use tablespaces for: putting indexes on fast SSDs, spreading data across disks, and separating I/O workloads. ... Moving objects between tablespaces locks the table and rewrites all data. Plan carefully. ... For most small setups, the default tablespace is perfectly fine. ... In our next class, we start learning data types ... beginning with numeric types!

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
