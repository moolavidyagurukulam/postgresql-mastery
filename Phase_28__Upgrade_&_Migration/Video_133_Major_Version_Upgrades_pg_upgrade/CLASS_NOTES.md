# Major Version Upgrades with pg_upgrade
**Series:** PostgreSQL Mastery | **Phase:** Phase 28: Upgrade & Migration | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we learned minor version upgrades — quick and simple. Now we tackle the big one — major version upgrades. Going from PostgreSQL 15 to 16, or 14 to 16, requires special handling because major versions change the internal data storage format. The tool for this is pg_upgrade — a purpose-built utility that upgrades your data directory in place without requiring a full dump-and-restore. In copy mode, it migrates the catalog while reusing your existing data files. In link mode, it finishes in seconds even for terabyte databases. Let us walk through every step.

### The Problem — Upgrading Large Databases
Here is the scenario. Your company has been running PostgreSQL 15 for two years. PostgreSQL 16 brings features you need — improved query performance, new SQL syntax, better security defaults. But you have a 500-gigabyte database. A full pg_dump and pg_restore would take hours with significant downtime. pg_upgrade solves this — it converts only the system catalog while keeping your actual data files. In copy mode, it copies data files which still takes time but less than dump-restore. In link mode, it creates hard links to the existing files and finishes in seconds regardless of database size.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand minor version upgrades from the previous class. You should know where PostgreSQL stores its data directory, configuration files, and binaries. And you should be comfortable with pg_dump and pg_basebackup for creating backups. Recap — minor upgrades replace binaries and restart. Major upgrades change the data format, so the data must be converted or migrated.

- Prerequisite: Minor version upgrades (previous class)
- Prerequisite: Data directory location and config files
- Prerequisite: Backup tools (pg_dump, pg_basebackup)
- Recap: Minor upgrade = replace binaries + restart
- Now: Major upgrade = data format conversion with pg_upgrade

### The Problem — Upgrading Large Databases
Here is the scenario. Your company has been running PostgreSQL 15 for two years. PostgreSQL 16 brings features you need — improved query performance, new SQL syntax, better security defaults. But you have a 500-gigabyte database. A full pg_dump and pg_restore would take hours with significant downtime. pg_upgrade solves this — it converts only the system catalog while keeping your actual data files. In copy mode, it copies data files which still takes time but less than dump-restore. In link mode, it creates hard links to the existing files and finishes in seconds regardless of database size.

| pg_dump + pg_restore | pg_upgrade |
| :--- | :--- |
| Dumps all data to SQL or custom format | Converts system catalog only |
| Restores into new version cluster | Reuses actual data files |
| 500 GB = hours of downtime | Copy mode: faster than dump/restore |
| Requires 2x disk space | Link mode: seconds, any size |
| Simple but very slow | Recommended for production |

### How pg_upgrade Works
pg_upgrade works by creating a new empty PostgreSQL cluster with the target version, then migrating the system catalog — the internal metadata about your databases, tables, indexes, and roles — from the old cluster to the new one. The actual data files on disk do not change format between major versions — only the catalog format changes. In copy mode, pg_upgrade copies the data files to the new data directory. In link mode, it creates hard links — the new data directory points to the same physical files on disk. Link mode is almost instant but means you cannot use the old cluster anymore after the upgrade.

| Term | Meaning / Explanation |
| :--- | :--- |
| **System Catalog** | Internal tables that describe your databases, tables, columns, indexes, roles |
| **Data Files** | Actual table and index data on disk — format is compatible across major versions |
| **Copy Mode (--copy)** | Copies data files to new directory. Safe rollback. Needs 2x disk space. |
| **Link Mode (--link)** | Hard links to existing files. Instant. Old cluster unusable after. |

### Support This Free Course
If you are learning from this course, here is how to support it. Like this video so more people find it. Share it with someone learning PostgreSQL. Subscribe and hit the bell icon so you never miss a class. Download today's class materials from the link in the description — the complete pg_upgrade command sequences are ready to use. And if this free course is helping you, consider supporting it through the donation link in the description. Now let us cover what to do when pg_upgrade finds problems.

