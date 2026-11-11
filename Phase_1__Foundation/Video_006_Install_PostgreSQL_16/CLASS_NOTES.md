# Install PostgreSQL 16 on Linux & Windows
**Series:** PostgreSQL Mastery | **Phase:** Phase 1: Foundation | **Classes:** Class 06
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In our previous class, we learned PostgreSQL terminology. Now it is time to get our hands dirty! Today, we install PostgreSQL 16 on your machine. By the end of this class, you will have a working PostgreSQL 16 server, and you will connect to it for the first time. ... Let us get started!

### The Problem
Here is the situation. You want to learn PostgreSQL. You have read about it. You know the theory. But you cannot practice without a working installation. Many beginners get stuck right at this step because the installation instructions on the internet are often for different versions, different operating systems, or are incomplete. ... Today, we do a clean, step by step installation. No shortcuts. Every command explained. Every step verified.

- You want to PRACTICE PostgreSQL — but need a working install first
- Internet instructions: wrong version, wrong OS, incomplete
- Today: Clean, step-by-step install — no shortcuts
- Every command explained, every step verified
- We cover BOTH Linux (Debian/Ubuntu) and Windows

### Why PostgreSQL 16?
Why PostgreSQL 16 specifically? ... PostgreSQL 16 was released in September 2023. It includes logical replication from standby servers, parallel full vacuum, improved query performance, and better monitoring. It is stable, well-tested, and widely supported. ... We use version 16 throughout this entire course. Every command, every config, every example is tested on PostgreSQL 16. This way, your output will match exactly what you see in our videos.

- Released September 2023 — stable and well-tested
- Logical replication from standby, parallel VACUUM
- Improved query performance and monitoring
- Used throughout this ENTIRE course
- Every command tested on PG 16 — your output will match ours


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should know what PostgreSQL is and the basic terminology like cluster, database, and schema. We covered these in the previous classes on What is PostgreSQL and PostgreSQL Terminology.

- You should know: What is PostgreSQL + PostgreSQL Terminology
- You need: A computer with Linux (Debian/Ubuntu) or Windows
- We will install: PostgreSQL 16 (the version used in this course)

### The Problem
Here is the situation. You want to learn PostgreSQL. You have read about it. You know the theory. But you cannot practice without a working installation. Many beginners get stuck right at this step because the installation instructions on the internet are often for different versions, different operating systems, or are incomplete. ... Today, we do a clean, step by step installation. No shortcuts. Every command explained. Every step verified.

- You want to PRACTICE PostgreSQL — but need a working install first
- Internet instructions: wrong version, wrong OS, incomplete
- Today: Clean, step-by-step install — no shortcuts
- Every command explained, every step verified
- We cover BOTH Linux (Debian/Ubuntu) and Windows

### Why PostgreSQL 16?
Why PostgreSQL 16 specifically? ... PostgreSQL 16 was released in September 2023. It includes logical replication from standby servers, parallel full vacuum, improved query performance, and better monitoring. It is stable, well-tested, and widely supported. ... We use version 16 throughout this entire course. Every command, every config, every example is tested on PostgreSQL 16. This way, your output will match exactly what you see in our videos.

- Released September 2023 — stable and well-tested
- Logical replication from standby, parallel VACUUM
- Improved query performance and monitoring
- Used throughout this ENTIRE course
- Every command tested on PG 16 — your output will match ours

### Linux File Paths Reference (Debian/Ubuntu)
Let me give you a clean reference table of all the important paths. Save this ... you will need it throughout the course.

| What | Path |
| :--- | :--- |
| Config directory | /etc/postgresql/16/main/ |
| postgresql.conf | /etc/postgresql/16/main/postgresql.conf |
| pg_hba.conf | /etc/postgresql/16/main/pg_hba.conf |
| Data directory | /var/lib/postgresql/16/main/ |
| WAL files | /var/lib/postgresql/16/main/pg_wal/ |
| Log file | /var/log/postgresql/postgresql-16-main.log |
| Binaries | /usr/lib/postgresql/16/bin/ |

### Windows Installation Steps
Now let us cover the Windows installation. ... Step 1 ... Go to postgresql.org slash download slash windows and download the installer for PostgreSQL 16. The installer is provided by EDB and it is free. ... Step 2 ... Run the installer. It will ask you for an installation directory. The default is C Program Files PostgreSQL 16. Keep the default. ... It will ask you to set a password for the postgres superuser. Choose a strong password and remember it! On Windows, you MUST provide a password. This is different from Linux where the default is peer authentication. ... It will ask for a port. Keep the default 5432. ... It will ask for a locale. Keep the default. ... Click Next and let the installer complete.

