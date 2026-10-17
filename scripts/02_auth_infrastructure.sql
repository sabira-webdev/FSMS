-- ==============================================================================
-- FSMS (Food Safety Management System) - Targeted Auth Infrastructure Migration
-- Target: Supabase PostgreSQL 15+ / GoTrue Auth Integration
-- Version: 2.1 (Hardened: SET search_path = '' & Fully Qualified Objects)
-- Safety: Non-destructive, idempotent, preserves all existing tables, data & RLS
-- Does NOT modify employees, departments, or employee RLS write policies yet.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. UTILITY: Timestamp updater function (idempotent, search_path = '')
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = pg_catalog.now();
  RETURN NEW;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. PROFILES TABLE: Linked directly to auth.users
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'Inspector'
    CHECK (role IN ('Super Admin', 'Quality Manager', 'Lead Auditor', 'Inspector', 'Operator')),
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- Index for fast user profile and role lookups
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- Ensure updated_at trigger on profiles
DROP TRIGGER IF EXISTS tr_profiles_updated_at ON public.profiles;
CREATE TRIGGER tr_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ------------------------------------------------------------------------------
-- 3. ROLE HELPER FUNCTION: Secure, cached role retrieval
-- Fully qualified, SECURITY DEFINER with SET search_path = '' to prevent hijacking
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_role()
RETURNS TEXT 
LANGUAGE sql 
STABLE 
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- ------------------------------------------------------------------------------
-- 4. PRIVILEGE ESCALATION & PROFILE FIELD PROTECTION TRIGGER
-- Blocks ordinary authenticated users from altering protected columns:
--   - role (privilege level)
--   - is_active (account status)
--   - department_id (department assignment)
--   - employee_id (employee record linkage)
--   - email and id (identity keys)
-- Allows trusted administrative sessions (Supabase SQL Editor / postgres / service_role)
-- and active Super Admins to manage all attributes.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_profile_fields()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_session_user TEXT;
  v_is_db_admin BOOLEAN;
  v_protected_modified BOOLEAN;
BEGIN
  -- Detect if any protected profile attribute is being altered
  v_protected_modified := (NEW.role IS DISTINCT FROM OLD.role)
                       OR (NEW.is_active IS DISTINCT FROM OLD.is_active)
                       OR (NEW.department_id IS DISTINCT FROM OLD.department_id)
                       OR (NEW.employee_id IS DISTINCT FROM OLD.employee_id)
                       OR (NEW.email IS DISTINCT FROM OLD.email)
                       OR (NEW.id IS DISTINCT FROM OLD.id);

  -- If no protected fields are being modified, allow immediately (e.g. updating avatar_url or full_name)
  IF NOT v_protected_modified THEN
    RETURN NEW;
  END IF;

  v_session_user := pg_catalog.session_user;

  -- Verify direct database administration:
  -- Must be executed directly by the PostgreSQL superuser/admin role (e.g. Supabase SQL Editor / direct psql)
  -- AND have no PostgREST JWT context (auth.role() IS NULL).
  -- Note: auth.role() IS NULL alone is NEVER treated as proof of an administrator.
  v_is_db_admin := (v_session_user IN ('postgres', 'supabase_admin'))
                   AND (auth.role() IS NULL);

  -- 1. Direct trusted database administration in SQL Editor
  IF v_is_db_admin THEN
    RETURN NEW;
  END IF;

  -- 2. Trusted backend service-role operations (Supabase service_role secret key)
  IF auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- 3. Authenticated end-user via PostgREST API: caller must already be a verified Super Admin
  IF auth.role() = 'authenticated' THEN
    IF public.get_current_role() = 'Super Admin' THEN
      RETURN NEW;
    END IF;
  END IF;

  -- 4. Fail-closed: block all unauthorized modifications to protected attributes
  RAISE EXCEPTION 'Privilege escalation blocked: unauthorized attempt to modify protected profile fields (role, is_active, department_id, employee_id)';
END;
$$;

-- Drop legacy trigger name if exists, then attach updated trigger
DROP TRIGGER IF EXISTS tr_protect_profile_roles ON public.profiles;
DROP TRIGGER IF EXISTS tr_protect_profile_fields ON public.profiles;
CREATE TRIGGER tr_protect_profile_fields
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_fields();

-- ------------------------------------------------------------------------------
-- 5. AUTO-PROVISION USER PROFILE TRIGGER (on auth.users insert)
-- Handles missing email or name safely without violating NOT NULL constraints.
-- Guarantees new sign-ups default to safe baseline role ('Inspector').
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  resolved_email TEXT;
  resolved_name TEXT;
BEGIN
  -- Safe email resolution to guarantee NOT NULL compliance
  resolved_email := COALESCE(
    NEW.email,
    NEW.raw_user_meta_data->>'email',
    NEW.id::TEXT || '@placeholder.fsms.internal'
  );

  -- Safe name resolution to guarantee NOT NULL compliance
  resolved_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    NULLIF(pg_catalog.split_part(resolved_email, '@', 1), ''),
    'Facility Personnel'
  );

  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    resolved_email,
    resolved_name,
    'Inspector' -- Always default to safe baseline role; elevated roles require Super Admin grant
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- ------------------------------------------------------------------------------
-- 6. BACKFILL: Provision profiles for any users already in auth.users
-- ------------------------------------------------------------------------------
INSERT INTO public.profiles (id, email, full_name, role)
SELECT 
  u.id,
  COALESCE(
    u.email,
    u.raw_user_meta_data->>'email',
    u.id::TEXT || '@placeholder.fsms.internal'
  ),
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    NULLIF(pg_catalog.split_part(COALESCE(u.email, ''), '@', 1), ''),
    'Facility Personnel'
  ),
  'Inspector'
FROM auth.users u
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY (RLS) FOR PROFILES
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 7.1 SELECT: Authenticated team members can read profiles (needed for auditor tags, header display, directories)
DROP POLICY IF EXISTS "Profiles: Read for authenticated users" ON public.profiles;
CREATE POLICY "Profiles: Read for authenticated users"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

-- 7.2 UPDATE: Users can update their own personal info (avatar, full_name)
-- Note: Protected fields (role, is_active, department_id, employee_id) are blocked by tr_protect_profile_fields trigger above
DROP POLICY IF EXISTS "Profiles: Update own profile" ON public.profiles;
CREATE POLICY "Profiles: Update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 7.3 ALL: Super Admins can manage all user profiles and roles
DROP POLICY IF EXISTS "Profiles: Full management by Super Admin" ON public.profiles;
CREATE POLICY "Profiles: Full management by Super Admin"
  ON public.profiles FOR ALL
  TO authenticated
  USING (public.get_current_role() = 'Super Admin')
  WITH CHECK (public.get_current_role() = 'Super Admin');

-- ------------------------------------------------------------------------------
-- 8. VERIFICATION QUERY (Run after execution to verify installation)
-- ------------------------------------------------------------------------------
SELECT 
  p.id,
  p.email,
  p.full_name,
  p.role,
  p.is_active,
  p.created_at
FROM public.profiles p;
