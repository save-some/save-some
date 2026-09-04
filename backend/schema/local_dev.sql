-- =========================================================
-- LOCAL DEVELOPMENT ONLY. Do not run this against Supabase.
--
-- Supabase provides two things implicitly that a plain Postgres cluster
-- does not. This file supplies them so schema.sql applies cleanly to a
-- local database.
--
-- Run this BEFORE schema.sql, since schema.sql's profiles table
-- references auth.users(id).
-- =========================================================

-- 1. Supabase owns the `auth` schema and manages auth.users. Locally we
--    need a stand-in for profiles' foreign key to resolve. Only the id
--    column matters here — nothing in this project reads the rest of
--    Supabase's auth.users.
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY,
  email TEXT
);

-- 2. helpers/db.py:retrieve_best_match_from_products calls similarity(),
--    which comes from pg_trgm. Supabase ships it enabled; a fresh local
--    cluster does not.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
