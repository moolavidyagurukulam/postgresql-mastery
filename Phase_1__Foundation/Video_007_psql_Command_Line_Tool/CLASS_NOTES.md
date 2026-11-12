# psql Command-Line Tool
**Series:** PostgreSQL Mastery | **Phase:** Phase 1: Foundation | **Classes:** Class 07
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In our previous class, we installed PostgreSQL 16 and connected for the first time. Today, we master psql ... the most powerful tool for working with PostgreSQL. psql is the official command-line client. Every DBA uses it daily. By the end of this class, you will be comfortable navigating, querying, and managing PostgreSQL from the command line. ... Let us dive in!

### The Problem: Blank Prompt, Now What?
Here is a common situation. You just installed PostgreSQL. You open psql and you see a blank prompt. Now what? How do you see what databases exist? How do you list tables? How do you run a query? How do you see the structure of a table? ... psql has dozens of useful commands, but beginners feel lost because they do not know any of them. Today, we learn the essential psql commands that you will use every single day.

- You open psql — you see a blank prompt
- How do I list databases?
- How do I list tables?
- How do I see a table's structure?
- How do I run a file of SQL commands?
- Today: Learn the essential psql commands you'll use DAILY


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Blank Prompt, Now What?
Here is a common situation. You just installed PostgreSQL. You open psql and you see a blank prompt. Now what? How do you see what databases exist? How do you list tables? How do you run a query? How do you see the structure of a table? ... psql has dozens of useful commands, but beginners feel lost because they do not know any of them. Today, we learn the essential psql commands that you will use every single day.

- You open psql — you see a blank prompt
- How do I list databases?
- How do I list tables?
- How do I see a table's structure?
- How do I run a file of SQL commands?
- Today: Learn the essential psql commands you'll use DAILY

### SQL Commands vs Meta-Commands
psql has two types of commands. SQL commands and meta-commands. ... SQL commands are standard SQL like SELECT, INSERT, CREATE TABLE. These end with a semicolon. ... Meta-commands start with a backslash. They are psql-specific and do NOT need a semicolon. For example, backslash l lists databases. backslash dt lists tables. backslash q quits psql. ... The most important meta-command to remember is backslash question mark. It shows the help for ALL meta-commands. If you ever forget a command, just type backslash question mark.

| SQL Commands | Meta-Commands (backslash) |
| :--- | :--- |
| Standard SQL: SELECT, INSERT, CREATE | psql-specific shortcuts |
| End with semicolon (;) | Start with backslash (\) |
| Work in any SQL tool | NO semicolon needed |
| Example: SELECT * FROM users; | Example: \l (list databases) |
| Example: CREATE TABLE test (id INT); | Example: \dt (list tables) |
|  | \? = show ALL meta-commands |

### psql Listing Commands — Cheat Sheet
Keep this complete listing cheat sheet handy whenever you work in psql. ... Remember the simple rule: backslash l lists databases, backslash c connects to another database, and backslash d describes things. ... Add a second letter to target exactly what you need: n for schemas, t for tables, i for indexes, v for views, f for functions, and u for users. ... Add a plus sign like backslash d plus for extra table details, and backslash question mark anytime for help!

| Command | What It Shows |
| :--- | :--- |
| \l | List all databases |
| \c dbname | Switch to database |
| \dn | List schemas |
| \dt | List tables (current schema) |
| \dt schema.* | List tables in a specific schema |
| \di | List indexes |
| \dv | List views |
| \df | List functions |
| \du | List roles/users |
| \d tablename | Describe table structure |
| \d+ tablename | Describe with extra detail |
| \? | Show ALL meta-commands help |

### History & Tab Completion
psql remembers your command history. Press the up arrow key to scroll through previous commands. This saves a lot of retyping. ... You can also search your history with Ctrl plus R. Start typing part of a command and it finds the match. ... Tab completion is another time-saver. Start typing a table name or command, press Tab, and psql auto-completes it. If there are multiple matches, press Tab twice to see all options.

- UP ARROW — scroll through previous commands
- CTRL + R — search command history
- TAB — auto-complete table names, columns, commands
- TAB TAB — show all possible completions
- History saved in ~/.psql_history file
- These save HOURS of retyping over time!


---

## 3. Hands-On Commands & psql Output

### Connecting with psql
**Explanation:** First, let us learn the different ways to connect with psql. ... The simplest way is sudo minus u postgres psql on Linux. This connects you to the default postgres database as the postgres superuser. ... To connect to a specific database, add minus d and the database name. psql minus U postgres minus d practice connects to our practice database. ... You can also specify a host and port for remote connections. psql minus h hostname minus p 5432 minus U postgres minus d practice. ... One very useful option is minus c to run a single command without entering the interactive prompt. psql minus c SELECT version semicolon runs the query and exits.

