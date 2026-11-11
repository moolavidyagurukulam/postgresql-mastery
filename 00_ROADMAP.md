# PostgreSQL Complete Learning Roadmap - Class by Class
# From Zero to Pro

---

## How This Works
- One class at a time
- Ask doubts after each class
- We move forward only when you're clear
- Every class has simple language + examples + hands-on
- Scenario-based questions & hands-on in every relevant class
- **Basics FIRST** — learn to USE PostgreSQL, then learn HOW it works inside

---

## PHASE 1: FOUNDATION (What & Why)

```
Class 01 - What is a Database? Why do we need it?
Class 02 - What is PostgreSQL? History & why it was created
Class 03 - PostgreSQL vs Other Databases (MySQL, Oracle, SQL Server, MongoDB)
Class 04 - PostgreSQL Distributions: Open Source vs EDB vs Cloud-Managed
Class 05 - PostgreSQL Terminology (Cluster, Database, Schema, Table, Row, Column)
Class 06 - Install PostgreSQL 16 (Windows/Linux) + Verify Setup
Class 07 - psql Command-Line Tool (Connect, basic commands, shortcuts)
Class 08 - pgAdmin GUI Tool (Visual way to manage PostgreSQL)
```

## PHASE 2: DATABASE OBJECTS (Building Blocks)

```
Class 09  - Creating & Managing Databases
Class 10  - Schemas (Namespaces inside a database)
Class 11  - Tablespaces (Where data is physically stored)
Class 12  - Data Types Part 1: Numeric (INTEGER, BIGINT, NUMERIC, SERIAL)
Class 13  - Data Types Part 2: Text (CHAR, VARCHAR, TEXT)
Class 14  - Data Types Part 3: Date/Time (DATE, TIME, TIMESTAMP, INTERVAL)
Class 15  - Data Types Part 4: Boolean, UUID, BYTEA
Class 16  - Data Types Part 5: Arrays
Class 17  - Data Types Part 6: JSON & JSONB
Class 18  - Data Types Part 7: Special Types (INET, CIDR, MACADDR, Geometric)
Class 19  - Type Casting & Conversion
```

## PHASE 3: DATABASE DESIGN BASICS (Think Before You Build)

```
Class 20  - Normalization (1NF, 2NF, 3NF, BCNF) with examples
Class 21  - Denormalization: When & Why to break the rules
Class 22  - Naming Conventions (Tables, Columns, Indexes, Constraints)
Class 23  - Database Design Best Practices & Anti-Patterns
Class 24  - Schema Design for OLTP vs OLAP
```

## PHASE 4: DDL - DATA DEFINITION LANGUAGE (Creating Structures)

```
Class 25  - CREATE TABLE (Columns, Defaults, Constraints basics)
Class 26  - ALTER TABLE (Add/Drop/Rename columns, Change types)
Class 27  - DROP & TRUNCATE TABLE
Class 28  - Constraints Part 1: PRIMARY KEY & NOT NULL
Class 29  - Constraints Part 2: UNIQUE & CHECK
Class 30  - Constraints Part 3: FOREIGN KEY (Relationships between tables)
Class 31  - Constraints Part 4: EXCLUDE & DEFAULT
Class 32  - Sequences (Auto-incrementing numbers: SERIAL, IDENTITY)
Class 33  - Temporary Tables & Unlogged Tables
```

## PHASE 5: DML - DATA MANIPULATION (CRUD Operations + Essential SQL)

```
Class 34  - INSERT (Single row, Multiple rows, INSERT...SELECT, RETURNING)
Class 35  - SELECT Basics (Columns, Aliases, DISTINCT)
Class 36  - WHERE Clause (=, <>, >, <, BETWEEN, IN, LIKE, IS NULL)
Class 37  - AND, OR, NOT (Combining conditions)
Class 38  - ORDER BY & LIMIT/OFFSET (Sorting & Pagination)
Class 39  - UPDATE (Single row, Multiple rows, UPDATE...FROM, RETURNING)
Class 40  - DELETE (Single row, Conditional delete, DELETE...USING, RETURNING)
Class 41  - UPSERT: INSERT...ON CONFLICT (Insert or Update in one shot)
Class 42  - COPY Command (Bulk import/export CSV, TSV)
Class 43  - CASE WHEN (Conditional logic in queries)
Class 44  - COALESCE, NULLIF, GREATEST, LEAST
```

