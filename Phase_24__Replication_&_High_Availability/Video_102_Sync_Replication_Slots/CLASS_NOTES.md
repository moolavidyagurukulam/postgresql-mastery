# Synchronous Replication & Replication Slots
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! So far, we have been using asynchronous replication — the primary does not wait for the standby. But what if you need zero data loss? What if losing even one transaction is unacceptable? That is where synchronous replication comes in. In this class, we also cover replication slots — the mechanism that prevents the primary from deleting WAL that standbys still need.

### The Data Loss Problem
With async replication, the COMMIT on the primary returns immediately. The standby receives and applies WAL later — usually milliseconds later, but not guaranteed. If the primary crashes before the standby receives the WAL, those transactions are lost. Synchronous replication solves this: the COMMIT waits until the standby confirms it has the WAL.


---

## 2. Core Technical Concepts & Mechanisms

### The Data Loss Problem
With async replication, the COMMIT on the primary returns immediately. The standby receives and applies WAL later — usually milliseconds later, but not guaranteed. If the primary crashes before the standby receives the WAL, those transactions are lost. Synchronous replication solves this: the COMMIT waits until the standby confirms it has the WAL.

| Async: Possible Data Loss | Sync: Zero Data Loss |
| :--- | :--- |
| 1. Client: COMMIT | 1. Client: COMMIT |
| 2. Primary: writes WAL, returns OK | 2. Primary: writes WAL, sends to standby |
| 3. Primary crashes BEFORE standby gets WAL | 3. Primary WAITS for standby confirmation |
| 4. Standby promoted → transactions LOST | 4. Standby confirms → primary returns OK |
| 5. Client thought COMMIT succeeded | 5. If primary crashes after confirm: |
| 6. But data is gone forever | 6. Standby has ALL committed data |

### synchronous_commit Levels
synchronous_commit controls how strong the guarantee is. There are five levels, from weakest to strongest. Each stronger level adds more latency but provides a stronger durability guarantee.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | synchronous_commit controls how strong the guarantee is |
| **There are five levels** | from weakest to strongest |
| **Point 3** | Each stronger level adds more latency but provides a stronger durability guarantee |

### on vs remote_apply
Let us see the difference between 'on' and 'remote_apply'. With 'on', the standby confirms it flushed WAL to disk. But if you query the standby immediately after COMMIT, the row might not be visible yet — it is on disk but not yet replayed. With 'remote_apply', the standby also confirms it has replayed the WAL, so the row is immediately visible on the standby.

| synchronous_commit = on | synchronous_commit = remote_apply |
| :--- | :--- |
| Standby flushes WAL to disk | Standby flushes AND replays WAL |
| Data is SAFE on standby | Data is SAFE and VISIBLE on standby |
| But NOT yet visible in queries | Read-your-writes guaranteed |
| Replay happens after confirm | Higher latency (must wait for replay) |
| Read-your-writes not guaranteed | Strongest guarantee possible |
| Good for: data safety | Good for: read-after-write consistency |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Replication Slots — What and Why
Now let us cover replication slots. A replication slot is a mechanism on the primary that tracks how much WAL a specific standby has consumed. The primary will never delete WAL that any active slot still needs. There are two types: physical slots for streaming replication and logical slots for logical replication.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Physical Slot** | Tracks WAL position for a streaming replication standby |
| **Logical Slot** | Tracks WAL position for a logical replication subscriber or decoder |

**Notes:**
- Without slots: wal_keep_size is a guess — too low = WAL recycled too early
- With slots: primary retains exactly the WAL each standby needs
- Slots persist across restarts — they are stored on disk

### Decision Framework
Here is a decision framework for choosing sync vs async and whether to use replication slots.

