# Backup Strategy, DR Planning & Drills
**Series:** PostgreSQL Mastery | **Phase:** Phase 18: Backup, Recovery & Disaster Recovery | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! This is the final class of the Backup and Recovery phase. We have learned all the tools — pg_dump, pg_basebackup, PITR, pgBackRest, Barman, WAL-G. Now we put it all together into a complete production backup strategy. We cover scheduling, retention policies, the grandfather-father-son rotation, disaster recovery planning, and most importantly — DR drills. Because a plan you have never tested is just a wish. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Five Questions of Backup Strategy
A complete backup strategy answers five questions. What to back up — which databases, which method. When to back up — schedule and frequency. Where to store backups — local, remote, cloud, and how many copies. How long to keep them — retention policy. And how to verify — testing restores regularly. Let us answer each one.

| Term | Meaning / Explanation |
| :--- | :--- |
| **WHAT** | Which databases, logical + physical, globals (roles/tablespaces) |
| **WHEN** | Full weekly + diff daily + incr hourly + continuous WAL archiving |
| **WHERE** | 3-2-1 rule: 3 copies, 2 different media, 1 offsite |
| **HOW LONG** | Grandfather-father-son: weekly × 4, monthly × 12, yearly × 3 |
| **VERIFY** | Monthly DR drill: full restore to test server, measure actual RTO |

**Notes:**
- Write this down as a formal Backup Policy document
- Review and update every 6 months

### The 3-2-1 Backup Rule
The 3-2-1 backup rule is the foundation. Keep 3 copies of your data. Store them on 2 different types of media — for example, local disk plus cloud storage. Keep 1 copy offsite — in a different data center, region, or cloud provider. If your server room floods, your offsite copy saves the business.

- 3 -- Production database + local backup + remote backup
- 2 -- Local SSD/NAS + cloud object storage (S3, GCS, Azure)
- 1 -- Different region or provider — survives site-level disaster

### Grandfather-Father-Son Retention
The Grandfather-Father-Son rotation is the standard retention policy. Daily backups are sons — keep the last 7. Weekly backups are fathers — keep the last 4. Monthly backups are grandfathers — keep the last 12. This gives you fine-grained recovery for recent data and longer-term recovery points stretching back a year.

| Term | Meaning / Explanation |
| :--- | :--- |
| **The Grandfather-Father-Son rotation** | the standard retention policy |
| **Daily backups** | sons — keep the last 7 |
| **Weekly backups** | fathers — keep the last 4 |
| **Monthly backups** | grandfathers — keep the last 12 |

### DR Plan — What It Must Cover
Now let us talk about disaster recovery planning. A DR plan is a written document that answers: what disasters can happen, what is the impact of each, and what are the exact steps to recover. It is not a vague idea in your head — it is a step-by-step runbook that anyone on the team can follow at 3 AM while panicking.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Disaster Scenarios** | Hardware failure, data corruption, accidental DROP, ransomware, datacenter fire |
| **Impact Analysis** | Which systems depend on this DB? Revenue per hour of downtime? |
| **Recovery Runbook** | Step-by-step commands — copy-paste ready, not 'figure it out' |
| **Contact List** | Who to call: DBA, sysadmin, cloud provider, management |
| **Communication Plan** | Who tells customers? Status page update? Internal Slack channel? |

**Notes:**
- Store the DR plan OUTSIDE the database server (wiki, shared drive, printed copy)
- Review quarterly, update after every infrastructure change

### Disaster Scenarios & Recovery Approaches
Here are the most common disaster scenarios and the recovery approach for each. Notice how different disasters need different tools. Accidental DROP needs PITR. Hardware failure needs standby failover. Corruption needs base backup restore. Ransomware needs offsite backup. Having only one backup type covers only one scenario.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the most common disaster scenarios and the recovery approach for each |
| **Point 2** | Notice how different disasters need different tools |
| **Point 3** | Accidental DROP needs PITR |
| **Point 4** | Hardware failure needs standby failover |
| **Point 5** | Corruption needs base backup restore |
| **Point 6** | Ransomware needs offsite backup |
| **Point 7** | Having only one backup type covers only one scenario |

### DR Runbook: Accidental DROP TABLE Recovery
Let us build a DR runbook — the actual step-by-step commands for the most common disaster: accidental data destruction. This is copy-paste ready. Print it. Put it in the wiki. Make sure every DBA on the team has access to it.

