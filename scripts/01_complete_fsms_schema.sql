-- ==============================================================================
-- FSMS (Food Safety Management System) - Enterprise PostgreSQL Database Migration
-- Architecture: Single-Company / Single-Facility Architecture
-- Compatibility: Supabase PostgreSQL 15+ / PostgREST / GoTrue Auth
-- Idempotency: Completely safe to execute multiple times (IF NOT EXISTS guards)
-- Safety: Preserves existing departments and employees; NO DESTRUCTIVE DROPS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. EXTENSIONS & UTILITIES
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Generic timestamp updater function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 1. DEPARTMENTS (Facility Zones & Organizational Units)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  code TEXT NOT NULL UNIQUE,
  zone_type TEXT NOT NULL DEFAULT 'Medium Care'
    CHECK (zone_type IN ('Low Care', 'Medium Care', 'High Care', 'High Risk', 'Non-Food Contact')),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure updated_at trigger on departments
DROP TRIGGER IF EXISTS tr_departments_updated_at ON public.departments;
CREATE TRIGGER tr_departments_updated_at
  BEFORE UPDATE ON public.departments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Seed Default 8 Departments idempotently
INSERT INTO public.departments (name, code, zone_type, description)
VALUES
  ('Quality Assurance', 'QA', 'High Risk', 'Central quality control, HACCP compliance, and regulatory governance'),
  ('Food Safety Lab', 'LAB', 'High Risk', 'Microbiology pathogen testing, allergen testing, and sensory evaluation'),
  ('Sanitation & Hygiene', 'SAN', 'High Care', 'Clean-In-Place (CIP) systems, chemical sanitation, and environmental swabs'),
  ('Cold Chain Operations', 'COLD', 'High Care', 'Blast chilling, deep freezer holding, and thermal continuous logging'),
  ('Production Line A', 'PROD-A', 'Medium Care', 'Primary thermal processing, mixing, batching, and cooking operations'),
  ('Production Line B', 'PROD-B', 'Medium Care', 'Secondary processing, slicing, blending, and intermediate holding'),
  ('Packaging & Dispatch', 'PKG', 'Medium Care', 'Modified atmosphere packaging (MAP), labeling, metal detection, and sorting'),
  ('Warehouse & Receiving', 'WH', 'Low Care', 'Raw material intake, lot traceability, quarantine bay, and dry storage')
ON CONFLICT (name) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 2. EMPLOYEES (Personnel Roster & Food Handler Medical / Training Dossier)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id TEXT NOT NULL UNIQUE,
  first_name TEXT,
  last_name TEXT,
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  phone TEXT,
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  position TEXT NOT NULL,
  employment_type TEXT NOT NULL DEFAULT 'Full-Time'
    CHECK (employment_type IN ('Full-Time', 'Part-Time', 'Contract', 'Seasonal', 'Apprentice')),
  status TEXT NOT NULL DEFAULT 'Active'
    CHECK (status IN ('Active', 'Pending Training', 'On Leave', 'Medical Review', 'Terminated')),
  shift TEXT NOT NULL DEFAULT 'Morning (Shift A)'
    CHECK (shift IN ('Morning (Shift A)', 'Evening (Shift B)', 'Night (Shift C)')),
  joined_date DATE NOT NULL DEFAULT CURRENT_DATE,
  training_status TEXT NOT NULL DEFAULT 'Completed / Certified'
    CHECK (training_status IN ('Completed / Certified', 'In Progress', 'Scheduled', 'Expired', 'Not Started')),
  training_completion_date DATE,
  training_expiry_date DATE,
  medical_fitness_status TEXT NOT NULL DEFAULT 'Fit / Cleared for Food Handling'
    CHECK (medical_fitness_status IN ('Fit / Cleared for Food Handling', 'Conditionally Fit', 'Pending Examination', 'Unfit / Restricted')),
  medical_certificate_expiry_date DATE,
  certifications TEXT[] NOT NULL DEFAULT '{}',
  medical_clearance TEXT,
  avatar_gradient TEXT NOT NULL DEFAULT 'from-emerald-600 to-teal-500',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure updated_at trigger on employees
