-- =============================================
-- PostgreSQL Mastery: PostgreSQL Terminology
-- Phase 1: Foundation | Class 05
-- =============================================
-- Key terms you must know before working with PostgreSQL.
-- =============================================

-- === CORE HIERARCHY ===
-- Cluster → Database → Schema → Table
--
-- Cluster = ONE running PostgreSQL instance (NOT multiple servers!)
-- Database = logical container, isolated from other databases
-- Schema = namespace inside a database (default: public)
-- Table = data organized in rows (records) and columns (fields)

-- === TERM REFERENCE ===

-- Table Terms:
-- Table    = also called: Relation
-- Row      = also called: Tuple, Record
-- Column   = also called: Attribute, Field
-- Cell     = intersection of row and column (one value)
-- Primary Key = unique identifier for each row

-- Database Objects:
-- Index    = makes searches faster (like a book index)
-- View     = saved query, used like a table
-- Function = reusable code inside the database
-- Trigger  = auto-runs code on INSERT/UPDATE/DELETE
-- Sequence = generates unique numbers (used for auto IDs)
-- Extension = add-on feature (PostGIS, pgcrypto, etc.)

-- Connection Terms:
-- Role       = user or group (PG uses one concept for both)
-- Session    = one connection to the database
-- Transaction = set of operations: all succeed or all fail
-- Port       = network address (default: 5432)
-- Superuser  = admin role with all privileges (default: postgres)

-- Default Databases:
-- postgres   = default admin database
-- template0  = clean, unmodified template
-- template1  = template used when creating new databases

-- Important Files (Debian/Ubuntu):
-- Data directory:    /var/lib/postgresql/16/main/
-- postgresql.conf:   /etc/postgresql/16/main/postgresql.conf
-- pg_hba.conf:       /etc/postgresql/16/main/pg_hba.conf
-- pg_ident.conf:     /etc/postgresql/16/main/pg_ident.conf
-- WAL directory:     /var/lib/postgresql/16/main/pg_wal/

-- Important Files (RHEL/Rocky):
-- Data directory:    /var/lib/pgsql/16/data/
-- postgresql.conf:   /var/lib/pgsql/16/data/postgresql.conf
-- pg_hba.conf:       /var/lib/pgsql/16/data/pg_hba.conf

-- === PRACTICE EXERCISES ===

-- Exercise 1:
-- Draw the PostgreSQL hierarchy from memory:
-- Cluster → Database → Schema → Table

-- Exercise 2:
-- What are the 3 default databases created on install?
-- What is each one used for?

-- Exercise 3:
-- What is the difference between a row and a column?
-- Give an example using a students table.

-- Exercise 4:
-- Name 5 objects you can create inside a schema besides tables.

-- Exercise 5:
-- Your friend says "cluster of PG servers for HA."
-- Explain why 'cluster' means something different in PostgreSQL.

-- === ANSWER KEY ===

-- Answer 1:
-- Cluster (PG server instance) -> Database (isolated project) -> Schema (folder/namespace) -> Table (rows & columns).

-- Answer 2:
-- postgres (default admin/connection DB), template1 (blueprint copied by CREATE DATABASE),
-- template0 (clean factory fallback template, never modify).

-- Answer 3:
-- Row (tuple) = one complete record (e.g., student Ravi, age 20).
-- Column (attribute) = one field across all records (e.g., name, email).

-- Answer 4:
-- Views, Indexes, Sequences, Functions/Procedures, Custom Data Types (also Triggers, Domains).

-- Answer 5:
-- Outside PG, 'cluster' means multiple servers. Inside PostgreSQL, a 'cluster'
-- is ONE running PostgreSQL server instance managing multiple databases on one data directory.

-- =============================================
-- Next Class: Install PostgreSQL 16
-- =============================================
