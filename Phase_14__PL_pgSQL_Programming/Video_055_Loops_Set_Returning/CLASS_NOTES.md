# PL/pgSQL Loops & Set-Returning Functions
**Series:** PostgreSQL Mastery | **Phase:** Phase 14: PL/pgSQL Programming | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover PL/pgSQL loops and set-returning functions. Loops let you repeat code — iterate over ranges, query results, or arrays. Set-returning functions let a function return multiple rows, like a virtual table. These are powerful tools for batch processing and data generation. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### PL/pgSQL Loop Types
PL/pgSQL has four loop types. The basic LOOP runs forever until you EXIT. WHILE loops check a condition before each iteration. FOR loops iterate over integer ranges or query results. FOREACH iterates over array elements. Each has its use case — FOR over query results is the most common in practice.

| Term | Meaning / Explanation |
| :--- | :--- |
| **LOOP** | Infinite loop — EXIT WHEN condition to stop |
| **WHILE** | Condition checked before each iteration |
| **FOR i IN 1..10** | Integer range loop (inclusive both ends) |
| **FOR rec IN SELECT...** | Loop over query results (most common!) |
| **FOREACH x IN ARRAY arr** | Loop over array elements |

**Notes:**
- EXIT: leave the loop immediately
- CONTINUE: skip to next iteration

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Beginner Trap: RETURN NEXT Memory Usage
Beginner trap: RETURN NEXT stores rows in memory until the function completes. For very large result sets — millions of rows — this can use a lot of memory. RETURN QUERY is more efficient because PostgreSQL can stream results. If you need to generate millions of rows, consider using generate_series built-in function instead, or use a cursor-based approach.

| RETURN NEXT (Buffered) | RETURN QUERY (Streamed) |
| :--- | :--- |
| Stores ALL rows in memory | Results can be streamed to caller |
| Returns them when function ends | More memory-efficient for large sets |
| Fine for small results (< 10K rows) | Faster for simple query transforms |
| Custom per-row logic possible | No per-row PL/pgSQL overhead |
| Can combine multiple sources | Prefer for large, simple results |

### Decision Framework: Loops & Returns
When should you use which loop or return pattern? Here is the decision framework. For a known count, use FOR with integer range. For query row processing, use FOR rec IN SELECT. For conditional repetition, use WHILE. For array processing, use FOREACH. For returning custom computed rows, use RETURN NEXT. For returning query results, prefer RETURN QUERY. For very large datasets, avoid RETURN NEXT — use RETURN QUERY or a procedure instead.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When should you use which loop or return pattern? |
| **For a known count** | use FOR with integer range |
| **For query row processing** | use FOR rec IN SELECT |
| **Point 4** | For conditional repetition, use WHILE |
| **Point 5** | For array processing, use FOREACH |
| **For returning custom computed rows** | use RETURN NEXT |
| **For returning query results** | prefer RETURN QUERY |
| **For very large datasets** | avoid RETURN NEXT — use RETURN QUERY or a procedure instead |

### Practice Exercises
Practice exercises: write a WHILE loop that finds the first power of 2 exceeding a given number, use FOR to loop over query results and build a summary, create a test data generator with RETURN NEXT, use FOREACH to process an array of account IDs, and try labeled loops with EXIT.

- 1. WHILE: find smallest power of 2 greater than N
- 2. FOR i IN 1..10: build a multiplication table
- 3. FOR rec IN SELECT: loop accounts, sum balances
- 4. RETURN NEXT: Fibonacci number generator
- 5. RETURN QUERY: accounts filtered by balance range
- 6. FOREACH: sum array of IDs' balances
- 7. CONTINUE WHEN: skip accounts with bal < 100
- 8. Test data: generate_test_accounts(1000)


---

## 3. Hands-On Commands & psql Output

### Basic LOOP with EXIT
**Explanation:** The basic LOOP repeats forever until you use EXIT or EXIT WHEN. Use it when you do not know the number of iterations in advance. EXIT WHEN stops the loop when the condition is true. You can also use EXIT by itself inside an IF block. CONTINUE WHEN skips the rest of the current iteration and goes to the next one.

```sql
practice=# CREATE OR REPLACE FUNCTION countdown(n INT)
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
    i INT := n;
BEGIN
    LOOP
        EXIT WHEN i <= 0;
        result := result || i || ' ';
        i := i - 1;
    END LOOP;
    RETURN result || 'Go!';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

practice=# SELECT countdown(5);
 5 4 3 2 1 Go!
```

