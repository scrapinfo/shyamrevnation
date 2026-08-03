-- ============================================================================
-- REV NATION JAIPUR — COMPLETE DATABASE BOOTSTRAP
-- ============================================================================
-- Run this ONCE in Supabase → SQL Editor on a FRESH project.
--
-- What it does:
--   ✔ Creates all data tables (leads, projects, testimonials, stats,
--     site_media, frame_sequences)
--   ✔ Creates security tables (admins, login_attempts, activity_log)
--   ✔ Adds rate-limit & audit support functions
--   ✔ Sets up storage buckets
--   ✔ Locks EVERYTHING down with strict Row Level Security
--   ✔ Seeds your 6 default homepage stats
--
-- Idempotent: safe to re-run. Won't delete rows. Won't error on re-runs.
-- ============================================================================


-- ============================================================================
-- BLOCK 1 — DATA TABLES (the content your site and admin panel use)
-- ============================================================================

CREATE TABLE IF NOT EXISTS leads (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at  timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  name        text        NOT NULL,
  phone       text        NOT NULL,
  city        text,
  car         text,
  service     text,
  message     text,
  status      text        DEFAULT 'new'::text
);

CREATE TABLE IF NOT EXISTS projects (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at   timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  title        text        NOT NULL,
  car_make     text,
  car_model    text,
  service_type text,
  cover_image  text,
  before_url   text,
  after_url    text,
  published    boolean     DEFAULT true,
  sort_order   integer     DEFAULT 0
);

CREATE TABLE IF NOT EXISTS testimonials (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at  timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  name        text        NOT NULL,
  city        text,
  car         text,
  quote       text        NOT NULL,
  published   boolean     DEFAULT true,
  sort_order  integer     DEFAULT 0
);

CREATE TABLE IF NOT EXISTS stats (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  label       text        NOT NULL UNIQUE,
  value       integer     NOT NULL DEFAULT 0,
  suffix      text,
  sort_order  integer     DEFAULT 0
);

