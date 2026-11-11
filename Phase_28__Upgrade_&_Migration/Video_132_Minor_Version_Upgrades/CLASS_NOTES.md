# Minor Version Upgrades
**Series:** PostgreSQL Mastery | **Phase:** Phase 28: Upgrade & Migration | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! We are now entering Phase 28 — Upgrade and Migration. In this phase, we learn how to safely upgrade PostgreSQL versions and migrate databases from other systems. We start with the simplest and most important upgrade you will ever do — the minor version upgrade. Minor upgrades like going from PostgreSQL 16.1 to 16.4 fix bugs and security vulnerabilities without changing features. They are low-risk, but skipping them is high-risk. Let us learn the right way to do them.

### The Problem — Unpatched Servers
Here is the scenario. A company runs PostgreSQL 16.1 in production. It works fine. Months go by. The PostgreSQL community releases 16.2, 16.3, 16.4 — each fixing bugs and security issues. The company ignores them because everything is working. Then one day, a security scanner flags a known vulnerability — CVE-2024-something — that was patched in 16.3. The company is now running a database with a publicly known exploit. The fix? A minor upgrade that takes less than five minutes with proper preparation.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand the basics of PostgreSQL installation and service management from Phase 1. You should also know how to use pg_dump and pg_restore from the backup phase. Recap — in Phase 27, we completed the full security setup. Now we ensure that secure server stays patched and up to date. A hardened server with known security vulnerabilities is not actually secure.

- Prerequisite: PostgreSQL installation (Phase 1)
- Prerequisite: Backup & restore (Phase 22)
- Prerequisite: Service management (systemctl)
- Recap: Phase 27 completed full security setup
- Now: Keeping that server patched and up to date

### PostgreSQL Version Numbering
PostgreSQL uses a three-part version number. The first two parts identify the major version — 16. The third part is the minor version — the patch release. Major versions like 15 to 16 add new features and may change behavior. Minor versions like 16.1 to 16.4 only fix bugs and security issues — they never add features and never change the data format. This means minor upgrades simply replace the binary files. No data migration, no dump-and-restore, no pg_upgrade needed. Just install the new package and restart.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Major Version (e.g., 16)** | New features, behavior changes, new data format. Released yearly. |
| **Minor Version (e.g., 16.4)** | Bug fixes and security patches only. No new features. Released quarterly. |
| **Minor Upgrade** | Replace binaries, restart. No data migration needed. |
| **Major Upgrade** | Requires pg_upgrade, dump/restore, or logical replication. Next class. |

### When to Apply Minor Upgrades
When should you apply minor upgrades? The PostgreSQL community releases minor versions roughly every quarter — February, May, August, and November. You should apply them within two weeks of release for production servers. For servers holding sensitive or regulated data, apply within one week. Never skip more than two minor releases — if you are on 16.1, upgrade to the latest like 16.4, not to 16.2. Always go to the latest available minor version.

| Release Schedule | Upgrade Timeline |
| :--- | :--- |
| Quarterly: Feb, May, Aug, Nov | Production: within 2 weeks of release |
| Each release: bug fixes + security patches | Sensitive/regulated data: within 1 week |
| Release notes list every fix | Always upgrade to LATEST minor (not just +1) |
| EOL: 5 years from major release | Never skip more than 2 minor releases |

### Pre-Upgrade Checklist
Before upgrading, always check the release notes. Go to postgresql.org/docs/release and find your target version. The release notes list every bug fix, every security patch, and any special notes. Look for the section that says items that may affect you. Occasionally, a bug fix changes behavior — for example, fixing a wrong query result means your application might see different data than before. Read the release notes. Then take a backup.

- 1. Read release notes at postgresql.org/docs/release
- 2. Check 'items that may affect you' section
- 3. Take a full backup (pg_dump or pg_basebackup)
- 4. Test the upgrade on staging/dev first
- 5. Schedule a maintenance window (restart = brief downtime)
- 6. Notify your team about the planned restart
- 7. Verify current version: SELECT version();

### Support This Free Course
If you are learning from this course, here is how to support it. Like this video so more people find it. Share it with someone learning PostgreSQL. Subscribe and hit the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping you, consider supporting it through the donation link in the description. Now let us look at handling replicas during upgrades.

