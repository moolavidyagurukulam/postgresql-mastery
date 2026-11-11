-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Node.js & .NET with PostgreSQL (Classes 270-271)
-- Phase 30: Integration with Other Technologies
-- ============================================================

-- ============================================================
-- 1. NODE.JS — pg (node-postgres)
-- ============================================================

-- Install: npm install pg

-- const { Pool } = require('pg');
--
-- const pool = new Pool({
--   host: 'localhost',
--   port: 5432,
--   database: 'myapp',
--   user: 'app_user',
--   password: 'secret',
--   max: 10,
--   idleTimeoutMillis: 30000
-- });
--
-- // Simple query (auto pool management)
-- const { rows } = await pool.query(
--   'SELECT * FROM users WHERE name = $1',
--   ['Alice']
-- );
--
-- // INSERT with RETURNING
-- const result = await pool.query(
--   'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id',
--   ['Alice', 'alice@example.com']
-- );
-- console.log('New ID:', result.rows[0].id);
--
-- // UPDATE
-- await pool.query(
--   'UPDATE users SET name = $1 WHERE id = $2',
--   ['Alice Smith', 1]
-- );
--
-- // DELETE
-- await pool.query(
--   'DELETE FROM users WHERE id = $1', [1]
-- );

-- ============================================================
-- 2. NODE.JS — TRANSACTIONS
-- ============================================================

-- async function transferFunds(fromId, toId, amount) {
--   const client = await pool.connect();
--   try {
--     await client.query('BEGIN');
--     await client.query(
--       'UPDATE accounts SET balance = balance - $1 WHERE id = $2',
--       [amount, fromId]
--     );
--     await client.query(
--       'UPDATE accounts SET balance = balance + $1 WHERE id = $2',
--       [amount, toId]
--     );
--     await client.query('COMMIT');
--   } catch (err) {
--     await client.query('ROLLBACK');
--     throw err;
--   } finally {
--     client.release();  // ALWAYS release back to pool!
--   }
-- }

-- ============================================================
-- 3. NODE.JS — PRISMA ORM
-- ============================================================

-- Install:
-- npm install prisma @prisma/client
-- npx prisma init

-- prisma/schema.prisma:
-- datasource db {
--   provider = "postgresql"
--   url      = env("DATABASE_URL")
-- }
--
-- model User {
--   id    Int    @id @default(autoincrement())
--   name  String
--   email String @unique
-- }

-- .env:
-- DATABASE_URL="postgresql://app_user:secret@localhost:5432/myapp"

-- Commands:
-- npx prisma db push      # Create/update tables
-- npx prisma generate     # Generate client
-- npx prisma migrate dev  # Create migration

-- Usage:
-- import { PrismaClient } from '@prisma/client'
-- const prisma = new PrismaClient()
--
-- // Create
-- const user = await prisma.user.create({
--   data: { name: 'Bob', email: 'bob@example.com' }
-- })
--
-- // Read
-- const users = await prisma.user.findMany({
--   where: { name: { contains: 'Bob' } }
-- })
--
-- // Update
-- await prisma.user.update({
--   where: { id: 1 },
--   data: { name: 'Bob Smith' }
-- })
--
-- // Delete
-- await prisma.user.delete({ where: { id: 1 } })

-- ============================================================
-- 4. .NET — NPGSQL (ADO.NET Driver)
-- ============================================================

-- Install: dotnet add package Npgsql

