# Go & Kafka CDC with PostgreSQL — pgx, GORM, Debezium Change Data Capture
**Series:** PostgreSQL Mastery | **Phase:** 30 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we cover two critical integration topics — connecting Go applications to PostgreSQL using pgx and GORM, and setting up real-time Change Data Capture with Kafka and Debezium to stream database changes to other systems.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you need PostgreSQL 16 running with a test database. For the Go section, install Go 1.21 or higher. For the Kafka section, you need Docker installed to run Kafka and Debezium. You should also understand logical replication from Phase 24.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL 16** | Running with wal_level=logical for CDC section |
| **Go 1.21+** | For pgx and GORM driver examples |
| **Docker** | For running Kafka, Zookeeper, and Debezium |
| **Logical Replication** | Understanding from Phase 24 helps for CDC |

### Go — PostgreSQL Options
Go has three main PostgreSQL options. pgx is the recommended driver — pure Go, fast, PostgreSQL-specific features. lib/pq is the older driver — it works but is in maintenance mode. GORM is the ORM — use it for CRUD-heavy applications. For high-performance applications or PostgreSQL-specific features, use pgx directly. For typical web APIs, GORM with pgx as the underlying driver is the best combination.

| Term | Meaning / Explanation |
| :--- | :--- |
| **pgx** | Type: Pure Go driver | Best For: Recommended. Fast, PG-specific features. |
| **pgxpool** | Type: Connection pool | Best For: Built into pgx. Always use for production. |
| **lib/pq** | Type: Older driver | Best For: Maintenance mode. Migrate to pgx. |
| **GORM** | Type: Full ORM | Best For: CRUD apps, auto-migration, associations. |
| **sqlx** | Type: Extensions to sql | Best For: Named params, struct scanning, raw SQL. |
| **sqlc** | Type: Code generator | Best For: Write SQL, generate Go code. Type-safe. |

### Comparison
If this integration guide is helping your team choose the right tools, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All code samples from this video |
| Every donation helps! | Practice exercises included |

### Change Data Capture (CDC)
Now let us talk about Change Data Capture — CDC. CDC captures every INSERT, UPDATE, and DELETE that happens in PostgreSQL and streams those changes to other systems in real time. Why do you need this? Because microservices need to sync data between databases. Analytics pipelines need real-time data. Search indexes like Elasticsearch need to stay in sync. Caches need invalidation. CDC solves all of these without polling.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Captures every INSERT/UPDATE/DELETE and streams changes in real time |
| **How** | Uses PostgreSQL logical replication (WAL decoding) — no polling |
| **Tool** | Debezium — open-source CDC connector for Kafka |
| **Use Case 1** | Sync data between microservice databases |
| **Use Case 2** | Feed real-time analytics and data warehouses |
| **Use Case 3** | Keep Elasticsearch/Redis in sync with PostgreSQL |

### CDC: PostgreSQL → Debezium → Kafka
Here is the CDC architecture. PostgreSQL writes changes to its WAL — Write-Ahead Log. Debezium reads the WAL using logical replication — the same mechanism PostgreSQL uses for logical replication between servers. Debezium converts each change into a JSON event and publishes it to a Kafka topic. Downstream consumers — your analytics pipeline, search indexer, cache invalidator — read from Kafka and react to changes. The database does not know or care about the consumers.

```
[PostgreSQL
(WAL)]
[Debezium
Connector]
[Apache
Kafka]
[Elasticsearch]
[Analytics DB]
[Cache (Redis)]
```

### CDC vs Polling vs Triggers
Why use CDC instead of polling or triggers? Polling queries the database every few seconds for changes — it is slow, wastes resources, and misses changes between polls. Triggers fire SQL on each change — but they add latency to writes and couple your database to downstream systems. CDC reads the WAL asynchronously — zero impact on write performance, no missed changes, and the database does not need to know about consumers.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Latency** | CDC (Debezium): Sub-second | Polling: Seconds to minutes | Triggers: Synchronous |
| **Write Impact** | CDC (Debezium): Zero (reads WAL) | Polling: Zero | Triggers: Adds latency to every write |
| **Missed Changes** | CDC (Debezium): Never | Polling: Between polls | Triggers: Never |
| **Coupling** | CDC (Debezium): Decoupled | Polling: Decoupled | Triggers: Tightly coupled |
| **Complexity** | CDC (Debezium): Kafka stack | Polling: Simple query | Triggers: PL/pgSQL code |
| **Best For** | CDC (Debezium): Microservices, analytics | Polling: Simple sync | Triggers: Same-DB triggers |

### Beginner Traps
Watch out for these traps. First, in Go, always use pgxpool not pgx.Connect for production — a single connection cannot handle concurrent requests. Second, lib/pq is in maintenance mode — use pgx for new Go projects. Third, for CDC, do not forget to monitor replication slots — an inactive slot prevents WAL cleanup and fills your disk. Fourth, CDC requires wal_level=logical which generates more WAL — plan for extra disk space.

