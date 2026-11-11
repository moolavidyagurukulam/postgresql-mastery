# Logical Replication Advanced — Logical Decoding & CDC
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we set up logical replication using publications and subscriptions. Now we go deeper into the engine behind it — logical decoding. Logical decoding lets you read database changes as a stream of events, which opens the door to Change Data Capture pipelines. In this class, we use the built-in test_decoding plugin, the wal2json plugin for JSON output, and introduce Debezium for production CDC.


---

## 2. Core Technical Concepts & Mechanisms

### Logical Decoding Pipeline
Logical decoding is the foundation of logical replication. It reads WAL and converts binary WAL records into a higher-level stream of changes — inserts, updates, deletes, with the actual row data. Output plugins format this stream — pgoutput is used by built-in logical replication, test_decoding is for debugging, and wal2json produces JSON for external systems.

```
[WAL Files
(binary)]
[Logical Decoder
(reads WAL)]
[Output Plugin
(formats changes)]
[Consumer
(app, Kafka, etc.)]
[pgoutput
(logical replication)]
[test_decoding
(human-readable)]
[wal2json
(JSON format)]
```

### get_changes vs peek_changes
There are two functions for reading slots: get_changes consumes the changes so they are gone after reading. peek_changes reads without consuming — useful for debugging or preview. Always use get_changes in production to advance the slot position.

| pg_logical_slot_get_changes | pg_logical_slot_peek_changes |
| :--- | :--- |
| Reads AND consumes changes | Reads WITHOUT consuming |
| Slot position advances | Slot position stays the same |
| Changes are gone after reading | Same changes returned next call |
| Use in production consumers | Use for debugging and testing |
| Prevents WAL accumulation | WARNING: WAL accumulates if never consumed |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### CDC Architecture with PostgreSQL
Now let us talk about Change Data Capture — CDC. CDC is a pattern where you capture every change in the database and stream it to other systems. This is how you sync PostgreSQL with Elasticsearch for search, with data warehouses for analytics, or with Kafka for event-driven architectures.

```
[PostgreSQL
(source of truth)]
[CDC Connector
(Debezium)]
[Apache Kafka
(event stream)]
[Elasticsearch
(search)]
[Data Warehouse
(analytics)]
```

### Debezium — PostgreSQL CDC Connector
Debezium is the most popular CDC connector for PostgreSQL. It reads logical replication slots, converts changes to events, and publishes them to Kafka. Each table becomes a Kafka topic. Debezium handles initial snapshots, schema changes, and exactly-once delivery.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What It Does** | Reads PostgreSQL logical replication slot → publishes events to Kafka |
| **How It Works** | Uses pgoutput plugin (built-in) to decode WAL changes |
| **Key Features** | Initial snapshot, schema tracking, exactly-once semantics |

**Notes:**
- Each table → one Kafka topic
- Events include before+after row state
- Handles schema evolution automatically
- Runs as Kafka Connect connector

### CDC Approaches Comparison
Here is a comparison of CDC approaches — from simplest to most powerful.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a comparison of CDC approaches — from simplest to most powerful |

### Logical Decoding Limitations
Here are some important limitations and considerations for logical decoding and CDC.

| Limitation | Details |
| :--- | :--- |
| DDL not decoded | CREATE/ALTER/DROP not in change stream |
| TRUNCATE handling | Decoded since PG 11, but some plugins skip it |
| Large transactions | One big transaction = one big batch of changes |
| Initial snapshot | Debezium handles it; manual slots need separate sync |
| CPU overhead | Decoding uses CPU on the publisher — monitor load |
| Slot WAL retention | Same risk as physical slots — always set max_slot_wal_keep_size |

### Choosing a CDC Approach
Here is a decision framework for choosing your CDC approach.

- Just need PG-to-PG table sync? -- Use built-in logical replication (CREATE PUBLICATION/SUBSCRIPTION)
- Need JSON stream for a simple app? -- Use wal2json + pg_recvlogical or polling
- Need to feed Kafka or multiple consumers? -- Use Debezium + Kafka Connect
- Need to sync with Elasticsearch/DW? -- Debezium → Kafka → Kafka Connect sink connectors
- Small project, minimal infrastructure? -- Python script + pg_recvlogical + wal2json

### Logical Decoding Output Plugins
Here is the complete list of output plugins available for PostgreSQL logical decoding.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the complete list of output plugins available for PostgreSQL logical decoding |


---

## 3. Hands-On Commands & psql Output

### test_decoding — Create Slot & Read Changes
**Explanation:** Let us start with test_decoding — the built-in output plugin that comes with every PostgreSQL installation. It outputs human-readable text, perfect for learning how logical decoding works. First, create a logical replication slot with the test_decoding plugin.

