# Liquibase & Flyway — Database Schema Migration Tools for PostgreSQL
**Series:** PostgreSQL Mastery | **Phase:** 30 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we cover the two most popular database migration tools — Liquibase and Flyway. These tools track and apply schema changes to PostgreSQL in a controlled, versioned, and repeatable way — essential for team development and production deployments.


---

## 2. Core Technical Concepts & Mechanisms

### Comparison
Without migration tools, schema changes are chaos. A developer adds a column locally but forgets to tell the team. Someone runs ALTER TABLE in production manually and there is no record. Staging and production drift apart. Rollbacks are impossible because nobody tracked what changed. Migration tools solve this by turning every schema change into a versioned file that is tracked in source control, applied automatically, and reversible.

| Without Migration Tools | With Migration Tools |
| :--- | :--- |
| Manual ALTER TABLE in production | Every change is a versioned file |
| No record of what changed when | Full history in source control |
| Staging ≠ Production schema | Same migrations → same schema |
| Rollback = guess and pray | Rollback = run the undo script |
| Team conflicts on schema | Team reviews changes in PRs |

### How Schema Migration Works
Both Liquibase and Flyway follow the same basic pattern. You write migration files — each one is a numbered SQL script or XML file that describes a schema change. The tool keeps a tracking table in your database that records which migrations have been applied. When you run the migrate command, it compares the tracking table to your migration files and applies only the new ones, in order.

- 1. Write Migration File -- V001__create_users.sql — CREATE TABLE users (id SERIAL, name TEXT, email TEXT);
- 2. Run Migrate Command -- Tool reads tracking table → finds V001 not applied → executes the SQL.
- 3. Tracking Table Updated -- Tool records: V001 applied at 2026-11-05 10:00:00, checksum: abc123.
- 4. Next Migration -- V002__add_phone_column.sql — ALTER TABLE users ADD COLUMN phone TEXT;
- 5. Run Again -- Tool sees V001 done, V002 pending → applies only V002. Idempotent.
- 6. All Environments Match -- Dev, staging, production all run same migrations → identical schema.

### Flyway Commands
Flyway provides several commands. Migrate applies pending migrations. Info shows the status of all migrations — which are applied, which are pending. Validate checks that applied migrations have not been modified — this catches someone editing a migration file after it was applied. Clean drops all objects in the schema — never use this in production. Repair fixes the tracking table if a migration failed halfway.

| Term | Meaning / Explanation |
| :--- | :--- |
| **flyway migrate** | What It Does: Apply pending migrations | When to Use: Every deployment |
| **flyway info** | What It Does: Show migration status | When to Use: Check what is applied/pending |
| **flyway validate** | What It Does: Check files match applied | When to Use: CI/CD pipeline validation |
| **flyway clean** | What It Does: DROP all objects | When to Use: Dev only — NEVER production! |
| **flyway repair** | What It Does: Fix failed migration entries | When to Use: After a migration fails halfway |
| **flyway baseline** | What It Does: Mark existing DB as V1 | When to Use: Adopting Flyway on existing DB |

### Comparison
If this migration tools guide is saving your team from schema chaos, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All migration examples from this video |
| Every donation helps! | Practice exercises included |

### Liquibase Commands
Liquibase provides commands similar to Flyway. Update applies pending changesets. Status shows what is pending. Rollback reverts changes — by count, date, or tag. Diff compares two databases and generates a changelog. GenerateChangeLog creates a changelog from an existing database — useful when adopting Liquibase on an existing project.

| Term | Meaning / Explanation |
| :--- | :--- |
| **liquibase update** | What It Does: Apply pending changesets | When to Use: Every deployment |
| **liquibase status** | What It Does: Show pending changesets | When to Use: Check what will change |
| **liquibase rollbackCount 1** | What It Does: Undo last N changesets | When to Use: Fix a bad migration |
| **liquibase diff** | What It Does: Compare two databases | When to Use: Find schema drift |
| **liquibase generateChangeLog** | What It Does: Create changelog from DB | When to Use: Adopt on existing DB |
| **liquibase validate** | What It Does: Check changelog syntax | When to Use: CI/CD validation |