DROP TRIGGER IF EXISTS tr_employees_updated_at ON public.employees;
CREATE TRIGGER tr_employees_updated_at
  BEFORE UPDATE ON public.employees
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Seed 9 Initial Employees idempotently
INSERT INTO public.employees (
  employee_id, name, first_name, last_name, email, phone,
  department_id, position, employment_type, status, shift,
  joined_date, training_status, training_completion_date, training_expiry_date,
  medical_fitness_status, medical_certificate_expiry_date,
  certifications, medical_clearance, avatar_gradient
)
SELECT
  emp.employee_id, emp.name, emp.first_name, emp.last_name, emp.email, emp.phone,
  d.id, emp.position, emp.employment_type, emp.status, emp.shift,
  emp.joined_date::DATE, emp.training_status, emp.training_completion_date::DATE, emp.training_expiry_date::DATE,
  emp.medical_fitness_status, emp.medical_certificate_expiry_date::DATE,
  emp.certifications, emp.medical_clearance, emp.avatar_gradient
FROM (
  VALUES
    ('EMP-1042', 'Jabir P k', 'Sarah', 'Jenkins', 'jabirapk@fsms-org', '+1 (555) 234-5678', 'Quality Assurance', 'Head of QA & Lead Auditor', 'Full-Time', 'Active', 'Morning (Shift A)', '2022-03-15', 'Completed / Certified', '2025-11-10', '2026-11-10', 'Fit / Cleared for Food Handling', '2026-12-31', ARRAY['ISO 22000 Lead Auditor', 'HACCP Level 4', 'BRCGS Professional']::TEXT[], 'Cleared (Valid until Dec 2026)', 'from-emerald-600 to-teal-500'),
    ('EMP-1043', 'David Kumar', 'David', 'Kumar', 'd.kumar@fsms-enterprise.org', '+1 (555) 345-6789', 'Cold Chain Operations', 'CCP Chiller Operations Lead', 'Full-Time', 'Active', 'Morning (Shift A)', '2023-01-10', 'Completed / Certified', '2025-10-15', '2026-10-15', 'Fit / Cleared for Food Handling', '2026-11-30', ARRAY['HACCP Level 3', 'Refrigerant & Cold Chain Compliance']::TEXT[], 'Cleared (Valid until Nov 2026)', 'from-blue-600 to-cyan-500'),
    ('EMP-1044', 'Elena Rostova', 'Elena', 'Rostova', 'e.rostova@fsms-enterprise.org', '+1 (555) 456-7890', 'Food Safety Lab', 'Lead Microbiologist', 'Full-Time', 'Active', 'Morning (Shift A)', '2021-08-20', 'Completed / Certified', '2026-01-12', '2027-01-12', 'Fit / Cleared for Food Handling', '2027-01-20', ARRAY['Microbial Pathogen Testing', 'ISO 17025 Lab Standard']::TEXT[], 'Cleared (Valid until Jan 2027)', 'from-purple-600 to-indigo-500'),
    ('EMP-1045', 'Marcus Chen', 'Marcus', 'Chen', 'm.chen@fsms-enterprise.org', '+1 (555) 567-8901', 'Sanitation & Hygiene', 'CIP Sanitation Supervisor', 'Full-Time', 'Pending Training', 'Night (Shift C)', '2023-09-01', 'Scheduled', NULL, '2026-09-01', 'Fit / Cleared for Food Handling', '2026-10-15', ARRAY['Chemical Safety & CIP Systems', 'Food Contact Sanitation']::TEXT[], 'Cleared (Valid until Oct 2026)', 'from-amber-600 to-orange-500'),
    ('EMP-1046', 'Amira Patel', 'Amira', 'Patel', 'a.patel@fsms-enterprise.org', '+1 (555) 678-9012', 'Production Line A', 'Line Quality Inspector', 'Full-Time', 'Active', 'Evening (Shift B)', '2024-02-15', 'Completed / Certified', '2026-02-10', '2027-02-10', 'Fit / Cleared for Food Handling', '2027-03-01', ARRAY['GMP Good Manufacturing Practices', 'Allergen Control']::TEXT[], 'Cleared (Valid until Mar 2027)', 'from-rose-600 to-pink-500'),
    ('EMP-1047', 'James Wilson', 'James', 'Wilson', 'j.wilson@fsms-enterprise.org', '+1 (555) 789-0123', 'Warehouse & Receiving', 'Raw Material Intake Officer', 'Full-Time', 'Active', 'Morning (Shift A)', '2022-11-05', 'Completed / Certified', '2025-08-14', '2026-08-14', 'Fit / Cleared for Food Handling', '2026-08-30', ARRAY['Traceability & Lot Control', 'HACCP Prerequisite Programs']::TEXT[], 'Cleared (Valid until Aug 2026)', 'from-teal-600 to-emerald-500'),
    ('EMP-1048', 'Carlos Mendez', 'Carlos', 'Mendez', 'c.mendez@fsms-enterprise.org', '+1 (555) 890-1234', 'Production Line B', 'Thermal Process Specialist', 'Full-Time', 'On Leave', 'Evening (Shift B)', '2023-05-18', 'Completed / Certified', '2025-05-10', '2026-05-10', 'Fit / Cleared for Food Handling', '2027-05-15', ARRAY['Thermal Processing & Pasteurization', 'HACCP Level 3']::TEXT[], 'Cleared (Valid until May 2027)', 'from-slate-600 to-slate-800'),
    ('EMP-1049', 'Fatima Al-Mansoor', 'Fatima', 'Al-Mansoor', 'f.almansoor@fsms-enterprise.org', '+1 (555) 901-2345', 'Quality Assurance', 'Supplier Quality Auditor', 'Full-Time', 'Active', 'Morning (Shift A)', '2023-10-12', 'Completed / Certified', '2025-09-20', '2026-09-20', 'Fit / Cleared for Food Handling', '2026-09-30', ARRAY['GFSI Benchmark Standards', 'FSVP Compliance']::TEXT[], 'Cleared (Valid until Sep 2026)', 'from-violet-600 to-purple-500'),
    ('EMP-1050', 'Thomas Wright', 'Thomas', 'Wright', 't.wright@fsms-enterprise.org', '+1 (555) 012-3456', 'Sanitation & Hygiene', 'Environmental Monitoring Tech', 'Full-Time', 'Medical Review', 'Night (Shift C)', '2024-04-01', 'In Progress', NULL, NULL, 'Pending Examination', NULL, ARRAY['ATP Swabbing & Environmental Sampling']::TEXT[], 'Pending Annual Health Examination', 'from-yellow-600 to-amber-500')
) AS emp(
  employee_id, name, first_name, last_name, email, phone, department_name, position,
  employment_type, status, shift, joined_date, training_status, training_completion_date,
  training_expiry_date, medical_fitness_status, medical_certificate_expiry_date,
  certifications, medical_clearance, avatar_gradient
)
JOIN public.departments d ON d.name = emp.department_name
ON CONFLICT (employee_id) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 3. PROFILES (Application User Roles & Auth Link)
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS tr_profiles_updated_at ON public.profiles;
CREATE TRIGGER tr_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Auto-provision user profile trigger on Supabase Auth Sign Up
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'Inspector')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- ------------------------------------------------------------------------------
-- 4. CHECKLIST TEMPLATES (SOPs, Inspection Protocols & Master Audit Forms)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  category TEXT NOT NULL DEFAULT 'Sanitation'
    CHECK (category IN ('Sanitation', 'HACCP Prerequisite', 'Thermal CCP', 'GMP Audit', 'Allergen Control', 'Receiving')),
  version INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS tr_checklist_templates_updated_at ON public.checklist_templates;
