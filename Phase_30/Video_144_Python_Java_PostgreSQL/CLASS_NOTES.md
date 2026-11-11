# Python & Java with PostgreSQL — psycopg2, SQLAlchemy, JDBC, Spring Boot
**Series:** PostgreSQL Mastery | **Phase:** 30 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we connect PostgreSQL to the two most popular backend languages — Python and Java. You will learn how to install drivers, connect, run queries, use connection pooling, and work with ORMs in both languages.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you need a running PostgreSQL 16 instance with a test database. You should know basic SQL — SELECT, INSERT, UPDATE, DELETE. For the Python section, you need Python 3.8 or higher. For the Java section, you need JDK 17 or higher and Maven or Gradle.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL 16** | Running instance with a test database and user |
| **SQL Knowledge** | SELECT, INSERT, UPDATE, DELETE — Phases 5-8 |
| **Python 3.8+** | For psycopg2 and SQLAlchemy sections |
| **JDK 17+** | For JDBC and Spring Boot sections |
| **pip / Maven** | Package managers for installing libraries |

### Comparison
You know how to query PostgreSQL from psql. But real applications do not use psql. A web application, an API, a data pipeline — they all need to connect to PostgreSQL from code. Each programming language needs a driver — a library that speaks the PostgreSQL wire protocol. The driver handles connections, sends SQL, receives results, and manages transactions. Choosing the right driver and using it correctly is critical for performance and security.

| What psql Does | What Apps Need |
| :--- | :--- |
| Interactive SQL terminal | Programmatic database access |
| One user, one connection | Hundreds of concurrent users |
| Manual queries | Connection pooling |
| Great for admin tasks | Parameterized queries (SQL injection safe) |

### Comparison
Never concatenate user input into SQL strings — that is how SQL injection attacks happen. Always use parameterized queries. In psycopg2, use %s placeholders and pass values as a tuple. psycopg2 handles escaping and type conversion safely. This is the single most important security practice when working with databases from application code.

