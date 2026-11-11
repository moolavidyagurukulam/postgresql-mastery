# PostgreSQL Glossary - Technical Terms
# (Updated after every class)

---

## How to Use This File
- All technical words from every class are collected here
- Sorted alphabetically
- Each term has: Meaning + Simple Analogy + Which class it was introduced
- Use this as a quick reference anytime you forget a term

---

## A

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| ACID | Atomicity, Consistency, Isolation, Durability — 4 guarantees that keep data safe | A bank transfer: either both debit AND credit happen, or neither | 02 |
| ALLOW_CONNECTIONS | Database property controlling whether anyone can connect to it (default: true) | A "Visitors Allowed" sign on the apartment door | 17 |
| ALTER DATABASE | SQL command to change database properties (owner, name, connection limit, settings) | Changing the rules for a specific apartment | 17 |
| AlloyDB | Google's PostgreSQL-compatible database with analytics engine | Google's turbocharged version of PostgreSQL | 04 |
| Analyzer (Query) | Query flow step that resolves table/column names and checks they exist | A spell-checker verifying all names are real before sending a letter | 09 |
| Attribute | Another name for a Column in a table | Column header in Excel | 01 |
| Aurora | AWS custom PostgreSQL-compatible engine (faster, auto-scaling storage) | Amazon's turbocharged version of PostgreSQL | 04 |
| Autovacuum | Background process that automatically cleans up dead rows and updates statistics | A self-driving garbage truck that runs on schedule | 09 |
| Autovacuum Launcher | Process that monitors tables and launches Autovacuum Workers when needed | The supervisor who checks which streets need garbage pickup | 10 |
| autovacuum_work_mem | Separate memory setting for autovacuum workers (default: uses maintenance_work_mem) | A budget specifically for the cleaning crew, separate from general maintenance | 11 |
| Autovacuum Worker | Short-lived process that runs VACUUM/ANALYZE on a specific table | A garbage truck sent to clean one specific street | 10 |
| archive_command | Shell command PostgreSQL runs to copy completed WAL files to an archive | Instructions for the courier: "copy this file to the safe" | 15 |
| archive_mode | Setting that enables/disables WAL file archiving (required for PITR) | The ON/OFF switch for the archiving courier service | 15 |

## B

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| Backend Process | A process created for each connected client — handles all its SQL work | A personal waiter assigned to one customer | 09 |
| Background Writer | Process that writes dirty pages from shared buffers to disk periodically | A janitor who keeps cleaning rooms regularly | 09, 16 |
| bgwriter_delay | How often (ms) the Background Writer wakes up to clean dirty pages (default: 200ms) | How often the janitor checks for dirty rooms | 16 |
| bgwriter_lru_maxpages | Max pages the BG Writer can write per round (default: 100) | Maximum rooms the janitor cleans per shift | 16 |
| buffers_backend | Counter in pg_stat_bgwriter — pages written by backends (high = bad, backends waiting) | Waiters forced to wash dishes because the dishwasher can't keep up | 16 |
| BART | EDB's Backup and Recovery Tool (like Oracle RMAN) | A professional backup manager for your database | 04 |