- Step 1: Download from postgresql.org/download/windows/
- Step 2: Run the installer (provided by EDB — free)
- Step 3: Installation directory → C:\Program Files\PostgreSQL\16\
- Step 4: Set postgres superuser PASSWORD — remember this!
- Step 5: Port → 5432 (keep default)
- Step 6: Locale → Default (keep default)
- Step 7: Click Next → Install → Wait → Done!

### Windows File Paths Reference
On Windows, the file paths are different. Here is the reference table. The key difference is that on Windows, all config files are inside the data directory, not in a separate config directory like on Linux.

| What | Path |
| :--- | :--- |
| Install directory | C:\Program Files\PostgreSQL\16\ |
| Data directory | C:\Program Files\PostgreSQL\16\data\ |
| postgresql.conf | C:\Program Files\PostgreSQL\16\data\postgresql.conf |
| pg_hba.conf | C:\Program Files\PostgreSQL\16\data\pg_hba.conf |
| Log directory | C:\Program Files\PostgreSQL\16\data\log\ |
| Binaries (psql, etc) | C:\Program Files\PostgreSQL\16\bin\ |


---

## 3. Hands-On Commands & psql Output

### Linux Install — Step 1: Add PostgreSQL Repository
**Explanation:** Let us start with the Linux installation. We will use Debian or Ubuntu, which is the most common setup. ... Step 1 ... Add the official PostgreSQL repository. This ensures you get PostgreSQL 16 directly from the PostgreSQL team, not an older version from your OS packages. ... First, install the required packages for adding repositories. Then, add the PostgreSQL APT repository. Finally, update your package list.

```sql
-- Step 1: Install prerequisites for adding repositories
$ sudo apt install -y gnupg2 wget lsb-release
Reading package lists... Done
Setting up gnupg2 ...

-- Step 2: Add the official PostgreSQL signing key
$ sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

$ wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
OK

-- Step 3: Update package list
$ sudo apt update
Hit:1 http://apt.postgresql.org/pub/repos/apt jammy-pgdg InRelease
Reading package lists... Done
```

### Linux Install — Step 2: Install PostgreSQL 16
**Explanation:** Step 2 ... Install PostgreSQL 16. This one command installs the PostgreSQL 16 server, the client tools including psql, and all required libraries.

```sql
-- Install PostgreSQL 16 server and client
$ sudo apt install -y postgresql-16
Reading package lists... Done
The following NEW packages will be installed:
  postgresql-16 postgresql-client-16 postgresql-common
Setting up postgresql-16 (16.6-1.pgdg22.04+1) ...
Creating new PostgreSQL cluster 16/main ...
/usr/lib/postgresql/16/bin/initdb -D /var/lib/postgresql/16/main
Success. You can now start the database server using:
    pg_ctlcluster 16 main start
```

### Linux Install — Step 3: Verify Installation
**Explanation:** Step 3 ... Verify the installation. Let us check that PostgreSQL is running, check the version, and find the important file locations. ... First, check the service status. You should see active and running in green. ... Then check the version.

```sql
-- Check if PostgreSQL service is running
$ sudo systemctl status postgresql
● postgresql.service - PostgreSQL RDBMS
   Loaded: loaded (/lib/systemd/system/postgresql.service; enabled)
   Active: active (exited) since Mon 2026-11-03 10:00:00 IST

-- Check PostgreSQL version
$ psql --version
psql (PostgreSQL) 16.6 (Debian 16.6-1.pgdg22.04+1)

-- Check the server version from inside PostgreSQL
$ sudo -u postgres psql -c 'SELECT version();'
PostgreSQL 16.6 (Debian 16.6-1.pgdg22.04+1) on x86_64-pc-linux-gnu
```

### Linux Install — Step 4: Connect for the First Time!
**Explanation:** Step 4 ... Connect to PostgreSQL for the first time! ... On Linux, PostgreSQL creates a system user called postgres and a database role called postgres. To connect, we switch to the postgres system user and run psql. ... This is your first time inside PostgreSQL! The prompt practice=# means you are connected as a superuser. The hash sign means superuser. A greater-than sign would mean regular user. ... Let us run a few quick checks. SELECT version shows the full version info. The backslash l command lists all databases. You should see postgres, template0, and template1 ... the three default databases we discussed in the terminology class.

```sql
-- Connect as the postgres superuser
$ sudo -u postgres psql
psql (16.6 (Debian 16.6-1.pgdg22.04+1))
Type "help" for help.

-- Check version from inside psql
postgres=# SELECT version();
PostgreSQL 16.6 on x86_64-pc-linux-gnu, compiled by gcc 11.4.0

-- List all databases (3 defaults)
postgres=# \l
   Name    |  Owner   | Encoding | Locale Provider
-----------+----------+----------+-----------------
 postgres  | postgres | UTF8     | libc
 template0 | postgres | UTF8     | libc
 template1 | postgres | UTF8     | libc
```