- Go: Use pgxpool -- pgx.Connect = one connection. pgxpool.New = pool. Always use pool for web applications.
- Go: lib/pq is deprecated -- lib/pq is maintenance-mode. pgx is actively developed, faster, and more features.
- CDC: Monitor replication slots -- Inactive slots prevent WAL cleanup → disk fills. SELECT * FROM pg_replication_slots; regularly.
- CDC: More WAL with logical -- wal_level=logical generates more WAL than replica. Plan 2-3x disk space for pg_wal.
- CDC: Test connector restarts -- Debezium must resume from last LSN after restart. Test this — lost events = data inconsistency.

### Practice Exercises
Here are your practice exercises. First, write a Go program using pgx that connects to PostgreSQL, creates a table, inserts rows, and queries them. Second, rewrite it using GORM. Third, set up the Docker Compose stack for Kafka and Debezium. Register a PostgreSQL connector and insert a row — watch the CDC event appear in Kafka. Fourth, write a simple Kafka consumer in any language that reads CDC events and logs them. Fifth, monitor the replication slot — check pg_replication_slots while Debezium is running.

- Exercise 1 -- Go + pgxpool: connect, create table, insert rows, query. Use parameterized queries ($1, $2).
- Exercise 2 -- Rewrite Exercise 1 with GORM. Compare code verbosity with pgx.
- Exercise 3 -- Docker Compose: Kafka + Debezium. Register PG connector. INSERT a row, find event in Kafka.
- Exercise 4 -- Write a Kafka consumer that reads CDC events and prints them. Any language.
- Exercise 5 -- Monitor: SELECT * FROM pg_replication_slots; Check slot_name, active, confirmed_flush_lsn.


---

## 3. Hands-On Commands & psql Output

### Go — pgx Connection and Query
**Explanation:** pgx is the recommended PostgreSQL driver for Go. It is pure Go — no CGo dependency — and supports PostgreSQL-specific features like LISTEN/NOTIFY, COPY, and binary protocol. It includes a built-in connection pool called pgxpool. pgx is faster than the standard database/sql driver because it uses PostgreSQL's binary format for data transfer instead of text.

```sql
// go get github.com/jackc/pgx/v5
// go get github.com/jackc/pgx/v5/pgxpool

package main

import (
  "context"
  "fmt"
  "github.com/jackc/pgx/v5/pgxpool"
)

func main() {
  ctx := context.Background()
  connStr := "postgres://app_user:secret" +
    "@localhost:5432/myapp"

  // Connection pool (recommended)
  pool, err := pgxpool.New(ctx, connStr)
  if err != nil { panic(err) }
  defer pool.Close()

  // INSERT (parameterized: $1, $2)
  var id int
  err = pool.QueryRow(ctx,
    "INSERT INTO users (name, email) "+
    "VALUES ($1, $2) RETURNING id",
    "Alice", "alice@example.com",
  ).Scan(&id)

  // SELECT
  rows, _ := pool.Query(ctx,
    "SELECT id, name FROM users")
  for rows.Next() {
    var uid int; var name string
    rows.Scan(&uid, &name)
    fmt.Printf("%d: %s\n", uid, name)
  }
}
```

### Go — GORM ORM
**Explanation:** GORM is Go's most popular ORM. It supports auto-migration, associations, hooks, and transactions. Install GORM with the PostgreSQL driver. Define your model as a Go struct with tags for column mapping. GORM generates SQL from method calls — Create, Find, Where, Update, Delete. For simple CRUD applications, GORM reduces boilerplate significantly.

```sql
// go get gorm.io/gorm
// go get gorm.io/driver/postgres

import (
  "gorm.io/gorm"
  "gorm.io/driver/postgres"
)

type User struct {
  ID    uint   `gorm:"primaryKey"`
  Name  string `gorm:"not null"`
  Email string `gorm:"uniqueIndex"`
}

dsn := "host=localhost port=5432 " +
  "user=app_user password=secret " +
  "dbname=myapp sslmode=disable"
db, err := gorm.Open(
  postgres.Open(dsn), &gorm.Config{})

// Auto-migrate (create table)
db.AutoMigrate(&User{})

// Create
db.Create(&User{
  Name: "Bob", Email: "bob@ex.com"})

// Read
var users []User
db.Where("name = ?", "Bob").Find(&users)

// Update
db.Model(&User{}).Where("id = ?", 1).
  Update("name", "Bob Smith")

// Delete
db.Delete(&User{}, 1)
```

### PostgreSQL — Enable Logical Replication for CDC
**Explanation:** To enable CDC, PostgreSQL must use logical WAL level. Set wal_level to logical in postgresql.conf and restart. Then create a publication for the tables you want to capture. Debezium will create a replication slot automatically when it connects. Make sure your PostgreSQL user has the REPLICATION privilege.