## PHASE 6: JOINS (Combining Tables)

```
Class 45  - What are Joins? Why do we need them?
Class 46  - INNER JOIN (Only matching rows)
Class 47  - LEFT JOIN / LEFT OUTER JOIN (All from left + matching from right)
Class 48  - RIGHT JOIN / RIGHT OUTER JOIN
Class 49  - FULL OUTER JOIN (All from both sides)
Class 50  - CROSS JOIN (Every combination)
Class 51  - SELF JOIN (Table joined with itself)
Class 52  - NATURAL JOIN & USING clause
Class 53  - Joining Multiple Tables (3+ tables)
Class 54  - Join Performance Tips
```

## PHASE 7: AGGREGATION & GROUPING

```
Class 55  - Aggregate Functions (COUNT, SUM, AVG, MIN, MAX)
Class 56  - GROUP BY (Grouping rows)
Class 57  - HAVING (Filtering groups)
Class 58  - GROUPING SETS, CUBE, ROLLUP (Advanced grouping)
Class 59  - FILTER Clause (Conditional aggregation)
```

## PHASE 8: SUBQUERIES & CTEs

```
Class 60  - Subqueries in WHERE clause
Class 61  - Subqueries in FROM clause (Derived tables)
Class 62  - Subqueries in SELECT clause (Scalar subqueries)
Class 63  - EXISTS & NOT EXISTS
Class 64  - ANY, ALL, SOME operators
Class 65  - CTE: Common Table Expressions (WITH clause)
Class 66  - Recursive CTEs (Hierarchical data - org charts, trees)
```

## PHASE 9: ARCHITECTURE (How PostgreSQL Works Inside)
> Now you've used SQL for 58 classes — you can appreciate HOW it all works under the hood!

```
Class 67  - PostgreSQL Architecture Overview (Big Picture)
Class 68  - Process Architecture (Postmaster, Backend, Background Workers)
Class 69  - Memory Architecture (Shared Buffers, WAL Buffers, Work Mem)
Class 70  - Storage Architecture (Data Files, WAL Files, TOAST, FSM, VM)
Class 71  - How a Query Flows (Parse -> Rewrite -> Plan -> Execute)
Class 72  - MVCC: How PostgreSQL Handles Multiple Users at Same Time
Class 73  - WAL: Write-Ahead Logging & Crash Recovery
Class 74  - Checkpoint & Background Writer
```

## PHASE 10: ADVANCED SQL

```
Class 75  - UNION, INTERSECT, EXCEPT (Combining result sets)
Class 76  - Window Functions Part 1: ROW_NUMBER, RANK, DENSE_RANK
Class 77  - Window Functions Part 2: LAG, LEAD, FIRST_VALUE, LAST_VALUE
Class 78  - Window Functions Part 3: SUM/AVG/COUNT OVER(), NTILE
Class 79  - Window Functions Part 4: Frame Clauses (ROWS, RANGE, GROUPS)
Class 80  - String Functions (CONCAT, SUBSTRING, TRIM, REPLACE, SPLIT_PART)
Class 81  - Date/Time Functions (EXTRACT, DATE_TRUNC, AGE, NOW, intervals)
Class 82  - Mathematical Functions (ROUND, CEIL, FLOOR, ABS, MOD, POWER)
Class 83  - Pattern Matching (LIKE, ILIKE, SIMILAR TO, POSIX Regex)
Class 84  - LATERAL Joins
Class 85  - GENERATE_SERIES (Creating sequences of numbers/dates)
```

## PHASE 11: VIEWS

```
Class 86  - Views (What, Why, How to create)
Class 87  - Updatable Views (INSERT/UPDATE/DELETE through views)
Class 88  - Materialized Views (Cached results for performance)
Class 89  - Refreshing Materialized Views (Manual & Concurrent)
```