### Flyway vs Liquibase
Here is the direct comparison. Flyway is simpler — plain SQL files, convention-based naming, fewer concepts. Liquibase is more powerful — XML changesets, database-agnostic, built-in rollback generation, diff command. For PostgreSQL-only projects, Flyway is usually the better choice — simpler and faster to adopt. For multi-database environments or teams that need automatic rollback, Liquibase is stronger.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Migration Format** | Flyway: Plain SQL files | Liquibase: XML/YAML/JSON/SQL |
| **DB-Agnostic** | Flyway: No (SQL per DB) | Liquibase: Yes (XML generates SQL) |
| **Rollback** | Flyway: Manual (write undo SQL) | Liquibase: Auto-generated from XML |
| **Diff Tool** | Flyway: No | Liquibase: Yes (compare 2 databases) |
| **Learning Curve** | Flyway: Low (just SQL) | Liquibase: Medium (XML concepts) |
| **Tracking Table** | Flyway: flyway_schema_history | Liquibase: databasechangelog |
| **Best For** | Flyway: PG-only projects | Liquibase: Multi-DB environments |
| **License** | Flyway: Community + Teams | Liquibase: Community + Pro |

### Schema Migration Best Practices
Here are the best practices for schema migrations regardless of which tool you use. First, one change per migration file — do not put CREATE TABLE and ALTER TABLE in the same file. Second, never edit a migration that has been applied — create a new migration instead. Third, test migrations against a copy of production data. Fourth, make migrations backward-compatible — add columns as nullable first, then backfill, then add the constraint.

- One Change Per File -- Each migration does one thing. Easier to review, rollback, and debug.
- Never Edit Applied Migrations -- Both tools detect modified files and fail. Always create a new migration.
- Test Against Prod Data Copy -- Schema changes may fail on real data. Test with a pg_dump of production.
- Backward-Compatible Changes -- ADD COLUMN as nullable first. Backfill data. ADD NOT NULL constraint separately.
- Include Rollback SQL -- Every migration should have an undo script. Test the rollback too.
- Run in CI/CD Pipeline -- flyway validate or liquibase validate in CI. Migrate automatically on deploy.

### Beginner Traps
Watch out for these traps. First, never run flyway clean or liquibase dropAll in production — it drops everything. Use environment checks to prevent this. Second, do not put long-running migrations in a single transaction — ALTER TABLE on a large table locks it. Use CREATE INDEX CONCURRENTLY instead. Third, both tools store checksums — if you edit an applied migration file, the next run will fail. Fourth, version numbers must be unique and sequential — gaps are fine, duplicates are not.

- NEVER clean/dropAll in prod -- flyway clean drops ALL objects. Set flyway.cleanDisabled=true in production.
- Large table migrations -- ALTER TABLE locks the table. Use CREATE INDEX CONCURRENTLY. Break into steps.
- Don't edit applied migrations -- Checksum mismatch = migration fails. Create a new migration instead.
- Version numbers -- Must be unique. Gaps are OK (V1, V3, V5). Duplicates cause errors.
- Test rollbacks -- A rollback you never tested is a rollback that won't work. Test in staging.

### Practice Exercises
Here are your practice exercises. First, install Flyway and create three migration files — create users table, add phone column, create orders table. Run flyway migrate and flyway info. Second, install Liquibase and create the same three changes as changesets. Run liquibase update and liquibase status. Third, try editing an applied migration and see what happens when you run migrate again. Fourth, write rollback scripts for each migration and test them.

- Exercise 1 -- Flyway: create 3 SQL migrations (users table, phone column, orders table). Run migrate + info.
- Exercise 2 -- Liquibase: same 3 changes as XML changesets. Run update + status. Compare with Flyway.
- Exercise 3 -- Edit an applied migration file. Run migrate. Observe the checksum error. Fix with repair.
- Exercise 4 -- Write rollback SQL for each migration. Test by running rollback commands.
- Exercise 5 -- Integrate Flyway or Liquibase into a CI/CD pipeline. Run validate on every build.


---

## 3. Hands-On Commands & psql Output

### Flyway — Install and Configure
**Explanation:** Let us start with Flyway. Flyway is simple — it uses plain SQL files with a naming convention. Files start with V for versioned migrations, followed by a version number, two underscores, and a description. Install Flyway via Docker, Maven, Gradle, or the standalone CLI. Configure the database URL and run flyway migrate.

```sql
# Install Flyway CLI
$ wget https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.10.0/flyway-commandline-10.10.0-linux-x64.tar.gz
$ tar xzf flyway-commandline-10.10.0-linux-x64.tar.gz

# flyway.conf
flyway.url=jdbc:postgresql://localhost:5432/myapp
flyway.user=app_user
flyway.password=secret
flyway.locations=filesystem:./sql

$ flyway migrate
Successfully applied 2 migrations (v1, v2)
```

### Flyway — Migration Files
**Explanation:** Flyway migration files are plain SQL. The naming convention is critical — V followed by a version number, two underscores, then a description. Flyway applies them in version order. Each file runs in a transaction by default. You can also write R files for repeatable migrations — like views or functions that are re-applied whenever they change.