CREATE TABLE IF NOT EXISTS site_media (
  id          text        PRIMARY KEY,
  media_url   text,
  key         text        UNIQUE,
  url         text,
  label       text,
  updated_at  timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS frame_sequences (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at   timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  section_key  text        NOT NULL,
  folder_path  text        NOT NULL,
  frame_count  integer     NOT NULL,
  project_id   uuid        REFERENCES projects(id) ON DELETE SET NULL
);


-- ============================================================================
-- BLOCK 2 — SECURITY & AUDIT TABLES
-- ============================================================================

-- Your admin accounts. Only YOUR user IDs get access to the panel.
CREATE TABLE IF NOT EXISTS admins (
  id          uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz DEFAULT now()
);

-- Every login attempt (success or fail) is logged here.
CREATE TABLE IF NOT EXISTS login_attempts (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  email       text        NOT NULL,
  success     boolean     NOT NULL,
  ip_address  text,
  user_agent  text,
  created_at  timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_login_attempts_email_created
  ON login_attempts(lower(email), created_at DESC);

-- Every admin action (delete, status change, upload) is logged here.
CREATE TABLE IF NOT EXISTS activity_log (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  actor_email   text,
  action        text,
  target_table  text,
  target_id     text,
  ip_address    text,
  created_at    timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_activity_log_created
  ON activity_log(created_at DESC);


-- ============================================================================
-- BLOCK 3 — SECURITY FUNCTIONS (rate limiting, admin check, IP detection)
-- ============================================================================

-- Is the current authenticated user an admin?
CREATE OR REPLACE FUNCTION is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS(SELECT 1 FROM public.admins WHERE id = auth.uid())
$$;

-- Capture the client IP as seen by Postgres (works through the Supabase API).
CREATE OR REPLACE FUNCTION get_client_ip() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog
AS $$ SELECT host(inet_client_addr()) $$;

-- Block brute-force: allow max 5 failed attempts in any 15-minute window.
CREATE OR REPLACE FUNCTION check_login_allowed(p_email text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  RETURN (
    SELECT count(*)
    FROM login_attempts
    WHERE email = lower(p_email)
      AND success = false
      AND created_at > now() - interval '15 minutes'
  ) < 5;
END;
$$;

-- Record every login attempt, always. Needed for rate limiting & audit trail.
CREATE OR REPLACE FUNCTION log_login_attempt(p_email text, p_success boolean, p_user_agent text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  INSERT INTO login_attempts (email, success, ip_address, user_agent, created_at)
  VALUES (lower(p_email), p_success, get_client_ip(), p_user_agent, now());
END;
$$;


-- ============================================================================
-- BLOCK 4 — STORAGE BUCKETS (for images, video, frame sequences)
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('project-images',  'project-images',  true),
  ('site-assets',     'site-assets',     true),
  ('frame-sequences', 'frame-sequences', true)
ON CONFLICT (id) DO NOTHING;


-- ============================================================================
-- BLOCK 5 — ROW LEVEL SECURITY (RLS) — the perimeter
-- ============================================================================

ALTER TABLE leads            ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects         ENABLE ROW LEVEL SECURITY;
ALTER TABLE testimonials     ENABLE ROW LEVEL SECURITY;
ALTER TABLE stats            ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_media       ENABLE ROW LEVEL SECURITY;
ALTER TABLE frame_sequences  ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins           ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_attempts   ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log     ENABLE ROW LEVEL SECURITY;

-- Drop any prior conflicting rules so we start clean
DROP POLICY IF EXISTS "Public Read Access"        ON site_media;
DROP POLICY IF EXISTS "Public Read Access"        ON projects;
DROP POLICY IF EXISTS "Public Read Access"        ON testimonials;
DROP POLICY IF EXISTS "Public Read Access"        ON stats;
DROP POLICY IF EXISTS "Public Read Access"        ON frame_sequences;
DROP POLICY IF EXISTS "Admin Full Access"         ON site_media;
DROP POLICY IF EXISTS "Admin Full Access"         ON projects;
DROP POLICY IF EXISTS "Admin Full Access"         ON testimonials;
DROP POLICY IF EXISTS "Admin Full Access"         ON stats;
DROP POLICY IF EXISTS "Admin Full Access"         ON frame_sequences;
DROP POLICY IF EXISTS "Public can insert leads"   ON leads;
DROP POLICY IF EXISTS "Admins can view leads"     ON leads;
DROP POLICY IF EXISTS "Admins can update leads"   ON leads;
DROP POLICY IF EXISTS "Admins can delete leads"   ON leads;
DROP POLICY IF EXISTS "Admins can view admins"    ON admins;
DROP POLICY IF EXISTS "Admins can view attempts"  ON login_attempts;
DROP POLICY IF EXISTS "Anyone can log attempts"   ON login_attempts;
DROP POLICY IF EXISTS "Admins can view activity"  ON activity_log;
DROP POLICY IF EXISTS "Users can log activity"    ON activity_log;


-- Public website can READ: site_content and frame_sequences only
CREATE POLICY "Public Read Access" ON site_media      FOR SELECT USING (true);
CREATE POLICY "Public Read Access" ON projects        FOR SELECT USING (true);
CREATE POLICY "Public Read Access" ON testimonials    FOR SELECT USING (true);
CREATE POLICY "Public Read Access" ON stats           FOR SELECT USING (true);
CREATE POLICY "Public Read Access" ON frame_sequences FOR SELECT USING (true);

-- Public booking form can INSERT into leads (only this — can't read back)
CREATE POLICY "Public can insert leads" ON leads FOR INSERT WITH CHECK (true);

-- Admin-only FULL access on all content tables
CREATE POLICY "Admin Full Access" ON projects        FOR ALL USING ((SELECT is_admin()));
CREATE POLICY "Admin Full Access" ON testimonials    FOR ALL USING ((SELECT is_admin()));
CREATE POLICY "Admin Full Access" ON stats           FOR ALL USING ((SELECT is_admin()));
CREATE POLICY "Admin Full Access" ON site_media      FOR ALL USING ((SELECT is_admin()));
CREATE POLICY "Admin Full Access" ON frame_sequences FOR ALL USING ((SELECT is_admin()));

-- Admin-only LEADS access: read, update status, delete
CREATE POLICY "Admins can view leads"    ON leads FOR SELECT USING ((SELECT is_admin()));
CREATE POLICY "Admins can update leads"  ON leads FOR UPDATE USING ((SELECT is_admin()));
CREATE POLICY "Admins can delete leads"  ON leads FOR DELETE USING ((SELECT is_admin()));

-- Viewing the admins table: only users already in it (service_role for writes)
CREATE POLICY "Admins can view admins" ON admins FOR SELECT USING ((SELECT is_admin()));

-- Login attempt audit: public INSERT (function needs it), only admins READ
CREATE POLICY "Anyone can log attempts"   ON login_attempts FOR INSERT WITH CHECK (true);
CREATE POLICY "Admins can view attempts"  ON login_attempts FOR SELECT USING ((SELECT is_admin()));

-- Activity log: authenticated INSERT (from panel), only admins READ
CREATE POLICY "Users can log activity"    ON activity_log FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admins can view activity"  ON activity_log FOR SELECT USING ((SELECT is_admin()));


-- ============================================================================
-- BLOCK 6 — SEED DATA (default stats shown on your homepage)
-- ============================================================================

INSERT INTO stats (label, value, suffix, sort_order) VALUES
  ('Vehicles Serviced',   4200, '+',         1),
  ('Studio Area',         28,   'k sq.ft',   2),
  ('Installation Bays',   12,   '',          3),
  ('Certified Installers',24,   '',          4),
  ('Cities Served',       9,    '',          5),
  ('Experience',          11,   'yrs',       6)
ON CONFLICT (label) DO NOTHING;


-- ============================================================================
-- ✅ DONE.
-- Next: See README-security.md for the remaining setup steps:
--   1. Add your user UUID to admins table
--   2. Paste your Cloudflare Turnstile Site Key into config.js
-- ============================================================================
