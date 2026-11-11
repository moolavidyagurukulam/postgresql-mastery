# pgAudit — Compliance Audit Logging
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Compliance regulations like GDPR, HIPAA, SOX, and PCI-DSS require you to answer one question: who did what to which data and when? PostgreSQL's built-in logging captures statements but lacks the detail needed for compliance. pgAudit provides structured, detailed audit logging — tracking every SELECT, INSERT, UPDATE, DELETE, and DDL statement with the precision regulators demand. Let us learn how to set it up.


---

## 2. Core Technical Concepts & Mechanisms

### Built-in Logging vs pgAudit
PostgreSQL has built-in statement logging with log_statement. But it only captures the raw SQL text — it does not tell you which tables were accessed, whether the query was a SELECT or UPDATE through a function, or distinguish between different types of DDL. pgAudit solves all of this with structured, categorized audit entries.

| log_statement (Built-in) | pgAudit |
| :--- | :--- |
| Logs raw SQL text only | Structured audit entries |
| No table-level detail | Identifies accessed tables |
| No categorization (DDL vs DML) | Categorized: READ, WRITE, DDL, etc. |
| Cannot audit SELECT separately | Audit SELECT on sensitive tables |
| No per-user/per-table control | Per-role and per-table granularity |
| Not compliance-ready | Compliance-ready (GDPR, HIPAA, SOX) |

### pgAudit Audit Modes
pgAudit has two modes — session audit logging and object audit logging. Session logging captures all statements of specified types for the entire session. Object logging captures operations on specific tables assigned to an audit role. Most setups use both.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Session Logging** | Captures ALL statements of specified classes (READ, WRITE, DDL, etc.) |
| **Object Logging** | Captures operations on specific tables assigned to an audit role |
| **pgaudit.log** | Controls session logging — which statement classes to audit |
| **pgaudit.role** | Controls object logging — the role whose GRANTs define audit scope |

**Notes:**
- Session: broad coverage, higher log volume
- Object: precise targeting, lower log volume
- Best practice: use both together

### pgaudit.log Statement Classes
The pgaudit.log setting supports several statement classes. Here is the complete list. You can combine them with commas, or use 'all' to capture everything, or 'none' to disable session logging.

| Term | Meaning / Explanation |
| :--- | :--- |
| **The pgaudit** | log setting supports several statement classes |
| **You can combine them with commas** | or use 'all' to capture everything, or 'none' to disable session logging |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### pgAudit Configuration Options
Additional pgAudit settings fine-tune what gets logged. pgaudit.log_catalog controls whether system catalog queries are logged — disable it to reduce noise. pgaudit.log_parameter logs the actual parameter values in prepared statements. pgaudit.log_statement_once avoids duplicating the SQL text in sub-statements.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Additional pgAudit settings fine** | tune what gets logged |
| **Point 2** | pgaudit.log_catalog controls whether system catalog queries are logged — disable it to reduce noise |
| **Point 3** | pgaudit.log_parameter logs the actual parameter values in prepared statements |
| **Point 4** | pgaudit.log_statement_once avoids duplicating the SQL text in sub-statements |

### Audit Log Pipeline
Ship audit logs to a centralized log management system. pgAudit writes to the PostgreSQL log. Use tools like Filebeat, Fluentd, or rsyslog to ship logs to Elasticsearch, Splunk, or a SIEM system for analysis, alerting, and long-term retention.

- pgAudit writes structured entries to PostgreSQL log
- Configure log format: csvlog or jsonlog (PG 15+)
- Ship logs with Filebeat / Fluentd / rsyslog
- Store in Elasticsearch / Splunk / SIEM
- Create dashboards for audit visibility
- Set alerts for suspicious activity
- Retain logs per compliance requirements
- Review periodically for auditors

### pgAudit Best Practices
A beginner trap — enabling pgaudit.log = 'all' on a busy production server. This logs every single statement including SELECT queries, which can generate gigabytes of logs per day and impact performance. Start with 'ddl, role' globally and use object audit for specific sensitive tables.

| Do This | Avoid This |
| :--- | :--- |
| Start with 'ddl, role' globally | pgaudit.log = 'all' on busy servers |
| Use object audit for sensitive tables | Logging parameters with sensitive data |
| Disable catalog logging (noise) | Storing audit logs only locally |
| Set per-role audit levels | Forgetting to rotate log files |
| Ship logs to centralized system | Auditing every table equally |
| Monitor log volume and disk usage | Ignoring log volume growth |