-- using Npgsql;
--
-- var connStr = "Host=localhost;Port=5432;"
--   + "Database=myapp;Username=app_user;"
--   + "Password=secret;Maximum Pool Size=10";
--
-- using var conn = new NpgsqlConnection(connStr);
-- await conn.OpenAsync();
--
-- // INSERT (parameterized with @param)
-- using var cmd = new NpgsqlCommand(
--   "INSERT INTO users (name, email) "
--   + "VALUES (@name, @email) RETURNING id", conn);
-- cmd.Parameters.AddWithValue("name", "Dave");
-- cmd.Parameters.AddWithValue("email", "dave@example.com");
-- var id = await cmd.ExecuteScalarAsync();
--
-- // SELECT
-- using var query = new NpgsqlCommand(
--   "SELECT id, name FROM users WHERE name = @name", conn);
-- query.Parameters.AddWithValue("name", "Dave");
-- using var reader = await query.ExecuteReaderAsync();
-- while (await reader.ReadAsync())
--   Console.WriteLine($"{reader.GetInt32(0)}: {reader.GetString(1)}");

-- ============================================================
-- 5. .NET — ENTITY FRAMEWORK CORE
-- ============================================================

-- Install: dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL

-- public class User {
--   public int Id { get; set; }
--   public string Name { get; set; }
--   public string Email { get; set; }
-- }
--
-- public class AppDbContext : DbContext {
--   public DbSet<User> Users => Set<User>();
--   protected override void OnConfiguring(
--     DbContextOptionsBuilder opt)
--     => opt.UseNpgsql(
--       "Host=localhost;Database=myapp;"
--       + "Username=app_user;Password=secret");
-- }
--
-- // Usage
-- using var db = new AppDbContext();
--
-- // Create
-- db.Users.Add(new User { Name = "Eve", Email = "eve@ex.com" });
-- await db.SaveChangesAsync();
--
-- // Read (LINQ → SQL)
-- var users = await db.Users
--   .Where(u => u.Name == "Eve").ToListAsync();
--
-- // Update
-- var user = await db.Users.FindAsync(1);
-- user.Name = "Eve Smith";
-- await db.SaveChangesAsync();
--
-- // Delete
-- db.Users.Remove(user);
-- await db.SaveChangesAsync();

-- ============================================================
-- 6. .NET — DAPPER (Micro-ORM)
-- ============================================================

-- Install: dotnet add package Dapper

-- using Dapper;
-- using Npgsql;
--
-- using var conn = new NpgsqlConnection(connStr);
--
-- // Query with auto object mapping
-- var users = await conn.QueryAsync<User>(
--   "SELECT id, name, email FROM users WHERE name = @Name",
--   new { Name = "Eve" });
--
-- // Insert
-- await conn.ExecuteAsync(
--   "INSERT INTO users (name, email) VALUES (@Name, @Email)",
--   new { Name = "Frank", Email = "frank@example.com" });

-- Dapper is 5-10x faster than EF Core for reads
-- Use EF Core for writes, Dapper for complex reads

-- ============================================================
-- 7. NODE.JS LIBRARY COMPARISON
-- ============================================================

-- pg (node-postgres) → Standard driver. Raw SQL, max control.
-- Prisma             → ORM + migrations. TypeScript, new projects.
-- Sequelize          → ORM. Callbacks, existing projects.
-- Knex.js            → Query builder. SQL-like API.
-- TypeORM            → ORM with decorators. NestJS.
-- Drizzle            → Lightweight ORM. SQL-like, type-safe.

-- ============================================================
-- 8. .NET LIBRARY COMPARISON
-- ============================================================

-- Npgsql             → ADO.NET driver. Low-level control.
-- EF Core + Npgsql   → Full ORM. LINQ queries. Most .NET projects.
-- Dapper + Npgsql    → Micro-ORM. Fast reads. Complex queries.
-- LinqToDB           → Alternative LINQ provider.

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Node.js + Express + pg: build REST API for users table.
--    GET /users, POST /users, PUT /users/:id, DELETE /users/:id.

-- 2. Rewrite Exercise 1 with Prisma. Compare code and type safety.

-- 3. .NET + ASP.NET Core + EF Core: same REST API.
--    Use LINQ queries and async SaveChanges.

-- 4. Add Dapper to .NET for a report query.
--    Compare speed with EF Core for same query.

-- 5. Node.js transaction: transfer funds between accounts.
--    Test rollback on insufficient balance error.