- Like this video — helps others discover PostgreSQL Mastery
- Share with someone learning PostgreSQL
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### Copy Mode vs Link Mode
Copy mode versus link mode — which should you choose? Copy mode is safer — it copies all data files to the new data directory, leaving the old one intact. If something goes wrong, you can start the old cluster and you are back to where you started. But it requires enough disk space for both copies and takes longer. Link mode is faster — it creates hard links so the new cluster points to the same physical files. For a terabyte database, link mode finishes in seconds. But once you start the new cluster, the old data directory is modified and unusable. You must have a backup before using link mode.

| Copy Mode (default) | Link Mode (--link) |
| :--- | :--- |
| Copies all data files to new directory | Hard links to existing files |
| Old cluster intact — safe rollback | Old cluster unusable after start |
| Requires 2x disk space | No extra disk space needed |
| Time proportional to database size | Finishes in seconds (any size) |
| 500 GB = ~30-60 minutes | 500 GB = ~30 seconds |
| Use when: disk space available + want rollback | Use when: need fast upgrade + have backup |

### Practice Exercises
Here are your practice exercises. One — install PostgreSQL 15 and 16 on a test server, create a test database in 15, and run pg_upgrade check to verify compatibility. Two — perform a full pg_upgrade in copy mode and verify all data is intact. Three — perform a pg_upgrade in link mode and measure the time difference. Four — intentionally create a check failure by adding a regclass column, then fix it and re-run. Five — practice the full upgrade workflow including config migration, extension updates, and statistics rebuild.

- 1. Install PG 15+16, create test DB, run pg_upgrade --check
- 2. Full pg_upgrade in copy mode — verify all data intact
- 3. Full pg_upgrade in link mode — measure time difference
- 4. Create regclass column, observe check failure, fix it
- 5. Full workflow: upgrade + config + extensions + vacuumdb


---

## 3. Hands-On Commands & psql Output

### Step 1: Install New Version Alongside Old
**Explanation:** Step one — install the new PostgreSQL version alongside the old one. On Debian and Ubuntu, you can have multiple major versions installed simultaneously. The packages go into different directories. The old version keeps running while you prepare the new one. On RHEL systems, the same applies — install the new packages without removing the old ones.

```sql
-- Check current version:
postgres=# SELECT version();
 PostgreSQL 15.8 on x86_64-pc-linux-gnu

-- Install PostgreSQL 16 alongside 15 (Debian/Ubuntu):
$ sudo apt install postgresql-16

-- Now both versions are installed:
$ ls /usr/lib/postgresql/
15  16

-- Old cluster still running on port 5432:
$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory
15  main    5432 online postgres /var/lib/postgresql/15/main
16  main    5433 online postgres /var/lib/postgresql/16/main
```

### Step 2: Prepare — Stop Clusters
**Explanation:** Step two — prepare for the upgrade. Stop both clusters. The old cluster must be stopped cleanly — not killed. The new cluster should be an empty, freshly initialized cluster. If the installer created one automatically, drop it and reinitialize. Check that both binaries are accessible and note the paths to the data directories, config files, and binaries for both versions.

```sql
-- Stop both PostgreSQL clusters:
$ sudo systemctl stop postgresql@15-main
$ sudo systemctl stop postgresql@16-main

-- Verify both are stopped:
$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory
15  main    5432 down   postgres /var/lib/postgresql/15/main
16  main    5433 down   postgres /var/lib/postgresql/16/main

-- Drop the auto-created PG 16 cluster (it has no data):
$ sudo pg_dropcluster 16 main

-- Reinitialize empty PG 16 cluster:
$ sudo pg_createcluster 16 main

-- Note the key paths:
-- Old binaries: /usr/lib/postgresql/15/bin/
-- New binaries: /usr/lib/postgresql/16/bin/
-- Old data dir: /var/lib/postgresql/15/main/
-- New data dir: /var/lib/postgresql/16/main/
```