## PHASE 12: INDEXES (Speed Up Queries)

```
Class 90  - What is an Index? Why do we need it? (Book index analogy)
Class 91  - B-Tree Index (Default, most common)
Class 92  - Hash Index
Class 93  - GIN Index (For arrays, JSONB, full-text search)
Class 94  - GiST Index (For geometric, range, full-text)
Class 95  - BRIN Index (For large sorted tables)
Class 96  - SP-GiST Index (For partitioned data)
Class 97  - Partial Indexes (Index only some rows)
Class 98  - Expression Indexes (Index on a function result)
Class 99  - Covering Indexes (INCLUDE clause)
Class 100 - Multi-Column Indexes
Class 101 - When to Create / When NOT to Create Indexes
Class 102 - Index Bloat & Maintenance
```

## PHASE 13: TRANSACTIONS & CONCURRENCY

```
Class 103 - What is a Transaction? (BEGIN, COMMIT, ROLLBACK)
Class 104 - ACID Properties (Atomicity, Consistency, Isolation, Durability)
Class 105 - SAVEPOINT (Partial rollback)
Class 106 - Isolation Levels (Read Uncommitted, Read Committed, Repeatable Read, Serializable)
Class 107 - Locks: Row-Level & Table-Level
Class 108 - Deadlocks: What they are & how to avoid
Class 109 - Advisory Locks (Application-level locking)
```

## PHASE 14: PL/pgSQL PROGRAMMING

```
Class 110 - Functions Part 1: SQL Functions (CREATE FUNCTION basics)
Class 111 - Functions Part 2: PL/pgSQL Language basics (DECLARE, BEGIN, END)
Class 112 - Functions Part 3: Variables, Constants, Parameters
Class 113 - Functions Part 4: IF/ELSE, CASE (Control flow)
Class 114 - Functions Part 5: Loops (FOR, WHILE, LOOP, FOREACH)
Class 115 - Functions Part 6: RETURN types (Single value, TABLE, SETOF)
Class 116 - Functions Part 7: RAISE (Printing messages, errors, debugging)
Class 117 - Stored Procedures (CREATE PROCEDURE, CALL, transaction control)
Class 118 - DO Blocks (Anonymous code blocks)
Class 119 - Cursors (Processing rows one by one)
Class 120 - Dynamic SQL (EXECUTE, format())
Class 121 - Error Handling (EXCEPTION, SQLSTATE, error codes)
Class 122 - User-Defined Types (CREATE TYPE: composite, enum, domain)
Class 123 - Operator Overloading (CREATE OPERATOR)
```

## PHASE 15: TRIGGERS & RULES

```
Class 124 - Triggers Part 1: What & Why (BEFORE, AFTER, INSTEAD OF)
Class 125 - Triggers Part 2: ROW-level vs STATEMENT-level
Class 126 - Triggers Part 3: NEW & OLD variables
Class 127 - Triggers Part 4: Practical examples (Audit log, auto-update timestamps)
Class 128 - Event Triggers (DDL triggers: on CREATE, ALTER, DROP)
Class 129 - Rules System (Alternative to triggers)
```

## PHASE 16: ADMINISTRATION BASICS

```
Class 130 - PostgreSQL Configuration Files (postgresql.conf, pg_hba.conf, pg_ident.conf)
Class 131 - postgresql.conf Deep Dive (Key parameters explained)
Class 132 - pg_hba.conf Deep Dive (Client authentication)
Class 133 - Users & Roles (CREATE ROLE, CREATE USER)
Class 134 - Privileges & GRANT/REVOKE (Table, Schema, Database level)
Class 135 - Row-Level Security (RLS) - Control which rows a user can see
Class 136 - Schema-Based Multi-Tenancy
Class 137 - Connection Management Best Practices
```

## PHASE 17: DATABASE SIZING & CAPACITY PLANNING

