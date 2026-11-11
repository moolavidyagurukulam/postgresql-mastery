-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Go & Kafka CDC with PostgreSQL (Classes 272-273)
-- Phase 30: Integration with Other Technologies
-- ============================================================

-- ============================================================
-- 1. GO — pgx DRIVER
-- ============================================================

-- Install:
-- go get github.com/jackc/pgx/v5
-- go get github.com/jackc/pgx/v5/pgxpool

-- Connection pool (recommended for production):
-- pool, err := pgxpool.New(ctx,
--   "postgres://app_user:secret@localhost:5432/myapp")
-- defer pool.Close()

-- INSERT (parameterized):
-- var id int
-- err = pool.QueryRow(ctx,
--   "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id",
--   "Alice", "alice@example.com",
-- ).Scan(&id)

-- SELECT:
-- rows, err := pool.Query(ctx, "SELECT id, name FROM users")
-- for rows.Next() {
--   var uid int; var name string
--   rows.Scan(&uid, &name)
-- }
-- rows.Close()

-- UPDATE:
-- _, err = pool.Exec(ctx,
--   "UPDATE users SET name = $1 WHERE id = $2",
--   "Alice Smith", 1)

-- DELETE:
-- _, err = pool.Exec(ctx,
--   "DELETE FROM users WHERE id = $1", 1)

-- ============================================================
-- 2. GO — GORM ORM
-- ============================================================

-- Install:
-- go get gorm.io/gorm
-- go get gorm.io/driver/postgres

-- type User struct {
--   ID    uint   `gorm:"primaryKey"`
--   Name  string `gorm:"not null"`
--   Email string `gorm:"uniqueIndex"`
-- }
--
-- dsn := "host=localhost port=5432 user=app_user " +
--   "password=secret dbname=myapp sslmode=disable"
-- db, _ := gorm.Open(postgres.Open(dsn), &gorm.Config{})
-- db.AutoMigrate(&User{})
--
-- db.Create(&User{Name: "Bob", Email: "bob@ex.com"})
-- var users []User
-- db.Where("name = ?", "Bob").Find(&users)
-- db.Model(&User{}).Where("id = ?", 1).Update("name", "Bob Smith")
-- db.Delete(&User{}, 1)

-- ============================================================
-- 3. GO DRIVER COMPARISON
-- ============================================================

-- pgx       → Recommended. Pure Go. Fast. PG-specific features.
-- pgxpool   → Connection pool built into pgx. Always use.
-- lib/pq    → Older driver. Maintenance mode. Migrate to pgx.
-- GORM      → Full ORM. CRUD apps, auto-migration.
-- sqlx      → Extensions to database/sql. Named params, scanning.
-- sqlc      → Code generator. Write SQL → Go code. Type-safe.

-- ============================================================
-- 4. CHANGE DATA CAPTURE (CDC) — SETUP
-- ============================================================

-- Step 1: Enable logical replication
ALTER SYSTEM SET wal_level = 'logical';
-- Restart PostgreSQL required

-- Verify:
SHOW wal_level;
-- Should show: logical

-- Step 2: Grant replication to CDC user
ALTER USER app_user REPLICATION;

-- Step 3: Create publication (optional, Debezium can do this)
CREATE PUBLICATION myapp_pub FOR ALL TABLES;

-- ============================================================
-- 5. DOCKER COMPOSE — KAFKA + DEBEZIUM
-- ============================================================

-- Save as docker-compose.yml:
--
-- version: '3'
-- services:
--   zookeeper:
--     image: confluentinc/cp-zookeeper:7.6.0
--     environment:
--       ZOOKEEPER_CLIENT_PORT: 2181
--
--   kafka:
--     image: confluentinc/cp-kafka:7.6.0
--     depends_on: [zookeeper]
--     ports: ["9092:9092"]
--     environment:
--       KAFKA_BROKER_ID: 1
--       KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
--       KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
--       KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
--
--   connect:
--     image: debezium/connect:2.6
--     depends_on: [kafka]
--     ports: ["8083:8083"]
--     environment:
--       BOOTSTRAP_SERVERS: kafka:9092
--       GROUP_ID: 1
--       CONFIG_STORAGE_TOPIC: connect_configs
--       OFFSET_STORAGE_TOPIC: connect_offsets
--       STATUS_STORAGE_TOPIC: connect_statuses

-- Start: docker-compose up -d

-- ============================================================
-- 6. REGISTER DEBEZIUM CONNECTOR
-- ============================================================

-- curl -X POST http://localhost:8083/connectors \
--   -H 'Content-Type: application/json' \
--   -d '{
--     "name": "pg-connector",
--     "config": {
--       "connector.class":
--         "io.debezium.connector.postgresql.PostgresConnector",
--       "database.hostname": "host.docker.internal",
--       "database.port": "5432",
--       "database.user": "app_user",
--       "database.password": "secret",
--       "database.dbname": "myapp",
--       "topic.prefix": "myapp",
--       "plugin.name": "pgoutput",
--       "slot.name": "debezium_slot",
--       "publication.name": "myapp_pub"
--     }
--   }'

-- Check connector status:
-- curl http://localhost:8083/connectors/pg-connector/status

-- ============================================================
-- 7. CDC EVENT FORMAT
-- ============================================================

-- INSERT → op: "c" (create)
-- {
--   "payload": {
--     "before": null,
--     "after": {"id": 1, "name": "Alice", "email": "alice@example.com"},
--     "op": "c",
--     "ts_ms": 1730000000000
--   }
-- }

-- UPDATE → op: "u" (update)
-- {
--   "payload": {
--     "before": {"id": 1, "name": "Alice", "email": "alice@example.com"},
--     "after": {"id": 1, "name": "Alice Smith", "email": "alice@example.com"},
--     "op": "u"
--   }
-- }

-- DELETE → op: "d" (delete)
-- {
--   "payload": {
--     "before": {"id": 1, "name": "Alice Smith", "email": "alice@example.com"},
--     "after": null,
--     "op": "d"
--   }
-- }

-- ============================================================
-- 8. MONITORING CDC
-- ============================================================

-- Check replication slots:
SELECT slot_name, plugin, slot_type,
  active, confirmed_flush_lsn
FROM pg_replication_slots;

-- Check WAL size (monitor for growth):
SELECT pg_size_pretty(
  pg_wal_lsn_diff(pg_current_wal_lsn(),
    confirmed_flush_lsn)
) AS lag
FROM pg_replication_slots
WHERE slot_name = 'debezium_slot';

-- Drop inactive slot (if Debezium removed):
-- SELECT pg_drop_replication_slot('debezium_slot');
-- WARNING: Only drop if connector is permanently removed!

-- ============================================================
-- 9. CDC vs POLLING vs TRIGGERS
-- ============================================================

-- CDC (Debezium): sub-second latency, zero write impact,
--   never misses changes, requires Kafka stack
-- Polling: seconds-to-minutes latency, zero write impact,
--   can miss changes between polls, simple query
-- Triggers: synchronous latency on every write,
--   never misses, tightly coupled, PL/pgSQL code

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Go + pgxpool: connect, create table, insert, query.
--    Use $1, $2 parameterized queries.

-- 2. Rewrite Exercise 1 with GORM. Compare code.

-- 3. Docker Compose: start Kafka + Debezium.
--    Register PG connector. INSERT a row in psql.
--    Read the CDC event from Kafka topic.

-- 4. Write a Kafka consumer (any language) that reads
--    CDC events and prints them.

-- 5. Monitor: SELECT * FROM pg_replication_slots;
--    Check active status and WAL lag.