```sql
-- Connect to default database as postgres user
$ sudo -u postgres psql

-- Connect to a specific database
$ psql -U postgres -d practice

-- Connect to a remote server
$ psql -h 192.168.1.100 -p 5432 -U postgres -d practice

-- Run a single command and exit
$ psql -U postgres -c 'SELECT version();'
PostgreSQL 16.6 on x86_64-pc-linux-gnu

-- Run a SQL file
$ psql -U postgres -d practice -f script.sql
```

### Essential Listing Commands
**Explanation:** Let me show you the most important listing commands. These are the commands you will use every day to navigate your databases. ... backslash l lists all databases. ... backslash c database name switches to a different database. ... backslash dn lists all schemas. ... backslash dt lists all tables in the current schema. ... backslash di lists all indexes. ... backslash dv lists all views. ... backslash df lists all functions. ... backslash du lists all roles and users. ... The pattern is simple. backslash d means describe. The letter after d tells you what to describe. t for tables, i for indexes, v for views, f for functions, u for users.

```sql
-- List all databases
practice=# \l
   Name    |  Owner   | Encoding
-----------+----------+----------
 postgres  | postgres | UTF8
 practice  | postgres | UTF8
 template0 | postgres | UTF8
 template1 | postgres | UTF8

-- Switch to a different database
practice=# \c postgres
You are now connected to database "postgres" as user "postgres".

-- List schemas, tables, indexes, views, functions, users
postgres=# \dn
  Name  | Owner
--------+----------
 public | pg_database_owner
```

### Describe a Table: \d tablename
**Explanation:** One of the most useful commands is backslash d followed by a table name. This shows the structure of that table ... columns, data types, and constraints. ... Let me create a quick test table so we can see this in action. ... First, CREATE TABLE students with id, name, email, and age columns. Then run backslash d students. You can see every column, its data type, whether it allows nulls, and the default value. ... For more detail, use backslash d plus ... that is backslash d with a plus sign. It shows additional information like storage type and description.

```sql
-- Create a test table first
practice=# CREATE TABLE students (id SERIAL PRIMARY KEY, name VARCHAR(100) NOT NULL, email VARCHAR(150) UNIQUE, age INT CHECK (age > 0));
CREATE TABLE

-- Describe the table structure
practice=# \d students
                         Table "public.students"
 Column |          Type          | Nullable |    Default
--------+------------------------+----------+----------------
 id     | integer                | not null | nextval(...)
 name   | character varying(100) | not null |
 email  | character varying(150) |          |
 age    | integer                |          |
Indexes: "students_pkey" PRIMARY KEY (id)
         "students_email_key" UNIQUE (email)
Check: "students_age_check" CHECK (age > 0)
```

### Running SQL in psql
**Explanation:** Now let us run some SQL inside psql. ... Every SQL statement must end with a semicolon. If you forget the semicolon, psql waits for more input. You will see the prompt change from hash to a dash. Just type the semicolon and press Enter. ... If you make a mistake and want to cancel, press Ctrl plus C. This cancels the current query. ... Let us insert some data into our students table and query it.

```sql
-- Insert some test data
practice=# INSERT INTO students (name, email, age) VALUES ('Ravi', 'ravi@example.com', 22);
INSERT 0 1
practice=# INSERT INTO students (name, email, age) VALUES ('Priya', 'priya@example.com', 25);
INSERT 0 1

-- Query the data
practice=# SELECT * FROM students;
 id | name  |       email       | age
----+-------+-------------------+-----
  1 | Ravi  | ravi@example.com  |  22
  2 | Priya | priya@example.com |  25
(2 rows)

-- Forgot semicolon? Prompt changes to - (just type ; and Enter)
practice=# SELECT * FROM students
practice-# ;
```

### Useful psql Features
**Explanation:** psql has several useful features that make your life easier. ... backslash timing turns on query timing. After every query, it shows how long it took. This is essential for performance tuning. ... backslash x turns on expanded display. Instead of showing results in a table, it shows each column on its own line. Very useful for tables with many columns. ... backslash o filename redirects output to a file. Everything you query goes to that file instead of the screen. backslash o with no filename turns it off. ... backslash i filename runs a SQL file. All the commands in that file get executed. ... backslash e opens your default text editor with the last query, so you can edit and re-run it.

```sql
-- Turn on query timing
practice=# \timing
Timing is on.
practice=# SELECT count(*) FROM students;
 count
-------
     2
Time: 0.542 ms

-- Expanded display (vertical format)
practice=# \x
Expanded display is on.
practice=# SELECT * FROM students WHERE id = 1;
-[ RECORD 1 ]------------------
id    | 1
name  | Ravi
email | ravi@example.com
age   | 22
```

### Working with Files in psql
**Explanation:** Let me show you how to work with files in psql. ... backslash i runs a SQL file. This is perfect for running scripts you saved. ... backslash o sends query output to a file. ... backslash copy can import and export CSV files. We will cover COPY in detail in a later class. ... The backslash exclamation mark runs a shell command without leaving psql. Very handy for quick checks.