- Like this video — helps others discover PostgreSQL Mastery
- Share with someone learning PostgreSQL
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### Beginner Traps — Minor Upgrade Mistakes
Beginner trap number one — upgrading without taking a backup first. Yes, minor upgrades are safe. But if the server hardware fails during the restart, or if the filesystem corrupts during the binary replacement, you need that backup. Always backup first. Trap two — upgrading the primary before the standbys. This can cause standbys to disconnect and require a full re-base. Always upgrade standbys first. Trap three — forgetting about extensions. If you have extensions from separate packages and they are not compatible with the new binary version, PostgreSQL may fail to start.

- Trap 1: No backup before upgrade
-   Minor upgrades are safe but hardware can fail during restart
-   Always: pg_dumpall before any upgrade
- Trap 2: Upgrading primary before standbys
-   Standbys may disconnect and need full re-base
-   Always: standbys first, primary last
- Trap 3: Forgetting extension packages
-   pgaudit, postgis, etc. need matching package versions
-   Fix: upgrade all postgresql-16-* packages together

### Practice Exercises
Here are your practice exercises. One — check your current PostgreSQL version and find out what minor versions are available. Two — take a full backup using pg_dumpall, then perform the minor upgrade on a test server. Three — write an automated upgrade script that logs every step. Four — practice the replica upgrade order — upgrade a standby first, verify replication, then upgrade the primary. Five — intentionally cause a failed upgrade by removing an extension package, then troubleshoot and fix it.

- 1. Check current version + available minor versions
- 2. Full pg_dumpall backup, then upgrade on test server
- 3. Write an automated upgrade script with logging
- 4. Practice replica upgrade order: standby first, primary last
- 5. Simulate failed upgrade (missing extension) and fix it


---

## 3. Hands-On Commands & psql Output

### The Problem — Unpatched Servers
**Explanation:** Here is the scenario. A company runs PostgreSQL 16.1 in production. It works fine. Months go by. The PostgreSQL community releases 16.2, 16.3, 16.4 — each fixing bugs and security issues. The company ignores them because everything is working. Then one day, a security scanner flags a known vulnerability — CVE-2024-something — that was patched in 16.3. The company is now running a database with a publicly known exploit. The fix? A minor upgrade that takes less than five minutes with proper preparation.

```sql
-- Company runs PostgreSQL 16.1 — 'everything works fine'

-- PostgreSQL releases:
-- 16.2 (Feb 2024): Fixes 3 bugs + 1 security issue
-- 16.3 (May 2024): Fixes 5 bugs + 2 security issues
-- 16.4 (Aug 2024): Fixes 4 bugs + 1 security issue

-- Company ignores all of them...

-- 6 months later: security scan flags CVE on 16.1
-- Fix was in 16.3 — a 5-minute upgrade
-- Now it's an emergency instead of routine maintenance
```

### Minor Upgrade — Debian/Ubuntu (APT)
**Explanation:** Let us do the upgrade. First, check your current version. Then check what versions are available in your package repository. On Debian and Ubuntu with the official PostgreSQL apt repository, the upgrade is a single apt command. The package manager replaces the binary files. Then restart PostgreSQL. The restart typically takes less than 30 seconds. After the restart, verify the new version.

```sql
-- Step 1: Check current version
postgres=# SELECT version();
                              version
-----------------------------------------------------------
 PostgreSQL 16.1 on x86_64-pc-linux-gnu

-- Step 2: Check available version
$ apt-cache policy postgresql-16
  Installed: 16.1-1.pgdg22.04+1
  Candidate: 16.4-1.pgdg22.04+1

-- Step 3: Take backup first!
$ pg_dumpall -U postgres > /backups/pre_upgrade_16.1.sql

-- Step 4: Upgrade the package
$ sudo apt update
$ sudo apt install postgresql-16

-- Step 5: Restart PostgreSQL
$ sudo systemctl restart postgresql-16

-- Step 6: Verify new version
postgres=# SELECT version();
 PostgreSQL 16.4 on x86_64-pc-linux-gnu
```