### Step 3: Run Compatibility Check
**Explanation:** Step three — run the pg_upgrade compatibility check. Before the actual upgrade, run pg_upgrade with the check flag. This performs all the pre-flight checks without changing anything. It verifies that both clusters are compatible, the encodings match, the locale settings are correct, and there are no data type incompatibilities. If the check passes, the actual upgrade will succeed.

```sql
-- Run as postgres user:
$ sudo -u postgres bash

-- Run pg_upgrade with --check (dry run):
$ /usr/lib/postgresql/16/bin/pg_upgrade \
    --old-bindir=/usr/lib/postgresql/15/bin \
    --new-bindir=/usr/lib/postgresql/16/bin \
    --old-datadir=/var/lib/postgresql/15/main \
    --new-datadir=/var/lib/postgresql/16/main \
    --check

Performing Consistency Checks
-----------------------------
Checking cluster versions                          ok
Checking database user is the install user          ok
Checking database connection settings               ok
Checking for prepared transactions                  ok
Checking for system-defined composite types         ok
Checking for reg* data types in user tables          ok
Checking for contrib/isn with bigint-passing mismatch  ok
*Clusters are compatible*
```

### Step 4: Run pg_upgrade (Link Mode)
**Explanation:** Step four — run the actual upgrade. Remove the check flag and optionally add the link flag for instant migration. In link mode, pg_upgrade creates hard links instead of copying files. This means the upgrade finishes in seconds even for terabyte databases. But once you start the new cluster with link mode, the old data directory becomes invalid — you cannot go back without restoring from backup. For copy mode, just omit the link flag. Copy mode is slower but lets you keep the old cluster as a rollback option.

```sql
-- Run the actual upgrade with --link:
$ /usr/lib/postgresql/16/bin/pg_upgrade \
    --old-bindir=/usr/lib/postgresql/15/bin \
    --new-bindir=/usr/lib/postgresql/16/bin \
    --old-datadir=/var/lib/postgresql/15/main \
    --new-datadir=/var/lib/postgresql/16/main \
    --link

Performing Consistency Checks
-----------------------------
... (all checks pass)

Performing Upgrade
------------------
Analyzing all rows in the new cluster               ok
Freezing all rows in the new cluster                ok
Deleting files from new pg_xact                    ok
Copying old pg_xact to new server                  ok
Setting next transaction ID and epoch               ok
Setting oldest multixact ID                        ok
Resetting WAL archives                             ok
Linking user relation files                        ok

Upgrade Complete
----------------
Optimizer statistics are not transferred by pg_upgrade.
Once you start the new server, consider running:
    /usr/lib/postgresql/16/bin/vacuumdb --all --analyze-in-stages
```

### Step 5: Post-Upgrade Configuration & Start
**Explanation:** Step five — post-upgrade tasks. Copy your custom configuration from the old postgresql.conf and pg_hba.conf to the new cluster. Do not just copy the files — the new version may have new parameters or changed defaults. Instead, compare them side by side and apply your customizations to the new config files. Then start the new cluster, run vacuumdb with analyze-in-stages to rebuild optimizer statistics, and verify everything works.

```sql
-- Compare config files (do NOT just copy old over new):
$ diff /etc/postgresql/15/main/postgresql.conf \
       /etc/postgresql/16/main/postgresql.conf

-- Apply your custom settings to the new config:
-- Edit /etc/postgresql/16/main/postgresql.conf
-- Edit /etc/postgresql/16/main/pg_hba.conf

-- Start the new cluster:
$ sudo systemctl start postgresql@16-main

-- Update optimizer statistics (important!):
$ /usr/lib/postgresql/16/bin/vacuumdb --all --analyze-in-stages
vacuumdb: processing database "app_db": Generating minimal optimizer statistics
vacuumdb: processing database "app_db": Generating medium optimizer statistics
vacuumdb: processing database "app_db": Generating default optimizer statistics

-- Verify:
postgres=# SELECT version();
 PostgreSQL 16.4 on x86_64-pc-linux-gnu
```

