# Large Objects — Storing Binary Files
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! This is our final class in Phase 25. How do you store large binary files in PostgreSQL — images, PDFs, videos, or backups? PostgreSQL gives you two options: bytea columns for small to medium files, and large objects for truly large files that need streaming access. Today we compare both approaches and learn when to use each one.


---

## 2. Core Technical Concepts & Mechanisms

### bytea vs Large Objects
PostgreSQL has two ways to store binary data. The bytea type stores binary data as a column value — limited to 1 GB, loaded entirely into memory. Large objects store data in a system table called pg_largeobject and support streaming, seeking, and partial reads — they can hold up to 4 TB.

| bytea Column | Large Objects (lo) |
| :--- | :--- |
| Stores binary as column value | Stored in pg_largeobject table |
| Max 1 GB per value | Max 4 TB per object |
| Loaded entirely into memory | Supports streaming (read/write chunks) |
| Simple: just a column type | Seek to any position in the file |
| Works with regular INSERT/SELECT | Referenced by OID (integer) |
| Best for: <10 MB files | Best for: >10 MB files |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Database Storage vs Filesystem
Here is a decision framework for when to store files in the database versus on the filesystem.

| Store in Database When | Store on Filesystem When |
| :--- | :--- |
| Files < 10 MB (use bytea) | Files > 10 MB (or many files) |
| Need transactional consistency | Need CDN or direct HTTP serving |
| Backup must include files | Database backup size is a concern |
| Files must follow row-level security | High-throughput file access needed |
| Simple architecture (no file server) | Cloud storage (S3, GCS) available |

### Large Object Functions Reference
Here is a complete reference of large object functions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a complete reference of large object functions |


---

## 3. Hands-On Commands & psql Output

### bytea — Storing Small Binary Data
**Explanation:** Let us start with bytea — the simpler approach. You define a column as bytea and store binary data in it. Use the encode and decode functions to convert between bytea and other formats.

```sql
postgres=# -- Create table with bytea column:
postgres=# CREATE TABLE attachments (
    id serial PRIMARY KEY,
    filename text NOT NULL,
    mime_type text NOT NULL,
    file_size int,
    data bytea NOT NULL,
    uploaded_at timestamptz DEFAULT now()
);
postgres=# -- Insert binary data (hex format):
postgres=# INSERT INTO attachments (filename, mime_type, file_size, data)
postgres-# VALUES ('hello.txt', 'text/plain', 13,
        '\x48656c6c6f2c20576f726c6421');
postgres=# -- Convert text to bytea:
postgres=# INSERT INTO attachments (filename, mime_type, file_size, data)
postgres-# VALUES ('note.txt', 'text/plain', 10,
        convert_to('Hello PG!', 'UTF8'));
postgres=# -- Read back as text:
postgres=# SELECT filename, convert_from(data, 'UTF8') AS content
postgres-# FROM attachments;
 filename  | content
postgres=# -----------+---------------
 hello.txt | Hello, World!
 note.txt  | Hello PG!
```

### Python: Insert File as bytea
**Explanation:** In real applications, you typically use your programming language to insert binary files as bytea. Here is how it looks in Python — you read the file and pass the bytes as a parameter.

```sql
import psycopg2

conn = psycopg2.connect("dbname=mydb user=postgres")
cur = conn.cursor()

# Read a file and insert as bytea:
with open('/path/to/photo.jpg', 'rb') as f:
    file_data = f.read()

cur.execute("""
    INSERT INTO attachments
        (filename, mime_type, file_size, data)
    VALUES (%s, %s, %s, %s)
""", ('photo.jpg', 'image/jpeg',
      len(file_data), psycopg2.Binary(file_data)))

conn.commit()

# Read it back:
cur.execute("""
    SELECT data FROM attachments
    WHERE filename = 'photo.jpg'
""")
file_data = cur.fetchone()[0]
with open('downloaded_photo.jpg', 'wb') as f:
    f.write(file_data)
```

### bytea Encoding Formats
**Explanation:** The bytea encoding format affects how binary appears in SQL. There are two formats: hex and escape. Hex is the default in modern PostgreSQL and shows binary as a hex string prefixed with backslash-x.

```sql
postgres=# -- Check current format:
postgres=# SHOW bytea_output;
postgres=# -- hex (default in PG 9.0+)
postgres=# -- Hex format: \x prefix + hex digits
postgres=# SELECT '\x48656c6c6f'::bytea;
postgres=# -- \x48656c6c6f
postgres=# -- Escape format: \NNN octal or printable chars
postgres=# SET bytea_output = 'escape';
postgres=# SELECT '\x48656c6c6f'::bytea;
postgres=# -- Hello
postgres=# -- Useful functions:
postgres=# SELECT length('\x48656c6c6f'::bytea);  -- 5 bytes
postgres=# SELECT encode('Hello'::bytea, 'base64'); -- SGVsbG8=
postgres=# SELECT decode('SGVsbG8=', 'base64');     -- \x48656c6c6f
postgres=# -- Reset:
postgres=# SET bytea_output = 'hex';
```