## C

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| Cache Hit Ratio | Percentage of data reads served from RAM (Shared Buffers) vs disk — goal is >99% | How often you find a book on your desk vs walking to the basement | 11 |
| Catalog Cache | Per-backend memory cache of system catalog data (table/column/type info) | A cheat sheet each worker keeps so they don't check the filing cabinet every time | 13 |
| Cost (Query Plan) | The Planner's estimated expense of running a plan — lower is cheaper/faster | A price estimate for a construction project | 13 |
| Crash Recovery | PostgreSQL's automatic process of replaying WAL records after an unclean shutdown | Re-reading your diary to remember what you did before you passed out | 15 |
| checkpoint_completion_target | Controls how much of the checkpoint interval is used for spreading writes (default: 0.9 = 90%) | Doing housework gradually all day vs rushing it in the last hour | 16 |
| checkpoint_timeout | Maximum time between automatic checkpoints (default: 5 min) | How often the complete inventory check must happen | 16 |
| Checkpointer | Process that writes ALL dirty pages to disk at intervals, creating a recovery point | A manager doing a complete inventory check periodically | 09, 16 |
| Clock Sweep | Algorithm PostgreSQL uses to decide which pages to evict from Shared Buffers | A clock hand sweeping around, removing pages nobody uses | 11 |
| CLOG | Commit Log — tracks which transactions committed or aborted | A ledger marking which bank transfers succeeded or failed | 09 |
| Cloud-Managed | Database hosted and managed by a cloud provider (AWS, Azure, GCP) | Renting a fully-furnished apartment instead of building a house | 04 |
| Cluster (PG) | One running PostgreSQL server instance (NOT multiple servers!) | An apartment building with many apartments (databases) inside | 05 |
| CONNECTION LIMIT (DB) | Database-level property that caps how many simultaneous connections it allows (-1 = unlimited) | A maximum occupancy sign on a room | 17 |
| Connection Pooler | Software (like pgBouncer) that reuses a small pool of real DB connections for many clients | A receptionist sharing a few meeting rooms among hundreds of visitors | 10 |
| CREATE DATABASE | SQL command that creates a new database by copying a template (default: template1) | Building a new apartment by copying the model apartment | 17 |
| createdb | Command-line tool that creates a database (wrapper around CREATE DATABASE) | A shortcut button to build a new apartment from the terminal | 17 |
| Connection String | A URI with all connection details in one string (user, host, port, db) | A full address on one line | 07 |
| Column | A vertical field in a table (Name, Age, City) | One column in Excel | 01 |
| Committer | A developer who has permission to merge code into PostgreSQL | A senior editor who can approve articles | 02 |
| Community | The global group of developers who build PostgreSQL (no single company) | A village where everyone contributes to build a road | 02 |
| Community PostgreSQL | The original, free PostgreSQL from postgresql.org | The original recipe, no modifications | 04 |
| Core Team | The ~7 people who manage PostgreSQL releases | The village elders who decide when the road is ready | 02 |
| CRUD | Create, Read, Update, Delete — the 4 basic data operations | The 4 things you do with any data | 01 |
| Crunchy Data | Company focused on PostgreSQL for Kubernetes (PGO operator) | The Kubernetes experts of the PostgreSQL world | 04 |
| CSV | Comma-Separated Values — a simple file format for data | A basic text version of Excel | 01 |

## D

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| dblink | Extension for querying across databases using explicit connection strings (older method) | A phone call to another apartment to ask for their data | 17 |
| contrib modules | Extra extensions bundled with PostgreSQL (pg_stat_statements, etc.) | Bonus accessories that come in the box | 06 |
| Data | Raw facts and figures (names, numbers, dates) | Words written in a notebook | 01 |
| Data Checksums | Feature that detects silent disk corruption by verifying page integrity | A spell-check that catches typos the printer made | 12 |
| Data Directory | The folder on disk where PostgreSQL stores all its files | The building's actual physical location | 05 |
| Dead Row (Tuple) | A row marked for deletion or replaced by UPDATE — not yet cleaned by VACUUM | A crossed-out line in a notebook, still taking up space | 12 |
| Dirty Page | A page in Shared Buffers that was modified but not yet written to disk | A draft with unsaved edits | 11 |
| Docker | A tool that runs applications in isolated containers (fast PG setup) | A shipping container that has everything the app needs inside | 06 |
| Database (PG) | An isolated container of data within a cluster (specific PG meaning) | One apartment in the building | 05 |
| Database | An organized collection of data stored electronically | A well-organized library | 01 |
| Dashboard | pgAdmin's monitoring panel showing server activity (connections, transactions) | A car's speedometer/fuel gauge panel | 08 |
| DBMS | Database Management System — software that manages a database | The librarian who manages the library | 01 |
| DELETE | SQL command to remove data from a table | Erasing a line from a notebook | 01 |
| Distribution (PG) | A packaged version of PostgreSQL with extra tools/support | Ubuntu vs Red Hat — same Linux core, different packaging | 04 |
| DROP DATABASE | SQL command that permanently deletes a database and all its data | Demolishing an apartment — permanent and irreversible | 17 |
| dropdb | Command-line tool that drops a database (wrapper around DROP DATABASE) | A shortcut button to demolish an apartment from the terminal | 17 |

