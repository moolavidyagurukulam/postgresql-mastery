# LISTEN & NOTIFY — Real-Time Notifications
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! How does your application know when data changes in the database? Most applications poll — they run a query every few seconds asking 'is there anything new?'. This wastes resources. PostgreSQL has a built-in pub-sub system called LISTEN and NOTIFY that pushes notifications to connected clients instantly when something changes. No polling needed.


---

## 2. Core Technical Concepts & Mechanisms

### Polling vs LISTEN/NOTIFY
The problem with polling is simple. Your app runs a query every 5 seconds to check for changes. If nothing changed, those queries were wasted. If something changed 4 seconds ago, the app did not know until the next poll. LISTEN and NOTIFY solves both problems — zero wasted queries and instant delivery.

| Polling (Wasteful) | LISTEN/NOTIFY (Efficient) |
| :--- | :--- |
| Query every N seconds | Event pushed instantly |
| Wastes CPU/IO when no changes | Zero queries when no changes |
| Delayed: up to N seconds late | Real-time: sub-millisecond delivery |
| More connections under load | Single persistent connection |
| Scales poorly with many watchers | Scales well with many listeners |

### LISTEN/NOTIFY Rules
Important rules for LISTEN and NOTIFY. Notifications are transactional — if you NOTIFY inside a transaction that rolls back, the notification is never sent. The payload is limited to 8000 bytes. And UNLISTEN stops listening on a channel.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Transactional** | Notifications sent only when the transaction commits — rollback = no notification |
| **Payload limit** | Maximum 8000 bytes per notification payload |
| **UNLISTEN** | Stop listening: UNLISTEN channel_name; or UNLISTEN *; for all |
| **Delivery** | Delivered to all sessions listening on that channel |

**Notes:**
- No persistence — if no one is listening, the notification is lost
- No acknowledgment — sender does not know if anyone received it
- Multiple listeners can listen on the same channel

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### LISTEN/NOTIFY Use Cases
What are the practical use cases for LISTEN and NOTIFY? Real-time dashboards, cache invalidation, job queues, live notifications, and chat applications. Here are the most common patterns.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | What are the practical use cases for LISTEN and NOTIFY? |
| **Real** | time dashboards, cache invalidation, job queues, live notifications, and chat applications |

### Limitations to Know
Important limitation — LISTEN and NOTIFY works only within a single PostgreSQL cluster. If you have multiple database servers with replication, notifications on the primary are NOT replicated to standbys. Also, notifications are not persistent — if your app is disconnected when a notification is sent, it is lost forever.

| Works Well For | Not Suitable For |
| :--- | :--- |
| Single-server applications | Cross-server notifications |
| Cache invalidation (miss = stale cache) | Guaranteed delivery (use MQ instead) |
| Real-time UI updates | High-volume events (>1000/sec) |
| Simple job queues | Persistent queues (use pgq or SKIP LOCKED) |
| Low-volume notifications | Large payloads (>8000 bytes limit) |


---

## 3. Hands-On Commands & psql Output

### Basic LISTEN and NOTIFY
**Explanation:** Here is how it works. One session listens on a channel — any string name you choose. Another session sends a notification on that channel. The listener receives it instantly. The channel name is like a topic in a messaging system.

```sql
postgres=# -- SESSION 1: Start listening
postgres=# LISTEN order_updates;
LISTEN
postgres=# -- SESSION 2: Send a notification
postgres=# NOTIFY order_updates;
NOTIFY
postgres=# -- SESSION 1: Receives it instantly!
Asynchronous notification "order_updates"
    received from server process with PID 12345.
postgres=# -- Send with a payload message:
postgres=# NOTIFY order_updates, 'order_id=42,status=shipped';
postgres=# -- SESSION 1:
Asynchronous notification "order_updates"
postgres=# with payload "order_id=42,status=shipped"
    received from server process with PID 12345.
```

### pg_notify Function
**Explanation:** You can also use the pg_notify function instead of the NOTIFY command. The function form is useful in triggers and PL/pgSQL because the channel name can be a variable.

```sql
postgres=# -- NOTIFY command (channel must be literal):
NOTIFY order_updates, 'order 42 shipped';
postgres=# -- pg_notify function (channel can be variable):
postgres=# SELECT pg_notify('order_updates', 'order 42 shipped');
postgres=# -- In PL/pgSQL, channel can be dynamic:
postgres=# DO $$
DECLAR
    channel text := 'order_updates';
postgres=# BEGIN
    PERFORM pg_notify(channel, 'dynamic channel!');
END;
$$;
postgres=# -- Both produce the same notification
```