### Linux Install — Step 5: Create Practice Database
**Explanation:** Step 5 ... Create our practice database. Throughout this course, we will use a database called practice for all our hands-on work. Let us create it now. ... CREATE DATABASE practice semicolon. Done! Now connect to it with backslash c practice. The prompt changes from postgres to practice, confirming you are now in the practice database. ... Let us also check the connection info with backslash conninfo. This shows you the database name, user, and port.

```sql
-- Create our practice database (used throughout the course)
postgres=# CREATE DATABASE practice;
CREATE DATABASE

-- Connect to the practice database
postgres=# \c practice
You are now connected to database "practice" as user "postgres".

-- Check connection info
practice=# \conninfo
You are connected to database "practice" as user "postgres" via socket in "/var/run/postgresql" at port "5432".

-- Exit psql
practice=# \q
```

### Linux — Important File Locations
**Explanation:** Before we move to Windows, let me show you the important file locations on Linux. These are the files you will work with throughout this course. ... The config directory is at etc postgresql 16 main. Inside it you find postgresql.conf, pg_hba.conf, and pg_ident.conf. ... The data directory is at var lib postgresql 16 main. This is where all your actual data lives. ... The log file is at var log postgresql. ... The binary files like psql, pg_dump, and pg_restore are in usr lib postgresql 16 bin. ... Remember these paths. You will use them in almost every class from now on.

```sql
-- Config files directory
$ ls /etc/postgresql/16/main/
pg_hba.conf  pg_ident.conf  postgresql.conf  conf.d/

-- Data directory (where all your data lives!)
$ sudo ls /var/lib/postgresql/16/main/
base/  global/  pg_wal/  postgresql.auto.conf  ...

-- Log files
$ ls /var/log/postgresql/
postgresql-16-main.log

-- PostgreSQL binaries
$ ls /usr/lib/postgresql/16/bin/ | head -5
pg_basebackup  pg_dump  pg_restore  psql  postgres
```

### Windows — Verify Installation
**Explanation:** After the Windows installation completes, let us verify it works. ... Open Command Prompt or PowerShell. Type psql minus U postgres. It will ask for the password you set during installation. Enter it and you are connected! ... If psql is not found, you need to add the PostgreSQL bin directory to your system PATH. The path is C Program Files PostgreSQL 16 bin. ... Once connected, run the same verification commands we used on Linux. SELECT version to check the version. Backslash l to list databases.

```sql
-- Connect from Command Prompt / PowerShell
C:\> psql -U postgres
Password for user postgres: ********
psql (16.6)
Type "help" for help.

postgres=# SELECT version();
PostgreSQL 16.6, compiled by Visual C++ build 1940, 64-bit

-- Create the practice database (same as Linux)
postgres=# CREATE DATABASE practice;
CREATE DATABASE

postgres=# \c practice
You are now connected to database "practice" as user "postgres".
```

### Start, Stop, Restart PostgreSQL
**Explanation:** One more important thing ... how to start, stop, and restart PostgreSQL. You will need this throughout the course. ... On Linux, use systemctl. sudo systemctl start postgresql to start. sudo systemctl stop postgresql to stop. sudo systemctl restart postgresql to restart. sudo systemctl reload postgresql to reload config without restarting. ... On Windows, use the Services panel. Press Windows plus R, type services.msc, find postgresql-x64-16, and you can start, stop, or restart from there. Or from the command line, use net stop and net start. ... The difference between restart and reload is important. Restart stops and starts the server ... all connections are dropped. Reload re-reads config files without dropping connections. Always prefer reload when possible. Only restart when the parameter requires it.

```sql
-- LINUX: Service management with systemctl
$ sudo systemctl start postgresql
$ sudo systemctl stop postgresql
$ sudo systemctl restart postgresql
$ sudo systemctl reload postgresql

-- Check if it's running
$ sudo systemctl is-active postgresql
active

-- WINDOWS: From Command Prompt (Run as Administrator)
C:\> net stop postgresql-x64-16
C:\> net start postgresql-x64-16

-- RELOAD vs RESTART: Reload keeps connections alive!
```

### Common Installation Errors & Fixes
**Explanation:** Let me show you the most common errors beginners face during installation and how to fix them. ... Error 1 ... psql command not found. This means psql is not in your system PATH. On Linux, install postgresql-client-16. On Windows, add C Program Files PostgreSQL 16 bin to your PATH. ... Error 2 ... connection refused. This means the PostgreSQL server is not running. Start it with systemctl start postgresql on Linux. ... Error 3 ... role does not exist. This happens when you try to connect as your OS username instead of postgres. Use sudo minus u postgres psql on Linux, or psql minus U postgres on Windows. ... Error 4 ... password authentication failed. You entered the wrong password. On Linux, you can reset it by editing pg_hba.conf to trust, reloading, changing the password, then changing back to the original authentication method.