```
Class 138 - Database Sizing: How to estimate storage needs
Class 139 - Table Size, Index Size, Database Size (pg_size_pretty, pg_relation_size)
Class 140 - Estimating Growth & Capacity Planning
Class 141 - Disk Space Management & Monitoring
Class 142 - TOAST: How PostgreSQL handles large values
```

## PHASE 18: BACKUP, RECOVERY & DISASTER RECOVERY

```
Class 143 - RTO & RPO: What they are & why they matter
Class 144 - Backup Overview (Types: Logical vs Physical vs Snapshot)
Class 145 - pg_dump & pg_dumpall (Logical backup)
Class 146 - pg_restore (Restoring from backup)
Class 147 - pg_basebackup (Physical/binary backup)
Class 148 - Point-in-Time Recovery (PITR) using WAL archiving
Class 149 - Continuous Archiving Setup
Class 150 - pgBackRest (Enterprise backup tool)
Class 151 - Barman (Backup and Recovery Manager by EDB)
Class 152 - WAL-G (Cloud-native WAL archiving)
Class 153 - Backup Strategy & Scheduling (cron, pgAgent)
Class 154 - Disaster Recovery Planning (Scenarios & Runbooks)
Class 155 - DR Drills: Testing your recovery process
```

## PHASE 19: VACUUM & MAINTENANCE

```
Class 156 - Dead Tuples & Bloat (Why VACUUM exists)
Class 157 - VACUUM (Manual cleanup)
Class 158 - VACUUM FULL vs VACUUM (Difference & when to use)
Class 159 - AUTOVACUUM (Automatic cleanup - configuration & tuning)
Class 160 - ANALYZE (Updating query planner statistics)
Class 161 - REINDEX (Rebuilding indexes)
Class 162 - pg_repack (Online table reorganization without locks)
Class 163 - Routine Maintenance Checklist & Schedule
```

## PHASE 20: QUERY OPTIMIZATION & PERFORMANCE

```
Class 164 - EXPLAIN & EXPLAIN ANALYZE (Reading query plans)
Class 165 - Understanding Scan Types (Seq Scan, Index Scan, Bitmap Scan)
Class 166 - Understanding Join Algorithms (Nested Loop, Hash Join, Merge Join)
Class 167 - Query Planner: How PostgreSQL Decides the Plan
Class 168 - Common Query Optimization Techniques
Class 169 - pg_stat_statements (Finding slow queries)
Class 170 - Index-Only Scans & Visibility Map
Class 171 - Parallel Query Execution
Class 172 - JIT Compilation
Class 173 - Query Optimization Scenarios (Real-world examples)
```

## PHASE 21: PERFORMANCE TUNING

```
Class 174 - Memory Tuning (shared_buffers, work_mem, maintenance_work_mem)
Class 175 - WAL Tuning (wal_buffers, checkpoint settings)
Class 176 - Connection Tuning (max_connections, connection pooling)
Class 177 - Disk I/O Tuning (effective_io_concurrency, random_page_cost)
Class 178 - OS-Level Tuning (Linux: vm.dirty_ratio, huge_pages, swappiness)
Class 179 - Benchmarking with pgbench
Class 180 - Performance Tuning Checklist (Quick reference)
Class 181 - Performance Tuning Scenarios (Real-world problems & solutions)
```

## PHASE 22: TABLE PARTITIONING

```
Class 182 - What is Partitioning? Why use it?
Class 183 - Range Partitioning (By date ranges, number ranges)
Class 184 - List Partitioning (By categories)
Class 185 - Hash Partitioning (Even distribution)
Class 186 - Sub-Partitioning (Multi-level)
Class 187 - Partition Pruning & Performance
Class 188 - Managing Partitions (Add, Drop, Attach, Detach)
Class 189 - Partitioning Scenarios (When to partition, when not to)
```

## PHASE 23: MONITORING & TROUBLESHOOTING

