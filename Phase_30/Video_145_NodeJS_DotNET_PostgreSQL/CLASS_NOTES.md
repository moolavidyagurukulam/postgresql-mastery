# Node.js & .NET with PostgreSQL — pg, Prisma, Npgsql, Entity Framework
**Series:** PostgreSQL Mastery | **Phase:** 30 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we connect PostgreSQL to Node.js and .NET — two of the most popular platforms for building web APIs and microservices. You will learn the drivers, ORMs, and best practices for each.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you need a running PostgreSQL 16 instance. For Node.js, install Node.js 18 or higher and npm. For .NET, install the .NET 8 SDK. You should understand SQL basics and connection pooling concepts from the previous class.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL 16** | Running instance with test database and user |
| **Node.js 18+** | With npm for installing packages |
| **.NET 8 SDK** | For Npgsql and Entity Framework Core |
| **Previous Class** | Connection pooling and parameterized query concepts |

### Node.js — PostgreSQL Options
Here is a summary of Node.js PostgreSQL options. The pg package is the standard low-level driver. Prisma is the recommended ORM for new projects. Sequelize is an older ORM still widely used. Knex is a query builder — it sits between raw SQL and a full ORM. TypeORM is popular with TypeScript developers. For most projects, start with Prisma unless you need raw SQL control.

| Term | Meaning / Explanation |
| :--- | :--- |
| **pg (node-postgres)** | Type: Low-level driver | Best For: Raw SQL, max control |
| **Prisma** | Type: ORM + migrations | Best For: New projects, TypeScript |
| **Sequelize** | Type: ORM | Best For: Existing projects, callbacks |
| **Knex.js** | Type: Query builder | Best For: SQL-like API, no full ORM |
| **TypeORM** | Type: ORM (decorators) | Best For: TypeScript, NestJS projects |
| **Drizzle** | Type: ORM (SQL-like) | Best For: Type-safe, lightweight ORM |

### Comparison
If this integration guide is helpful, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All code samples from this video |
| Every donation helps! | Practice exercises included |

### .NET — PostgreSQL Options
Here is a summary of .NET PostgreSQL options. Npgsql is the standard low-level driver. Entity Framework Core is the full ORM — use it for most .NET projects. Dapper is the micro-ORM — use it for performance-critical reads. Many production applications combine EF Core for writes and Dapper for complex read queries.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Npgsql** | Type: ADO.NET driver | Best For: Low-level, maximum control |
| **EF Core + Npgsql** | Type: Full ORM | Best For: Most .NET projects, LINQ |
| **Dapper + Npgsql** | Type: Micro-ORM | Best For: Performance-critical reads |
| **Npgsql (pooling)** | Type: Built-in pool | Best For: Auto-enabled in connection string |
| **LinqToDB** | Type: LINQ provider | Best For: Alternative to EF Core |

### All Languages — PostgreSQL Comparison
Let us compare all four languages we have covered — Python, Java, Node.js, and .NET. Each has a mature driver, connection pooling, and ORM support. The parameterized query syntax differs — Python uses %s, Java uses ?, Node.js uses $1 $2, and .NET uses @param. But the concepts are identical. Choose based on your team and ecosystem.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Driver** | Python: psycopg2 | Java: JDBC | Node.js: pg |
| **ORM** | Python: SQLAlchemy | Java: JPA/Hibernate | Node.js: Prisma |
| **Pool** | Python: ThreadedPool | Java: HikariCP | Node.js: pg.Pool |
| **Params** | Python: %s | Java: ? | Node.js: $1, $2 |
| **Migrations** | Python: Alembic | Java: Flyway | Node.js: Prisma migrate |
| **Async** | Python: asyncpg | Java: R2DBC | Node.js: Native async |

### Beginner Traps
Watch out for these traps. First, in Node.js, never forget to release a client back to the pool — leaked clients will eventually exhaust your pool and hang your application. Second, in .NET, always use parameterized queries with @param placeholders — never string interpolation. Third, do not use Prisma's raw query mode unless you need it — the generated client is type-safe and prevents SQL injection. Fourth, connection pooling is enabled by default in Npgsql — do not disable it.

- Node.js: Release clients! -- Always call client.release() in a finally block. Leaked clients exhaust the pool and hang your app.
- .NET: Use @param syntax -- cmd.Parameters.AddWithValue("name", value). NEVER use string interpolation in SQL commands.
- Prisma: Trust the client -- Use generated methods (create, findMany). Raw queries bypass type safety and injection protection.
- Npgsql: Pooling is auto -- Npgsql pools connections by default. Don't disable it. Set 'Maximum Pool Size=10' in connection string.
- All: Close connections -- Use 'using' (.NET), 'try/finally' (Node.js), or 'with' (Python). Never leave connections open.