- 1 -- Prevent further writes: disconnect app servers or set PG to read-only
- 2 -- Check pg_stat_activity or app logs for exact DROP timestamp
- 3 -- systemctl stop postgresql
- 4 -- mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main_disaster
- 5 -- pgbackrest --stanza=prod --delta --type=time --target='TIMESTAMP' restore
- 6 -- systemctl start postgresql — watch logs for recovery complete
- 7 -- Check table exists, row counts match, critical data present
- 8 -- Reconnect app servers, verify application works end-to-end

### DR Drills — Testing Your Recovery
Now the most important topic in this entire phase: DR drills. A DR drill is a scheduled, planned test of your recovery process. You simulate a disaster on a test server and practice the full recovery. You measure the actual RTO — how long it takes from start to finish. You find problems before they matter. Monthly DR drills are the minimum for production databases.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Full recovery test: restore from backup → verify data → measure time |
| **How Often** | Monthly minimum, quarterly for complex environments |
| **Where** | Separate test server — NEVER practice on production |
| **Who** | Different team member each month — everyone must know the process |
| **Record** | Document: start time, end time, actual RTO, issues found, fixes applied |

**Notes:**
- Alternate scenarios: full server failure, single table recovery, PITR to timestamp
- If the drill fails, fix the issue and repeat until it succeeds

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Daily Backup Monitoring Checklist
Here are the backup monitoring checks you should run daily. If any of these fail, your backups may not work when you need them most. Add these to your monitoring system — Nagios, Zabbix, Prometheus, or even a simple cron script that sends alerts.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the backup monitoring checks you should run daily |
| **If any of these fail** | your backups may not work when you need them most |
| **Add these to your monitoring system** | Nagios, Zabbix, Prometheus, or even a simple cron script that sends alerts |

### Backup Strategy Beginner Traps
Here are the beginner traps for backup strategy. These are the mistakes that get people fired.

| Mistakes That Get You Fired | What Good Looks Like |
| :--- | :--- |
| Only pg_dump, no physical backup | Logical + physical + WAL archiving |
| Backups on the same disk as data | Backups on separate storage + cloud |
| No offsite copy (3-2-1 violated) | 3-2-1 rule: local + remote + offsite |
| Never tested a restore | Monthly DR drills with documented RTO |
| No monitoring — silent failures | Automated monitoring with alerts |
| Backup runs but nobody checks it | Weekly verify, daily backup checks |

### Practice Exercises
Time to practice. First, write a backup policy document for a hypothetical e-commerce database with RTO of 1 hour and RPO of 5 minutes. Second, create a crontab with full, differential, and incremental schedules. Third, perform a complete DR drill — restore from backup, PITR, measure your actual RTO. Fourth, write a DR drill report. Fifth, set up monitoring queries and test them.

- 1 -- RTO=1h, RPO=5min: what tools, what schedule, where stored, how long kept
- 2 -- Full Sunday + diff Mon-Sat + incr hourly + verify weekly
- 3 -- Restore from backup → PITR → verify data → measure actual RTO
- 4 -- Scenario, actual RTO, issues found, action items
- 5 -- pg_stat_archiver + backup age checks + alert thresholds


---

## 3. Hands-On Commands & psql Output

### Complete DR Drill Walkthrough
**Explanation:** Let us walk through a complete DR drill. This is exactly what you do every month on a test server. We will restore from a pgBackRest backup, perform PITR, and measure the actual RTO.

```sql
$ # Record start time:
$ echo "DR Drill Start: $(date)"
DR Drill Start: Wed Nov  4 14:00:00 IST 2026
$ # Step 1: Restore to test server via pgBackRest
$ sudo -u postgres pgbackrest --stanza=prod --delta \
  --type=time --target='2026-11-04 10:30:00+05:30' \
  --target-action=promote \
  --pg1-path=/var/lib/postgresql/16/test restore
P00   INFO: restore command end: completed successfully
$ # Step 2: Start test instance
$ sudo pg_ctlcluster 16 test start
... recovery complete, ready to accept connections
$ # Step 3: Verify data
$ psql -p 5433 -U postgres -d prod -c 'SELECT count(*) FROM orders;'
  count
 1234567
$ echo "DR Drill End: $(date)"
DR Drill End: Wed Nov  4 14:47:00 IST 2026
-- -- Actual RTO: 47 minutes (target was 60 minutes) ✓
```

### Backup Monitoring Queries
**Explanation:** Let us write the monitoring queries. These are the queries you add to your monitoring system. The first checks if the last backup is recent. The second checks if WAL archiving is working. Run these every 5 minutes and alert on failures.