```
Class 190 - System Catalog Tables (pg_class, pg_tables, pg_indexes, etc.)
Class 191 - Statistics Views (pg_stat_user_tables, pg_stat_user_indexes)
Class 192 - pg_stat_activity (Who is doing what right now?)
Class 193 - pg_locks (Finding lock conflicts)
Class 194 - Logging Configuration (log_statement, log_duration, etc.)
Class 195 - pgBadger (Log analysis tool)
Class 196 - Monitoring Tools (Grafana + Prometheus, Zabbix, Nagios)
Class 197 - Common Troubleshooting Scenarios & Solutions
Class 198 - Health Check Scripts & Automation
```

## PHASE 24: REPLICATION & HIGH AVAILABILITY

```
Class 199 - Replication Overview (Why, Types, Use cases)
Class 200 - Streaming Replication Setup (Primary-Standby)
Class 201 - Synchronous vs Asynchronous Replication
Class 202 - Replication Slots (Physical & Logical)
Class 203 - Cascading Replication
Class 204 - Logical Replication Setup
Class 205 - Logical Replication: Publications & Subscriptions
Class 206 - Logical Decoding, Output Plugins & Change Data Capture (CDC)
Class 207 - Patroni: Automatic Failover Setup
Class 208 - repmgr: Replication Manager
Class 209 - PgBouncer: Connection Pooling
Class 210 - Pgpool-II: Load Balancing & Connection Pooling
Class 211 - HAProxy with PostgreSQL
Class 212 - HA Architecture Design (Scenarios & Decision Making)
```

## PHASE 25: ADVANCED FEATURES

```
Class 213 - Full-Text Search (tsvector, tsquery, ranking)
Class 214 - Full-Text Search: Indexes & Configuration
Class 215 - JSON & JSONB Deep Dive (Operators, Functions, Indexing)
Class 216 - JSONB Practical Use Cases
Class 217 - Foreign Data Wrappers (Query other databases from PostgreSQL)
Class 218 - postgres_fdw (Connect PostgreSQL to PostgreSQL)
Class 219 - Inheritance (Table inheritance)
Class 220 - LISTEN / NOTIFY (Real-time notifications)
Class 221 - Large Objects (Storing binary files in PostgreSQL)
```

## PHASE 26: EXTENSIONS

```
Class 222 - What are Extensions? How to install & manage
Class 223 - pg_cron (Scheduled jobs inside PostgreSQL)
Class 224 - pgcrypto (Encryption & hashing)
Class 225 - uuid-ossp & gen_random_uuid
Class 226 - PostGIS Introduction (Geographic/spatial data)
Class 227 - pg_trgm (Fuzzy string matching)
Class 228 - hstore (Key-value pairs)
Class 229 - TimescaleDB Introduction (Time-series data)
Class 230 - Citus (Distributed PostgreSQL)
Class 231 - pgAudit (Audit logging)
```

## PHASE 27: SECURITY

```
Class 232 - Authentication Methods (md5, scram-sha-256, cert, ldap, gss)
Class 233 - SSL/TLS Connections (Encrypting client-server traffic)
Class 234 - Data Encryption (At rest, Column-level with pgcrypto)
Class 235 - SQL Injection: What it is & how to prevent it
Class 236 - Security Hardening Checklist
Class 237 - Auditing & Compliance
```

## PHASE 28: UPGRADE & MIGRATION

```
Class 238 - Minor Version Upgrades (How & when)
Class 239 - Major Version Upgrades with pg_upgrade
Class 240 - Major Version Upgrades with Logical Replication (Zero downtime)
Class 241 - Migrating from Oracle to PostgreSQL (Ora2Pg)
Class 242 - Migrating from MySQL to PostgreSQL (pgLoader)
Class 243 - Migrating from SQL Server to PostgreSQL
Class 244 - Migration Planning & Testing Checklist
```

## PHASE 29: EDB (EnterpriseDB) & POSTGRESQL DISTRIBUTIONS

