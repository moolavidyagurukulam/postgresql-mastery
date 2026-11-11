-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Large Objects — Storing Binary Files (Class 221)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. bytea — BINARY COLUMN
-- ============================================================

CREATE TABLE attachments (
    id serial PRIMARY KEY,
    filename text NOT NULL,
    mime_type text NOT NULL,
    file_size int,
    data bytea NOT NULL,
    uploaded_at timestamptz DEFAULT now()
);

-- Insert text as bytea:
INSERT INTO attachments (filename, mime_type, file_size, data)
VALUES ('hello.txt', 'text/plain', 13,
        '\x48656c6c6f2c20576f726c6421');

-- Using convert_to:
INSERT INTO attachments (filename, mime_type, file_size, data)
VALUES ('note.txt', 'text/plain', 10,
        convert_to('Hello PG!', 'UTF8'));

-- Read back:
SELECT filename, convert_from(data, 'UTF8') AS content
FROM attachments;

-- ============================================================
-- 2. bytea FUNCTIONS
-- ============================================================

-- Length in bytes:
SELECT length('\x48656c6c6f'::bytea);  -- 5

-- Encode to base64:
SELECT encode('Hello'::bytea, 'base64');  -- SGVsbG8=

-- Decode from base64:
SELECT decode('SGVsbG8=', 'base64');  -- \x48656c6c6f

-- Substring of bytea:
SELECT substring('\x0102030405'::bytea from 2 for 3);
-- \x020304

-- Check format:
SHOW bytea_output;  -- hex (default)

-- ============================================================
-- 3. LARGE OBJECTS — BASIC OPERATIONS
-- ============================================================

-- Create empty large object:
SELECT lo_create(0);  -- returns OID

-- Import from server file:
SELECT lo_import('/tmp/report.pdf');

-- Export to server file:
-- SELECT lo_export(16385, '/tmp/report_copy.pdf');

-- Delete a large object:
-- SELECT lo_unlink(16385);

-- ============================================================
-- 4. LARGE OBJECTS — TABLE REFERENCE
-- ============================================================

CREATE TABLE documents (
    id serial PRIMARY KEY,
    title text NOT NULL,
    file_oid oid,
    uploaded_at timestamptz DEFAULT now()
);

-- Store OID after import:
-- INSERT INTO documents (title, file_oid)
-- VALUES ('Monthly Report', lo_import('/tmp/report.pdf'));

-- ============================================================
-- 5. LARGE OBJECTS — STREAMING
-- ============================================================

-- Must be inside a transaction:
BEGIN;

-- Open for reading (INV_READ = 262144):
-- SELECT lo_open(16385, 262144);

-- Read bytes:
-- SELECT loread(0, 100);

-- Seek to position:
-- SELECT lo_lseek(0, 500, 0);  -- 0 = SEEK_SET

-- Close:
-- SELECT lo_close(0);

COMMIT;

-- ============================================================
-- 6. lo EXTENSION — AUTOMATIC CLEANUP
-- ============================================================

CREATE EXTENSION lo;

CREATE TABLE docs_v2 (
    id serial PRIMARY KEY,
    title text NOT NULL,
    file_ref lo
);

CREATE TRIGGER trg_docs_lo
    BEFORE UPDATE OR DELETE ON docs_v2
    FOR EACH ROW
    EXECUTE FUNCTION lo_manage(file_ref);

-- Now DELETE auto-removes the large object!

-- ============================================================
-- 7. FINDING ORPHANED LARGE OBJECTS
-- ============================================================

-- List all large objects with sizes:
SELECT loid AS oid,
       pg_size_pretty(sum(length(data))) AS size
FROM pg_largeobject
GROUP BY loid;

-- Count large objects:
SELECT count(DISTINCT loid) FROM pg_largeobject;

-- Clean up orphans from command line:
-- vacuumlo -v mydb

-- ============================================================
-- 8. PRODUCTION PATTERN: PATH IN DB
-- ============================================================

CREATE TABLE file_metadata (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    original_name text NOT NULL,
    storage_path text NOT NULL,
    mime_type text NOT NULL,
    file_size bigint NOT NULL,
    checksum text,
    uploaded_by int,
    uploaded_at timestamptz DEFAULT now()
);

CREATE INDEX idx_files_uploaded
    ON file_metadata (uploaded_by, uploaded_at DESC);

INSERT INTO file_metadata
    (original_name, storage_path, mime_type, file_size)
VALUES ('report.pdf',
    's3://mybucket/uploads/2024/11/abc123.pdf',
    'application/pdf', 2457600);

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create the attachments table and insert text as bytea.
--    Read it back with convert_from.

-- 2. Try encode/decode with base64 format.

-- 3. Create a large object with lo_create(0).
--    Open it, write some bytes, close it.
--    Open it again and read the bytes back.

-- 4. If you have a file on the server, import it with
--    lo_import and export it with lo_export.

-- 5. Set up the lo extension with auto-cleanup trigger.
--    Insert a document, then delete it.
--    Verify the large object was cleaned up.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS docs_v2;
-- DROP TABLE IF EXISTS documents;
-- DROP TABLE IF EXISTS attachments;
-- DROP TABLE IF EXISTS file_metadata;
-- DROP EXTENSION IF EXISTS lo;
-- Run: vacuumlo mydb  (to clean orphaned large objects)