```sql
-- Run a SQL file
practice=# \i /home/postgres/setup.sql
CREATE TABLE
INSERT 0 5

-- Send query output to a file
practice=# \o /tmp/report.txt
practice=# SELECT * FROM students;
practice=# \o
-- Output is now back to screen. File saved!

-- Run a shell command without leaving psql
practice=# \! ls /tmp/report.txt
/tmp/report.txt

-- Show current working directory
practice=# \! pwd
/var/lib/postgresql
```

### Common psql Mistakes
**Explanation:** Common psql mistakes. ... Mistake 1 ... Forgetting the semicolon. Your query just hangs. The prompt changes from hash to dash. Solution ... type a semicolon and press Enter. Or press Ctrl plus C to cancel. ... Mistake 2 ... Typing backslash dt and seeing no tables. This means there are no tables in the current schema, or you are in the wrong database. Check with backslash conninfo. ... Mistake 3 ... Confusing backslash q with quit. Just typing quit does not work. You must type backslash q. ... Mistake 4 ... Running a command meant for bash inside psql, like sudo or apt. psql only understands SQL and meta-commands. Use backslash exclamation mark for shell commands.

```sql
-- MISTAKE 1: Forgot semicolon — query hangs
practice=# SELECT * FROM students
practice-# -- Prompt changed to - (waiting for ;)
practice-# ;
-- Or press CTRL+C to cancel

-- MISTAKE 2: \dt shows nothing — no tables yet!
practice=# \dt
Did not find any relations.
-- Check: are you in the right database? \conninfo

-- MISTAKE 3: typing 'quit' instead of \q
practice=# quit
ERROR:  syntax error at or near "quit"
-- FIX: use \q to exit psql
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common psql Mistakes
Common psql mistakes. ... Mistake 1 ... Forgetting the semicolon. Your query just hangs. The prompt changes from hash to dash. Solution ... type a semicolon and press Enter. Or press Ctrl plus C to cancel. ... Mistake 2 ... Typing backslash dt and seeing no tables. This means there are no tables in the current schema, or you are in the wrong database. Check with backslash conninfo. ... Mistake 3 ... Confusing backslash q with quit. Just typing quit does not work. You must type backslash q. ... Mistake 4 ... Running a command meant for bash inside psql, like sudo or apt. psql only understands SQL and meta-commands. Use backslash exclamation mark for shell commands.

```sql
-- MISTAKE 1: Forgot semicolon — query hangs
SELECT * FROM students
-- Prompt changed to - (waiting for ;)
;
-- Or press CTRL+C to cancel

-- MISTAKE 2: \dt shows nothing — no tables yet!
\dt
Did not find any relations.
-- Check: are you in the right database? \conninfo

-- MISTAKE 3: typing 'quit' instead of \q
quit
ERROR:  syntax error at or near "quit"
-- FIX: use \q to exit psql
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time! ... Exercise 1 ... Connect to the practice database. List all databases with backslash l. Switch to the postgres database and back to practice. ... Exercise 2 ... Create a table called products with columns: id SERIAL PRIMARY KEY, name VARCHAR 100, price NUMERIC 10,2, in_stock BOOLEAN. Describe it with backslash d. ... Exercise 3 ... Insert 3 products. Query them. Turn on timing and run the query again to see execution time. ... Exercise 4 ... Turn on expanded display with backslash x. Run SELECT star FROM products. See the difference. Turn it off. ... Exercise 5 ... Export the products data to a file using backslash o. Check the file exists using backslash exclamation mark.

1. Exercise 1: \l → \c postgres → \c practice (switch databases)
2. Exercise 2: CREATE TABLE products (...) then \d products
3. Exercise 3: INSERT 3 rows, SELECT *, turn on \timing
4. Exercise 4: \x on → SELECT * → see expanded → \x off
5. Exercise 5: \o /tmp/data.txt → SELECT * → \o → check with \! cat /tmp/data.txt


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... psql is the official command-line client for PostgreSQL. ... Connect with psql minus U postgres minus d practice. ... Meta-commands start with backslash. SQL commands end with semicolon. ... Essential commands: backslash l for databases, backslash dt for tables, backslash d for table structure, backslash c to switch database. ... Useful features: backslash timing, backslash x for expanded display, backslash i to run files, backslash o for output redirection. ... Up arrow for history, Tab for auto-completion. ... backslash q to quit. backslash question mark for help. ... In our next class, we explore pgAdmin, the graphical tool for PostgreSQL!

- **Connect: psql -U postgres -d practice**
- **Meta-commands: backslash (\) — no semicolon needed**
- **\l = databases, \dt = tables, \d = structure, \c = switch DB**
- **\timing = show query time, \x = expanded display**
- **\i = run file, \o = output to file, \! = shell command**
- **UP arrow = history, TAB = auto-complete**
- **\q = quit, \? = show all help**


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
