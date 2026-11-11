-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Liquibase & Flyway — Schema Migrations (Classes 274-275)
-- Phase 30: Integration with Other Technologies
-- ============================================================

-- ============================================================
-- 1. WHY MIGRATION TOOLS?
-- ============================================================

-- Without: manual ALTER TABLE, no history, staging ≠ production
-- With: versioned files, source control, repeatable, rollbackable

-- Both Flyway and Liquibase:
--   1. Read migration files from a directory
--   2. Check a tracking table for what is already applied
--   3. Apply only new migrations in order
--   4. Record each applied migration with a checksum

-- ============================================================
-- 2. FLYWAY — SETUP
-- ============================================================

-- Install options:
-- Docker:  docker run flyway/flyway migrate
-- Maven:   mvn flyway:migrate
-- Gradle:  gradle flywayMigrate
-- CLI:     download from https://flywaydb.org

-- flyway.conf:
-- flyway.url=jdbc:postgresql://localhost:5432/myapp
-- flyway.user=app_user
-- flyway.password=secret
-- flyway.locations=filesystem:./sql

-- ============================================================
-- 3. FLYWAY — MIGRATION FILE NAMING
-- ============================================================

-- V{version}__{description}.sql   → Versioned (applied once)
-- R__{description}.sql            → Repeatable (re-applied on change)

-- Examples:
-- V1__create_users_table.sql
-- V2__add_phone_column.sql
-- V3__create_orders_table.sql
-- R__create_user_stats_view.sql

-- ============================================================
-- 4. FLYWAY — EXAMPLE MIGRATIONS
-- ============================================================

-- V1__create_users_table.sql:
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- V2__add_phone_column.sql:
ALTER TABLE users ADD COLUMN phone TEXT;

-- V3__create_orders_table.sql:
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    total NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_orders_user ON orders(user_id);

-- R__create_user_stats_view.sql:
CREATE OR REPLACE VIEW user_stats AS
SELECT u.id, u.name,
  count(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.name;

-- ============================================================
-- 5. FLYWAY — COMMANDS
-- ============================================================

-- flyway migrate       → Apply pending migrations
-- flyway info          → Show migration status
-- flyway validate      → Check files match applied
-- flyway clean         → DROP all objects (DEV ONLY!)
-- flyway repair        → Fix tracking table
-- flyway baseline      → Mark existing DB as version

-- Check tracking table:
SELECT installed_rank, version, description,
  type, checksum, installed_on, success
FROM flyway_schema_history
ORDER BY installed_rank;

-- ============================================================
-- 6. LIQUIBASE — SETUP
-- ============================================================

-- Install: download from https://www.liquibase.com/download

-- liquibase.properties:
-- url=jdbc:postgresql://localhost:5432/myapp
-- username=app_user
-- password=secret
-- changeLogFile=changelog.xml

-- ============================================================
-- 7. LIQUIBASE — CHANGELOG EXAMPLE (XML)
-- ============================================================

-- changelog.xml:
-- <databaseChangeLog ...>
--
--   <changeSet id="1" author="dev">
--     <createTable tableName="users">
--       <column name="id" type="serial">
--         <constraints primaryKey="true"/>
--       </column>
--       <column name="name" type="text">
--         <constraints nullable="false"/>
--       </column>
--       <column name="email" type="text">
--         <constraints unique="true"/>
--       </column>
--     </createTable>
--   </changeSet>
--
--   <changeSet id="2" author="dev">
--     <addColumn tableName="users">
--       <column name="phone" type="text"/>
--     </addColumn>
--   </changeSet>
--
--   <changeSet id="3" author="dev">
--     <sql>
--       CREATE INDEX idx_users_email ON users(email);
--     </sql>
--     <rollback>
--       DROP INDEX idx_users_email;
--     </rollback>
--   </changeSet>
--
-- </databaseChangeLog>

-- ============================================================
-- 8. LIQUIBASE — COMMANDS
-- ============================================================

-- liquibase update          → Apply pending changesets
-- liquibase status          → Show pending changesets
-- liquibase rollbackCount 1 → Undo last N changesets
-- liquibase diff            → Compare two databases
-- liquibase generateChangeLog → Create from existing DB
-- liquibase validate        → Check changelog syntax

-- Check tracking table:
SELECT id, author, filename, dateexecuted,
  orderexecuted, md5sum
FROM databasechangelog
ORDER BY orderexecuted;

-- ============================================================
-- 9. FLYWAY vs LIQUIBASE COMPARISON
-- ============================================================

-- Feature         | Flyway           | Liquibase
-- ----------------|------------------|------------------
-- Format          | Plain SQL        | XML/YAML/JSON/SQL
-- DB-Agnostic     | No (SQL per DB)  | Yes (XML→SQL)
-- Rollback        | Manual undo SQL  | Auto from XML
-- Diff Tool       | No               | Yes
-- Learning Curve  | Low              | Medium
-- Tracking Table  | flyway_schema_h  | databasechangelog
-- Best For        | PG-only projects | Multi-DB envs
-- License         | Community+Teams  | Community+Pro

-- ============================================================
-- 10. BEST PRACTICES
-- ============================================================

-- 1. One change per migration file
-- 2. Never edit applied migrations (checksum mismatch)
-- 3. Test migrations against copy of production data
-- 4. Make changes backward-compatible:
--    Step 1: ADD COLUMN phone TEXT;          (nullable)
--    Step 2: UPDATE users SET phone = '...'; (backfill)
--    Step 3: ALTER COLUMN phone SET NOT NULL; (constraint)
-- 5. Include rollback SQL in every migration
-- 6. Run validate in CI, migrate on deploy
-- 7. Use CREATE INDEX CONCURRENTLY for large tables
-- 8. Set flyway.cleanDisabled=true in production

-- ============================================================
-- 11. ORM MIGRATION TOOLS
-- ============================================================

-- Django:      python manage.py makemigrations + migrate
-- SQLAlchemy:  Alembic (alembic revision + upgrade)
-- Prisma:      npx prisma migrate dev
-- EF Core:     dotnet ef migrations add + database update
-- Hibernate:   Flyway or Liquibase (no built-in)
-- GORM:        AutoMigrate() (dev only, not production)

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Flyway: create 3 SQL migration files.
--    Run: flyway migrate, flyway info.
--    Verify flyway_schema_history table.

-- 2. Liquibase: same 3 changes as XML changesets.
--    Run: liquibase update, liquibase status.
--    Compare with Flyway experience.

-- 3. Edit an applied migration. Run migrate again.
--    Observe checksum error. Fix with repair/rollback.

-- 4. Write rollback SQL for each migration.
--    Test: flyway undo or liquibase rollbackCount 1.

-- 5. Integrate into CI/CD: add validate step to build pipeline.