```sql
postgres=# -- Create a logical slot with test_decoding:
postgres=# SELECT pg_create_logical_replication_slot(
    'test_slot', 'test_decoding');
 pg_create_logical_replication_slot
postgres=# ------------------------------------
 (test_slot,0/B000100)
postgres=# -- Make some changes:
postgres=# INSERT INTO customers (name, email)
postgres-# VALUES ('Eve', 'eve@example.com');
postgres=# UPDATE customers SET name = 'Eve Smith'
postgres-# WHERE email = 'eve@example.com';
postgres=# DELETE FROM customers
postgres-# WHERE email = 'eve@example.com';
```

### Reading Decoded Changes
**Explanation:** Now read the decoded changes from the slot. Each change shows the operation type, table, and the row data. Notice that the slot tracks its position — each call to pg_logical_slot_get_changes consumes the changes so they are not returned again.

```sql
postgres=# -- Read and consume changes:
postgres=# SELECT lsn, xid, data
postgres-# FROM pg_logical_slot_get_changes('test_slot', NULL, NULL);
     lsn     | xid |                     data
postgres=# -------------+-----+----------------------------------------------
 0/B000160   | 750 | BEGIN 750
 0/B000160   | 750 | table public.customers: INSERT: id[int4]:4
             |     |   name[text]:'Eve' email[text]:'eve@example.com'
 0/B000228   | 750 | COMMIT 750
 0/B000260   | 751 | BEGIN 751
 0/B000260   | 751 | table public.customers: UPDATE: id[int4]:4
             |     |   name[text]:'Eve Smith' email[text]:'eve@...'
 0/B000340   | 751 | COMMIT 751
 0/B000370   | 752 | BEGIN 752
 0/B000370   | 752 | table public.customers: DELETE: id[int4]:4
 0/B000410   | 752 | COMMIT 752
postgres=# -- Call again — empty! Changes were consumed:
postgres=# SELECT * FROM pg_logical_slot_get_changes(
    'test_slot', NULL, NULL);
postgres=# -- (0 rows)
```

### wal2json — JSON Output Plugin
**Explanation:** Now let us use wal2json — a popular output plugin that formats changes as JSON. This makes it easy to feed changes into external systems like Kafka, Elasticsearch, or any application that speaks JSON. wal2json must be installed separately.

```sql
# Install wal2json (Debian/Ubuntu):
sudo apt install postgresql-16-wal2json
# Or compile from source:
# git clone https://github.com/eulerto/wal2json.git
# cd wal2json
# make && sudo make install
```

### wal2json — Create Slot & Read JSON
**Explanation:** Create a logical slot with the wal2json plugin and read changes as JSON.

```sql
postgres=# -- Create slot with wal2json:
postgres=# SELECT pg_create_logical_replication_slot(
    'json_slot', 'wal2json');
postgres=# -- Make changes:
postgres=# INSERT INTO orders (customer_id, amount, status)
postgres-# VALUES (1, 500.00, 'pending');
postgres=# -- Read as JSON:
postgres=# SELECT data FROM pg_logical_slot_get_changes(
    'json_slot', NULL, NULL);
{
  "change": [
    {
      "kind": "insert",
      "schema": "public",
      "table": "orders",
      "columnnames": ["id","customer_id","amount","status"],
      "columntypes": ["int4","int4","numeric","text"],
      "columnvalues": [4, 1, 500.00, "pending"]
    }
  ]
}
```

### pg_recvlogical — Stream Changes Continuously
**Explanation:** You can also stream changes using pg_recvlogical, a command-line tool. This keeps a persistent connection and streams changes as they happen — perfect for building a simple consumer process.

```sql
# Stream changes to stdout (runs until Ctrl+C):
pg_recvlogical \
    -h localhost \
    -U replicator \
    -d mydb \
postgres=# --slot=json_slot \
postgres=# --start \
    -f -
# Output appears as each change happens:
{"change":[{"kind":"insert","table":"orders",...}]}
{"change":[{"kind":"update","table":"orders",...}]}
# Stream to a file:
pg_recvlogical \
    -d mydb \
postgres=# --slot=json_slot \
postgres=# --start \
    -f /var/log/pg_changes.json
# Pipe to another process:
pg_recvlogical ... -f - | python3 process_changes.py
```

### Debezium Event — INSERT Example
**Explanation:** A Debezium event for an INSERT looks like this. It includes the operation type, the table, the after state with all column values, and metadata like the transaction ID and timestamp.

```sql
// Kafka topic: pg.public.orders
{
  "schema": { ... },
  "payload": {
    "before": null,
    "after": {
      "id": 5,
      "customer_id": 1,
      "amount": 500.00,
      "status": "pending",
      "ordered_at": 1730722200000
    },
    "source": {
      "version": "2.5.0",
      "connector": "postgresql",
      "db": "mydb",
      "schema": "public",
      "table": "orders",
      "txId": 800,
      "lsn": 184549600
    },
    "op": "c",
    "ts_ms": 1730722200123
  }
}
// op: c=create, u=update, d=delete, r=read(snapshot)
```