```
Class 245 - Open Source PostgreSQL vs EDB vs Cloud-Managed: Deep Comparison
Class 246 - EDB Postgres Advanced Server (EPAS) - Oracle compatibility features
Class 247 - EDB Tools: Postgres Enterprise Manager (PEM)
Class 248 - EDB Tools: Failover Manager (EFM)
Class 249 - EDB Tools: Backup and Recovery Tool (BART)
Class 250 - EDB Tools: Migration Toolkit
Class 251 - EDB Tools: pgd (Distributed PostgreSQL by EDB)
Class 252 - Crunchy Data PostgreSQL & Tools (pgMonitor, Crunchy Bridge)
Class 253 - Percona Distribution for PostgreSQL
Class 254 - When to choose: Open Source vs EDB vs Crunchy vs Percona
```

## PHASE 30: INTEGRATION WITH OTHER TECHNOLOGIES

```
Class 255 - Python + PostgreSQL (psycopg2, SQLAlchemy)
Class 256 - Java + PostgreSQL (JDBC, Spring Boot)
Class 257 - Node.js + PostgreSQL (pg, Sequelize, Prisma)
Class 258 - .NET + PostgreSQL (Npgsql, Entity Framework)
Class 259 - Go + PostgreSQL (pgx, GORM)
Class 260 - Kafka + PostgreSQL (CDC with Debezium)
Class 261 - Liquibase + PostgreSQL (Database schema migrations)
Class 262 - Flyway + PostgreSQL (Database migrations)
Class 263 - Ansible + PostgreSQL (Automation)
Class 264 - Docker + PostgreSQL (Containerized databases)
Class 265 - Kubernetes + PostgreSQL (Cloud-native deployment)
Class 266 - Terraform + PostgreSQL (Infrastructure as Code)
```

## PHASE 31: CLOUD PostgreSQL

```
Class 267 - AWS RDS PostgreSQL
Class 268 - AWS Aurora PostgreSQL
Class 269 - Azure Database for PostgreSQL (Single Server, Flexible Server)
Class 270 - Google Cloud SQL for PostgreSQL & AlloyDB
Class 271 - Self-Managed vs Cloud-Managed: Pros, Cons & Cost comparison
Class 272 - Cloud PostgreSQL Administration (Scaling, Monitoring, Backups)
Class 273 - Multi-Cloud & Hybrid PostgreSQL Strategies
```

## PHASE 32: REAL-WORLD SCENARIOS & HANDS-ON PROJECTS

```
Class 274 - Scenario: Slow query on production - How to diagnose & fix
Class 275 - Scenario: Database is running out of disk space
Class 276 - Scenario: Replication lag is increasing
Class 277 - Scenario: Connection limit reached
Class 278 - Scenario: Table bloat causing performance issues
Class 279 - Scenario: Failover - Primary server goes down
Class 280 - Scenario: Data corruption recovery
Class 281 - Scenario: Long-running queries blocking others
Class 282 - Project 1: Design & Build a Library Management System
Class 283 - Project 2: Design & Build an E-Commerce Database
Class 284 - Project 3: Build a Multi-Tenant SaaS Database
Class 285 - Project 4: Set up Full HA Cluster (Primary + Standby + Patroni + PgBouncer)
```

## PHASE 33: INTERVIEW & CAREER

```
Class 286 - PostgreSQL DBA Daily Tasks & Responsibilities
Class 287 - Interview Preparation: Top 50 PostgreSQL Questions
Class 288 - Interview Preparation: Scenario-Based Questions
Class 289 - Certifications & Learning Resources
```

---

## TOTAL: 289 Classes across 33 Phases

> **Changes from original roadmap (v2, 2026-10-25):**
> - Architecture moved from Phase 2 → Phase 9 (learn SQL first, then understand internals)
> - Database Design Basics added as Phase 3 (think before you build tables)
> - COPY, CASE WHEN, COALESCE moved into Phase 5 DML (essential everyday SQL)
> - Connection Management moved into Phase 16 Administration
> - Schema Design OLTP/OLAP moved into Phase 3 Design
> - pg_stat_statements duplicate removed (was in Phase 19 AND Phase 25)
> - Logical Decoding + Output Plugins merged into one class in Phase 24
> - Total reduced from 291 → 289 (2 duplicates removed)

---

> **PostgreSQL Version: 16 ONLY** (PG 17 reserved for other project)