### Step 6: Update Extensions
**Explanation:** Step six — update extensions. After a major version upgrade, extensions may need to be reinstalled or updated. The old extension shared libraries are for the old version and will not work with the new binary. Install the new version's extension packages and run ALTER EXTENSION UPDATE for each one.

```sql
-- Install extension packages for PG 16:
$ sudo apt install postgresql-16-pgaudit postgresql-16-postgis-3

-- Check which extensions need updating:
postgres=# SELECT extname, extversion AS installed, a.default_version AS available
postgres-# FROM pg_extension e JOIN pg_available_extensions a ON e.extname = a.name
postgres-# WHERE e.extversion != a.default_version;
  extname  | installed | available
----------+-----------+-----------
 pgaudit  | 1.7       | 16.0

-- Update each extension:
postgres=# ALTER EXTENSION pgaudit UPDATE;
ALTER EXTENSION
```

### Common pg_upgrade Check Failures
**Explanation:** The check step can fail for several reasons. The most common is reg star data types in user tables. PostgreSQL stores some catalog references as reg types like regclass or regproc. These contain OIDs that are valid only in the old cluster. If your tables have columns of these types, you need to change them before upgrading. Another common issue is prepared transactions — any open two-phase commit transactions must be committed or rolled back before pg_upgrade will run.

```sql
-- Failure 1: reg* data types in user tables
Checking for reg* data types in user tables    FAILED
Your installation contains one of the reg* data types in user tables.

-- Fix: find and convert the columns
postgres=# SELECT n.nspname, c.relname, a.attname, t.typname
postgres-# FROM pg_class c JOIN pg_attribute a ON c.oid = a.attrelid
postgres-# JOIN pg_type t ON a.atttypid = t.oid
postgres-# JOIN pg_namespace n ON c.relnamespace = n.oid
postgres-# WHERE t.typname ~ '^reg' AND c.relkind = 'r' AND n.nspname NOT LIKE 'pg_%';

-- Failure 2: Prepared transactions
Checking for prepared transactions              FAILED

-- Fix: commit or rollback prepared transactions
postgres=# SELECT gid FROM pg_prepared_xacts;
postgres=# ROLLBACK PREPARED 'transaction_name';
```

### Step 7: Cleanup After Successful Upgrade
**Explanation:** After the upgrade is complete and verified, clean up. Delete the old cluster data directory to free disk space. Remove the old PostgreSQL packages if you do not need them. And run the delete script that pg_upgrade generates — it removes the old cluster's data files safely.

```sql
-- pg_upgrade generates cleanup scripts:
$ ls *_script
analyze_new_cluster.sh  delete_old_cluster.sh

-- Run analyze (if not done with vacuumdb):
$ ./analyze_new_cluster.sh

-- After verifying everything works, delete old cluster:
$ ./delete_old_cluster.sh

-- Remove old PostgreSQL packages:
$ sudo apt remove postgresql-15

-- Update port if needed (new cluster may be on 5433):
-- Edit /etc/postgresql/16/main/postgresql.conf
-- Change port = 5433 to port = 5432
$ sudo systemctl restart postgresql@16-main
```

### pg_upgrade on RHEL/Rocky/Alma
**Explanation:** What about RHEL and CentOS? The process is identical but the paths are different. On RHEL, the binaries are in /usr/pgsql-15/bin and /usr/pgsql-16/bin. The data directories are typically in /var/lib/pgsql/15/data and /var/lib/pgsql/16/data. And the pg_upgrade command uses these RHEL-specific paths. Everything else — the check, the upgrade, the post-upgrade steps — is the same.

