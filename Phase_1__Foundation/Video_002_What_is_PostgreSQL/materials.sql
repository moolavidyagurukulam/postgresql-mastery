-- =============================================
-- PostgreSQL Mastery: What is PostgreSQL?
-- Phase 1: Foundation | Class 02
-- =============================================
-- This file contains all concepts from the class.
-- No SQL commands yet — this is a concept/history class.
-- SQL starts from the Installation class onwards.
-- =============================================

-- === KEY CONCEPTS ===

-- 1. PostgreSQL = Free, open-source, relational DBMS
--    - Free: No cost, even for commercial projects
--    - Open Source: Full source code available, community-driven
--    - Relational: Tables with rows/columns, linked by relationships
--    - DBMS: Software that stores, protects, and serves data

-- 2. History:
--    - 1986: Started at UC Berkeley by Prof. Michael Stonebraker
--    - Named POSTGRES (Post-Ingres)
--    - 1996: Renamed PostgreSQL (added SQL support)
--    - Community took over open-source development
--    - New major version released every year
--    - Current: PostgreSQL 16 (used in this course)

-- 3. Pronunciation: post-GRES-Q-L or post-GRES
--    (NOT post-gray-SQL)

-- 4. Key Strengths:
--    - Standards compliance (most SQL-standard-compliant DB)
--    - Extensibility (custom types, operators, extensions)
--    - Data integrity (full ACID transactions)
--    - Advanced features (JSON, full-text search, partitioning)
--    - Community (thousands of contributors)
--    - Cost (100% free forever)

-- 5. Who uses PostgreSQL:
--    Apple, Instagram, Spotify, Netflix, Reddit,
--    International Space Station, banks, governments

-- 6. When to use PostgreSQL:
--    - Strong data integrity needs (banking, healthcare)
--    - Complex queries and advanced SQL
--    - JSON + relational data together
--    - General-purpose applications (80%+ of projects)

-- === PRACTICE EXERCISES ===

-- Exercise 1:
-- Visit https://www.postgresql.org and find the download page.
-- What is the latest stable version available?

-- Exercise 2:
-- Name 3 companies that use PostgreSQL.
-- For each, think about what kind of data they store.

-- Exercise 3:
-- What does "open source" mean?
-- Why is it important for a database?
-- Write your answer in your own words.

-- Exercise 4:
-- PostgreSQL was created in 1986.
-- How many years has it been in development?
-- Name 3 other software products that have survived this long.

-- Exercise 5:
-- A startup is building a food delivery app.
-- They need: restaurants, menus, orders, delivery addresses, payments.
-- Would you recommend PostgreSQL? Why or why not?

-- === ANSWER KEY ===

-- Answer 1:
-- Visit https://www.postgresql.org/download/ ? PostgreSQL 16 is our course
-- baseline, alongside the newest stable release listed on the download page.

-- Answer 2:
-- Instagram (user posts, comments & likes), Spotify (music catalog & playlists),
-- and Netflix (internal studio tools & analytics).

-- Answer 3:
-- Open source means the source code is publicly visible and free to use,
-- audit, and improve ? zero license fees, no vendor lock-in, faster security audits.

-- Answer 4:
-- Over 38+ years of continuous development since 1986.
-- Other long-lived software: Oracle (1979), GCC (1987), Linux (1991), Python (1991).

-- Answer 5:
-- YES ? PostgreSQL is ideal. Relational tables link restaurants, menus,
-- orders, and delivery addresses cleanly, while ACID transactions protect payments.

-- =============================================
-- Next Class: PostgreSQL vs Other Databases
-- =============================================
