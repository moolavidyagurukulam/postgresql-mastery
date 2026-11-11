-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Python & Java with PostgreSQL (Classes 268-269)
-- Phase 30: Integration with Other Technologies
-- ============================================================

-- ============================================================
-- 1. TEST DATABASE SETUP
-- ============================================================

CREATE DATABASE myapp;
\c myapp

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE USER app_user WITH PASSWORD 'secret';
GRANT ALL PRIVILEGES ON DATABASE myapp TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- ============================================================
-- 2. PYTHON — psycopg2 (Standard Driver)
-- ============================================================

-- Install:
-- pip install psycopg2-binary   (development)
-- pip install psycopg2           (production, compiles from source)

-- Basic connection and CRUD:
--
-- import psycopg2
--
-- conn = psycopg2.connect(
--     host='localhost',
--     port=5432,
--     dbname='myapp',
--     user='app_user',
--     password='secret'
-- )
--
-- # Context manager: auto-commit on success, rollback on error
-- with conn:
--     with conn.cursor() as cur:
--         # INSERT (parameterized — NEVER concatenate!)
--         cur.execute(
--             "INSERT INTO users (name, email) "
--             "VALUES (%s, %s) RETURNING id",
--             ('Alice', 'alice@example.com')
--         )
--         user_id = cur.fetchone()[0]
--
--         # SELECT
--         cur.execute("SELECT * FROM users WHERE id = %s", (user_id,))
--         row = cur.fetchone()
--
--         # UPDATE
--         cur.execute(
--             "UPDATE users SET name = %s WHERE id = %s",
--             ('Alice Smith', user_id)
--         )
--
--         # DELETE
--         cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
--
-- conn.close()

-- ============================================================
-- 3. PYTHON — Connection Pooling
-- ============================================================

-- from psycopg2 import pool
--
-- db_pool = pool.ThreadedConnectionPool(
--     minconn=2,
--     maxconn=10,
--     host='localhost',
--     port=5432,
--     dbname='myapp',
--     user='app_user',
--     password='secret'
-- )
--
-- def get_users():
--     conn = db_pool.getconn()
--     try:
--         with conn.cursor() as cur:
--             cur.execute('SELECT id, name, email FROM users')
--             return cur.fetchall()
--     finally:
--         db_pool.putconn(conn)  # Return to pool, don't close!
--
-- # On shutdown:
-- db_pool.closeall()

-- ============================================================
-- 4. PYTHON — SQLAlchemy ORM
-- ============================================================

-- pip install sqlalchemy

-- from sqlalchemy import create_engine, Column, Integer, String
-- from sqlalchemy.orm import declarative_base, sessionmaker
--
-- engine = create_engine(
--     'postgresql://app_user:secret@localhost:5432/myapp',
--     pool_size=5,
--     max_overflow=10
-- )
--
-- Base = declarative_base()
--
-- class User(Base):
--     __tablename__ = 'users'
--     id = Column(Integer, primary_key=True)
--     name = Column(String, nullable=False)
--     email = Column(String, unique=True)
--
-- Base.metadata.create_all(engine)
--
-- Session = sessionmaker(bind=engine)
-- with Session() as session:
--     # Create
--     user = User(name='Bob', email='bob@example.com')
--     session.add(user)
--     session.commit()
--
--     # Read
--     users = session.query(User).filter_by(name='Bob').all()
--
--     # Update
--     user.name = 'Bob Smith'
--     session.commit()
--
--     # Delete
--     session.delete(user)
--     session.commit()

-- ============================================================
-- 5. PYTHON — SQL INJECTION DEMO (TEST ONLY!)
-- ============================================================

-- WRONG (vulnerable):
-- name = "'; DROP TABLE users; --"
-- cur.execute(f"SELECT * FROM users WHERE name='{name}'")
-- # This DROPS your users table!

-- CORRECT (safe):
-- name = "'; DROP TABLE users; --"
-- cur.execute("SELECT * FROM users WHERE name = %s", (name,))
-- # psycopg2 escapes the input — returns 0 rows safely

-- ============================================================
-- 6. JAVA — JDBC Driver
-- ============================================================

-- Maven dependency (pom.xml):
-- <dependency>
--     <groupId>org.postgresql</groupId>
--     <artifactId>postgresql</artifactId>
--     <version>42.7.3</version>
-- </dependency>

-- Gradle:
-- implementation 'org.postgresql:postgresql:42.7.3'

