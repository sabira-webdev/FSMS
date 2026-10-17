-- ==============================================================================
-- FSMS (Food Safety Management System) - Employee & Department RLS Policies
-- Target: Supabase PostgreSQL 15+ / PostgREST / GoTrue Auth Integration
-- File: scripts/03_employee_department_rls.sql
-- Idempotency: Completely safe to execute multiple times (DROP POLICY IF EXISTS guards)
-- Safety: Preserves existing departments, employees, and profile data; NO DESTRUCTIVE DROPS
-- Dependencies: Requires scripts/02_auth_infrastructure.sql (public.profiles table)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. HELPER FUNCTIONS: Non-recursive, cached profile verification
-- STABLE + SECURITY DEFINER + SET search_path = ''
-- Guarantees zero policy recursion by running as function owner (postgres)
-- ------------------------------------------------------------------------------

-- 1.1 Verify authenticated caller has an active profile
CREATE OR REPLACE FUNCTION public.is_active_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT is_active FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$;

-- 1.2 Verify authenticated caller has an active profile with an authorized role
CREATE OR REPLACE FUNCTION public.is_active_role(allowed_roles TEXT[])
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT (is_active AND role = ANY(allowed_roles))
     FROM public.profiles 
     WHERE id = auth.uid()),
    false
  );
$$;

-- ------------------------------------------------------------------------------
-- 1.3 FUNCTION ACCESS PERMISSIONS
-- Revoke default PUBLIC and anonymous execution; grant strictly to authenticated
-- (and service_role for backend automation) so RLS policies can evaluate them safely.
-- ------------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.is_active_user() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_active_user() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_active_role(TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_active_role(TEXT[]) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 2. DEPARTMENTS ROW LEVEL SECURITY (RLS) POLICIES
-- Table: public.departments
-- Relationship: Referenced by employees(department_id) and profiles(department_id)
-- ------------------------------------------------------------------------------
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

-- 2.1 SELECT: Active authenticated team members can read departments
-- Needed for dropdowns, employee assignment, audit scheduling, and badge display
DROP POLICY IF EXISTS "Departments: Read for authenticated users" ON public.departments;
DROP POLICY IF EXISTS "Departments: Read for active authenticated users" ON public.departments;
CREATE POLICY "Departments: Read for active authenticated users"
  ON public.departments FOR SELECT
  TO authenticated
  USING (public.is_active_user());

-- 2.2 ALL: Only active Super Admin & Quality Manager can manage departments (insert, update, delete)
DROP POLICY IF EXISTS "Departments: Manage by Super Admin & Quality Manager" ON public.departments;
DROP POLICY IF EXISTS "Departments: Manage by active Super Admin & Quality Manager" ON public.departments;
CREATE POLICY "Departments: Manage by active Super Admin & Quality Manager"
  ON public.departments FOR ALL
  TO authenticated
  USING (public.is_active_role(ARRAY['Super Admin', 'Quality Manager']))
  WITH CHECK (public.is_active_role(ARRAY['Super Admin', 'Quality Manager']));

-- ------------------------------------------------------------------------------
-- 3. EMPLOYEES ROW LEVEL SECURITY (RLS) POLICIES
-- Table: public.employees
-- Relationship: Foreign key to departments(id) ON DELETE RESTRICT
-- ------------------------------------------------------------------------------
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

-- 3.1 SELECT: Active authenticated team members can read employee records
-- Needed for roster view, auditor assignment, supervisor checks, and training audits
DROP POLICY IF EXISTS "Employees: Read for authenticated users" ON public.employees;
DROP POLICY IF EXISTS "Employees: Read for active authenticated users" ON public.employees;
CREATE POLICY "Employees: Read for active authenticated users"
  ON public.employees FOR SELECT
  TO authenticated
  USING (public.is_active_user());

-- 3.2 INSERT: Only active Super Admin & Quality Manager can create employee records
DROP POLICY IF EXISTS "Employees: Insert by active Super Admin & Quality Manager" ON public.employees;
CREATE POLICY "Employees: Insert by active Super Admin & Quality Manager"
  ON public.employees FOR INSERT
  TO authenticated
  WITH CHECK (public.is_active_role(ARRAY['Super Admin', 'Quality Manager']));

-- 3.3 UPDATE: Only active Super Admin & Quality Manager can update employee records
DROP POLICY IF EXISTS "Employees: Update by active Super Admin & Quality Manager" ON public.employees;
CREATE POLICY "Employees: Update by active Super Admin & Quality Manager"
  ON public.employees FOR UPDATE
  TO authenticated
  USING (public.is_active_role(ARRAY['Super Admin', 'Quality Manager']))
  WITH CHECK (public.is_active_role(ARRAY['Super Admin', 'Quality Manager']));

-- 3.4 DELETE: Only active Super Admin & Quality Manager can delete employee records
DROP POLICY IF EXISTS "Employees: Delete by active Super Admin & Quality Manager" ON public.employees;
CREATE POLICY "Employees: Delete by active Super Admin & Quality Manager"
  ON public.employees FOR DELETE
  TO authenticated
  USING (public.is_active_role(ARRAY['Super Admin', 'Quality Manager']));

-- Clean up any legacy composite policy names
DROP POLICY IF EXISTS "Employees: Modify by Super Admin & Quality Manager" ON public.employees;
DROP POLICY IF EXISTS "Employees: Modify by active Super Admin & Quality Manager" ON public.employees;

-- ------------------------------------------------------------------------------
-- 4. VERIFICATION QUERY (Run after execution to verify installed policies)
-- ------------------------------------------------------------------------------
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_catalog.pg_policies
WHERE schemaname = 'public' 
  AND tablename IN ('departments', 'employees')
ORDER BY tablename, cmd;