### Minor Upgrade — RHEL/Rocky/Alma (YUM/DNF)
**Explanation:** On RHEL, CentOS, Rocky, or AlmaLinux with the PGDG yum repository, the process is similar but uses yum or dnf. Check the current version, check available updates, take a backup, run yum update, and restart. On RHEL-based systems, the service name is postgresql-16 with a dash.

```sql
-- Check current installed version:
$ rpm -q postgresql16-server
postgresql16-server-16.1-1PGDG.rhel9.x86_64

-- Check available update:
$ sudo dnf check-update postgresql16*
postgresql16-server.x86_64  16.4-1PGDG.rhel9  pgdg16

-- Take backup first!
$ pg_dumpall -U postgres > /backups/pre_upgrade_16.1.sql

-- Upgrade:
$ sudo dnf update postgresql16*

-- Restart:
$ sudo systemctl restart postgresql-16

-- Verify:
postgres=# SELECT version();
 PostgreSQL 16.4 on x86_64-pc-linux-gnu
```

### Post-Upgrade Verification
**Explanation:** After the upgrade, verify everything is working. Check the version, check that all databases are accessible, run a quick query on your most important tables, check the PostgreSQL log for any errors, and verify that your application can connect. If you have a monitoring system, check that all metrics are healthy. The whole verification should take less than five minutes.

```sql
-- 1. Version check:
postgres=# SELECT version();
 PostgreSQL 16.4 on x86_64-pc-linux-gnu

-- 2. Database list:
postgres=# \l
    Name    |  Owner   | Encoding
------------+----------+----------
 app_db     | postgres | UTF8
 postgres   | postgres | UTF8

-- 3. Quick smoke test on critical table:
postgres=# SELECT count(*) FROM app_db.public.orders;
  count
---------
 1250000

-- 4. Check log for errors:
$ tail -20 /var/log/postgresql/postgresql-16-main.log
2026-11-04 23:55:00 UTC [1234] LOG:  database system is ready to accept connections
-- No errors = good!
```

### Extension Updates After Minor Upgrade
**Explanation:** What about extensions? When you upgrade the PostgreSQL package, extensions installed from the same repository are usually updated too. But if you installed extensions from separate packages, you need to update those separately. After upgrading, check if any extension needs an ALTER EXTENSION UPDATE command to update its catalog entry.

```sql
-- Check installed extensions and their versions:
postgres=# SELECT extname, extversion, extversion != default_version AS needs_update
postgres-# FROM pg_extension e JOIN pg_available_extensions a ON e.extname = a.name;
  extname  | extversion | needs_update
----------+------------+--------------
 plpgsql  | 1.0        | f
 pgcrypto | 1.3        | f
 pgaudit  | 16.0       | t

-- Update extensions that need it:
postgres=# ALTER EXTENSION pgaudit UPDATE;
ALTER EXTENSION

-- Update separate extension packages (if any):
$ sudo apt install postgresql-16-pgaudit
```

### Minor Upgrade — Windows
**Explanation:** What about Windows? On Windows, the upgrade process uses the installer or the update functionality. Download the new minor version installer from postgresql.org. Stop the PostgreSQL service. Run the installer — it detects the existing installation and upgrades in place. Start the service. The data directory is untouched — only the program files change.

```sql
-- Step 1: Check current version
psql -U postgres -c "SELECT version();"
 PostgreSQL 16.1, compiled by Visual C++

-- Step 2: Take backup
pg_dumpall -U postgres > C:\backups\pre_upgrade.sql

-- Step 3: Stop PostgreSQL service
net stop postgresql-x64-16

-- Step 4: Run new installer (downloads from postgresql.org)
-- Installer detects existing installation
-- Upgrades program files in C:\Program Files\PostgreSQL\16\
-- Data directory is NOT touched

-- Step 5: Start PostgreSQL service
net start postgresql-x64-16

-- Step 6: Verify
psql -U postgres -c "SELECT version();"
 PostgreSQL 16.4, compiled by Visual C++
```