### Practice Exercises
Here are your practice exercises. First, build a Node.js REST API with Express and pg that does CRUD operations on a users table. Second, rewrite it using Prisma and compare the code. Third, build the same API in .NET with ASP.NET Core and Entity Framework Core. Fourth, add Dapper to the .NET project for a complex report query and compare performance with EF Core. Fifth, write a Node.js transaction that transfers funds between accounts — test that rollback works on error.

- Exercise 1 -- Node.js + Express + pg: REST API for users table. GET, POST, PUT, DELETE. Use pool.query.
- Exercise 2 -- Rewrite Exercise 1 with Prisma. Compare code complexity and type safety.
- Exercise 3 -- .NET + ASP.NET Core + EF Core: same REST API. Use LINQ queries and SaveChangesAsync.
- Exercise 4 -- Add Dapper to .NET project for a report query. Compare speed with EF Core.
- Exercise 5 -- Node.js transaction: transfer funds between accounts. Test rollback on insufficient balance.


---

## 3. Hands-On Commands & psql Output

### Installing pg (node-postgres)
**Explanation:** The pg package — also called node-postgres — is the standard PostgreSQL driver for Node.js. Install it with npm. It provides a Pool class for connection pooling, supports parameterized queries, handles type conversion between JavaScript and PostgreSQL types, and works with both callbacks and async/await. For production, always use the Pool class, never create individual Client connections.

```sql
$ npm init -y
Wrote to /app/package.json
$ npm install pg
added 15 packages in 2s

# Verify installation
$ node -e "const {Pool}=require('pg'); console.log('pg loaded')"
pg loaded
```

### Node.js — Pool Connection and CRUD
**Explanation:** Create a Pool with your connection settings. The pool manages connections automatically — it opens them when needed, reuses idle ones, and closes them when they time out. Use pool.query for simple queries — it automatically acquires a connection, runs the query, and releases it back. For transactions, acquire a client from the pool explicitly.

```sql
const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'myapp',
  user: 'app_user',
  password: 'secret',
  max: 10,          // max pool size
  idleTimeoutMillis: 30000
});

// INSERT (parameterized — $1, $2 placeholders)
const { rows } = await pool.query(
  'INSERT INTO users (name, email) '
  + 'VALUES ($1, $2) RETURNING id',
  ['Alice', 'alice@example.com']
);
console.log('Inserted:', rows[0].id);

// SELECT
const result = await pool.query(
  'SELECT * FROM users WHERE name = $1',
  ['Alice']
);
console.log(result.rows);

// On shutdown:
await pool.end();
```

### Node.js — Transactions
**Explanation:** For transactions, acquire a dedicated client from the pool. Call BEGIN, run your queries, then COMMIT or ROLLBACK. Always release the client back to the pool in a finally block — a leaked client means one less connection in your pool. The try-catch-finally pattern ensures the client is always returned, even if an error occurs.

```sql
async function transferFunds(
  fromId, toId, amount
) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(
      'UPDATE accounts SET balance = '
      + 'balance - $1 WHERE id = $2',
      [amount, fromId]
    );
    await client.query(
      'UPDATE accounts SET balance = '
      + 'balance + $1 WHERE id = $2',
      [amount, toId]
    );

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release(); // Return to pool!
  }
}
```

### Node.js — Prisma ORM
**Explanation:** Prisma is the most popular ORM for Node.js and TypeScript. You define your data model in a Prisma schema file, and Prisma generates a type-safe client. It handles connection pooling, migrations, and query building. Prisma's query API is intuitive — create, findMany, update, delete — with full TypeScript autocompletion. For new Node.js projects with PostgreSQL, Prisma is the recommended starting point.

```sql
// Install:
// npm install prisma @prisma/client
// npx prisma init

// prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url = env("DATABASE_URL")
}

model User {
  id    Int    @id @default(autoincrement())
  name  String
  email String @unique
}

// After: npx prisma db push

import { PrismaClient } from '@prisma/client'
const prisma = new PrismaClient()

// Create
const user = await prisma.user.create({
  data: { name: 'Bob', email: 'bob@ex.com' }
})

// Read
const users = await prisma.user.findMany({
  where: { name: 'Bob' }
})

// Update
await prisma.user.update({
  where: { id: 1 },
  data: { name: 'Bob Smith' }
})
```

### .NET — Npgsql Connection and Query
**Explanation:** Now let us switch to .NET. Npgsql is the standard PostgreSQL driver for .NET. It is an ADO.NET data provider — if you know ADO.NET for SQL Server, you already know the pattern. Install it via NuGet. Npgsql provides NpgsqlConnection, NpgsqlCommand, and NpgsqlDataReader — the standard .NET database interfaces. It includes built-in connection pooling enabled by default.