### pgAudit Compliance Mapping
Here is a compliance mapping. GDPR requires tracking who accessed personal data — use object audit on PII tables. HIPAA requires audit trails for healthcare data — audit all operations on patient tables. SOX requires tracking financial data changes — audit WRITE on financial tables. PCI-DSS requires monitoring access to cardholder data — audit SELECT and WRITE on payment tables.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here** | a compliance mapping |
| **GDPR** | tracking who accessed personal data — use object audit on PII tables |
| **HIPAA** | audit trails for healthcare data — audit all operations on patient tables |
| **PCI-DSS** | monitoring access to cardholder data — audit SELECT and WRITE on payment tables |


---

## 3. Hands-On Commands & psql Output

### Installing pgAudit
**Explanation:** Install pgAudit. It requires shared_preload_libraries and a restart — it hooks deep into the PostgreSQL executor to capture statement details.

```sql
postgres=# -- 1. Install the package:
postgres=# -- Debian/Ubuntu:
postgres=# --   sudo apt install postgresql-16-pgaudit
postgres=# -- RHEL/Rocky:
postgres=# --   sudo dnf install pgaudit_16
postgres=# -- 2. Edit postgresql.conf:
postgres=# --   shared_preload_libraries = 'pgaudit'
postgres=# -- 3. Restart PostgreSQL:
postgres=# --   sudo systemctl restart postgresql-16
postgres=# -- 4. Create extension:
postgres=# CREATE EXTENSION pgaudit;
postgres=# -- Verify:
\dx pgaudit
  Name   | Version |  Schema  |    Description
postgres=# ---------+---------+----------+------------------
 pgaudit | 16.0    | public   | provides auditing
         |         |          | functionality
postgres=# SHOW shared_preload_libraries;
postgres=# -- pgaudit
```

### Session Audit Logging — pgaudit.log
**Explanation:** Configure session audit logging with pgaudit.log. Set it to the statement classes you want to audit. READ captures all SELECT statements. WRITE captures INSERT, UPDATE, DELETE. DDL captures CREATE, ALTER, DROP. You can combine multiple classes.

```sql
postgres=# -- Audit DDL and WRITE operations:
postgres=# ALTER SYSTEM SET pgaudit.log = 'ddl, write';
postgres=# SELECT pg_reload_conf();
postgres=# -- Now every DDL and DML is logged:
postgres=# CREATE TABLE customers (
    id serial PRIMARY KEY,
    name text,
    email text
);
postgres=# -- LOG: AUDIT: SESSION,1,1,DDL,CREATE TABLE,,,...
postgres=# INSERT INTO customers (name, email)
postgres-# VALUES ('Alice', 'alice@example.com');
postgres=# -- LOG: AUDIT: SESSION,2,1,WRITE,INSERT,,,...
postgres=# -- Audit everything (high volume!):
postgres=# ALTER SYSTEM SET pgaudit.log = 'all';
postgres=# -- Or be selective:
postgres=# ALTER SYSTEM SET pgaudit.log = 'read, ddl';
postgres=# -- Only audit SELECT and schema changes
```

### Object Audit Logging — Targeted Tables
**Explanation:** Object audit logging is more precise. Create an audit role, grant it permissions on the specific tables you want to audit, and set pgaudit.role to that role. Only operations on those granted tables are logged — much less noise than session logging.

```sql
postgres=# -- Create an audit role (no login needed):
postgres=# CREATE ROLE auditor NOLOGIN;
postgres=# -- Set pgaudit.role:
postgres=# ALTER SYSTEM SET pgaudit.role = 'auditor';
postgres=# SELECT pg_reload_conf();
postgres=# -- Grant audit permissions on sensitive tables:
postgres=# GRANT SELECT ON customers TO auditor;
postgres=# GRANT INSERT, UPDATE, DELETE ON customers TO auditor;
postgres=# -- Now ALL operations on 'customers' are audited
postgres=# -- Only audit SELECT on financial data:
postgres=# GRANT SELECT ON financial_records TO auditor;
postgres=# -- INSERTs on financial_records are NOT audited
postgres=# -- Test:
postgres=# SELECT * FROM customers;
postgres=# -- LOG: AUDIT: OBJECT,1,1,READ,SELECT,TABLE,
postgres=# --   public.customers,SELECT * FROM customers
postgres=# SELECT * FROM products;  -- no audit role grant
postgres=# -- (not logged — products is not audited)
```

### Understanding Audit Log Format
**Explanation:** The audit log entries have a structured format. Each entry includes the audit type — session or object — a statement ID, a substatement ID, the class, the command, the object type, the object name, and the full SQL statement. This makes it easy to parse and analyze with log management tools.

