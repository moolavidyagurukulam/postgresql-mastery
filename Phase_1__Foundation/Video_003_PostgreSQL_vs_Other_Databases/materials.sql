-- =============================================
-- PostgreSQL Mastery: PostgreSQL vs Other Databases
-- Phase 1: Foundation | Class 03
-- =============================================
-- Comparison of PostgreSQL with MySQL, Oracle, SQL Server, MongoDB.
-- No SQL commands yet — comparison/decision class.
-- =============================================

-- === KEY COMPARISONS ===

-- PostgreSQL vs MySQL:
-- - PG: Most SQL-compliant, JSONB, arrays, custom types, full MVCC
-- - MySQL: Simpler setup, larger install base, dual license (free/paid)
-- - Choose PG when: advanced SQL needed, complex data types, enterprise features
-- - Choose MySQL when: simple app, team already knows it

-- PostgreSQL vs Oracle:
-- - PG: FREE, partitioning included, replication included
-- - Oracle: $17,500-$47,500/CPU, paid add-ons for many features
-- - PG matches most Oracle features at zero cost
-- - Oracle stronger for: extreme scale (RAC), very complex optimizer scenarios

-- PostgreSQL vs SQL Server:
-- - PG: Vendor-neutral, runs everywhere, no data limits
-- - MSSQL: Best in Microsoft ecosystem, Express limited to 10GB
-- - Choose PG when: vendor independence matters, non-Microsoft stack
-- - Choose MSSQL when: heavy .NET/Azure investment

-- PostgreSQL vs MongoDB:
-- - PG: Relational + JSONB, full ACID, JOINs, foreign keys
-- - MongoDB: Native JSON, schema-flexible, built-in sharding
-- - Choose PG when: data has relationships, need transactions
-- - Choose MongoDB when: truly schema-less, no relationships

-- === DECISION FRAMEWORK ===

-- Q1: Budget concern? → Eliminate Oracle, SQL Server Enterprise
-- Q2: Need advanced SQL? → PostgreSQL over MySQL
-- Q3: Microsoft ecosystem? → SQL Server fits; otherwise PostgreSQL
-- Q4: Truly schema-less, no relationships? → MongoDB; otherwise PG
-- Q5: Need enterprise features for free? → PostgreSQL wins

-- === PRACTICE EXERCISES ===

-- Exercise 1:
-- A startup builds a social media app: profiles, posts, comments,
-- likes, followers. Which database? Why?

-- Exercise 2:
-- A bank pays Rs 50 lakh/year for Oracle licenses. OLTP workload.
-- Can they switch to PostgreSQL? What do they gain and lose?

-- Exercise 3:
-- Developer building a simple blog. MySQL or PostgreSQL?
-- What 3 questions would you ask to help them decide?

-- Exercise 4:
-- Name one thing Oracle can do that PostgreSQL cannot.
-- Name one thing PostgreSQL does free that Oracle charges for.

-- Exercise 5:
-- Project has relational data AND JSON documents from an API.
-- Should they use PostgreSQL, MongoDB, or both? Explain.

-- =============================================
-- Next Class: PostgreSQL Distributions
-- =============================================