## E

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| effective_cache_size | Planner hint — tells PG how much total OS + shared cache is available for planning | Telling a chef how big the kitchen is so they plan recipes accordingly | 09 |
| EDB | EnterpriseDB — biggest commercial PostgreSQL company, offers EPAS with Oracle compatibility | The enterprise car dealership for PostgreSQL | 04 |
| Executor | Final query flow step — actually runs the plan and returns results | The worker who follows the blueprint and builds the product | 09 |
| EFM | EDB Failover Manager — auto-promotes standby when primary goes down | An automatic backup driver that takes over if the main driver faints | 04 |
| EPAS | EDB Postgres Advanced Server — PostgreSQL + Oracle PL/SQL compatibility | PostgreSQL wearing an Oracle-compatible suit | 04 |
| EXPLAIN | Shows how PostgreSQL will execute a query (the query plan) | Asking "how will you find this book?" before actually searching | 08 |
| EXPLAIN ANALYZE | Runs the query AND shows actual execution times and row counts | Searching for the book AND timing how long each step took | 08 |
| Extensibility | Ability to add your own data types, functions, operators to PostgreSQL | A phone where you can install any app you want | 02 |
| Extension | A plugin/add-on that adds extra features to PostgreSQL (e.g., PostGIS) | An app you install on your phone | 02 |

## F

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| Field | Another name for a Column | Same as Column | 01 |
| FORCE (DROP DATABASE) | PG 13+ option that auto-terminates all connections before dropping a database | Evacuating the apartment before demolishing it | 17 |
| FOR UPDATE | Row-level lock clause in SELECT that exclusively locks selected rows for writing | Putting a "reserved" sign on a chair so nobody else takes it | 14 |
| fork() | OS system call to create a copy of the current process — how Postmaster creates backends | Cloning yourself so the clone can handle a customer | 10 |
| Foreign Key | A column that links one table to another table | "Refer to customer #1 in the other sheet" | 01 |
| fsync | OS operation that forces data from kernel cache to physical disk — true durability | Pressing "save" so the file actually reaches the hard drive, not just memory | 16 |
| FSM | Free Space Map — tracks available space in each page for new data | A parking lot map showing which spots are empty | 09 |
| Full Page Write (FPW) | Writing an entire 8 KB page into WAL the first time it's modified after a checkpoint — prevents torn pages | Photocopying the whole document before editing, in case the edit goes wrong | 15 |
| Function (PG) | Reusable code stored inside the database | A formula in Excel that you can call anytime | 05 |

## G

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| GIN Index | Generalized Inverted Index — for arrays, JSONB, full-text search | A book index that lists every word and where it appears | 03 |
| GRANT (Database) | SQL command to give a user specific database-level privileges (CONNECT, CREATE, TEMPORARY) | Giving someone a key to specific rooms in the building | 17 |
| GPL | GNU General Public License — MySQL's license (free but with conditions) | Free food, but you must share your recipe if you modify it | 03 |

## H

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| Hash Join | Join method that builds a hash table from the smaller table and probes it | Building a phone book from one list, then looking up names from the other | 13 |
| Heap | The main data file of a table — stores rows in no particular order | A pile of papers on a desk (no specific sort order) | 12 |
| HOT Update | Heap-Only Tuple update — avoids index updates when non-indexed columns change on same page | Editing a note in place instead of moving it to a new folder | 14 |
| Index-Only Scan | A query that reads only the index, skipping the table — enabled by VM | Finding an answer in the book's index without opening any chapter | 12 |
| initdb | Command to initialize a new PostgreSQL data directory (cluster) | Laying the foundation before building a house | 06 |
| Item Pointer | A 4-byte pointer in a page header that points to a tuple's location on that page | A table of contents entry pointing to where a section starts | 12 |