```sql
postgres=# -- Example log entry:
postgres=# -- LOG: AUDIT: SESSION,1,1,WRITE,INSERT,,
postgres=# --   "INSERT INTO customers (name,email)
postgres=# --    VALUES ('Alice','alice@example.com')"
postgres=# -- Format breakdown:
postgres=# -- AUDIT: SESSION   — audit type (SESSION or OBJECT)
postgres=# -- 1                — statement ID
postgres=# -- 1                — substatement ID
postgres=# -- WRITE            — class
postgres=# -- INSERT           — command
postgres=# -- (empty)          — object type (TABLE for object audit)
postgres=# -- (empty)          — object name (table for object audit)
postgres=# -- "INSERT INTO..." — the full SQL statement
postgres=# -- Object audit adds table details:
postgres=# -- LOG: AUDIT: OBJECT,3,1,READ,SELECT,TABLE,
postgres=# --   public.customers,
postgres=# --   "SELECT * FROM customers WHERE id = 1"
```

### Per-User Audit Configuration
**Explanation:** Per-user audit settings. You can configure pgaudit.log differently for different roles. This way, you audit everything for admin users but only DDL for regular application users — reducing log volume while maintaining compliance.

```sql
postgres=# -- Audit everything for admin users:
postgres=# ALTER ROLE admin_user SET pgaudit.log = 'all';
postgres=# -- Only audit DDL for app users:
postgres=# ALTER ROLE app_user SET pgaudit.log = 'ddl';
postgres=# -- Audit reads + writes for analyst role:
postgres=# ALTER ROLE analyst SET pgaudit.log = 'read, write';
postgres=# -- No session audit for monitoring role:
postgres=# ALTER ROLE monitoring SET pgaudit.log = 'none';
postgres=# -- Check a role's setting:
postgres=# SELECT rolname,
    (SELECT setting FROM pg_db_role_setting
postgres-# WHERE setdatabase = 0
postgres-# AND setrole = pg_roles.oid) AS audit_settings
postgres-# FROM pg_roles
postgres-# WHERE rolname IN ('admin_user', 'app_user');
```

### Production Configuration
**Explanation:** A production-ready configuration. Audit DDL and role changes globally, use object audit for sensitive tables, disable catalog logging to reduce noise, and enable log_parameter only if compliance requires actual values — be careful with privacy.

```sql
postgres=# -- Production pgAudit configuration:
postgres=# -- Global: audit schema changes and role modifications
postgres=# ALTER SYSTEM SET pgaudit.log = 'ddl, role';
postgres=# -- Object audit for sensitive tables:
postgres=# ALTER SYSTEM SET pgaudit.role = 'auditor';
postgres=# -- Reduce noise — skip catalog queries:
postgres=# ALTER SYSTEM SET pgaudit.log_catalog = off;
postgres=# -- Log parameter values (careful — may contain PII!):
postgres=# ALTER SYSTEM SET pgaudit.log_parameter = on;
postgres=# -- Avoid duplicate SQL in sub-statements:
postgres=# ALTER SYSTEM SET pgaudit.log_statement_once = on;
postgres=# -- Apply:
postgres=# SELECT pg_reload_conf();
postgres=# -- Then grant auditor role on sensitive tables:
postgres=# GRANT ALL ON customers TO auditor;
postgres=# GRANT ALL ON financial_records TO auditor;
postgres=# GRANT SELECT ON medical_records TO auditor;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. pgAudit provides compliance-grade audit logging for PostgreSQL. Session logging captures statement classes globally — READ, WRITE, DDL, ROLE. Object logging targets specific tables through a dedicated audit role. Configure per-user with ALTER ROLE SET. Disable catalog logging to reduce noise. Ship logs to a centralized system for analysis and retention. Start with ddl and role globally, add object audit for sensitive tables. That completes Phase 26 — Extensions. In the next phase, we move to Performance Tuning.

- **Compliance-grade audit logging extension**
- **Session logging: pgaudit.log = 'ddl, write'**
- **Object logging: pgaudit.role + GRANT on tables**
- **Statement classes: READ, WRITE, DDL, ROLE, FUNCTION**
- **Per-user: ALTER ROLE SET pgaudit.log**
- **Disable pgaudit.log_catalog to reduce noise**
- **Ship logs to Elasticsearch/Splunk/SIEM**
- **Start targeted — don't audit 'all' on busy servers**
- **Maps to GDPR, HIPAA, SOX, PCI-DSS**
- **Phase 26 Complete!**
- **Next Phase: Performance Tuning**


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