```sql
-- ERROR 1: psql command not found
$ psql
bash: psql: command not found
-- FIX: sudo apt install postgresql-client-16

-- ERROR 2: Connection refused
$ psql -U postgres
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
-- FIX: sudo systemctl start postgresql

-- ERROR 3: Role does not exist
$ psql
psql: error: FATAL:  role "john" does not exist
-- FIX: sudo -u postgres psql (use postgres user)

-- ERROR 4: Password authentication failed
psql: error: FATAL:  password authentication failed for user "postgres"
-- FIX: Edit pg_hba.conf → set trust → reload → change password
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Installation Errors & Fixes
Let me show you the most common errors beginners face during installation and how to fix them. ... Error 1 ... psql command not found. This means psql is not in your system PATH. On Linux, install postgresql-client-16. On Windows, add C Program Files PostgreSQL 16 bin to your PATH. ... Error 2 ... connection refused. This means the PostgreSQL server is not running. Start it with systemctl start postgresql on Linux. ... Error 3 ... role does not exist. This happens when you try to connect as your OS username instead of postgres. Use sudo minus u postgres psql on Linux, or psql minus U postgres on Windows. ... Error 4 ... password authentication failed. You entered the wrong password. On Linux, you can reset it by editing pg_hba.conf to trust, reloading, changing the password, then changing back to the original authentication method.

```sql
-- ERROR 1: psql command not found
psql
bash: psql: command not found
-- FIX: sudo apt install postgresql-client-16

-- ERROR 2: Connection refused
psql -U postgres
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
-- FIX: sudo systemctl start postgresql

-- ERROR 3: Role does not exist
psql
psql: error: FATAL:  role "john" does not exist
-- FIX: sudo -u postgres psql (use postgres user)

-- ERROR 4: Password authentication failed
psql: error: FATAL:  password authentication failed for user "postgres"
-- FIX: Edit pg_hba.conf → set trust → reload → change password
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Step 5 ... Create our practice database. Throughout this course, we will use a database called practice for all our hands-on work. Let us create it now. ... CREATE DATABASE practice semicolon. Done! Now connect to it with backslash c practice. The prompt changes from postgres to practice, confirming you are now in the practice database. ... Let us also check the connection info with backslash conninfo. This shows you the database name, user, and port.

Practice time! ... Exercise 1 ... Install PostgreSQL 16 on your machine following the steps in this class. Verify with SELECT version. ... Exercise 2 ... Create the practice database. Connect to it. Run backslash conninfo to check your connection details. ... Exercise 3 ... Find the postgresql.conf file on your machine. Open it in a text editor and look at the first 20 lines. Do not change anything yet. ... Exercise 4 ... Stop PostgreSQL, then start it again. Verify it is running with systemctl status on Linux or services panel on Windows. ... Exercise 5 ... Try connecting as your OS username without specifying postgres. See the error. Then connect correctly using the postgres user.

1. Exercise 1: Install PG 16 on your machine. Verify with SELECT version();
2. Exercise 2: CREATE DATABASE practice; connect with \c practice; run \conninfo
3. Exercise 3: Find postgresql.conf on your system. Open and read first 20 lines.
4. Exercise 4: Stop PostgreSQL, start it again, verify with status command
5. Exercise 5: Try connecting without -U postgres — see the error, then fix it


---

## 7. Key Takeaways & Cheat Sheet

Let me give you a clean reference table of all the important paths. Save this ... you will need it throughout the course.


Let us summarize. ... On Linux ... add the PostgreSQL repository, install postgresql-16, it starts automatically. Connect with sudo minus u postgres psql. ... On Windows ... download from postgresql.org, run the installer, set a password, connect with psql minus U postgres. ... We created our practice database that we will use throughout the course. ... Key commands are systemctl start, stop, restart, reload on Linux. ... Config files are in etc postgresql 16 main on Linux, and in the data directory on Windows. ... In our next class, we learn psql ... the powerful command-line tool for working with PostgreSQL!

- **Linux: apt install postgresql-16 → auto-starts, connect with sudo -u postgres psql**
- **Windows: Download from postgresql.org → installer → set password → psql -U postgres**
- **Created 'practice' database for all course work**
- **Service: systemctl start/stop/restart/reload postgresql**
- **Config: /etc/postgresql/16/main/ (Linux), data\ dir (Windows)**
- **Common errors: command not found, connection refused, role missing**
- **RELOAD keeps connections alive; RESTART drops them**


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