```sql
-- postgresql.conf
postgres=# ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM
postgres=# SELECT pg_reload_conf();
 pg_reload_conf 
----------------
 t
-- Restart required for wal_level change

postgres=# SHOW wal_level;
 wal_level 
-----------
 logical

-- Grant replication to CDC user
postgres=# ALTER USER app_user REPLICATION;
ALTER ROLE
```

### docker-compose.yml — Kafka + Debezium
**Explanation:** The easiest way to run Kafka and Debezium is with Docker Compose. This configuration starts Zookeeper for Kafka coordination, Kafka as the message broker, and Kafka Connect with the Debezium PostgreSQL connector. Once running, you register a connector configuration that tells Debezium which PostgreSQL server and tables to capture.

```sql
version: '3'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.6.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.6.0
    depends_on: [zookeeper]
    ports: ["9092:9092"]
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS:
        PLAINTEXT://kafka:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

  connect:
    image: debezium/connect:2.6
    depends_on: [kafka]
    ports: ["8083:8083"]
    environment:
      BOOTSTRAP_SERVERS: kafka:9092
      GROUP_ID: 1
      CONFIG_STORAGE_TOPIC: connect_configs
      OFFSET_STORAGE_TOPIC: connect_offsets
      STATUS_STORAGE_TOPIC: connect_statuses
```

### Register Debezium PostgreSQL Connector
**Explanation:** After starting the Docker services, register the PostgreSQL connector with a POST request to Kafka Connect. This JSON configuration tells Debezium the PostgreSQL host, port, database, credentials, and which tables to capture. Debezium creates a replication slot, starts reading the WAL, and publishes change events to Kafka topics named after your tables.

```sql
$ curl -X POST http://localhost:8083/connectors \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "pg-connector",
    "config": {
      "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
      "database.hostname": "host.docker.internal",
      "database.port": "5432",
      "database.user": "app_user",
      "database.password": "secret",
      "database.dbname": "myapp",
      "topic.prefix": "myapp",
      "plugin.name": "pgoutput"
    }}'
```

### Debezium CDC Event (JSON)
**Explanation:** When you INSERT, UPDATE, or DELETE a row in PostgreSQL, Debezium publishes a JSON event to Kafka. The event contains the operation type — c for create, u for update, d for delete — plus the before and after values of the row. This is the same format used by every Debezium connector, so your consumers can handle changes from PostgreSQL, MySQL, MongoDB, and SQL Server with the same code.

```sql
// Kafka topic: myapp.public.users
{
  "schema": { ... },
  "payload": {
    "before": null,
    "after": {
      "id": 1,
      "name": "Alice",
      "email": "alice@example.com"
    },
    "source": {
      "version": "2.6.0",
      "connector": "postgresql",
      "db": "myapp",
      "schema": "public",
      "table": "users",
      "lsn": 23456789,
      "txId": 1234
    },
    "op": "c",  // c=create, u=update,
                 // d=delete, r=read(snapshot)
    "ts_ms": 1730000000000
  }
}
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. First, in Go, always use pgxpool not pgx.Connect for production — a single connection cannot handle concurrent requests. Second, lib/pq is in maintenance mode — use pgx for new Go projects. Third, for CDC, do not forget to monitor replication slots — an inactive slot prevents WAL cleanup and fills your disk. Fourth, CDC requires wal_level=logical which generates more WAL — plan for extra disk space.

- Go: Use pgxpool -- pgx.Connect = one connection. pgxpool.New = pool. Always use pool for web applications.
- Go: lib/pq is deprecated -- lib/pq is maintenance-mode. pgx is actively developed, faster, and more features.
- CDC: Monitor replication slots -- Inactive slots prevent WAL cleanup → disk fills. SELECT * FROM pg_replication_slots; regularly.
- CDC: More WAL with logical -- wal_level=logical generates more WAL than replica. Plan 2-3x disk space for pg_wal.
- CDC: Test connector restarts -- Debezium must resume from last LSN after restart. Test this — lost events = data inconsistency.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Go uses pgx as its recommended driver with pgxpool for connection pooling. GORM is Go's standard ORM. For Change Data Capture, Debezium reads PostgreSQL's WAL via logical replication and streams change events to Kafka. CDC enables real-time data sync between microservices, analytics, search, and caches — with zero impact on database write performance. Monitor replication slots to prevent disk issues.

- **Go: pgx driver + pgxpool (pool) + GORM (ORM) — pure Go, fast**
- **lib/pq is deprecated — use pgx for all new Go projects**
- **CDC: Debezium reads PostgreSQL WAL via logical replication**
- **Architecture: PG → Debezium → Kafka → consumers**
- **CDC events: JSON with op (c/u/d), before, after values**
- **CDC vs polling: sub-second, zero write impact, no missed changes**
- **Monitor pg_replication_slots — inactive slots fill disk**


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