### Debezium Event — UPDATE Example
**Explanation:** For an UPDATE, Debezium includes both the before and after state of the row. This is extremely useful — you can see exactly what changed. For this to work, the table needs REPLICA IDENTITY FULL, or at least a primary key.

```sql
// Kafka topic: pg.public.orders
{
  "payload": {
    "before": {
      "id": 5,
      "customer_id": 1,
      "amount": 500.00,
      "status": "pending"
    },
    "after": {
      "id": 5,
      "customer_id": 1,
      "amount": 500.00,
      "status": "shipped"
    },
    "source": {
      "table": "orders",
      "txId": 801,
      "lsn": 184549800
    },
    "op": "u"
  }
}
// 'before' shows old values, 'after' shows new
// status changed: pending → shipped
```

### Simple CDC Consumer (Python + wal2json)
**Explanation:** You do not need Kafka or Debezium for simple CDC. You can build a lightweight consumer using pg_recvlogical with wal2json and a Python script. This is a great starting point for small projects.

```sql
#!/usr/bin/env python3
import subprocess, json, sys

proc = subprocess.Popen(
    ['pg_recvlogical',
     '-d', 'mydb',
     '--slot=json_slot',
     '--start', '-f', '-'],
    stdout=subprocess.PIPE,
    text=True
)

for line in proc.stdout:
    event = json.loads(line)
    for change in event.get('change', []):
        table = change['table']
        kind = change['kind']
        print(f'{kind.upper()} on {table}')
        if kind == 'insert':
            cols = dict(zip(
              change['columnnames'],
              change['columnvalues']))
            print(f'  Data: {cols}')
        # Forward to Elasticsearch, webhook, etc.
```

### Managing Logical Replication Slots
**Explanation:** Slot management is critical for logical decoding. Every logical slot holds WAL until the consumer processes it. If your consumer stops, WAL accumulates. Monitor slots and drop unused ones.

```sql
postgres=# -- List all logical slots:
SELECT
    slot_name,
    plugin,
    active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)
    ) AS lag
postgres-# FROM pg_replication_slots
postgres-# WHERE slot_type = 'logical';
  slot_name  |    plugin     | active |   lag
postgres=# -------------+---------------+--------+----------
 test_slot   | test_decoding | f      | 500 MB
 json_slot   | wal2json      | f      | 200 MB
postgres=# -- Drop unused slots:
postgres=# SELECT pg_drop_replication_slot('test_slot');
postgres=# SELECT pg_drop_replication_slot('json_slot');
postgres=# -- ALWAYS clean up slots you are done with!
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `debezium-pg-connector.json` — Debezium PostgreSQL Connector Config
Here is a sample Debezium connector configuration for PostgreSQL. It connects to your database, reads changes via logical decoding, and publishes them to Kafka topics. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `connector.class` | `io.debezium.connector.postgresql.PostgresConnector` | `[SETTING]` | Debezium PG Kafka connector |
| `database.hostname` | `10.0.1.1` | `[SETTING]` | PostgreSQL primary host |
| `database.port` | `5432` | `[SETTING]` | PostgreSQL port |
| `database.user` | `replicator` | `[SETTING]` | User with REPLICATION privilege |
| `database.dbname` | `mydb` | `[SETTING]` | Database to stream CDC from |
| `database.server.name` | `pg` | `[SETTING]` | Kafka topic prefix name |
| `plugin.name` | `pgoutput` | `[SETTING]` | PostgreSQL 16 native logical decoding plugin |
| `slot.name` | `debezium_slot` | `[SETTING]` | Logical replication slot name |
| `table.include.list` | `public.orders,public.customers` | `[SETTING]` | Explicit list of tables to capture |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Logical decoding reads WAL and converts it to row-level change events. Output plugins format the events — test_decoding for text, wal2json for JSON, pgoutput for built-in logical replication. pg_recvlogical streams changes continuously via command line. Debezium is the production CDC connector that publishes changes to Kafka. Always manage your slots — drop unused ones and set max_slot_wal_keep_size. In the next class, we cover HA tools — Patroni, repmgr, PgBouncer, and production HA architecture.

- **Logical decoding: WAL → row-level change events**
- **test_decoding: built-in, human-readable text output**
- **wal2json: JSON output for custom consumers**
- **pgoutput: used by logical replication and Debezium**
- **pg_logical_slot_get_changes: read + consume changes**
- **pg_logical_slot_peek_changes: read without consuming**
- **pg_recvlogical: command-line continuous streaming**
- **Debezium: production CDC → Kafka → any consumer**
- **Events include before/after state (with REPLICA IDENTITY FULL)**
- **ALWAYS drop unused slots and set max_slot_wal_keep_size**
- **Next: HA Tools & Architecture**


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