```sql
-- sql/V1__create_users_table.sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- sql/V2__add_phone_column.sql
ALTER TABLE users
  ADD COLUMN phone TEXT;

-- sql/V3__create_orders_table.sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    total NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_orders_user
  ON orders(user_id);

-- sql/R__create_user_stats_view.sql
-- R = Repeatable (re-run when changed)
CREATE OR REPLACE VIEW user_stats AS
SELECT u.id, u.name,
  count(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.name;
```

### Liquibase — Install and Configure
**Explanation:** Now let us cover Liquibase. Unlike Flyway which uses plain SQL files, Liquibase uses a changelog — an XML, YAML, JSON, or SQL file that describes changes using Liquibase-specific elements called changesets. Each changeset has an author, an ID, and a set of changes. Liquibase can generate SQL for different databases from the same changelog — PostgreSQL, MySQL, Oracle — making it popular in multi-database environments.

```sql
# Install Liquibase
$ wget https://github.com/liquibase/liquibase/releases/download/v4.27.0/liquibase-4.27.0.tar.gz
$ tar xzf liquibase-4.27.0.tar.gz

# liquibase.properties
url=jdbc:postgresql://localhost:5432/myapp
username=app_user
password=secret
changeLogFile=changelog.xml

$ liquibase update
Liquibase: Update has been successful.
```

### Liquibase — changelog.xml
**Explanation:** A Liquibase changelog contains changesets. Each changeset describes one logical change — create a table, add a column, create an index. Liquibase supports both its own XML format and plain SQL. The XML format is database-agnostic — Liquibase generates the correct SQL for PostgreSQL, MySQL, or Oracle. For PostgreSQL-only projects, you can use the SQL format which is simpler and more readable.

```sql
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
  xmlns="http://www.liquibase.org/xml/ns"
  xmlns:xsi="http://www.w3.org/2001/"
  xsi:schemaLocation="http://...">

  <changeSet id="1" author="dev">
    <createTable tableName="users">
      <column name="id" type="serial">
        <constraints primaryKey="true"/>
      </column>
      <column name="name" type="text">
        <constraints nullable="false"/>
      </column>
      <column name="email" type="text">
        <constraints unique="true"/>
      </column>
    </createTable>
  </changeSet>

  <changeSet id="2" author="dev">
    <addColumn tableName="users">
      <column name="phone" type="text"/>
    </addColumn>
  </changeSet>

  <!-- SQL format also works -->
  <changeSet id="3" author="dev">
    <sql>
      CREATE INDEX idx_users_email
        ON users(email);
    </sql>
    <rollback>
      DROP INDEX idx_users_email;
    </rollback>
  </changeSet>
</databaseChangeLog>
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. First, never run flyway clean or liquibase dropAll in production — it drops everything. Use environment checks to prevent this. Second, do not put long-running migrations in a single transaction — ALTER TABLE on a large table locks it. Use CREATE INDEX CONCURRENTLY instead. Third, both tools store checksums — if you edit an applied migration file, the next run will fail. Fourth, version numbers must be unique and sequential — gaps are fine, duplicates are not.

- NEVER clean/dropAll in prod -- flyway clean drops ALL objects. Set flyway.cleanDisabled=true in production.
- Large table migrations -- ALTER TABLE locks the table. Use CREATE INDEX CONCURRENTLY. Break into steps.
- Don't edit applied migrations -- Checksum mismatch = migration fails. Create a new migration instead.
- Version numbers -- Must be unique. Gaps are OK (V1, V3, V5). Duplicates cause errors.
- Test rollbacks -- A rollback you never tested is a rollback that won't work. Test in staging.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Migration tools turn schema changes into versioned files tracked in source control. Flyway uses plain SQL files with convention-based naming — simple and fast for PostgreSQL-only projects. Liquibase uses changelogs with changesets — more powerful, database-agnostic, with auto-rollback. Both track applied migrations in a database table. Best practice: one change per file, never edit applied migrations, test against production data, and run in CI/CD.

- **Migration tools: versioned schema changes tracked in source control**
- **Flyway: plain SQL files, V1__name.sql convention, simple**
- **Liquibase: XML/YAML/SQL changesets, database-agnostic, auto-rollback**
- **Both track applied migrations in a database table (checksum-verified)**
- **Never edit applied migrations — create new ones instead**
- **One change per migration file for easy review and rollback**
- **Run validate in CI, migrate on deploy, test rollbacks in staging**


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