```sql
-- 1. Check WAL archiving is healthy:
SELECT
    archived_count,
    failed_count,
    last_archived_time,
    CASE WHEN last_archived_time < now() - '10 min'::interval
         THEN 'ALERT: archiving stale!'
         ELSE 'OK' END AS status
FROM pg_stat_archiver;

-- 2. Check for inactive replication slots (WAL leak!):
SELECT slot_name, active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
FROM pg_replication_slots
WHERE NOT active;

-- 3. Simple backup age check (pgBackRest):
-- pgbackrest --stanza=prod info --output=json
-- Parse: backup[0].timestamp.stop > now - 25 hours
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Production Backup Schedule (crontab)
Let us build a complete production backup schedule using pgBackRest. This covers all the bases — full, differential, incremental backups plus WAL archiving plus verification. Adjust the timing to your database's quiet hours.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `0 1 1 * *` | `pgbackrest --stanza=prod --type=full backup` | `[SETTING]` |  |
| `0 1 * * 0` | `pgbackrest --stanza=prod --type=full backup` | `[SETTING]` |  |
| `0 1 * * 1-6` | `pgbackrest --stanza=prod --type=diff backup` | `[SETTING]` |  |
| `0 * * * *` | `pgbackrest --stanza=prod --type=incr backup` | `[SETTING]` |  |
| `0 6 * * 0` | `pgbackrest --stanza=prod verify` | `[SETTING]` |  |
| `30 1 * * *` | `pg_dump -Fc -t orders -t payments -d prod -f /backups/critical.dump` | `[SETTING]` |  |


### File: `postgresql.conf` — DR Drill Report Template
After every DR drill, write a brief report. Document the scenario, the actual RTO, any issues you found, and what you fixed. Keep these reports — they prove your backup strategy works and help you improve over time. Here is a template.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `Date` | `2026-11-04` | `[SETTING]` |  |
| `Scenario` | `Full PITR to 30 minutes ago` | `[SETTING]` |  |
| `Backup Tool` | `pgBackRest` | `[SETTING]` |  |
| `Backup Used` | `20261104-020000F + diff + WAL` | `[SETTING]` |  |
| `Target Time` | `2026-11-04 10:30:00+05:30` | `[SETTING]` |  |
| `Actual RTO` | `47 minutes` | `[SETTING]` |  |
| `Target RTO` | `60 minutes` | `[SETTING]` |  |
| `RTO Met?` | `YES` | `[SETTING]` |  |
| `Data Verified?` | `YES — row counts match, spot checks pass` | `[SETTING]` |  |
| `Issues Found` | `Archive dir permissions wrong on test server (fixed)` | `[SETTING]` |  |
| `Action Items` | `Add permission check to DR checklist` | `[SETTING]` |  |
| `Performed By` | `Alice` | `[SETTING]` |  |



---

## 5. Common Beginner Traps & How to Fix Them

### Backup Strategy Beginner Traps
Here are the beginner traps for backup strategy. These are the mistakes that get people fired.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review this class and the entire backup phase. A backup strategy answers: what, when, where, how long, and verify. Use the 3-2-1 rule — 3 copies, 2 media, 1 offsite. Grandfather-father-son retention for long-term recovery. Build a DR plan with step-by-step runbooks for each disaster scenario. DR drills monthly — full restore, measure actual RTO, document results. Monitor daily — backup completion, WAL archiving, archive disk space. And the golden rule: a backup you have not tested is not a backup.

- **5 questions: what, when, where, how long, verify**
- **3-2-1 rule: 3 copies, 2 media types, 1 offsite**
- **GFS retention: daily × 7, weekly × 4, monthly × 12**
- **Schedule: full weekly + diff daily + incr hourly + continuous WAL**
- **DR plan: written runbooks for each disaster scenario**
- **DR drills: monthly, measure actual RTO, rotate team members**
- **Monitor: backup age, WAL archiving, archive disk, replication slots**
- **A backup you have not tested is NOT a backup**

Let us also review the entire backup and recovery phase. We covered pg_dump and pg_restore for logical backups. pg_basebackup for physical backups. Point-in-Time Recovery with WAL archiving. pgBackRest, Barman, and WAL-G for enterprise automation. And now backup strategy, DR planning, and DR drills. You have everything you need to protect any PostgreSQL database in production.

- **pg_dump/pg_restore: logical backup — portable, selective, cross-version**
- **pg_basebackup: physical backup — fast, PITR-capable, replica-ready**
- **PITR: base backup + WAL archive → any point in time**
- **pgBackRest: full/diff/incr, encryption, retention, verify**
- **Barman: centralized remote backup for multiple servers**
- **WAL-G: cloud-native, env var config, delta backups**
- **Backup strategy: 3-2-1 rule + GFS retention**
- **DR planning: runbooks + monthly drills + monitoring**


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
