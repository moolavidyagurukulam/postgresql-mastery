# EDB Tools — BART, Migration Toolkit & pgd (Distributed PostgreSQL)
**Series:** PostgreSQL Mastery | **Phase:** 29 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we cover three more EDB enterprise tools — BART for backup and recovery, Migration Toolkit for moving data from other databases, and pgd for distributed PostgreSQL across multiple regions.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should understand PostgreSQL backup methods — pg_basebackup, pg_dump, WAL archiving, and PITR — from Phase 18. You should also know the migration concepts from Phase 28.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Backup Knowledge** | pg_basebackup, pg_dump, WAL archiving, PITR — Phase 18 |
| **Migration Tools** | Ora2Pg, pgLoader — Phase 28 |
| **Replication** | Streaming and logical replication — Phases 23-24 |

### EDB BART — Backup and Recovery Tool
BART is EDB's enterprise backup solution. It manages full, incremental, and differential backups for multiple PostgreSQL and EPAS servers from a central backup host. BART uses pg_basebackup under the hood but adds management features — retention policies, backup catalogs, backup verification, and point-in-time recovery with a simple command. Think of it as a wrapper that makes PostgreSQL backup management production-ready.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Centralized backup management for PG/EPAS clusters |
| **Backup Types** | Full, incremental (block-level), differential |
| **Features** | Retention policies, catalog, verification, PITR, compression |
| **Architecture** | BART server (central) manages backups for multiple PG servers |
| **Under the Hood** | Uses pg_basebackup + WAL archiving with management layer |
| **Alternative** | Community: Barman (pgbarman.org) or pgBackRest |

### BART vs Barman vs pgBackRest
The community equivalents of BART are Barman by 2ndQuadrant and pgBackRest. All three manage backups centrally, support incremental backups, retention policies, and PITR. pgBackRest is the most popular community choice — it supports parallel backup and restore, compression, encryption, and cloud storage. BART is simpler but integrated into the EDB ecosystem.

| Term | Meaning / Explanation |
| :--- | :--- |
| **License** | BART (EDB): EDB subscription | Barman: Free (GPLv3) | pgBackRest: Free (MIT) |
| **Full Backup** | BART (EDB): Yes | Barman: Yes | pgBackRest: Yes |
| **Incremental** | BART (EDB): Yes (block-level) | Barman: Yes | pgBackRest: Yes (block + file) |
| **Parallel Backup** | BART (EDB): No | Barman: Yes | pgBackRest: Yes |
| **Compression** | BART (EDB): gzip | Barman: gzip, lz4, zstd | pgBackRest: lz4, zstd, gz, bz2 |
| **Encryption** | BART (EDB): No | Barman: No | pgBackRest: Yes (AES-256) |
| **Cloud Storage** | BART (EDB): No (local/NFS) | Barman: S3 (via WAL-G) | pgBackRest: S3, Azure, GCS native |
| **Retention Policy** | BART (EDB): Yes | Barman: Yes | pgBackRest: Yes |
| **PITR** | BART (EDB): Yes | Barman: Yes | pgBackRest: Yes |
| **Community** | BART (EDB): EDB customers | Barman: Moderate | pgBackRest: Very widely adopted |

### EDB Migration Toolkit
EDB Migration Toolkit is a Java-based command-line tool that migrates schema and data from Oracle, SQL Server, MySQL, and Sybase directly into PostgreSQL or EPAS. It is similar to Ora2Pg and pgLoader but supports all four source databases with one tool. It handles DDL conversion, data type mapping, and bulk data transfer. For Oracle migrations into EPAS, it preserves Oracle-specific objects like packages and synonyms.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Java-based CLI migration tool |
| **Sources** | Oracle, SQL Server, MySQL, Sybase → PostgreSQL/EPAS |
| **Migrates** | Schema (DDL), data, stored procedures, triggers, sequences |
| **EPAS Advantage** | Preserves Oracle packages, synonyms when migrating to EPAS |
| **Alternative** | Ora2Pg (Oracle), pgLoader (MySQL/MSSQL) |
| **Best For** | Multi-source migrations, especially Oracle → EPAS |

### Migration Toolkit vs Community Tools
Migration Toolkit is convenient because one tool handles Oracle, MySQL, SQL Server, and Sybase. The community equivalents are Ora2Pg for Oracle and pgLoader for MySQL and SQL Server. For Oracle to EPAS specifically, Migration Toolkit has an advantage — it preserves Oracle packages and synonyms natively because EPAS supports them. For Oracle to community PostgreSQL, Ora2Pg is equally capable.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Oracle source** | EDB Migration Toolkit: Yes | Ora2Pg + pgLoader: Ora2Pg (excellent) |
| **MySQL source** | EDB Migration Toolkit: Yes | Ora2Pg + pgLoader: pgLoader (excellent) |
| **SQL Server source** | EDB Migration Toolkit: Yes | Ora2Pg + pgLoader: pgLoader (good) |
| **Sybase source** | EDB Migration Toolkit: Yes | Ora2Pg + pgLoader: No direct tool |
| **Oracle → EPAS** | EDB Migration Toolkit: Best (packages preserved) | Ora2Pg + pgLoader: N/A (Ora2Pg converts) |
| **Assessment report** | EDB Migration Toolkit: Yes | Ora2Pg + pgLoader: Ora2Pg SHOW_REPORT |
| **Data transfer** | EDB Migration Toolkit: JDBC-based | Ora2Pg + pgLoader: Native protocols |
| **Speed (large data)** | EDB Migration Toolkit: Moderate | Ora2Pg + pgLoader: pgLoader faster |
| **License** | EDB Migration Toolkit: EDB subscription | Ora2Pg + pgLoader: Free |