CREATE TRIGGER tr_checklist_templates_updated_at
  BEFORE UPDATE ON public.checklist_templates
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ------------------------------------------------------------------------------
-- 5. CHECKLIST ITEMS (Verification Criteria & Critical Safety Limits)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES public.checklist_templates(id) ON DELETE CASCADE,
  item_order INTEGER NOT NULL DEFAULT 1,
  section_title TEXT NOT NULL DEFAULT 'General Inspection',
  question TEXT NOT NULL,
  instruction TEXT,
  response_type TEXT NOT NULL DEFAULT 'pass_fail'
    CHECK (response_type IN ('pass_fail', 'numeric', 'text', 'multiple_choice')),
  is_critical BOOLEAN NOT NULL DEFAULT false,
  min_value NUMERIC(8,2),
  max_value NUMERIC(8,2),
  unit TEXT,
  options JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- 6. INSPECTIONS (Conducted On-Site Audits & Operational Records)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_code TEXT NOT NULL UNIQUE,
  template_id UUID NOT NULL REFERENCES public.checklist_templates(id) ON DELETE RESTRICT,
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  auditor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  scheduled_date DATE NOT NULL DEFAULT CURRENT_DATE,
  conducted_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'Draft'
    CHECK (status IN ('Draft', 'In Progress', 'Passed', 'CAPA Required', 'Failed', 'In Review')),
  score NUMERIC(5,2),
  total_items INTEGER NOT NULL DEFAULT 0,
  passed_items INTEGER NOT NULL DEFAULT 0,
  failed_items INTEGER NOT NULL DEFAULT 0,
  facility_zone TEXT,
  shift TEXT DEFAULT 'Morning (Shift A)',
  summary_notes TEXT,
  digital_signature_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS tr_inspections_updated_at ON public.inspections;