### WHILE and FOR Integer Loops
**Explanation:** WHILE loops check a condition before each iteration — if the condition is false from the start, the body never runs. FOR loops with integer ranges are the most readable — specify start, end, and an optional step. BY 2 counts by twos, REVERSE counts backward. The range is inclusive on both ends.

```sql
practice=# CREATE OR REPLACE FUNCTION factorial(n INT)
RETURNS BIGINT AS $$
DECLARE
    result BIGINT := 1;
    i INT := n;
BEGIN
    WHILE i > 1 LOOP
        result := result * i;
        i := i - 1;
    END LOOP;
    RETURN result;
END; $$ LANGUAGE plpgsql IMMUTABLE;

practice=# SELECT factorial(5);
 120

-- FOR integer range (inclusive both ends)
-- FOR i IN 1..5 LOOP        → 1,2,3,4,5
-- FOR i IN 1..10 BY 2 LOOP  → 1,3,5,7,9
-- FOR i IN REVERSE 5..1 LOOP → 5,4,3,2,1
```

### FOR Loop Over Query Results
**Explanation:** FOR over query results is the most useful loop pattern. The loop variable is automatically a record that holds each row. You access columns with dot notation — rec.name, rec.bal. This is how you process rows one at a time inside a function — apply logic, accumulate results, or make decisions per row.

```sql
practice=# CREATE OR REPLACE FUNCTION account_report()
RETURNS TEXT AS $$
DECLARE
    rec RECORD;
    report TEXT := '';
BEGIN
    FOR rec IN SELECT name, bal FROM accounts ORDER BY bal DESC
    LOOP
        report := report || format('%s: $%s', rec.name, rec.bal);
        IF rec.bal >= 1000 THEN
            report := report || ' (VIP)';
        END IF;
        report := report || E'\n';
    END LOOP;
    RETURN report;
END; $$ LANGUAGE plpgsql STABLE;

practice=# SELECT account_report();
 Alice: $1000.00 (VIP)
 Bob: $500.00
 Carol: $300.00
```

### RETURN NEXT — Build Result Set Row by Row
**Explanation:** Set-returning functions return multiple rows. Use RETURNS TABLE to define the output columns, then RETURN NEXT to add each row, or RETURN QUERY to return an entire query result at once. RETURN NEXT is used inside loops — you build the result set one row at a time. The function finishes when it reaches the end of the body.

```sql
practice=# CREATE OR REPLACE FUNCTION generate_series_custom(
    start_val INT, end_val INT
) RETURNS TABLE(num INT, squared INT) AS $$
BEGIN
    FOR i IN start_val..end_val LOOP
        num := i;
        squared := i * i;
        RETURN NEXT;  -- adds current row to result
    END LOOP;
END; $$ LANGUAGE plpgsql IMMUTABLE;

practice=# SELECT * FROM generate_series_custom(1, 5);
 num | squared
-----+---------
   1 |       1
   2 |       4
   3 |       9
   4 |      16
   5 |      25
```

### RETURN QUERY — Return Entire Query Results
**Explanation:** RETURN QUERY returns all rows from a query at once — no loop needed. You can call RETURN QUERY multiple times to combine results from different queries. This is often cleaner than RETURN NEXT when you are not doing per-row processing.

```sql
practice=# CREATE OR REPLACE FUNCTION accounts_by_tier(tier VARCHAR)
RETURNS TABLE(acct_name VARCHAR, balance NUMERIC) AS $$
BEGIN
    CASE tier
        WHEN 'high' THEN
            RETURN QUERY SELECT name, bal FROM accounts
                WHERE bal >= 1000 ORDER BY bal DESC;
        WHEN 'low' THEN
            RETURN QUERY SELECT name, bal FROM accounts
                WHERE bal < 400 ORDER BY bal DESC;
        ELSE
            RAISE EXCEPTION 'Unknown tier: %', tier;
    END CASE;
END; $$ LANGUAGE plpgsql STABLE;

practice=# SELECT * FROM accounts_by_tier('high');
 acct_name | balance
-----------+---------
 Alice     | 1000.00
practice=# SELECT * FROM accounts_by_tier('low');
 Carol     |  300.00
```