```sql
// Install: dotnet add package Npgsql

using Npgsql;

var connStr = "Host=localhost;Port=5432;"
  + "Database=myapp;Username=app_user;"
  + "Password=secret;Maximum Pool Size=10";

using var conn =
  new NpgsqlConnection(connStr);
await conn.OpenAsync();

// INSERT (parameterized — @name, @email)
using var cmd = new NpgsqlCommand(
  "INSERT INTO users (name, email) "
  + "VALUES (@name, @email) RETURNING id",
  conn);
cmd.Parameters.AddWithValue("name", "Dave");
cmd.Parameters.AddWithValue(
  "email", "dave@example.com");
var id = await cmd.ExecuteScalarAsync();

// SELECT
using var query = new NpgsqlCommand(
  "SELECT id, name FROM users", conn);
using var reader =
  await query.ExecuteReaderAsync();
while (await reader.ReadAsync())
  Console.WriteLine(
    $"{reader.GetInt32(0)}: "
    + $"{reader.GetString(1)}");
```

### .NET — Entity Framework Core
**Explanation:** Entity Framework Core is .NET's standard ORM — similar to SQLAlchemy or Hibernate. You define entity classes and a DbContext, and EF Core generates SQL, manages connections, and handles migrations. Install the Npgsql.EntityFrameworkCore.PostgreSQL package. EF Core supports LINQ queries — you write C-sharp expressions and EF Core translates them to SQL.

```sql
// dotnet add package
//  Npgsql.EntityFrameworkCore.PostgreSQL

public class User {
  public int Id { get; set; }
  public string Name { get; set; }
  public string Email { get; set; }
}

public class AppDbContext : DbContext {
  public DbSet<User> Users => Set<User>();

  protected override void OnConfiguring(
    DbContextOptionsBuilder opt)
    => opt.UseNpgsql(
      "Host=localhost;Database=myapp;"
      + "Username=app_user;Password=secret");
}

// Usage
using var db = new AppDbContext();

// Create
db.Users.Add(new User {
  Name = "Eve", Email = "eve@ex.com" });
await db.SaveChangesAsync();

// Read (LINQ → SQL)
var users = await db.Users
  .Where(u => u.Name == "Eve")
  .ToListAsync();
```

### .NET — Dapper (Micro-ORM)
**Explanation:** Dapper is a micro-ORM for .NET — it maps SQL results to C-sharp objects without the overhead of Entity Framework. You write raw SQL and Dapper handles the object mapping. It is significantly faster than EF Core for read-heavy workloads. Use Dapper when you want the speed of raw SQL with the convenience of automatic mapping. Many .NET developers use EF Core for writes and Dapper for complex reads.

```sql
// dotnet add package Dapper

using Dapper;
using Npgsql;

var connStr = "Host=localhost;Port=5432;"
  + "Database=myapp;Username=app_user;"
  + "Password=secret";

using var conn =
  new NpgsqlConnection(connStr);

// Query → automatic object mapping
var users = await conn.QueryAsync<User>(
  "SELECT id, name, email FROM users "
  + "WHERE name = @Name",
  new { Name = "Eve" });

// Insert
await conn.ExecuteAsync(
  "INSERT INTO users (name, email) "
  + "VALUES (@Name, @Email)",
  new { Name = "Frank",
        Email = "frank@example.com" });

// Dapper is 5-10x faster than EF Core
// for read-heavy workloads
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. First, in Node.js, never forget to release a client back to the pool — leaked clients will eventually exhaust your pool and hang your application. Second, in .NET, always use parameterized queries with @param placeholders — never string interpolation. Third, do not use Prisma's raw query mode unless you need it — the generated client is type-safe and prevents SQL injection. Fourth, connection pooling is enabled by default in Npgsql — do not disable it.

- Node.js: Release clients! -- Always call client.release() in a finally block. Leaked clients exhaust the pool and hang your app.
- .NET: Use @param syntax -- cmd.Parameters.AddWithValue("name", value). NEVER use string interpolation in SQL commands.
- Prisma: Trust the client -- Use generated methods (create, findMany). Raw queries bypass type safety and injection protection.
- Npgsql: Pooling is auto -- Npgsql pools connections by default. Don't disable it. Set 'Maximum Pool Size=10' in connection string.
- All: Close connections -- Use 'using' (.NET), 'try/finally' (Node.js), or 'with' (Python). Never leave connections open.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Node.js uses the pg package as its standard driver with built-in Pool for connection management. Prisma is the recommended ORM for new Node.js projects. .NET uses Npgsql as its ADO.NET driver with automatic connection pooling. Entity Framework Core is the standard ORM, and Dapper is the micro-ORM for performance. All four languages — Python, Java, Node.js, and .NET — follow the same pattern: driver plus connection pool plus parameterized queries plus ORM.

- **Node.js: pg driver + Pool + Prisma ORM (or Sequelize/Knex)**
- **.NET: Npgsql driver (auto-pooling) + EF Core ORM + Dapper micro-ORM**
- **Parameterized queries: Node.js uses $1,$2 — .NET uses @param**
- **Node.js: always release pool clients in finally blocks**
- **.NET: Npgsql pools automatically — set max size in connection string**
- **Pattern: driver + pool + parameterized queries + ORM (all languages)**
- **Choose language by team expertise — all are excellent with PostgreSQL**


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
