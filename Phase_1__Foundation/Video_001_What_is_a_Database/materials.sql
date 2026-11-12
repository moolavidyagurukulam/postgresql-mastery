-- =============================================
-- PostgreSQL Mastery: What is a Database?
-- Phase 1: Foundation | Class 01
-- =============================================
-- This file contains all concepts and exercises from the class.
-- No SQL commands in this class — it's a concept introduction.
-- SQL starts from the Installation class onwards.
-- =============================================

-- === KEY CONCEPTS ===

-- 1. Database = An organized collection of data that can be
--    easily accessed, managed, and updated.

-- 2. Why databases exist:
--    - Notebooks don't scale beyond a few records
--    - Spreadsheets can't handle large data, concurrent users,
--      rules enforcement, or relationships between data

-- 3. Types of Databases:
--    - Relational (PostgreSQL, MySQL, Oracle) → Tables with relationships
--    - Document (MongoDB) → JSON documents
--    - Key-Value (Redis) → Simple key → value pairs
--    - Graph (Neo4j) → Nodes and connections

-- 4. Database vs DBMS:
--    - Database = the actual data (tables, rows, information)
--    - DBMS = the software that manages data (PostgreSQL, MySQL)

-- 5. When to use a database:
--    - Large data (thousands+ records)
--    - Multiple users accessing simultaneously
--    - Need data rules (price > 0, unique emails)
--    - Need security (who can see/edit what)
--    - Data has relationships (customers → orders → products)

-- === PRACTICE EXERCISES ===

-- Exercise 1:
-- Name 3 applications you use daily that definitely have
-- a database behind them. For each, think about what data
-- the database stores.

-- Exercise 2:
-- Your friend runs a small bakery with 20 customers.
-- Should they use a database or a spreadsheet? Why?
-- What if the bakery grows to 5 chains with 50,000 customers?

-- Exercise 3:
-- A hospital wants to store patient records, doctor schedules,
-- and billing. Which type of database would you recommend?
-- Hint: Think about relationships between patients, doctors,
-- appointments, and bills.

-- Exercise 4:
-- What is the difference between a database and a DBMS?
-- Explain in your own words using the bank analogy:
-- Database = money in the locker
-- DBMS = the bank that protects your money

-- Exercise 5:
-- An online shopping site has Customers, Products, and Orders.
-- Draw the relationships:
-- - A Customer can place many Orders
-- - An Order contains many Products
-- - A Product can appear in many Orders
-- How would you connect these tables?

-- === ANSWER KEY ===

-- Answer 1:
-- Apps like Swiggy/Zomato (restaurants, menus, orders), banking apps
-- (accounts, balances, transactions), and Instagram (users, posts, likes).

-- Answer 2:
-- 20 customers -> A simple spreadsheet is enough (do not over-engineer).
-- 5 chains with 50,000 customers -> Use a Relational Database (PostgreSQL).

-- Answer 3:
-- Relational Database (PostgreSQL) ? patient records, doctor schedules,
-- and billing require strict rules and linked tables.

-- Answer 4:
-- Database = the stored data itself (money in the locker).
-- DBMS = the software managing and protecting it (the bank).

-- Answer 5:
-- Connect Customers -> Orders using customer_id, and
-- connect Products -> Orders using product_id (or an OrderItems bridge table).

-- =============================================
-- Next Class: What is PostgreSQL?
-- =============================================