```sql
-- RHEL paths:
-- Old binaries: /usr/pgsql-15/bin/
-- New binaries: /usr/pgsql-16/bin/
-- Old data:     /var/lib/pgsql/15/data/
-- New data:     /var/lib/pgsql/16/data/

-- Initialize new cluster:
$ sudo /usr/pgsql-16/bin/postgresql-16-setup initdb

-- Stop both:
$ sudo systemctl stop postgresql-15
$ sudo systemctl stop postgresql-16

-- Run pg_upgrade:
$ sudo -u postgres /usr/pgsql-16/bin/pg_upgrade \
    --old-bindir=/usr/pgsql-15/bin \
    --new-bindir=/usr/pgsql-16/bin \
    --old-datadir=/var/lib/pgsql/15/data \
    --new-datadir=/var/lib/pgsql/16/data \
    --link
```

### Beginner Traps — pg_upgrade Mistakes
**Explanation:** Beginner trap number one — running pg_upgrade as root instead of the postgres user. pg_upgrade must run as the same OS user that owns the data directories, which is postgres. Running as root causes permission errors. Trap two — not stopping both clusters before running pg_upgrade. Both the old and new clusters must be completely stopped. Trap three — copying the old postgresql.conf directly over the new one. The new version may have new parameters or changed defaults. Always diff and apply only your customizations.

```sql
-- Trap 1: Running as root
$ sudo pg_upgrade --old-bindir=... --new-bindir=...
pg_upgrade: cannot be run as root
-- Fix: sudo -u postgres pg_upgrade ...

-- Trap 2: Clusters not stopped
$ /usr/lib/postgresql/16/bin/pg_upgrade --check ...
There seems to be a postmaster servicing the old cluster.
Please shutdown that postmaster and try again.
-- Fix: sudo systemctl stop postgresql@15-main

-- Trap 3: Copying old config directly
-- BAD: cp /etc/postgresql/15/main/postgresql.conf \
--          /etc/postgresql/16/main/postgresql.conf
-- GOOD: diff the files, apply only your custom settings
$ diff /etc/postgresql/15/main/postgresql.conf \
       /etc/postgresql/16/main/postgresql.conf | head -30
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — pg_upgrade Mistakes
Beginner trap number one — running pg_upgrade as root instead of the postgres user. pg_upgrade must run as the same OS user that owns the data directories, which is postgres. Running as root causes permission errors. Trap two — not stopping both clusters before running pg_upgrade. Both the old and new clusters must be completely stopped. Trap three — copying the old postgresql.conf directly over the new one. The new version may have new parameters or changed defaults. Always diff and apply only your customizations.

```sql
-- Trap 1: Running as root
$ sudo pg_upgrade --old-bindir=... --new-bindir=...
pg_upgrade: cannot be run as root
-- Fix: sudo -u postgres pg_upgrade ...

-- Trap 2: Clusters not stopped
$ /usr/lib/postgresql/16/bin/pg_upgrade --check ...
There seems to be a postmaster servicing the old cluster.
Please shutdown that postmaster and try again.
-- Fix: sudo systemctl stop postgresql@15-main

-- Trap 3: Copying old config directly
-- BAD: cp /etc/postgresql/15/main/postgresql.conf \
--          /etc/postgresql/16/main/postgresql.conf
-- GOOD: diff the files, apply only your custom settings
$ diff /etc/postgresql/15/main/postgresql.conf \
       /etc/postgresql/16/main/postgresql.conf | head -30
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. Major version upgrades use pg_upgrade to convert the system catalog while keeping data files intact. Always run pg_upgrade check before the actual upgrade. Copy mode is safer with rollback capability but slower. Link mode is near-instant but makes the old cluster unusable. After upgrading, migrate your custom configuration carefully, update extensions, and rebuild optimizer statistics with vacuumdb. Take a full backup before any major upgrade. Always test on staging first.

- **pg_upgrade converts catalog, keeps data files intact**
- **Always run --check first (dry run, no changes)**
- **Copy mode: safe rollback, needs 2x disk, slower**
- **Link mode: instant, old cluster unusable, needs backup**
- **Post-upgrade: diff configs, update extensions, run vacuumdb**
- **Run as postgres user, both clusters must be stopped**
- **Test on staging before production**
- **Take full backup before every major upgrade**


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