## I

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| ICU Locale | International Components for Unicode — PG 15+ locale provider giving consistent sorting across OSes | A universal dictionary that sorts the same way everywhere | 17 |
| InnoDB | MySQL's storage engine that supports ACID transactions | The reliable engine inside a MySQL car | 03 |
| IS_TEMPLATE | Database property marking whether it can be used as a template for CREATE DATABASE | A "master copy" stamp on a document | 17 |
| Isolation Level | Controls what data a transaction can see from other concurrent transactions | How thick the walls are between neighboring offices | 14 |
| In-Memory Database | A database that stores everything in RAM (very fast) | Writing on a whiteboard (fast but erased when cleaned) | 01 |
| Index | A structure that speeds up searching in a table | Index page at the back of a book | 01 |
| INSERT | SQL command to add new data into a table | Writing a new line in a notebook | 01 |

## J - K

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| JSONB | Binary JSON — PostgreSQL's fast, indexable JSON storage | A super-organized filing system for flexible data | 02 |
| JIT | Just-In-Time compilation — compiles queries for faster execution | Translating a recipe into your language right before cooking | 02 |

## L

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| LC_COLLATE | Locale setting controlling how text is sorted (alphabetical order rules) | The dictionary that decides A comes before B | 17 |
| LC_CTYPE | Locale setting controlling character classification (what is a letter, digit, uppercase) | The rulebook that says 'A' is uppercase and '3' is a digit | 17 |
| libpq | PostgreSQL client library — used by applications to connect to PG | The phone app that lets you call the database | 06 |
| log_checkpoints | Setting that logs detailed checkpoint info to the server log (essential for monitoring) | Turning on the activity report for inventory checks | 16 |
| LSN | Log Sequence Number — unique position in the WAL stream (e.g., 0/1A3B5C8) | A page number in the transaction diary | 12 |
| LZ4 | Fast compression algorithm available for TOAST since PG 14 (faster than pglz) | A speed-focused packing method for large items | 12 |
| License (PostgreSQL) | The legal terms — similar to MIT/BSD, fully free to use, modify, sell | A "take it, it's free" sign with no strings attached | 02 |
| listen_addresses | PostgreSQL setting that controls which IP addresses the server accepts connections from | The building's front doors — which entrances are open | 06 |
| localhost | Your own machine (IP: 127.0.0.1) — PG only accepts local connections by default | Your own house — visitors from outside are blocked by default | 06 |

## M

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| maintenance_work_mem | Memory for maintenance tasks (VACUUM, CREATE INDEX, etc.) — usually set higher than work_mem | Extra workspace given to the cleaning crew for big jobs | 09 |
| max_connections | Setting that limits how many clients can connect simultaneously (default: 100) | Maximum number of chairs in a restaurant | 10 |
| Major Version | A big release with new features (e.g., PG 16 to PG 17) | A new model year of a car | 02 |
| Meta-Command | psql-specific command starting with backslash, not SQL | A psql shortcut, not a database command | 07 |
| Merge Join | Join method that sorts both tables and walks through them simultaneously | Two sorted stacks of papers being merged side by side | 13 |
| Multi-process Model | PostgreSQL's architecture: one OS process per connection (not threads) | One waiter per table, not one waiter juggling all tables | 09 |
| Multi-AZ | Multi-Availability Zone — cloud HA across data centers in same region | Having a backup office in another part of the city | 04 |
| MongoDB | A NoSQL document database that stores JSON-like documents | A folder of sticky notes instead of a spreadsheet | 03 |
| MQL | MongoDB Query Language — MongoDB's way of querying data (not SQL) | A different language to talk to a different kind of database | 03 |
| MVCC | Multi-Version Concurrency Control — readers never block writers | Multiple people reading different drafts of same document at same time | 03, 14 |
| MySQL | Popular open-source RDBMS, now owned by Oracle | PostgreSQL's main open-source competitor | 03 |

## N

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| NoSQL | Databases that do not use fixed tables — document, key-value, graph based | A folder where every page can look different | 01 |

## O

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| OID | Object Identifier — internal numeric ID PostgreSQL assigns to every database object | An employee ID number the system uses internally | 12 |
| Open Source | Software whose code is free to view, use, modify, and distribute | A recipe that anyone can read, cook, and change | 02 |
| Oracle | Most popular commercial RDBMS — very powerful but very expensive | A luxury car with all features but costs a fortune | 03 |