-- Basic JDBC connection:
--
-- String url = "jdbc:postgresql://localhost:5432/myapp";
-- try (Connection conn = DriverManager.getConnection(url, "app_user", "secret")) {
--     // INSERT (parameterized)
--     PreparedStatement ps = conn.prepareStatement(
--         "INSERT INTO users (name, email) VALUES (?, ?)",
--         Statement.RETURN_GENERATED_KEYS
--     );
--     ps.setString(1, "Charlie");
--     ps.setString(2, "charlie@example.com");
--     ps.executeUpdate();
--
--     ResultSet keys = ps.getGeneratedKeys();
--     if (keys.next()) {
--         long userId = keys.getLong(1);
--     }
--
--     // SELECT
--     PreparedStatement query = conn.prepareStatement(
--         "SELECT id, name, email FROM users WHERE name = ?"
--     );
--     query.setString(1, "Charlie");
--     ResultSet rs = query.executeQuery();
--     while (rs.next()) {
--         System.out.println(rs.getLong("id") + ": " + rs.getString("name"));
--     }
-- }

-- ============================================================
-- 7. JAVA — HikariCP Connection Pool
-- ============================================================

-- Maven:
-- <dependency>
--     <groupId>com.zaxxer</groupId>
--     <artifactId>HikariCP</artifactId>
--     <version>5.1.0</version>
-- </dependency>

-- HikariConfig config = new HikariConfig();
-- config.setJdbcUrl("jdbc:postgresql://localhost:5432/myapp");
-- config.setUsername("app_user");
-- config.setPassword("secret");
-- config.setMaximumPoolSize(10);
-- config.setMinimumIdle(2);
-- config.setConnectionTimeout(30000);
-- config.setIdleTimeout(600000);
--
-- HikariDataSource ds = new HikariDataSource(config);
--
-- try (Connection conn = ds.getConnection()) {
--     // Use connection from pool — auto-returned on close
-- }

-- ============================================================
-- 8. JAVA — Spring Boot + JPA
-- ============================================================

-- application.properties:
-- spring.datasource.url=jdbc:postgresql://localhost:5432/myapp
-- spring.datasource.username=app_user
-- spring.datasource.password=secret
-- spring.jpa.hibernate.ddl-auto=update
-- spring.datasource.hikari.maximum-pool-size=10

-- @Entity @Table(name = "users")
-- public class User {
--     @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
--     private Long id;
--     @Column(nullable = false) private String name;
--     @Column(unique = true) private String email;
-- }

-- public interface UserRepository extends JpaRepository<User, Long> {
--     List<User> findByName(String name);
--     Optional<User> findByEmail(String email);
-- }

-- ============================================================
-- 9. CONNECTION POOL SIZING
-- ============================================================

-- Formula: pool_size = (CPU_cores × 2) + spinning_disks
-- Example: 4 cores + SSD = 8 connections per app instance

-- Check current connections:
SELECT count(*) AS active_connections
FROM pg_stat_activity
WHERE state = 'active';

-- Check max connections:
SHOW max_connections;

-- Monitor connection usage:
SELECT usename, state, count(*)
FROM pg_stat_activity
GROUP BY usename, state
ORDER BY count DESC;

-- ============================================================
-- 10. PYTHON DRIVER COMPARISON
-- ============================================================

-- psycopg2   → Standard sync driver (C extension). Most projects.
-- psycopg3   → Next-gen sync+async. Better typing, pipeline.
-- asyncpg    → Pure async. Fastest for asyncio apps.
-- SQLAlchemy → ORM layer (uses any driver). Complex apps.
-- Django ORM → Django framework ORM (uses psycopg2).

-- ============================================================
-- 11. JAVA STACK COMPARISON
-- ============================================================

-- JDBC driver       → Low-level. Maximum control.
-- HikariCP          → Connection pool. Always use in production.
-- Spring Data JPA   → ORM for Spring Boot.
-- Hibernate         → ORM for non-Spring projects.
-- jOOQ              → Type-safe SQL builder. Complex queries.
-- R2DBC             → Reactive driver. WebFlux apps.

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Python + psycopg2: create table, insert 100 rows, query.
--    Use parameterized queries. Measure time.

-- 2. Rewrite #1 with SQLAlchemy ORM. Compare code.

-- 3. Java + JDBC: same task. PreparedStatement. Measure time.

-- 4. Add HikariCP. Benchmark pooled vs unpooled connections.

-- 5. SQL injection test on TEST db: try ' OR 1=1 --
--    with and without parameterized queries. See the difference.