### pgd — EDB Postgres Distributed
pgd — formerly known as BDR, Bi-Directional Replication — is EDB's distributed PostgreSQL solution. It enables multi-master replication across multiple regions. Every node can accept writes, and changes are replicated to all other nodes asynchronously. pgd handles conflict resolution automatically using last-writer-wins or custom rules. It provides always-on availability — if one data center goes down, others continue serving reads and writes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Formerly** | BDR (Bi-Directional Replication) |
| **Type** | Multi-master distributed PostgreSQL (active-active) |
| **Replication** | Logical replication, all nodes writable |
| **Conflict Resolution** | Last-writer-wins (default) or custom conflict handlers |
| **Use Case** | Multi-region active-active, always-on availability |
| **Alternative** | Community: no direct equivalent (Citus for sharding, not multi-master) |

### pgd Multi-Region Architecture
pgd deploys PostgreSQL nodes in multiple regions. Each node holds a full copy of the data. Applications connect to the nearest node for low latency. When a write happens on one node, it replicates to all other nodes using logical replication. If the same row is modified on two nodes simultaneously, the conflict resolver picks the winner. This architecture provides geographic redundancy and local read and write performance.

```
[App (US-East)]
[PG Node 1
(US-East)]
[App (EU-West)]
[PG Node 2
(EU-West)]
[App (AP-South)]
[PG Node 3
(AP-South)]
```

### Comparison
If this enterprise tools overview is helpful, please support the course. Your donation keeps this content free for everyone. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All commands from this video |
| Every donation helps! | Practice exercises included |

### Beginner Traps
Watch out for these mistakes. First, BART is being phased out in favor of pgBackRest — even EDB now recommends pgBackRest for new deployments. Second, Migration Toolkit is JDBC-based and slower than pgLoader for large data transfers — use it for Oracle-to-EPAS, but prefer pgLoader for MySQL and SQL Server. Third, pgd is complex and expensive — do not use it when simple streaming replication or read replicas would suffice.

- BART → pgBackRest trend -- EDB now recommends pgBackRest for new deployments. BART is maintenance-mode. Choose pgBackRest.
- Migration Toolkit speed -- JDBC-based = slower than native protocols. Use for Oracle→EPAS. Use pgLoader for MySQL/MSSQL.
- pgd is complex -- Multi-master adds conflict resolution complexity. Use only when you truly need active-active multi-region.
- pgd ≠ sharding -- pgd replicates full data to every node. For sharding (split data), look at Citus instead.

### Practice Exercises
Here are your practice exercises. First, install pgBackRest and configure full plus incremental backups with a 7-day retention policy — this is the recommended backup tool even for EDB shops. Second, if you have EDB trial, run Migration Toolkit against an Oracle XE database and compare the output with Ora2Pg. Third, research pgd architecture documentation and draw a diagram of how you would deploy it across three AWS regions.

- Exercise 1 -- Install pgBackRest. Configure full + incremental backups with 7-day retention. Test restore.
- Exercise 2 -- If you have EDB trial: run Migration Toolkit against Oracle XE. Compare output with Ora2Pg.
- Exercise 3 -- Research pgd docs. Design a 3-region deployment (US, EU, AP). Document conflict resolution strategy.
- Exercise 4 -- Compare: pgBackRest vs Barman for your backup needs. Choose one and document why.


---

## 3. Hands-On Commands & psql Output

*(Refer to the attached `materials.sql` script for full runnable queries and setups for this topic.)*


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these mistakes. First, BART is being phased out in favor of pgBackRest — even EDB now recommends pgBackRest for new deployments. Second, Migration Toolkit is JDBC-based and slower than pgLoader for large data transfers — use it for Oracle-to-EPAS, but prefer pgLoader for MySQL and SQL Server. Third, pgd is complex and expensive — do not use it when simple streaming replication or read replicas would suffice.

- BART → pgBackRest trend -- EDB now recommends pgBackRest for new deployments. BART is maintenance-mode. Choose pgBackRest.
- Migration Toolkit speed -- JDBC-based = slower than native protocols. Use for Oracle→EPAS. Use pgLoader for MySQL/MSSQL.
- pgd is complex -- Multi-master adds conflict resolution complexity. Use only when you truly need active-active multi-region.
- pgd ≠ sharding -- pgd replicates full data to every node. For sharding (split data), look at Citus instead.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. BART is EDB's backup tool — but pgBackRest is now the recommended choice even for EDB shops. Migration Toolkit migrates from Oracle, MySQL, SQL Server, and Sybase into PostgreSQL or EPAS — best for Oracle-to-EPAS migrations. pgd provides multi-master distributed PostgreSQL for active-active multi-region deployments — use it only when you truly need every region to accept writes. Community alternatives exist for all three: pgBackRest for backup, Ora2Pg and pgLoader for migration, and there is no community equivalent to pgd's multi-master.

- **BART: centralized backup management (pgBackRest now recommended instead)**
- **Migration Toolkit: Java CLI for Oracle/MySQL/MSSQL/Sybase → PG/EPAS**
- **Migration Toolkit best for: Oracle → EPAS (packages preserved)**
- **pgd: multi-master active-active distributed PostgreSQL**
- **pgd use case: multi-region, every node writable, conflict resolution**
- **Community alternatives: pgBackRest (backup), Ora2Pg + pgLoader (migration)**
- **No community equivalent to pgd multi-master (Citus = sharding, not multi-master)**


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