- Can you tolerate losing 1-2 seconds of data? -- Yes → Async replication (simpler, no write latency)
- Must have zero data loss? -- Yes → Synchronous replication (sync_commit = on or remote_apply)
- Need read-your-writes on standby? -- Yes → synchronous_commit = remote_apply
- Multiple standbys, can tolerate one going down? -- Yes → ANY N quorum (e.g., ANY 2 (s1, s2, s3))
- Standby may disconnect for hours? -- Yes → Use replication slots + max_slot_wal_keep_size
- Simple setup, standbys rarely disconnect? -- wal_keep_size may be enough without slots

### Beginner Traps
Here are the common beginner traps with synchronous replication and replication slots.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the common beginner traps with synchronous replication and replication slots |


---

## 3. Hands-On Commands & psql Output

### Enable Synchronous Replication
**Explanation:** To enable synchronous replication, you set synchronous_standby_names on the primary. This parameter names which standbys must confirm before COMMIT returns. You also need to understand the synchronous_commit levels — they control exactly what the standby must do before the primary considers the write safe.

```sql
postgres=# -- Name the standby(s) that must confirm:
postgres=# ALTER SYSTEM SET
    synchronous_standby_names = 'standby1';
postgres=# ALTER SYSTEM
postgres=# -- Reload (no restart needed):
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
postgres=# ----------------
 t
postgres=# -- The standby's application_name must match!
postgres=# -- On STANDBY, in primary_conninfo:
postgres=# -- primary_conninfo = 'user=replicator host=10.0.1.1
postgres=# --   application_name=standby1'
postgres=# -- Verify:
postgres=# SELECT application_name, sync_state
postgres-# FROM pg_stat_replication;
 application_name | sync_state
postgres=# ------------------+------------
 standby1         | sync
```

### Per-Transaction synchronous_commit
**Explanation:** You can set synchronous_commit per transaction. This means critical transactions like payments can use remote_apply, while batch inserts use local. This gives you fine-grained control over the safety vs speed tradeoff.

```sql
postgres=# -- Critical transaction: maximum safety
postgres=# BEGIN;
postgres=# SET LOCAL synchronous_commit = 'remote_apply';
postgres=# INSERT INTO payments (amount, user_id)
postgres-# VALUES (1000.00, 42);
postgres=# COMMIT;
postgres=# -- Waits until standby has applied this row
postgres=# -- Batch insert: speed matters more
postgres=# BEGIN;
postgres=# SET LOCAL synchronous_commit = 'local';
postgres=# INSERT INTO analytics_events
postgres=# SELECT generate_series(1, 10000), 'page_view', now();
postgres=# COMMIT;
postgres=# -- Returns immediately after local flush
postgres=# -- Standby gets it eventually (async for this tx)
```

### Multiple Sync Standbys: FIRST vs ANY
**Explanation:** synchronous_standby_names supports multiple standbys with two modes: FIRST and ANY. FIRST means the primary waits for the first N standbys in the list to confirm. ANY means it waits for any N out of the listed standbys — quorum-based commit.

```sql
postgres=# -- FIRST: wait for first N in order
postgres=# -- Waits for standby1 to confirm (priority order):
synchronous_standby_names = 'FIRST 1 (standby1, standby2)'
postgres=# -- If standby1 is down, waits for standby2 instead
postgres=# -- ANY: quorum — wait for any N to confirm
postgres=# -- Waits for any 2 out of 3 to confirm:
synchronous_standby_names = 'ANY 2 (standby1, standby2, standby3)'
postgres=# -- Even if one standby is down, commits succeed
postgres=# -- because 2 out of 3 is enough
postgres=# -- Check sync state of all standbys:
postgres=# SELECT application_name, sync_state
postgres-# FROM pg_stat_replication;
 application_name | sync_state
postgres=# ------------------+------------
 standby1         | quorum
 standby2         | quorum
 standby3         | quorum
```

### DANGER: Sync Standby Down = Writes Blocked!
**Explanation:** Here is the critical danger of synchronous replication: if all named sync standbys go down, writes on the primary BLOCK. The COMMIT hangs forever, waiting for a standby that will never confirm. Your application freezes. This is the biggest gotcha in sync replication.