| WRONG (SQL Injection!) | CORRECT (Parameterized) |
| :--- | :--- |
| name = request.args['name'] | name = request.args['name'] |
| cur.execute( | cur.execute( |
|   f"SELECT * FROM users |   "SELECT * FROM users |
|     WHERE name='{name}'" |     WHERE name = %s", |
| ) |   (name,) |
| # Attacker sends: ' OR 1=1 -- | ) |
| # Deletes your database! | # psycopg2 escapes safely |

### Python — PostgreSQL Drivers
Let us summarize Python driver choices. psycopg2 is the standard — fast, mature, widely used. psycopg3 is the next generation with async support and better typing. asyncpg is the fastest async driver — built from scratch for asyncio applications. SQLAlchemy is the ORM layer that works on top of any driver. For most projects, start with psycopg2 plus SQLAlchemy.

| Term | Meaning / Explanation |
| :--- | :--- |
| **psycopg2** | Type: Sync (C extension) | Best For: Most projects. Fast, mature, stable. |
| **psycopg3** | Type: Sync + Async | Best For: New projects. Better typing, pipeline mode. |
| **asyncpg** | Type: Async only | Best For: High-perf async apps. Fastest raw driver. |
| **SQLAlchemy** | Type: ORM (uses above) | Best For: Complex apps. Auto-pooling, migrations. |
| **Django ORM** | Type: ORM (uses psycopg2) | Best For: Django web framework projects. |

### Comparison
If this integration guide is saving you time, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All code samples from this video |
| Every donation helps! | Practice exercises included |

### Java — PostgreSQL Stack
Here is a summary of Java PostgreSQL options. The JDBC driver is the standard low-level API — use it for maximum control. HikariCP is the connection pool — always use it in production. Spring Data JPA is the ORM — use it with Spring Boot. For non-Spring projects, Hibernate is the ORM and jOOQ generates type-safe SQL. For most Java projects, Spring Boot plus JPA plus HikariCP is the recommended stack.

| Term | Meaning / Explanation |
| :--- | :--- |
| **JDBC Driver** | Tool: postgresql-42.x.jar | Best For: Low-level access, max control |
| **Connection Pool** | Tool: HikariCP | Best For: All Java apps (fastest pool) |
| **ORM** | Tool: Spring Data JPA | Best For: Spring Boot projects |
| **ORM** | Tool: Hibernate (standalone) | Best For: Non-Spring Java projects |
| **Query Builder** | Tool: jOOQ | Best For: Type-safe SQL, complex queries |
| **Reactive** | Tool: R2DBC + r2dbc-postgresql | Best For: Reactive/WebFlux apps |

### Connection Pool Sizing
How many connections should your pool have? The PostgreSQL wiki recommends this formula: connections equal CPU cores times 2 plus the number of spinning disks. For a server with 4 CPU cores and SSD storage, that is 4 times 2 plus 0 equals 8 connections. More connections does not mean more performance — too many connections cause context switching and lock contention. PgBouncer in front of PostgreSQL lets hundreds of application instances share a small number of actual database connections.

- Formula -- pool_size = (CPU_cores × 2) + spinning_disks. Example: 4 cores + SSD = 8 connections.
- Per App Instance -- 5-10 connections per app instance. 10 app instances × 10 = 100 PG connections total.
- max_connections -- PostgreSQL default: 100. Increase only if needed. Each connection uses ~10MB RAM.
- PgBouncer -- Put PgBouncer between apps and PG. 1000 app connections → 20 real PG connections.
- Monitor -- SELECT count(*) FROM pg_stat_activity; — watch active connection count. Alert at 80%.

### Python vs Java with PostgreSQL
Let us compare the two stacks. Both use parameterized queries for security. Both have connection pooling. Both have mature ORMs. Python is faster for prototyping and data science workloads. Java is faster for high-throughput enterprise services. The choice depends on your team and ecosystem — both are excellent with PostgreSQL.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Driver** | Python: psycopg2 / psycopg3 | Java: JDBC (postgresql.jar) |
| **Connection Pool** | Python: ThreadedConnectionPool | Java: HikariCP |
| **ORM** | Python: SQLAlchemy / Django ORM | Java: JPA / Hibernate / jOOQ |
| **Migrations** | Python: Alembic (SQLAlchemy) | Java: Flyway / Liquibase |
| **Async Support** | Python: asyncpg / psycopg3 | Java: R2DBC (reactive) |
| **Best For** | Python: Prototyping, data science | Java: Enterprise, high throughput |
| **Parameterized** | Python: %s placeholders | Java: ? placeholders |

### Beginner Traps
Watch out for these traps. First, never concatenate user input into SQL strings — always use parameterized queries. This is the number one security vulnerability in web applications. Second, always use connection pooling in production — creating a new connection per request can bring down your database. Third, always close connections and cursors — leaked connections exhaust your pool. Use try-with-resources in Java or with statements in Python. Fourth, do not set pool size to 100 — more connections does not mean faster. Start with 5 to 10.

- SQL Injection -- NEVER concatenate user input into SQL. Use parameterized queries (%s in Python, ? in Java). Always.
- No Connection Pool -- Creating new connections per request is slow and crashes PG. Always pool in production.
- Connection Leaks -- Unclosed connections exhaust the pool. Use 'with' (Python) or try-with-resources (Java).
- Pool Too Large -- pool_size=100 causes contention. Start with 5-10 per app instance. Monitor and adjust.
- Storing Passwords in Code -- Use environment variables or secret managers. Never hardcode DB passwords in source code.

### Practice Exercises
Here are your practice exercises. First, write a Python script that connects to PostgreSQL using psycopg2, creates a table, inserts 100 rows, and queries them back. Second, rewrite the same script using SQLAlchemy ORM. Third, write a Java program using JDBC that does the same — create, insert, query. Fourth, set up HikariCP in Java and benchmark the difference between pooled and unpooled connections. Fifth, deliberately try an SQL injection attack on your test database to see what happens with and without parameterized queries.

- Exercise 1 -- Python + psycopg2: connect, create table, insert 100 rows, query back. Use parameterized queries.
- Exercise 2 -- Rewrite Exercise 1 using SQLAlchemy ORM. Compare the code — which is simpler?
- Exercise 3 -- Java + JDBC: same task. Create table, insert, query. Use PreparedStatement.
- Exercise 4 -- Add HikariCP to Java. Benchmark: pooled vs new connection per query. Measure response time.
- Exercise 5 -- SQL injection test: try injecting ' OR 1=1 -- with and without parameterized queries on test DB.


---

## 3. Hands-On Commands & psql Output

### Installing psycopg2
**Explanation:** psycopg2 is the most popular Python driver for PostgreSQL. It is a C extension that wraps libpq — the official PostgreSQL client library. Install it with pip. Use psycopg2-binary for development — it bundles libpq so you do not need to install PostgreSQL client libraries. For production, compile psycopg2 from source against your system's libpq for best performance.

```sql
# Development (bundled libpq)
$ pip install psycopg2-binary
Successfully installed psycopg2-binary-2.9.9

# Production (compile from source)
$ pip install psycopg2
Successfully installed psycopg2-2.9.9

# Verify installation
>>> import psycopg2; print(psycopg2.__version__)
2.9.9 (dt dec pq3 ext lo64)
```

### Python — Connect and Query
**Explanation:** To connect, pass your host, database name, user, and password to psycopg2.connect. This returns a connection object. Create a cursor from the connection, execute SQL, and fetch results. Always close the cursor and connection when done. The best practice is to use Python's with statement — it automatically commits on success and rolls back on error.

```sql
import psycopg2

# Connect to PostgreSQL
conn = psycopg2.connect(
    host='localhost',
    port=5432,
    dbname='myapp',
    user='app_user',
    password='secret'
)

# Use context manager for auto-commit/rollback
with conn:
    with conn.cursor() as cur:
        # Create table
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT UNIQUE
            )
        """)

        # Insert with parameterized query
        cur.execute(
            "INSERT INTO users (name, email) "
            "VALUES (%s, %s) RETURNING id",
            ('Alice', 'alice@example.com')
        )
        user_id = cur.fetchone()[0]
        print(f'Inserted user {user_id}')

conn.close()
```

### Python — Connection Pooling
**Explanation:** Creating a new database connection for every request is slow — each connection takes a TCP handshake, authentication, and memory allocation. Connection pooling solves this by maintaining a pool of open connections that are reused. psycopg2 provides SimpleConnectionPool and ThreadedConnectionPool. For production web applications, use ThreadedConnectionPool with a minimum of 2 and maximum of 10 connections per application instance.

```sql
from psycopg2 import pool

# Create a threaded connection pool
db_pool = pool.ThreadedConnectionPool(
    minconn=2,
    maxconn=10,
    host='localhost',
    port=5432,
    dbname='myapp',
    user='app_user',
    password='secret'
)

def get_users():
    conn = db_pool.getconn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                'SELECT id, name, email FROM users'
            )
            return cur.fetchall()
    finally:
        # Return connection to pool (don't close!)
        db_pool.putconn(conn)

# On application shutdown:
# db_pool.closeall()
```

### Python — SQLAlchemy ORM
**Explanation:** SQLAlchemy is Python's most popular ORM — Object Relational Mapper. Instead of writing raw SQL, you define Python classes that map to database tables. SQLAlchemy generates the SQL for you. It handles connection pooling automatically, supports migrations with Alembic, and works with PostgreSQL-specific features like JSONB, arrays, and full-text search.

```sql
from sqlalchemy import create_engine, Column
from sqlalchemy import Integer, String
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker

# Connection URL with pool settings
engine = create_engine(
    'postgresql://app_user:secret@'
    'localhost:5432/myapp',
    pool_size=5,
    max_overflow=10
)

Base = declarative_base()

class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True)

# Create tables
Base.metadata.create_all(engine)

# Use session for queries
Session = sessionmaker(bind=engine)
with Session() as session:
    user = User(name='Bob', email='bob@ex.com')
    session.add(user)
    session.commit()
```

### Java — Maven Dependency + JDBC Connection
**Explanation:** Now let us switch to Java. The PostgreSQL JDBC driver is the standard way to connect Java applications to PostgreSQL. Add the dependency to your Maven pom.xml or Gradle build file. The JDBC driver uses the standard java.sql API — DriverManager, Connection, PreparedStatement, ResultSet. If you know JDBC for any database, you already know it for PostgreSQL.

```sql
<!-- pom.xml -->
<dependency>
  <groupId>org.postgresql</groupId>
  <artifactId>postgresql</artifactId>
  <version>42.7.3</version>
</dependency>

// Java code
import java.sql.*;

String url = "jdbc:postgresql://"
  + "localhost:5432/myapp";
String user = "app_user";
String pass = "secret";

try (Connection conn =
  DriverManager.getConnection(url, user, pass)) {

  // Parameterized query
  PreparedStatement ps = conn.prepareStatement(
    "SELECT id, name, email FROM users "
    + "WHERE name = ?"
  );
  ps.setString(1, "Alice");
  ResultSet rs = ps.executeQuery();

  while (rs.next()) {
    System.out.println(
      rs.getInt("id") + ": "
      + rs.getString("name")
    );
  }
}
```

### Java — HikariCP Connection Pool
**Explanation:** In Java, HikariCP is the de facto connection pool — it is the fastest Java connection pool and is used by Spring Boot by default. Configure it with a maximum pool size, connection timeout, and idle timeout. For most applications, set the maximum pool size to 10 connections per application instance. HikariCP also validates connections before giving them to your code, so stale connections are never returned.

```sql
<!-- pom.xml -->
<dependency>
  <groupId>com.zaxxer</groupId>
  <artifactId>HikariCP</artifactId>
  <version>5.1.0</version>
</dependency>

// Java code
import com.zaxxer.hikari.*;

HikariConfig config = new HikariConfig();
config.setJdbcUrl(
  "jdbc:postgresql://localhost:5432/myapp"
);
config.setUsername("app_user");
config.setPassword("secret");
config.setMaximumPoolSize(10);
config.setMinimumIdle(2);
config.setConnectionTimeout(30000);
config.setIdleTimeout(600000);

HikariDataSource ds =
  new HikariDataSource(config);

try (Connection conn = ds.getConnection()) {
  // Use connection from pool
  PreparedStatement ps = conn.prepareStatement(
    "INSERT INTO users (name, email) "
    + "VALUES (?, ?)"
  );
  ps.setString(1, "Charlie");
  ps.setString(2, "charlie@example.com");
  ps.executeUpdate();
}  // auto-returned to pool
```

### Java — Spring Boot + JPA
**Explanation:** Spring Boot is Java's most popular web framework. It uses Spring Data JPA for database access — an ORM similar to SQLAlchemy. You define entity classes with annotations, create repository interfaces, and Spring generates the SQL and connection management. Spring Boot auto-configures HikariCP. Just set the connection URL, username, and password in application.properties.

```sql
# application.properties
spring.datasource.url=\
  jdbc:postgresql://localhost:5432/myapp
spring.datasource.username=app_user
spring.datasource.password=secret
spring.jpa.hibernate.ddl-auto=update
spring.datasource.hikari.maximum-pool-size=10

// Entity class
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(
      strategy = GenerationType.IDENTITY
    )
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(unique = true)
    private String email;
}

// Repository (Spring generates SQL!)
public interface UserRepository
    extends JpaRepository<User, Long> {

    List<User> findByName(String name);
    Optional<User> findByEmail(String email);
}
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. First, never concatenate user input into SQL strings — always use parameterized queries. This is the number one security vulnerability in web applications. Second, always use connection pooling in production — creating a new connection per request can bring down your database. Third, always close connections and cursors — leaked connections exhaust your pool. Use try-with-resources in Java or with statements in Python. Fourth, do not set pool size to 100 — more connections does not mean faster. Start with 5 to 10.

- SQL Injection -- NEVER concatenate user input into SQL. Use parameterized queries (%s in Python, ? in Java). Always.
- No Connection Pool -- Creating new connections per request is slow and crashes PG. Always pool in production.
- Connection Leaks -- Unclosed connections exhaust the pool. Use 'with' (Python) or try-with-resources (Java).
- Pool Too Large -- pool_size=100 causes contention. Start with 5-10 per app instance. Monitor and adjust.
- Storing Passwords in Code -- Use environment variables or secret managers. Never hardcode DB passwords in source code.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Python uses psycopg2 as the standard driver and SQLAlchemy as the ORM — both with connection pooling built in. Java uses the JDBC driver with HikariCP for connection pooling and Spring Data JPA as the ORM. Both languages require parameterized queries to prevent SQL injection. Connection pool size should be small — 5 to 10 per application instance. PgBouncer handles pooling at the database level when you have many application instances.

- **Python: psycopg2 (driver) + SQLAlchemy (ORM) + ThreadedConnectionPool**
- **Java: JDBC driver + HikariCP (pool) + Spring Data JPA (ORM)**
- **ALWAYS use parameterized queries — never concatenate user input**
- **Connection pool size: 5-10 per app instance, not 100**
- **Formula: pool = (CPU cores × 2) + spinning disks**
- **PgBouncer: database-level pooling for many app instances**
- **Use environment variables for database passwords, never hardcode**


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