## P

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| Page (Block) | The basic unit of storage in PostgreSQL — always 8 KB | One fixed-size box that holds rows of data | 09 |
| pageinspect | Extension that lets you examine the internal structure of database pages | A magnifying glass to look inside each 8 KB box | 12 |
| pg_freespacemap | Extension that shows the Free Space Map data for tables | A tool to see which pages have empty space | 12 |
| Parallel Query | Executor feature (PG 9.6+) that uses multiple CPU cores for one query | Multiple workers building one wall together | 13 |
| Parse Tree | Internal tree structure the Parser builds from valid SQL text | A sentence diagram from grammar class | 13 |
| Parser | First query flow step — checks SQL syntax is correct and builds a parse tree | A grammar checker for your SQL sentence | 09 |
| pg_stats | System view containing column-level statistics used by the Planner | A census report the Planner reads to estimate row counts | 13 |
| Prepared Statement | Pre-parsed SQL template that skips Parse/Analyze/Rewrite on repeated use | A pre-filled form where you only change the blanks | 13 |
| Planner/Optimizer | Query flow step that finds the cheapest/fastest way to execute a query | A GPS finding the fastest route to a destination | 09 |
| Materialized View | A view that stores results on disk (cached, needs manual refresh) | A printed copy of a report — fast to read but needs reprinting when data changes | 05 |
| Namespace | Another word for Schema — a container that avoids name conflicts | Departments in a company — HR and Sales can both have a "reports" folder | 05 |
| Nested Loop | Join method that scans the inner table once for each row of the outer table | Checking every locker for each student name on a list | 13 |
| Patroni | Open-source tool for automatic PostgreSQL failover and HA | An auto-pilot that takes over when the main pilot is down | 04 |
| PEM | Postgres Enterprise Manager — EDB's GUI monitoring dashboard | A control room showing all your database servers on one screen | 04 |
| Percona | Company offering free curated PostgreSQL tool bundle | A free starter kit with everything pre-tested together | 04 |
| pgBackRest | Enterprise-grade backup tool for PostgreSQL | A professional-grade backup system | 04 |
| pgBouncer | Lightweight connection pooler for PostgreSQL | A receptionist managing a queue of visitors | 04 |
| PGO | Crunchy Postgres Operator for Kubernetes | A robot that manages your database on Kubernetes | 04 |
| PGTune | Free online tool that suggests PostgreSQL memory/performance settings based on your server specs | A car mechanic who tunes your engine based on the car model | 11 |
| PITR | Point-in-Time Recovery — restore database to any exact second in the past | Rewinding a video to the exact moment you want | 02 |
| Postgres | Short/common name for PostgreSQL | Like calling "Bangalore" as "BLR" | 02 |
| PostgreSQL | Free, open-source, advanced relational database (pronounced post-gress-Q-L) | The most powerful free librarian in the world | 02 |
| pg_basebackup | Tool that takes a physical backup of the entire PostgreSQL cluster for replication or PITR | A complete photocopy of the entire building | 15 |
| pg_buffercache | Extension that lets you see what's currently stored in Shared Buffers | An X-ray machine for the database cache | 11 |
| pg_database | System catalog table listing all databases in the cluster with their properties | The building registry listing every apartment and its details | 17 |
| pg_control | Critical file storing the last checkpoint location and recovery info | The "resume from here" bookmark for crash recovery | 15 |
| pg_cancel_backend() | Function to politely cancel a running query (sends SIGINT) | Tapping someone's shoulder and asking them to stop | 10 |
| pg_reload_conf() | Function to reload configuration without restarting the server | Refreshing settings without turning off the machine | 11 |
| pg_ctl | Command-line tool to start, stop, restart PostgreSQL server | The power switch for the database server | 06 |
| pg_relation_filepath() | Function that returns the file path for a table or index on disk | Asking "which file on disk holds this table?" | 12 |
| pg_stat_activity | System view showing all current processes, their state, and running queries | A live dashboard of who is doing what in the database | 10 |
| pg_stat_database | System view showing per-database statistics (connections, commits, cache hits, etc.) | A report card for each apartment showing usage and performance | 17 |
| pg_stat_bgwriter | System view showing page write statistics for Checkpointer, BG Writer, and backends | A scorecard showing who did the dishes — checkpointer, janitor, or the cook | 16 |
| pg_stat_checkpointer | System view (PG 17+) with dedicated checkpoint statistics, separated from pg_stat_bgwriter | A dedicated report card just for the inventory manager | 16 |
| pg_stat_wal | System view (PG 14+) showing WAL generation statistics | A meter tracking how much WAL the database is producing | 15 |
| pg_terminate_backend() | Function to forcefully kill a backend connection (sends SIGTERM) | Escorting someone out of the building | 10 |
| pg_dump | Tool for logical backup of a database (exports as SQL) | Photocopying all documents in one department | 06 |
| pg_hba.conf | Configuration file controlling WHO can connect and HOW (authentication) | The visitor entry register at the building gate | 06 |
| pg_restore | Tool to restore a database from a pg_dump backup | Putting all photocopied documents back in the filing cabinet | 06 |
| pgAdmin | GUI tool to manage PostgreSQL visually (web-based interface) | A control panel with buttons instead of typing commands | 06 |
| postgres_fdw | Foreign Data Wrapper extension for querying tables in other databases as if local (modern approach) | A tunnel between apartments letting you see the neighbor's furniture | 17 |
| Postmaster | The main PostgreSQL process that listens for connections and spawns backends | The security guard at the building gate | 05 |
| postgresql.conf | Main configuration file for PostgreSQL server settings | The building's rule book (max residents, visiting hours, etc.) | 06 |
| POSTQUEL | The old query language POSTGRES used before SQL (now replaced) | An old language nobody speaks anymore | 02 |
| Primary Key | A unique identifier for each row in a table — no duplicates allowed | Roll number in a class — every student has a unique one | 01 |
| psql | PostgreSQL's command-line tool for running SQL and admin commands | A text-based chat window to talk to the database | 05 |
| public (schema) | The default schema in every PostgreSQL database | The living room — where everything goes unless you specify another room | 05 |