### Large Objects — SQL Interface
**Explanation:** Now let us look at large objects. They use a different API. You create a large object with lo_create, write data with lo_write, and read with lo_read. Each large object gets a unique OID that you store in your table.

```sql
postgres=# -- Create an empty large object:
postgres=# SELECT lo_create(0);  -- 0 = let PG pick the OID
 lo_create
postgres=# ----------
   16384
postgres=# -- Store the OID in your table:
postgres=# CREATE TABLE documents (
    id serial PRIMARY KEY,
    title text NOT NULL,
    file_oid oid,  -- reference to large object
    uploaded_at timestamptz DEFAULT now()
);
postgres=# INSERT INTO documents (title, file_oid)
postgres-# VALUES ('Contract PDF', 16384);
postgres=# -- Delete a large object:
postgres=# SELECT lo_unlink(16384);
```

### lo_import and lo_export
**Explanation:** The easiest way to work with large objects from psql is the lo_import and lo_export commands. lo_import loads a file from the server filesystem into a large object. lo_export saves a large object back to a file.

```sql
postgres=# -- Import a file into a large object:
postgres=# SELECT lo_import('/tmp/report.pdf');
 lo_import
postgres=# ----------
   16385
postgres=# -- Store the OID:
postgres=# INSERT INTO documents (title, file_oid)
postgres-# VALUES ('Monthly Report', 16385);
postgres=# -- Export a large object to a file:
postgres=# SELECT lo_export(16385, '/tmp/report_copy.pdf');
 lo_export
postgres=# ----------
        1
postgres=# -- Import with specific OID:
postgres=# SELECT lo_import('/tmp/logo.png', 20000);
postgres=# -- Creates large object with OID 20000
postgres=# -- NOTE: file paths are on the SERVER filesystem,
postgres=# -- not the client! The PostgreSQL process must
postgres=# -- have read/write access to those paths.
```

### Streaming with lo_open / lo_read / lo_write
**Explanation:** For streaming large objects — reading or writing in chunks — use the lo_open, lo_read, lo_write, lo_lseek, and lo_close functions. This must happen inside a transaction.

```sql
postgres=# -- Must be inside a transaction:
postgres=# BEGIN;
postgres=# -- Open for reading (INV_READ = x'40000' = 262144):
postgres=# SELECT lo_open(16385, 262144);
 lo_open
postgres=# --------
      0     -- file descriptor
postgres=# -- Read first 100 bytes:
postgres=# SELECT loread(0, 100);
postgres=# -- Returns bytea (first 100 bytes of the file)
postgres=# -- Seek to position 500:
postgres=# SELECT lo_lseek(0, 500, 0);  -- 0 = SEEK_SET
postgres=# -- Read 200 bytes from position 500:
postgres=# SELECT loread(0, 200);
postgres=# -- Close the file descriptor:
postgres=# SELECT lo_close(0);
postgres=# COMMIT;
postgres=# -- File descriptors are only valid within the transaction
```

### The lo Extension — Automatic Cleanup
**Explanation:** The lo extension provides a convenient lo data type and automatic cleanup. Without it, deleting a row does NOT delete its large object — it becomes an orphan consuming disk space.

```sql
postgres=# -- Problem: DELETE leaves orphaned large objects!
postgres=# DELETE FROM documents WHERE id = 1;
postgres=# -- Row is gone, but large object 16385 still exists!
postgres=# -- Solution: use the 'lo' extension:
postgres=# CREATE EXTENSION lo;
postgres=# -- Use 'lo' type instead of 'oid':
postgres=# CREATE TABLE docs_v2 (
    id serial PRIMARY KEY,
    title text NOT NULL,
    file_ref lo  -- special type from lo extension
);
postgres=# -- Create trigger for automatic cleanup:
postgres=# CREATE TRIGGER trg_docs_lo
    BEFORE UPDATE OR DELETE ON docs_v2
    FOR EACH ROW
    EXECUTE FUNCTION lo_manage(file_ref);
postgres=# -- Now DELETE automatically removes the large object!
postgres=# DELETE FROM docs_v2 WHERE id = 1;
postgres=# -- Both the row AND the large object are deleted
```

### Finding and Cleaning Orphaned Large Objects
**Explanation:** You can find and clean up orphaned large objects using the vacuumlo utility. It scans all tables for OID references and removes any large objects that are not referenced by any table.