CREATE TRIGGER tr_inspections_updated_at
  BEFORE UPDATE ON public.inspections
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ------------------------------------------------------------------------------
-- 7. INSPECTION RESULTS (Individual Check-Item Answers & Non-Conformance Evidence)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inspection_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id UUID NOT NULL REFERENCES public.inspections(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.checklist_items(id) ON DELETE RESTRICT,
  result_status TEXT NOT NULL DEFAULT 'Pending'
    CHECK (result_status IN ('Pass', 'Fail', 'N/A', 'Pending')),
  numeric_value NUMERIC(8,2),
  text_value TEXT,
  comment TEXT,
  photo_evidence_urls TEXT[] NOT NULL DEFAULT '{}',
  is_deviation BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- 8. CAPA ACTIONS (Corrective and Preventive Action Workflows)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.capa_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  capa_number TEXT NOT NULL UNIQUE,
  inspection_id UUID REFERENCES public.inspections(id) ON DELETE SET NULL,
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'Medium'
    CHECK (severity IN ('Low', 'Medium', 'High', 'Critical')),
  root_cause_analysis JSONB NOT NULL DEFAULT '{}'::jsonb,
  corrective_action TEXT NOT NULL,
  preventive_action TEXT,
  assigned_to UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  due_date DATE NOT NULL,
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'Open'
    CHECK (status IN ('Open', 'In Progress', 'Pending Verification', 'Closed', 'Overdue')),
  verification_notes TEXT,
  verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS tr_capa_actions_updated_at ON public.capa_actions;
CREATE TRIGGER tr_capa_actions_updated_at
  BEFORE UPDATE ON public.capa_actions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ------------------------------------------------------------------------------
-- 9. CCP MONITORING LOGS (Critical Control Point HACCP Telemetry Logs)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ccp_monitoring_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ccp_number TEXT NOT NULL,
  equipment_name TEXT NOT NULL,
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  logged_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  measurement_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  parameter_name TEXT NOT NULL DEFAULT 'Temperature',
  measured_value NUMERIC(6,2) NOT NULL,
  unit TEXT NOT NULL DEFAULT '°C',
  target_min NUMERIC(6,2),
  target_max NUMERIC(6,2),
  status TEXT NOT NULL DEFAULT 'Optimal'
    CHECK (status IN ('Optimal', 'Acceptable', 'Deviation', 'Verified')),
  corrective_action_taken TEXT,
  is_critical_deviation BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- 10. NOTIFICATIONS (In-App Compliance Alerts & Action Item Triggers)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info'
    CHECK (type IN ('info', 'success', 'warning', 'danger')),
  link TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- 11. PERFORMANCE INDEXES
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_employees_dept ON public.employees (department_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON public.employees (status);
CREATE INDEX IF NOT EXISTS idx_employees_training_status ON public.employees (training_status);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles (role);
CREATE INDEX IF NOT EXISTS idx_checklist_templates_dept ON public.checklist_templates (department_id);
CREATE INDEX IF NOT EXISTS idx_checklist_items_template ON public.checklist_items (template_id, item_order);
CREATE INDEX IF NOT EXISTS idx_inspections_dept ON public.inspections (department_id);
CREATE INDEX IF NOT EXISTS idx_inspections_auditor ON public.inspections (auditor_id);
CREATE INDEX IF NOT EXISTS idx_inspections_status ON public.inspections (status);
CREATE INDEX IF NOT EXISTS idx_inspection_results_audit ON public.inspection_results (inspection_id);
CREATE INDEX IF NOT EXISTS idx_capa_dept ON public.capa_actions (department_id);
CREATE INDEX IF NOT EXISTS idx_capa_status ON public.capa_actions (status);
CREATE INDEX IF NOT EXISTS idx_capa_assigned_to ON public.capa_actions (assigned_to);
CREATE INDEX IF NOT EXISTS idx_ccp_logs_dept_time ON public.ccp_monitoring_logs (department_id, measurement_time DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications (user_id, is_read);

-- ------------------------------------------------------------------------------
-- 12. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------

-- Helper function to safely get user role
CREATE OR REPLACE FUNCTION public.get_current_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Enable RLS on all 10 tables
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.capa_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ccp_monitoring_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 12.1 DEPARTMENTS POLICIES
DROP POLICY IF EXISTS "Departments: Read for authenticated users" ON public.departments;
CREATE POLICY "Departments: Read for authenticated users"
  ON public.departments FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Departments: Manage by Super Admin & Quality Manager" ON public.departments;
CREATE POLICY "Departments: Manage by Super Admin & Quality Manager"
  ON public.departments FOR ALL
  TO authenticated
  USING (public.get_current_role() IN ('Super Admin', 'Quality Manager'))
  WITH CHECK (public.get_current_role() IN ('Super Admin', 'Quality Manager'));

-- 12.2 EMPLOYEES POLICIES
DROP POLICY IF EXISTS "Employees: Read for authenticated users" ON public.employees;
CREATE POLICY "Employees: Read for authenticated users"
  ON public.employees FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Employees: Modify by Super Admin & Quality Manager" ON public.employees;
CREATE POLICY "Employees: Modify by Super Admin & Quality Manager"
  ON public.employees FOR ALL
  TO authenticated
  USING (public.get_current_role() IN ('Super Admin', 'Quality Manager'))
  WITH CHECK (public.get_current_role() IN ('Super Admin', 'Quality Manager'));

-- 12.3 PROFILES POLICIES
DROP POLICY IF EXISTS "Profiles: Read for authenticated users" ON public.profiles;
CREATE POLICY "Profiles: Read for authenticated users"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Profiles: Update own profile" ON public.profiles;
CREATE POLICY "Profiles: Update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Profiles: Full management by Super Admin" ON public.profiles;
CREATE POLICY "Profiles: Full management by Super Admin"
  ON public.profiles FOR ALL
  TO authenticated
  USING (public.get_current_role() = 'Super Admin');

-- 12.4 CHECKLIST TEMPLATES & ITEMS POLICIES
DROP POLICY IF EXISTS "Templates: Read for authenticated users" ON public.checklist_templates;
CREATE POLICY "Templates: Read for authenticated users"
  ON public.checklist_templates FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Templates: Authoring by Admins, QM, & Lead Auditors" ON public.checklist_templates;
CREATE POLICY "Templates: Authoring by Admins, QM, & Lead Auditors"
  ON public.checklist_templates FOR ALL
  TO authenticated
  USING (public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor'))
  WITH CHECK (public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor'));

DROP POLICY IF EXISTS "Items: Read for authenticated users" ON public.checklist_items;
CREATE POLICY "Items: Read for authenticated users"
  ON public.checklist_items FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Items: Authoring by Admins, QM, & Lead Auditors" ON public.checklist_items;
CREATE POLICY "Items: Authoring by Admins, QM, & Lead Auditors"
  ON public.checklist_items FOR ALL
  TO authenticated
  USING (public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor'))
  WITH CHECK (public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor'));

-- 12.5 INSPECTIONS & RESULTS POLICIES
DROP POLICY IF EXISTS "Inspections: Read for authenticated users" ON public.inspections;
CREATE POLICY "Inspections: Read for authenticated users"
  ON public.inspections FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Inspections: Insert & conduct by qualified auditors & inspectors" ON public.inspections;
CREATE POLICY "Inspections: Insert & conduct by qualified auditors & inspectors"
  ON public.inspections FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = auditor_id OR public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor'));

DROP POLICY IF EXISTS "Inspections: Update own in-progress audits or by management" ON public.inspections;
CREATE POLICY "Inspections: Update own in-progress audits or by management"
  ON public.inspections FOR UPDATE
  TO authenticated
  USING (auth.uid() = auditor_id OR public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor'))
  WITH CHECK (auth.uid() = auditor_id OR public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor'));

DROP POLICY IF EXISTS "Results: Read for authenticated users" ON public.inspection_results;
CREATE POLICY "Results: Read for authenticated users"
  ON public.inspection_results FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Results: Manage answers by auditor or management" ON public.inspection_results;
CREATE POLICY "Results: Manage answers by auditor or management"
  ON public.inspection_results FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.inspections i
      WHERE i.id = inspection_id AND (i.auditor_id = auth.uid() OR public.get_current_role() IN ('Super Admin', 'Quality Manager'))
    )
  );

-- 12.6 CAPA ACTIONS POLICIES
DROP POLICY IF EXISTS "CAPA: Read for authenticated users" ON public.capa_actions;
CREATE POLICY "CAPA: Read for authenticated users"
  ON public.capa_actions FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "CAPA: Create by authorized personnel" ON public.capa_actions;
CREATE POLICY "CAPA: Create by authorized personnel"
  ON public.capa_actions FOR INSERT
  TO authenticated
  WITH CHECK (public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor', 'Inspector'));

DROP POLICY IF EXISTS "CAPA: Update by management or assigned owner" ON public.capa_actions;
CREATE POLICY "CAPA: Update by management or assigned owner"
  ON public.capa_actions FOR UPDATE
  TO authenticated
  USING (public.get_current_role() IN ('Super Admin', 'Quality Manager', 'Lead Auditor'));

-- 12.7 CCP MONITORING LOGS (HACCP Append-Only Audit Integrity)
DROP POLICY IF EXISTS "CCP: Read for authenticated users" ON public.ccp_monitoring_logs;
CREATE POLICY "CCP: Read for authenticated users"
  ON public.ccp_monitoring_logs FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "CCP: Insert telemetry by operators, inspectors & QA" ON public.ccp_monitoring_logs;
CREATE POLICY "CCP: Insert telemetry by operators, inspectors & QA"
  ON public.ccp_monitoring_logs FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = logged_by);

-- NOTICE: No UPDATE or DELETE policies are granted to Operators/Inspectors on CCP logs.
-- Only Super Admin can perform corrective edits for regulatory compliance audit tracking.
DROP POLICY IF EXISTS "CCP: Admin corrective maintenance only" ON public.ccp_monitoring_logs;
CREATE POLICY "CCP: Admin corrective maintenance only"
  ON public.ccp_monitoring_logs FOR UPDATE
  TO authenticated
  USING (public.get_current_role() = 'Super Admin')
  WITH CHECK (public.get_current_role() = 'Super Admin');

-- 12.8 NOTIFICATIONS POLICIES
DROP POLICY IF EXISTS "Notifications: Access own notifications" ON public.notifications;
CREATE POLICY "Notifications: Access own notifications"
  ON public.notifications FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 13. VERIFICATION QUERY
-- ------------------------------------------------------------------------------
SELECT 
  table_name,
  (SELECT count(*) FROM information_schema.columns c WHERE c.table_name = t.table_name AND c.table_schema = 'public') AS column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name IN (
    'departments', 'employees', 'profiles', 'checklist_templates',
    'checklist_items', 'inspections', 'inspection_results',
    'capa_actions', 'ccp_monitoring_logs', 'notifications'
  )
ORDER BY table_name;