### FOREACH — Loop Over Arrays
**Explanation:** FOREACH loops iterate over arrays. PostgreSQL arrays are common — a column might store tags or a list of values. FOREACH gives each element in turn. Use ARRAY constructor or curly brace syntax to create arrays.

```sql
practice=# CREATE OR REPLACE FUNCTION sum_array(arr INT[])
RETURNS INT AS $$
DECLARE
    total INT := 0;
    elem  INT;
BEGIN
    FOREACH elem IN ARRAY arr LOOP
        total := total + elem;
    END LOOP;
    RETURN total;
END; $$ LANGUAGE plpgsql IMMUTABLE;

practice=# SELECT sum_array(ARRAY[10, 20, 30, 40]);
 100
practice=# SELECT sum_array('{5,15,25}');
 45
```

### EXIT, CONTINUE & Loop Labels
**Explanation:** EXIT and CONTINUE control loop flow. EXIT leaves the loop immediately. CONTINUE skips to the next iteration. Both can have a WHEN clause for conditional use. You can also label loops and EXIT or CONTINUE a specific outer loop by name — useful with nested loops.

```sql
-- EXIT: leave the loop
LOOP
    FETCH cur INTO rec;
    EXIT WHEN NOT FOUND;
    -- process rec...
END LOOP;

-- CONTINUE: skip to next iteration
FOR i IN 1..100 LOOP
    CONTINUE WHEN i % 2 = 0;  -- skip even numbers
    -- process odd numbers only
END LOOP;

-- Loop labels: EXIT specific loop
<<outer_loop>>
FOR i IN 1..10 LOOP
    <<inner_loop>>
    FOR j IN 1..10 LOOP
        EXIT outer_loop WHEN i * j > 50;
        -- exits the OUTER loop, not just inner
    END LOOP inner_loop;
END LOOP outer_loop;
```

### Practical: Test Data Generator
**Explanation:** Practical example: a test data generator. This set-returning function creates realistic sample accounts with random names and balances. You can use it to populate tables for testing. INSERT INTO accounts SELECT * FROM generate_test_accounts(100) creates 100 test rows instantly. This pattern is much better than writing a hundred INSERT statements by hand.

```sql
practice=# CREATE OR REPLACE FUNCTION generate_test_accounts(count INT)
RETURNS TABLE(id INT, name VARCHAR, bal NUMERIC) AS $$
DECLARE
    names TEXT[] := ARRAY['Alice','Bob','Carol','Dave',
        'Eve','Frank','Grace','Hank','Ivy','Jack'];
BEGIN
    FOR i IN 1..count LOOP
        id := i + 100;
        name := names[1 + (i % array_length(names, 1))]
               || '_' || i;
        bal := ROUND((random() * 9000 + 100)::NUMERIC, 2);
        RETURN NEXT;
    END LOOP;
END; $$ LANGUAGE plpgsql;

practice=# SELECT * FROM generate_test_accounts(5);
 id  |  name   |   bal
-----+---------+---------
 101 | Bob_1   | 4523.17
 102 | Carol_2 | 7891.44
 103 | Dave_3  |  312.89
 104 | Eve_4   | 5678.23
 105 | Frank_5 | 2145.67
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: RETURN NEXT Memory Usage
Beginner trap: RETURN NEXT stores rows in memory until the function completes. For very large result sets — millions of rows — this can use a lot of memory. RETURN QUERY is more efficient because PostgreSQL can stream results. If you need to generate millions of rows, consider using generate_series built-in function instead, or use a cursor-based approach.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. LOOP runs forever until EXIT. WHILE checks a condition first. FOR iterates over integer ranges or query results — the most common pattern. FOREACH processes arrays. RETURN NEXT builds result sets row by row. RETURN QUERY returns entire queries efficiently. EXIT and CONTINUE control flow, with loop labels for nested loops. Use RETURN QUERY over RETURN NEXT for large results. In the next class, we cover procedures and DO blocks.

- **LOOP ... EXIT WHEN ... END LOOP**
- **WHILE condition LOOP ... END LOOP**
- **FOR i IN 1..N [BY step] / REVERSE N..1**
- **FOR rec IN SELECT ... LOOP: query rows**
- **FOREACH elem IN ARRAY arr: array elements**
- **RETURN NEXT: add one row (buffered)**
- **RETURN QUERY: add all query rows (streamed)**
- **EXIT / CONTINUE WHEN: loop control**
- **<<label>>: name loops for nested EXIT**


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