```sql
postgres=# -- Standby goes down:
postgres=# -- sudo systemctl stop postgresql (on standby)
postgres=# -- On primary, try to INSERT:
postgres=# INSERT INTO orders (amount) VALUES (100);
postgres=# -- ... hangs forever! Waiting for standby confirmation.
postgres=# -- Ctrl+C to cancel.
postgres=# -- pg_stat_replication shows no connected standbys:
postgres=# SELECT * FROM pg_stat_replication;
postgres=# -- (0 rows)
postgres=# -- EMERGENCY FIX: switch to async temporarily:
postgres=# ALTER SYSTEM SET synchronous_standby_names = '';
postgres=# ALTER SYSTEM
postgres=# SELECT pg_reload_conf();
postgres=# -- Writes resume immediately!
postgres=# -- Or per-session:
postgres=# SET synchronous_commit = 'local';
postgres=# -- This session's writes don't wait for standby
```

### Creating & Using Physical Replication Slots
**Explanation:** Let us create and manage physical replication slots. Create a slot on the primary, then configure the standby to use it.

```sql
postgres=# -- Create a physical slot:
postgres=# SELECT pg_create_physical_replication_slot('standby1_slot');
 pg_create_physical_replication_slot
postgres=# -------------------------------------
 (standby1_slot,)
postgres=# -- View all slots:
postgres=# SELECT
    slot_name,
    slot_type,
    active,
    active_pid,
    restart_lsn
postgres-# FROM pg_replication_slots;
   slot_name    | slot_type | active | active_pid | restart_lsn
postgres=# -----------------+-----------+--------+------------+-------------
 standby1_slot   | physical  | f      |            |
postgres=# -- On STANDBY, add to postgresql.conf:
postgres=# -- primary_slot_name = 'standby1_slot'
postgres=# -- Then restart the standby
postgres=# -- After standby connects:
postgres=# -- active = t, active_pid = <WAL receiver PID>
```

### DANGER: Inactive Slots Fill Your Disk!
**Explanation:** Now the most dangerous aspect of replication slots: inactive slots retain WAL forever. If a standby goes offline and you do not drop its slot, WAL accumulates on the primary until the disk fills up. This causes a PANIC: no space left on device — PostgreSQL crashes.

```sql
postgres=# -- Standby is offline — its slot retains WAL:
postgres=# SELECT
    slot_name,
    active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
postgres-# FROM pg_replication_slots;
   slot_name    | active | retained_wal
postgres=# -----------------+--------+--------------
 standby1_slot   | f      | 15 GB
postgres=# -- 15 GB of WAL retained and GROWING!
postgres=# -- If disk fills:
postgres=# -- PANIC: could not write to file "pg_wal/...":
postgres=# --   No space left on device
postgres=# -- PostgreSQL CRASHES!
postgres=# -- Fix: Drop the inactive slot:
postgres=# SELECT pg_drop_replication_slot('standby1_slot');
postgres=# -- WAL is released immediately
```

### max_slot_wal_keep_size — Safety Net
**Explanation:** PostgreSQL 16 has a safety net: max_slot_wal_keep_size. This limits how much WAL a slot can retain. When the limit is reached, the slot is invalidated — the standby will need a fresh pg_basebackup, but at least the primary does not crash.

```sql
postgres=# -- Set maximum WAL retention per slot:
postgres=# ALTER SYSTEM SET max_slot_wal_keep_size = '10GB';
postgres=# ALTER SYSTEM
postgres=# SELECT pg_reload_conf();
postgres=# -- If a slot exceeds 10GB of retained WAL:
postgres=# -- The slot is INVALIDATED (marked as invalid)
postgres=# -- WAL is released, disk is saved
postgres=# -- Standby must re-sync with pg_basebackup
postgres=# -- Check for invalidated slots:
postgres=# SELECT slot_name, active,
    conflicting IS NOT NULL AS is_invalidated
postgres-# FROM pg_replication_slots;
postgres=# -- ALWAYS set this in production!
postgres=# -- Recommended: 2x your expected max disconnect time's WAL
```