## Q

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| Query | A request/command you send to the database to get or change data | Asking the librarian "Find all science books" | 01 |
| Query Tool | pgAdmin's SQL editor where you write and run queries with a GUI | A notepad with a "Run" button that talks to the database | 08 |

## R

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| RAC | Real Application Clusters — Oracle's clustering (multiple servers share one DB) | Multiple cashiers sharing one cash register | 03 |
| RDS | Amazon Relational Database Service — AWS managed database service | Renting a database that Amazon maintains for you | 04 |
| RDBMS | Relational Database Management System — stores data in linked tables | Multiple Excel sheets connected to each other | 01 |
| Read Replica | A copy of the database used only for reading (offloads the primary) | A photocopy of a document for people who only need to read | 04 |
| Record | Another name for a Row in a table | One line in Excel | 01 |
| Relation | Formal/academic name for a Table | Same as Table | 05 |
| Relational Database | A database where data is stored in tables that can be linked | Multiple Excel sheets with connecting IDs | 01 |
| Read Committed | Default isolation level — each statement sees data committed before it started | A fresh newspaper delivered for every question you ask | 14 |
| REDO | Recovery step that replays WAL records to reconstruct changes lost in a crash | Re-doing your work by reading your diary notes | 15 |
| REDO Point | The WAL position from which crash recovery must start replaying | The bookmark in your diary where you start re-reading | 15 |
| Repeatable Read | Isolation level where the entire transaction sees a consistent snapshot | A newspaper from the morning — same edition all day, ignoring later updates | 14 |
| Rewriter | Query flow step that applies rules and expands views into base queries | A translator who expands abbreviations into full sentences | 09 |
| Role | An identity in PostgreSQL that can own objects and have privileges | An ID badge | 05 |
| Row | One horizontal entry (record) in a table | One line in an Excel sheet | 01 |

