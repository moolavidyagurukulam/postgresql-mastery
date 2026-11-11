-- =============================================
-- PostgreSQL Mastery: Schemas
-- Phase 2: Database Objects | Class 10
-- =============================================
-- Schemas = namespaces inside a database.
-- Organize tables, views, functions into logical groups.
-- =============================================

-- === WHAT IS A SCHEMA? ===
-- Schema = namespace/container inside a database
-- Hierarchy: Cluster → Database → Schema → Tables
-- Default schema: public (exists in every new database)

-- === CREATE SCHEMA ===

CREATE SCHEMA sales;
CREATE SCHEMA hr;
CREATE SCHEMA inventory;

-- Safe: only create if not exists
CREATE SCHEMA IF NOT EXISTS sales;

-- Create schema with an owner
CREATE SCHEMA app AUTHORIZATION webapp;

-- List all schemas
-- \dn

-- === CREATE TABLES IN SCHEMAS ===

CREATE TABLE sales.orders (
    id    SERIAL PRIMARY KEY,
    total NUMERIC(10,2)
);

CREATE TABLE hr.employees (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- List tables in a specific schema
-- \dt sales.*
-- \dt hr.*

-- === search_path ===

-- Check current search_path
SHOW search_path;
-- Default: "$user", public

-- PostgreSQL looks for tables in search_path order
-- If table not in search_path → ERROR: relation does not exist

-- Option 1: Use fully qualified name
SELECT * FROM sales.orders;

-- Option 2: Change search_path (session only)
SET search_path TO sales, public;
SELECT * FROM orders;  -- now works without schema prefix

-- Permanent change for a database
ALTER DATABASE practice SET search_path TO sales, public;

-- Permanent change for a user/role
ALTER ROLE webapp SET search_path TO app, public;

-- First schema in search_path = where new objects are created
-- (if you don't specify schema.tablename)

-- === PUBLIC SCHEMA SECURITY ===

-- By default, ALL users can create objects in public
-- This is a security risk in production!

-- Revoke CREATE on public from everyone
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Grant specific access to schemas
GRANT USAGE ON SCHEMA sales TO webapp;
GRANT ALL ON ALL TABLES IN SCHEMA sales TO webapp;

-- Restore if needed
GRANT CREATE ON SCHEMA public TO PUBLIC;

-- === ALTER SCHEMA ===

-- Rename
ALTER SCHEMA inventory RENAME TO warehouse;

-- Change owner
ALTER SCHEMA warehouse OWNER TO postgres;

-- === DROP SCHEMA ===

-- Drop empty schema
DROP SCHEMA warehouse;

-- Drop schema + everything inside (DANGEROUS!)
DROP SCHEMA hr CASCADE;

-- Safe: only drop if exists
DROP SCHEMA IF EXISTS hr;

-- === MOVING OBJECTS BETWEEN SCHEMAS ===

-- Move a table from one schema to another
CREATE TABLE public.users (id SERIAL PRIMARY KEY, name VARCHAR(100));
CREATE SCHEMA app;
ALTER TABLE public.users SET SCHEMA app;
-- Now: app.users (was public.users)

-- Verify
-- \dt app.*

-- === USE CASES ===

-- 1. By department:  sales, hr, finance
-- 2. Multi-tenancy:  tenant_acme, tenant_globex
-- 3. App layers:     api, admin, reporting
-- 4. Extensions:     CREATE SCHEMA extensions;
-- 5. API versioning: v1, v2

-- === COMMON ERRORS ===

-- ERROR: relation "orders" does not exist
-- FIX: Use sales.orders OR SET search_path TO sales, public;

-- ERROR: schema "sales" already exists
-- FIX: CREATE SCHEMA IF NOT EXISTS sales;

-- ERROR: cannot drop schema — other objects depend on it
-- FIX: DROP SCHEMA sales CASCADE; (drops everything inside!)

-- === PRACTICE EXERCISES ===

-- Exercise 1:
CREATE SCHEMA app;
CREATE SCHEMA analytics;
CREATE SCHEMA staging;
-- \dn

-- Exercise 2:
CREATE TABLE app.customers (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100),
    email VARCHAR(150)
);
INSERT INTO app.customers (name, email) VALUES ('Ravi', 'ravi@example.com');
INSERT INTO app.customers (name, email) VALUES ('Priya', 'priya@example.com');
SELECT * FROM app.customers;

-- Exercise 3:
SET search_path TO app, public;
SELECT * FROM customers;  -- works without schema prefix

-- Exercise 4:
ALTER TABLE app.customers SET SCHEMA analytics;
-- \dt analytics.*

-- Exercise 5:
DROP SCHEMA IF EXISTS app CASCADE;
DROP SCHEMA IF EXISTS analytics CASCADE;
DROP SCHEMA IF EXISTS staging CASCADE;
DROP SCHEMA IF EXISTS sales CASCADE;
-- \dn

-- =============================================
-- Next Class: Tablespaces
-- =============================================