### Combined Sync + Slot Monitoring Query
**Explanation:** Here is a monitoring query that covers both synchronous replication status and replication slot health. Run this regularly to catch problems early.

```sql
-- Replication status with sync info:
SELECT
    r.client_addr,
    r.application_name,
    r.sync_state,
    r.state,
    pg_size_pretty(
      pg_wal_lsn_diff(pg_current_wal_lsn(), r.replay_lsn)
    ) AS lag
FROM pg_stat_replication r;

-- Slot health:
SELECT
    s.slot_name,
    s.slot_type,
    s.active,
    pg_size_pretty(
      pg_wal_lsn_diff(pg_current_wal_lsn(), s.restart_lsn)
    ) AS retained_wal,
    CASE
      WHEN NOT s.active AND pg_wal_lsn_diff(
          pg_current_wal_lsn(), s.restart_lsn
        ) > 5368709120 THEN 'DANGER (> 5 GB)'
      WHEN NOT s.active THEN 'INACTIVE'
      ELSE 'OK'
    END AS status
FROM pg_replication_slots s;
```

### Create Slot During pg_basebackup
**Explanation:** Replication slots can also be created during pg_basebackup. The -C flag creates a slot on the primary, and -S names it. The standby automatically uses it.

```sql
# Create slot AND take backup in one command:
sudo -u postgres pg_basebackup \
    -h 10.0.1.1 \
    -U replicator \
    -D /var/lib/postgresql/16/main \
    -Fp -Xs -P -R \
    -C -S standby1_slot
# -C = Create replication slot on primary
# -S = Name the slot 'standby1_slot'
# -R adds primary_slot_name to postgresql.auto.conf
# Verify on PRIMARY:
# SELECT slot_name, active
# FROM pg_replication_slots;
#    slot_name    | active
# ----------------+--------
#  standby1_slot  | f
# (active becomes true when standby starts)
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf (on PRIMARY)` — Production Sync Replication Config
Here is the complete configuration for a production synchronous replication setup with replication slots. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `wal_level` | `replica` | **`[RESTART]`** (Postmaster Restart) | Required for replication (Default: replica) |
| `max_wal_senders` | `10` | **`[RESTART]`** (Postmaster Restart) | Max standby connections (Default: 10) |
| `synchronous_standby_names` | `'ANY 2 (s1, s2, s3)'` | `[RELOAD]` (Live Reload `SIGHUP`) | Quorum: any 2 of 3 standbys must acknowledge |
| `synchronous_commit` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Wait for standby flush (Default: on) |
| `max_replication_slots` | `10` | **`[RESTART]`** (Postmaster Restart) | Total replication slots (Default: 10) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Here are the common beginner traps with synchronous replication and replication slots.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Synchronous replication makes the primary wait for standby confirmation before returning COMMIT, guaranteeing zero data loss. synchronous_commit levels control exactly what the standby confirms — from OS write to full replay. Use ANY N for quorum commit so one standby failure does not block writes. Replication slots track WAL consumption per standby and prevent premature deletion. Always set max_slot_wal_keep_size to prevent inactive slots from crashing your server. In the next class, we build a cascading replication chain.

- **Sync replication: COMMIT waits for standby confirmation**
- **synchronous_standby_names names which standbys must confirm**
- **5 levels: off → local → remote_write → on → remote_apply**
- **remote_apply: read-your-writes guarantee on standby**
- **Per-transaction: SET LOCAL synchronous_commit = '...'**
- **ANY N quorum: tolerate N-1 standby failures**
- **DANGER: if all sync standbys down, writes BLOCK**
- **Replication slots: prevent WAL deletion for specific standbys**
- **DANGER: inactive slots hold WAL forever → disk full → crash**
- **max_slot_wal_keep_size: safety net, ALWAYS set in production**
- **Next: Cascading Replication**


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