## S

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| Query Tree | Enriched parse tree produced by the Analyzer — has resolved types, OIDs, permissions | A sentence diagram with every word defined and verified | 13 |
| random_page_cost | Planner's estimated cost of a random disk page read (default: 4.0) | The difficulty of finding a random book in the basement | 13 |
| SELECT | SQL command to read/retrieve data from a table | Asking "Show me all customers" | 01 |
| seq_page_cost | Planner's estimated cost of a sequential disk page read (default: 1.0) | The ease of reading the next book on the shelf | 13 |
| Serializable | Strictest isolation level — detects conflicts, may abort transactions to ensure serial order | A traffic cop forcing cars through an intersection one at a time | 14 |
| Sequential Scan | Reading an entire table page by page from start to end | Reading a book from first page to last | 13 |
| Snapshot | A frozen view of which transactions are committed/active at a point in time | A photograph of the database's state at one moment | 14 |
| Streaming Replication | Continuously sending WAL from primary to standby server over the network | A live news broadcast from HQ to all branch offices | 15 |
| synchronous_commit | Setting controlling whether COMMIT waits for WAL to reach disk (on=safe, off=faster) | Choosing between waiting for the receipt vs trusting the cashier | 15 |
| Schema | A namespace (folder) inside a database that groups related objects | A room inside an apartment | 05 |
| Search Path | The order of schemas PostgreSQL looks in when you don't specify a schema | The order you check rooms when looking for something | 05 |
| Sequence | An auto-incrementing number generator in PostgreSQL | A token machine at a bank — gives 1, 2, 3... | 05 |
| SERIAL | A column type that auto-generates incrementing integers (shortcut for sequence) | A token machine — gives 1, 2, 3 automatically | 06 |
| Service | A background process managed by the OS (PG runs as a service) | An appliance that runs in the background (like a fridge) | 06 |
| SLA | Service Level Agreement — a contract guaranteeing uptime and support response time | A promise from your landlord to fix things within 24 hours | 04 |
| Superuser | A role with ALL privileges — can do anything in the cluster (postgres is default) | The building owner who has keys to every room | 06 |
| systemctl | Linux command to manage services (start, stop, restart PostgreSQL) | The power panel for all building appliances | 06 |
| SET LOCAL | SQL command to change a setting for the current transaction only — resets after COMMIT | A temporary rule that expires when the meeting ends | 11 |
| Shared Buffers | PostgreSQL's main cache in RAM — stores frequently accessed data pages | A desk where you keep the files you use most often | 09 |
| Shared Memory | Memory allocated once at startup and shared by all PostgreSQL processes | A common whiteboard everyone in the office can read and write | 11 |
| Sharding | Splitting data across multiple servers for scale | Dividing a library's books across multiple buildings | 03 |
| Shutdown Mode (Smart) | Waits for all clients to disconnect before stopping | Waiting for all customers to leave the store before closing | 10 |
| Shutdown Mode (Fast) | Disconnects clients, rolls back active transactions, does clean shutdown | Announcing "store closing now" and ushering everyone out | 10 |
| Shutdown Mode (Immediate) | Kills everything instantly, no clean checkpoint — emergency only | Pulling the fire alarm and running out | 10 |
| SQL | Structured Query Language — the language to talk to relational databases | English is for people, SQL is for databases | 01 |
| SQL Compliance | How closely a database follows the official SQL standard | How closely a car follows traffic rules | 03 |
| SQL Server | Microsoft's commercial RDBMS, primarily for Windows/.NET | Microsoft's answer to Oracle | 03 |
| SSPL | Server Side Public License — MongoDB's controversial license (not truly open-source) | "Free to use, but big restrictions if you offer it as a service" | 03 |