```sql
postgres=# -- List all large objects:
postgres=# SELECT oid, pg_size_pretty(lo_size.size)
postgres-# FROM (
postgres=# SELECT loid AS oid,
           sum(length(data)) AS size
postgres-# FROM pg_largeobject
postgres-# GROUP BY loid
) lo_size;
postgres=# -- Count large objects:
postgres=# SELECT count(DISTINCT loid) FROM pg_largeobject;
postgres=# -- Clean up orphans with vacuumlo:
postgres=# -- vacuumlo -v mydb
postgres=# -- Checking documents.file_oid
postgres=# -- Checking docs_v2.file_ref
postgres=# -- Removing lo 16384
postgres=# -- Removing lo 16386
postgres=# -- Successfully removed 2 large objects
```

### Production Pattern: Path in DB, File on Disk/S3
**Explanation:** The most common production pattern is to store the file on a filesystem or cloud storage and keep only the path or URL in the database. This gives you the best of both worlds — the database handles metadata and the filesystem handles the bytes.

```sql
postgres=# -- Store path/URL, not the file itself:
postgres=# CREATE TABLE file_metadata (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    original_name text NOT NULL,
    storage_path text NOT NULL,  -- '/uploads/2024/abc.pdf'
    mime_type text NOT NULL,
    file_size bigint NOT NULL,
    checksum text,  -- SHA-256 hash
    uploaded_by int REFERENCES users(id),
    uploaded_at timestamptz DEFAULT now()
);
postgres=# CREATE INDEX idx_files_uploaded
postgres-# ON file_metadata (uploaded_by, uploaded_at DESC);
postgres=# -- For S3:
postgres=# INSERT INTO file_metadata
    (original_name, storage_path, mime_type, file_size)
postgres-# VALUES ('report.pdf',
    's3://mybucket/uploads/2024/11/abc123.pdf',
    'application/pdf', 2457600);
postgres=# -- App reads path from DB, then fetches from S3/disk
```

### Beginner Trap: Backup and Large Objects
**Explanation:** A common beginner trap — pg_dump and pg_restore handle large objects only if you include the dash-b flag or use custom format. Plain SQL format with dash-F p does NOT include large objects by default.

```sql
postgres=# -- Custom format includes large objects automatically:
postgres=# -- pg_dump -Fc mydb > backup.dump
postgres=# -- pg_restore -d mydb backup.dump
postgres=# -- ✓ Large objects included
postgres=# -- Plain SQL format: must add -b flag:
postgres=# -- pg_dump -Fp mydb > backup.sql
postgres=# -- ✗ Large objects NOT included!
postgres=# -- pg_dump -Fp -b mydb > backup.sql
postgres=# -- ✓ Large objects included with -b
postgres=# -- Directory format (parallel) includes them:
postgres=# -- pg_dump -Fd -j 4 mydb -f backup_dir/
postgres=# -- ✓ Large objects included
postgres=# -- Best practice: always use custom format (-Fc)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Backup and Large Objects
A common beginner trap — pg_dump and pg_restore handle large objects only if you include the dash-b flag or use custom format. Plain SQL format with dash-F p does NOT include large objects by default.

```sql
-- Custom format includes large objects automatically:
-- pg_dump -Fc mydb > backup.dump
-- pg_restore -d mydb backup.dump
-- ✓ Large objects included
-- Plain SQL format: must add -b flag:
-- pg_dump -Fp mydb > backup.sql
-- ✗ Large objects NOT included!
-- pg_dump -Fp -b mydb > backup.sql
-- ✓ Large objects included with -b
-- Directory format (parallel) includes them:
-- pg_dump -Fd -j 4 mydb -f backup_dir/
-- ✓ Large objects included
-- Best practice: always use custom format (-Fc)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary and the Phase 25 wrap-up. For binary data: use bytea for files under 10 MB, large objects for files up to 4 TB with streaming, or store paths in the database and files on the filesystem or cloud storage for the best production approach. Large objects use OID references, support lo_import and lo_export, and need the lo extension or vacuumlo to prevent orphans. Phase 25 covered full-text search, JSON and JSONB, foreign data wrappers, table inheritance, LISTEN and NOTIFY, and large objects.

- **bytea: binary column, max 1 GB, loaded fully into memory**
- **Large objects: stored in pg_largeobject, max 4 TB, streamable**
- **lo_import/lo_export: file ↔ large object (server paths!)**
- **lo_open/loread/lowrite: streaming inside transactions**
- **lo extension + lo_manage trigger: auto-cleanup**
- **vacuumlo: find and remove orphaned large objects**
- **Production: store path in DB, file on disk/S3**
- **pg_dump -Fc: includes large objects automatically**
- **Phase 25 complete: FTS, JSON, FDW, Inheritance, LISTEN/NOTIFY, LO**


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