### Automated Minor Upgrade Script (Linux)
**Explanation:** Automating minor upgrades. For production environments with multiple servers, automate the process. Use a simple shell script that checks the current version, takes a backup, runs the upgrade, restarts, and verifies. Schedule it to run during your maintenance window. Add notifications so you know if any step fails.

```sql
#!/bin/bash
# pg_minor_upgrade.sh
set -e

DATE=$(date +%Y%m%d)
LOG="/var/log/pg_upgrade_${DATE}.log"
BACKUP="/backups/pre_upgrade_${DATE}.sql"

echo "[$(date)] Starting minor upgrade" >> $LOG

# 1. Current version
CURRENT=$(psql -U postgres -t -c "SHOW server_version;" | xargs)
echo "Current: $CURRENT" >> $LOG

# 2. Backup
pg_dumpall -U postgres > $BACKUP 2>> $LOG
echo "Backup saved to $BACKUP" >> $LOG

# 3. Upgrade
sudo apt update >> $LOG 2>&1
sudo apt install -y postgresql-16 >> $LOG 2>&1

# 4. Restart
sudo systemctl restart postgresql-16

# 5. Verify
NEW=$(psql -U postgres -t -c "SHOW server_version;" | xargs)
echo "Upgraded: $CURRENT -> $NEW" >> $LOG

echo "[$(date)] Upgrade complete" >> $LOG
```

### Troubleshooting Failed Minor Upgrades
**Explanation:** What could go wrong? Minor upgrades are the safest type of PostgreSQL change, but things can still go wrong. If the package manager has a dependency conflict, the install may fail — but since PostgreSQL is still running on the old version, no harm done. If the restart fails, check the log — usually it is a configuration issue that existed before the upgrade. And rarely, a bug fix can change query behavior, which is why you test on staging first.

```sql
-- Problem 1: Package dependency conflict
$ sudo apt install postgresql-16
E: Unable to correct problems, you have held broken packages
-- Fix: sudo apt --fix-broken install
-- Or: sudo apt install -f

-- Problem 2: Service won't start after upgrade
$ sudo systemctl status postgresql-16
Active: failed
-- Fix: Check the log:
$ tail -50 /var/log/postgresql/postgresql-16-main.log
FATAL: could not load library "/usr/lib/postgresql/16/lib/pgaudit.so"
-- Fix: upgrade the extension package too:
$ sudo apt install postgresql-16-pgaudit

-- Problem 3: Rollback needed
-- Restore from backup taken before upgrade
-- Or: sudo apt install postgresql-16=16.1-1.pgdg22.04+1
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Minor Upgrade Mistakes
Beginner trap number one — upgrading without taking a backup first. Yes, minor upgrades are safe. But if the server hardware fails during the restart, or if the filesystem corrupts during the binary replacement, you need that backup. Always backup first. Trap two — upgrading the primary before the standbys. This can cause standbys to disconnect and require a full re-base. Always upgrade standbys first. Trap three — forgetting about extensions. If you have extensions from separate packages and they are not compatible with the new binary version, PostgreSQL may fail to start.

- Trap 1: No backup before upgrade
-   Minor upgrades are safe but hardware can fail during restart
-   Always: pg_dumpall before any upgrade
- Trap 2: Upgrading primary before standbys
-   Standbys may disconnect and need full re-base
-   Always: standbys first, primary last
- Trap 3: Forgetting extension packages
-   pgaudit, postgis, etc. need matching package versions
-   Fix: upgrade all postgresql-16-* packages together


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. Minor version upgrades fix bugs and security issues without changing features or the data format. They require only a package update and a restart — no data migration. Always read the release notes, take a backup, and test on staging first. Upgrade standbys before the primary. Update extension packages too. Apply minor upgrades within two weeks of release. Automate the process for multi-server environments. Minor upgrades are the easiest way to keep your database secure and stable.

- **Minor upgrades = bug fixes + security patches, no feature changes**
- **Process: update package, restart — no data migration needed**
- **Always: read release notes, backup, test on staging first**
- **Replica order: standbys first, primary last**
- **Extension packages: update them too (postgresql-16-*)**
- **Timeline: apply within 2 weeks of release**
- **Downtime: typically < 30 seconds for restart**
- **Automate for multi-server environments**


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