### Trigger-Based Notifications
**Explanation:** The most powerful use — trigger-based notifications. When a row changes, a trigger automatically sends a notification with the row data as JSON payload. This is how you build real-time features.

```sql
postgres=# CREATE TABLE orders (
    id serial PRIMARY KEY,
    customer text NOT NULL,
    amount numeric(10,2),
    status text DEFAULT 'pending'
);
postgres=# -- Trigger function that notifies on changes:
postgres=# CREATE OR REPLACE FUNCTION notify_order_change()
RETURNS trigger AS $$
postgres=# BEGIN
    PERFORM pg_notify('order_events',
        json_build_object(
            'action', TG_OP,
            'order_id', NEW.id,
            'customer', NEW.customer,
            'status', NEW.status,
            'amount', NEW.amount
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
postgres=# CREATE TRIGGER trg_order_notify
    AFTER INSERT OR UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_change();
```

### Trigger Notifications in Action
**Explanation:** Now when anyone inserts or updates an order, all listeners get a JSON notification instantly.

```sql
postgres=# -- SESSION 1: Listen for order events
LISTEN order_events;
postgres=# -- SESSION 2: Insert an order
postgres=# INSERT INTO orders (customer, amount)
postgres-# VALUES ('Alice', 299.99);
postgres=# -- SESSION 1: Receives instantly!
Asynchronous notification "order_events"
postgres=# with payload
    "{\"action\":\"INSERT\",\"order_id\":1,
      \"customer\":\"Alice\",\"status\":\"pending\",
      \"amount\":299.99}"
postgres=# -- SESSION 2: Update the order
postgres=# UPDATE orders SET status = 'shipped' WHERE id = 1;
postgres=# -- SESSION 1:
Asynchronous notification "order_events"
postgres=# with payload
    "{\"action\":\"UPDATE\",\"order_id\":1,
      \"customer\":\"Alice\",\"status\":\"shipped\",
      \"amount\":299.99}"
```

### Python Listener Example (psycopg2)
**Explanation:** In a real application, you use a programming language to listen for notifications. Here is a Python example using psycopg2. The connection stays open and select waits for notifications without consuming CPU.

```sql
import select
import psycopg2
import json

conn = psycopg2.connect("dbname=mydb user=postgres")
conn.set_isolation_level(
    psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

cur = conn.cursor()
cur.execute("LISTEN order_events;")
print("Listening for order events...")

while True:
    # Wait for notification (blocks efficiently)
    select.select([conn], [], [], 5)  # 5s timeout
    conn.poll()
    while conn.notifies:
        notify = conn.notifies.pop(0)
        payload = json.loads(notify.payload)
        print(f"Action: {payload['action']}")
        print(f"Order: #{payload['order_id']}")
        print(f"Status: {payload['status']}")
```

### Node.js Listener Example (pg)
**Explanation:** Here is a Node.js example using the pg library. The client emits a 'notification' event that you handle with a callback.

```sql
const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres@localhost/mydb'
});

async function main() {
  await client.connect();
  await client.query('LISTEN order_events');
  console.log('Listening for order events...');

  client.on('notification', (msg) => {
    const payload = JSON.parse(msg.payload);
    console.log(`${payload.action}: Order #${payload.order_id}`);
    console.log(`  Customer: ${payload.customer}`);
    console.log(`  Status: ${payload.status}`);
  });
}

main().catch(console.error);
```

### Pattern: Cache Invalidation
**Explanation:** Let us build a simple cache invalidation pattern. When a product changes, the trigger notifies the application which then clears that product from its cache.

```sql
postgres=# CREATE OR REPLACE FUNCTION notify_cache_invalidation()
RETURNS trigger AS $$
DECLARE
    record_id int;