## T

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| Table | Data stored in rows and columns inside a database | One sheet in Excel | 01 |
| Tab Completion | Press Tab to auto-complete keywords and object names in psql | Phone auto-complete for text messages | 07 |
| Tablespace | A physical disk location where PostgreSQL stores data files | The floor type (SSD or HDD) that furniture sits on | 05 |
| temp_buffers | Per-session memory for temporary table data | A small personal notepad for scratch work | 09 |
| template0 | Clean template database — never modify, used for pristine restores | A sealed original copy of a document | 05 |
| template1 | Template database used when creating new databases — can be customized | A master copy you can customize before making copies | 05 |
| TOAST | The Oversized-Attribute Storage Technique — handles data larger than one page | A compression system for values too big to fit in one box | 09 |
| Trigger | Code that automatically runs when data in a table changes | A motion-sensor alarm that fires automatically | 05 |
| Tuple | Another name for a Row (used in formal/academic contexts) | Same as Row/Record | 01 |
| Table Bloat | Wasted space from accumulated dead rows that VACUUM hasn't reclaimed | A filing cabinet full of outdated papers nobody threw away | 14 |
| Transaction ID (XID) | Unique incrementing number assigned to each write transaction | A receipt number at a shop — 101, 102, 103... | 14 |
| Transaction ID Wraparound | Critical condition when XIDs run out (2 billion) — PG shuts down if VACUUM can't freeze old rows | The receipt machine running out of numbers | 14 |
| Torn Page | A data page that is half-old, half-new due to a crash during write — Full Page Writes prevent this | A document where the printer jammed halfway through | 15 |
| Tuple Header | ~23 bytes of metadata stored with every row (xmin, xmax, ctid, flags) | A label on each package showing who sent it and when | 12 |

## U

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| UPDATE | SQL command to change existing data in a table | Correcting a phone number in your notebook | 01 |
| UTF8 | Unicode encoding that supports every language's characters — the default and recommended encoding | A universal alphabet that can write every language | 17 |

## V - Z

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| User (PG) | A Role with LOGIN permission — can connect to the database | An ID badge with door access (not just a name badge) | 05 |
| Vendor Lock-in | Being stuck with one company's product because switching is too hard/expensive | Being trapped in a phone contract you cannot leave | 03 |
| View | A saved SQL query that acts like a virtual table (no data stored) | A saved report template — runs fresh every time | 05 |
| VM (Visibility Map) | Tracks which pages have only visible (non-dead) rows — helps VACUUM skip clean pages | A checklist marking which rooms are already clean | 09 |
| WAL | Write-Ahead Logging — writes changes to a log BEFORE applying to data (crash safety) | Writing a plan in your diary before actually doing the work | 02 |
| WAL Buffers | Shared memory area that temporarily holds WAL records before writing to disk | A notepad where you jot things down before writing in the official diary | 09 |
| wal_compression | Setting (PG 15+) to compress full page images in WAL (off, pglz, lz4, zstd) — reduces WAL size 30-50% | Shrink-wrapping diary entries to save paper | 15 |
| wal_level | Setting controlling how much detail is logged in WAL (minimal, replica, logical) | How detailed your diary entries are | 15 |
| WAL Record | A single entry in the WAL describing one change (insert, update, delete, etc.) | One line in your diary | 15 |
| WAL Segment | One WAL file — 16 MB by default, stored in pg_wal/ directory | One chapter of the transaction diary | 12 |
| WAL Sender | Process that sends WAL data to a replica server for replication | A courier delivering transaction logs to the branch office | 10 |
| WAL Writer | Background process that flushes WAL buffers to WAL files on disk | The person who copies notes from the notepad into the official diary | 09 |
| work_mem | Per-operation memory for sorts, hash joins, etc. (each query can use multiple) | A temporary workspace given to each worker for their current task | 09 |
| xmin | Transaction ID stored in each row — identifies who created this row version | A "created by" stamp on a document | 14 |
| xmax | Transaction ID stored in each row — identifies who deleted/updated this row version (0 = alive) | A "deleted by" stamp (blank if still alive) | 14 |
| Window Function | SQL function that performs calculation across a set of rows related to current row | Comparing your marks with classmates without merging into one score | 03 |

## Symbols

| Term | Meaning | Simple Analogy | Class |
|------|---------|----------------|-------|
| .psqlrc | Startup config file for psql — runs every time psql starts | Auto-settings like your phone's startup apps | 07 |

---

> This glossary grows with every class.
> Last updated: Class 17