postgres=# BEGIN
    IF TG_OP = 'DELETE' THEN
        record_id := OLD.id;
    ELSE
        record_id := NEW.id;
    END IF;
    PERFORM pg_notify('cache_invalidation',
        json_build_object(
            'table', TG_TABLE_NAME,
            'action', TG_OP,
            'id', record_id
        )::text
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
postgres=# CREATE TRIGGER trg_products_cache
    AFTER INSERT OR UPDATE OR DELETE ON products
    FOR EACH ROW
    EXECUTE FUNCTION notify_cache_invalidation();
postgres=# -- App listens: LISTEN cache_invalidation;
postgres=# -- On notification: clear cache for that product ID
```

### Beginner Trap: Long Transactions Delay Notifications
**Explanation:** A beginner trap — if you use NOTIFY inside a long transaction, the notification is held until COMMIT. If the transaction runs for 5 minutes, the listener waits 5 minutes. Keep your notifying transactions short.

```sql
postgres=# -- SESSION 2: Start a long transaction
postgres=# BEGIN;
postgres=# INSERT INTO orders (customer, amount)
postgres-# VALUES ('Bob', 500.00);
postgres=# -- Notification is QUEUED, not sent yet!
postgres=# -- ... 5 minutes of other work ...
postgres=# COMMIT;
postgres=# -- NOW the notification is delivered to listeners
postgres=# -- Worse: ROLLBACK = notification never sent:
postgres=# BEGIN;
postgres=# INSERT INTO orders (customer, amount)
postgres-# VALUES ('Eve', 100.00);
postgres=# ROLLBACK;
postgres=# -- No notification sent! The INSERT was rolled back.
postgres=# -- Best practice: keep notifying transactions SHORT
postgres=# -- Use AUTOCOMMIT for immediate delivery
```

### PgBouncer Compatibility
**Explanation:** For connection poolers like PgBouncer — LISTEN only works in session pooling mode, NOT in transaction pooling mode. In transaction mode, your session changes between queries, so LISTEN state is lost.

```sql
postgres=# -- PgBouncer session mode: ✓ LISTEN works
postgres=# -- PgBouncer transaction mode: ✗ LISTEN broken!
postgres=# -- Workaround: dedicated direct connection for LISTEN
postgres=# -- Your app has two connections:
postgres=# --   1. PgBouncer (transaction mode) → normal queries
postgres=# --   2. Direct to PG (bypass PgBouncer) → LISTEN
postgres=# -- In pgbouncer.ini:
postgres=# -- [databases]
postgres=# -- mydb = host=localhost port=5432 dbname=mydb
postgres=# -- mydb_listen = host=localhost port=5432 dbname=mydb
postgres=# --              pool_mode=session pool_size=5
postgres=# -- Or connect directly:
postgres=# -- psql -h localhost -p 5432 -d mydb  (direct)
postgres=# -- psql -h localhost -p 6432 -d mydb  (PgBouncer)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Long Transactions Delay Notifications
A beginner trap — if you use NOTIFY inside a long transaction, the notification is held until COMMIT. If the transaction runs for 5 minutes, the listener waits 5 minutes. Keep your notifying transactions short.

```sql
-- SESSION 2: Start a long transaction
BEGIN;
INSERT INTO orders (customer, amount)
VALUES ('Bob', 500.00);
-- Notification is QUEUED, not sent yet!
-- ... 5 minutes of other work ...
COMMIT;
-- NOW the notification is delivered to listeners
-- Worse: ROLLBACK = notification never sent:
BEGIN;
INSERT INTO orders (customer, amount)
VALUES ('Eve', 100.00);
ROLLBACK;
-- No notification sent! The INSERT was rolled back.
-- Best practice: keep notifying transactions SHORT
-- Use AUTOCOMMIT for immediate delivery
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. LISTEN subscribes to a channel, NOTIFY sends a message on it. Notifications are transactional — only delivered on COMMIT. pg_notify function allows dynamic channel names in triggers. The payload is limited to 8000 bytes. Notifications are not persistent and not replicated to standbys. Use triggers to auto-notify on data changes. Best for cache invalidation, real-time UI, and simple job queues. Not suitable for guaranteed delivery — use a message queue for that. In the next class, we explore large objects — storing binary files inside PostgreSQL.

- **LISTEN channel: subscribe to notifications**
- **NOTIFY channel, 'payload': send notification**
- **pg_notify(channel, payload): function form for triggers**
- **Transactional: delivered on COMMIT, lost on ROLLBACK**
- **Payload limit: 8000 bytes (use JSON for structure)**
- **Not persistent: lost if no listener connected**
- **Not replicated: works only on the same PG server**
- **Trigger pattern: auto-notify on INSERT/UPDATE/DELETE**
- **Cache invalidation: clear cache when data changes**
- **PgBouncer: only works in session pooling mode**
- **Next: Large Objects**


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
