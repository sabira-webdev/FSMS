-- ==============================================================================
-- FSMS (Food Safety Management System) - Checklist Management Infrastructure
-- File: scripts/04_checklist_infrastructure.sql
-- Target: Supabase PostgreSQL 15+ / PostgREST / GoTrue Auth Integration
-- Version: 5.3 (Resilient Preflight & Department Resolution, Idempotent RLS & Triggers)
-- Safety: Preserves existing departments, employees, profiles, and RLS policies;
--         NO DESTRUCTIVE DROPS of existing tables, data, triggers, or custom policies;
--         NO UNCONDITIONAL DELETES of checklist items;
--         Deterministic, fail-closed preflight schema and prerequisite validation;
--         Transactional execution (BEGIN / COMMIT).
-- Dependencies: Requires public.departments, public.profiles,
--               public.handle_updated_at(), public.is_active_user(),
--               and public.is_active_role(TEXT[]).
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. PREFLIGHT SCHEMA & PREREQUISITE VALIDATION
-- Halts execution immediately with clear error if prerequisites or essential
-- schema compatibility checks fail, preventing partial or corrupt migrations.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_missing_depts TEXT;
  v_col_rec RECORD;
  v_actual_type TEXT;
  v_actual_nullable TEXT;
BEGIN
  -- 1.1 Verify prerequisite helper functions exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'handle_updated_at'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Function public.handle_updated_at() was not found. Please ensure scripts/02_auth_infrastructure.sql has been executed.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'is_active_user'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Function public.is_active_user() was not found. Please ensure scripts/03_employee_department_rls.sql has been executed.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'is_active_role'
      AND pg_get_function_arguments(p.oid) LIKE '%text[]%'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Function public.is_active_role(TEXT[]) was not found. Please ensure scripts/03_employee_department_rls.sql has been executed.';
  END IF;

  -- 1.2 Verify prerequisite tables exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'departments'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.departments was not found. Department foundation must exist before creating checklists.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'profiles'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.profiles was not found. Auth profiles infrastructure must exist.';
  END IF;

  -- 1.3 Check department codes availability (non-fatal; reports notice if any are missing)
  SELECT string_agg(req_code, ', ') INTO v_missing_depts
  FROM (
    SELECT unnest(ARRAY['SAN', 'COLD', 'PROD-A', 'WH']) AS req_code
  ) r
  WHERE NOT EXISTS (
    SELECT 1 FROM public.departments d 
    WHERE d.code = r.req_code 
       OR (r.req_code = 'SAN' AND d.name ILIKE '%Sanitation%')
       OR (r.req_code = 'COLD' AND d.name ILIKE '%Cold%')
       OR (r.req_code = 'PROD-A' AND (d.code = 'PROD' OR d.name ILIKE '%Production%'))
       OR (r.req_code = 'WH' AND (d.name ILIKE '%Warehouse%' OR d.name ILIKE '%Receiving%'))
  );

  IF v_missing_depts IS NOT NULL AND v_missing_depts <> '' THEN
    RAISE NOTICE 'Preflight notice: One or more starter department code(s) [%] not directly found in public.departments. Fallback department matching or NULL assignment will be applied during template seeding.', v_missing_depts;
  END IF;

  -- 1.4 Validate schema compatibility if public.checklist_templates already exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'checklist_templates'
  ) THEN
    -- A. Validate all required columns, data types, and nullability
    FOR v_col_rec IN (
      SELECT * FROM (VALUES
        ('id', 'uuid', 'NO'),
        ('code', 'text', 'NO'),
        ('title', 'text', 'NO'),
        ('description', 'text', 'YES'),
        ('department_id', 'uuid', 'YES'),
        ('category', 'text', 'NO'),
        ('version', 'integer', 'NO'),
        ('is_active', 'boolean', 'NO'),
        ('created_by', 'uuid', 'YES'),
        ('metadata', 'jsonb', 'NO'),
        ('created_at', 'timestamp with time zone', 'NO'),
        ('updated_at', 'timestamp with time zone', 'NO')
      ) AS t(col_name, expected_type, expected_nullable)
    ) LOOP
      SELECT data_type, is_nullable 
      INTO v_actual_type, v_actual_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public' 
        AND table_name = 'checklist_templates' 
        AND column_name = v_col_rec.col_name;

      IF v_actual_type IS NULL THEN
        RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_templates is missing required column "%".', v_col_rec.col_name;
      ELSIF v_actual_type <> v_col_rec.expected_type THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."%" has incompatible type "%" (expected "%").', v_col_rec.col_name, v_actual_type, v_col_rec.expected_type;
      ELSIF v_col_rec.expected_nullable = 'NO' AND v_actual_nullable <> 'NO' THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."%" is nullable, but required NOT NULL constraint is missing.', v_col_rec.col_name;
      END IF;
    END LOOP;

    -- B. Validate Primary Key constraint on id
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'checklist_templates' 
        AND tc.constraint_type = 'PRIMARY KEY' 
        AND kcu.column_name = 'id'
      GROUP BY tc.constraint_name
      HAVING COUNT(*) = 1
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_templates is missing a single-column PRIMARY KEY constraint on "id".';
    END IF;

    -- C. Validate unconditional UNIQUE constraint or unique index on code
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'checklist_templates' 
        AND tc.constraint_type = 'UNIQUE' 
        AND kcu.column_name = 'code'
      GROUP BY tc.constraint_name
      HAVING COUNT(*) = 1
    ) AND NOT EXISTS (
      SELECT 1 FROM pg_index i
      JOIN pg_class c ON c.oid = i.indrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = i.indkey[0]
      WHERE n.nspname = 'public' 
        AND c.relname = 'checklist_templates' 
        AND a.attname = 'code' 
        AND i.indisunique = true
        AND i.indnatts = 1
        AND i.indpred IS NULL
        AND i.indexprs IS NULL
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_templates is missing an unconditional single-column UNIQUE constraint or unique index on "code".';
    END IF;

    -- D. Validate Foreign Key on department_id if present
    IF EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'checklist_templates' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'department_id'
    ) AND NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      JOIN information_schema.constraint_column_usage ccu 
        ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'checklist_templates' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'department_id' 
        AND ccu.table_name = 'departments' 
        AND ccu.column_name = 'id'
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_templates has an invalid FOREIGN KEY on "department_id" (does not reference public.departments(id)).';
    END IF;

    -- E. Validate that existing category values strictly conform to allowed domain
    IF EXISTS (
      SELECT 1 FROM public.checklist_templates
      WHERE category NOT IN ('Sanitation', 'HACCP Prerequisite', 'Thermal CCP', 'GMP Audit', 'Allergen Control', 'Receiving')
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_templates contains rows with category values outside the allowed set [Sanitation, HACCP Prerequisite, Thermal CCP, GMP Audit, Allergen Control, Receiving]. Manual data review required before migration.';
    END IF;
  END IF;

  -- 1.5 Validate schema compatibility if public.checklist_items already exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'checklist_items'
  ) THEN
    -- A. Validate all required columns, data types, and nullability
    FOR v_col_rec IN (
      SELECT * FROM (VALUES
        ('id', 'uuid', 'NO'),
        ('template_id', 'uuid', 'NO'),
        ('item_order', 'integer', 'NO'),
        ('section_title', 'text', 'NO'),
        ('question', 'text', 'NO'),
        ('instruction', 'text', 'YES'),
        ('response_type', 'text', 'NO'),
        ('is_critical', 'boolean', 'NO'),
        ('min_value', 'numeric', 'YES'),
        ('max_value', 'numeric', 'YES'),
        ('unit', 'text', 'YES'),
        ('options', 'jsonb', 'NO'),
        ('created_at', 'timestamp with time zone', 'NO')
      ) AS t(col_name, expected_type, expected_nullable)
    ) LOOP
      SELECT data_type, is_nullable 
      INTO v_actual_type, v_actual_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public' 
        AND table_name = 'checklist_items' 
        AND column_name = v_col_rec.col_name;

      IF v_actual_type IS NULL THEN
        RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_items is missing required column "%".', v_col_rec.col_name;
      ELSIF v_actual_type <> v_col_rec.expected_type THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."%" has incompatible type "%" (expected "%").', v_col_rec.col_name, v_actual_type, v_col_rec.expected_type;
      ELSIF v_col_rec.expected_nullable = 'NO' AND v_actual_nullable <> 'NO' THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."%" is nullable, but required NOT NULL constraint is missing.', v_col_rec.col_name;
      END IF;
    END LOOP;

    -- B. Validate Primary Key constraint on id
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'checklist_items' 
        AND tc.constraint_type = 'PRIMARY KEY' 
        AND kcu.column_name = 'id'
      GROUP BY tc.constraint_name
      HAVING COUNT(*) = 1
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_items is missing a single-column PRIMARY KEY constraint on "id".';
    END IF;

    -- C. Validate Foreign Key on template_id referencing public.checklist_templates(id)
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      JOIN information_schema.constraint_column_usage ccu 
        ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'checklist_items' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'template_id' 
        AND ccu.table_name = 'checklist_templates' 
        AND ccu.column_name = 'id'
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_items has an invalid or missing FOREIGN KEY on "template_id" (expected references public.checklist_templates(id)).';
    END IF;

    -- D. Validate that existing response_type values strictly conform to allowed domain
    IF EXISTS (
      SELECT 1 FROM public.checklist_items
      WHERE response_type NOT IN ('pass_fail', 'numeric', 'text', 'multiple_choice')
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_items contains rows with response_type values outside the allowed set [pass_fail, numeric, text, multiple_choice]. Manual data review required before migration.';
    END IF;

    -- E. Validate item_key column if it already exists
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' 
        AND table_name = 'checklist_items' 
        AND column_name = 'item_key'
    ) THEN
      SELECT data_type INTO v_actual_type
      FROM information_schema.columns
      WHERE table_schema = 'public' 
        AND table_name = 'checklist_items' 
        AND column_name = 'item_key';

      IF v_actual_type <> 'text' THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."item_key" exists but has incompatible type "%" (expected "text").', v_actual_type;
      END IF;

      -- Check for existing duplicate non-null values
      IF EXISTS (
        SELECT 1 FROM public.checklist_items
        WHERE item_key IS NOT NULL
        GROUP BY item_key
        HAVING COUNT(*) > 1
      ) THEN
        RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_items contains duplicate non-null values for "item_key". Manual deduplication required before migration.';
      END IF;
    END IF;
  END IF;

END $$;

-- ------------------------------------------------------------------------------
-- 2. CHECKLIST TEMPLATES (SOPs, Inspection Protocols & Master Audit Forms)
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- Idempotently configure updated_at trigger on checklist_templates
DROP TRIGGER IF EXISTS tr_checklist_templates_updated_at ON public.checklist_templates;
CREATE TRIGGER tr_checklist_templates_updated_at
  BEFORE UPDATE ON public.checklist_templates
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ------------------------------------------------------------------------------
-- 3. CHECKLIST ITEMS (Verification Questions, Critical Safety Limits & Options)
-- Supports stable identifier (item_key) for safe idempotent seed operations.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES public.checklist_templates(id) ON DELETE CASCADE,
  item_key TEXT UNIQUE,
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- Safely ensure item_key column exists if checklist_items pre-existed without it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
      AND table_name = 'checklist_items' 
      AND column_name = 'item_key'
  ) THEN
    ALTER TABLE public.checklist_items ADD COLUMN item_key TEXT UNIQUE;
  END IF;
END $$;

-- Ensure an unconditional unique index on item_key exists if column exists without constraint/index
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_index i
    JOIN pg_class c ON c.oid = i.indrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = i.indkey[0]
    WHERE n.nspname = 'public' 
      AND c.relname = 'checklist_items' 
      AND a.attname = 'item_key' 
      AND i.indisunique = true
      AND i.indnatts = 1
      AND i.indpred IS NULL
      AND i.indexprs IS NULL
  ) THEN
    CREATE UNIQUE INDEX idx_checklist_items_item_key ON public.checklist_items(item_key);
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 4. PERFORMANCE INDEXES
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_checklist_templates_dept ON public.checklist_templates(department_id);
CREATE INDEX IF NOT EXISTS idx_checklist_templates_category ON public.checklist_templates(category);
CREATE INDEX IF NOT EXISTS idx_checklist_templates_active ON public.checklist_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_checklist_items_template ON public.checklist_items(template_id, item_order);

-- ------------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- Enables RLS and idempotently recreates exact checklist policies.
-- Preserves any unrelated custom policies on these tables.
-- ------------------------------------------------------------------------------
ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;

-- 5.1 Checklist Templates Policies
DROP POLICY IF EXISTS "Checklist Templates: Read for active authenticated users" ON public.checklist_templates;
CREATE POLICY "Checklist Templates: Read for active authenticated users"
  ON public.checklist_templates FOR SELECT
  TO authenticated
  USING (public.is_active_user());

DROP POLICY IF EXISTS "Checklist Templates: Manage by active Admins, QM, & Lead Auditors" ON public.checklist_templates;
CREATE POLICY "Checklist Templates: Manage by active Admins, QM, & Lead Auditors"
  ON public.checklist_templates FOR ALL
  TO authenticated
  USING (public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']))
  WITH CHECK (public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']));

-- 5.2 Checklist Items Policies
DROP POLICY IF EXISTS "Checklist Items: Read for active authenticated users" ON public.checklist_items;
CREATE POLICY "Checklist Items: Read for active authenticated users"
  ON public.checklist_items FOR SELECT
  TO authenticated
  USING (public.is_active_user());

DROP POLICY IF EXISTS "Checklist Items: Manage by active Admins, QM, & Lead Auditors" ON public.checklist_items;
CREATE POLICY "Checklist Items: Manage by active Admins, QM, & Lead Auditors"
  ON public.checklist_items FOR ALL
  TO authenticated
  USING (public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']))
  WITH CHECK (public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']));

-- ------------------------------------------------------------------------------
-- 6. AUDIT INTEGRITY CONSTRAINT DOCUMENTATION
-- In operational inspection workflows (public.inspections), records reference
-- public.checklist_templates(id) with ON DELETE RESTRICT.
-- Checklist templates that have been audited against MUST NOT be hard-deleted.
-- The UI handles deprecation through soft-deactivation (is_active = false).
-- ------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------
-- 7. IDEMPOTENT STARTER SEED DATA
-- Inserts 4 starter checklist templates and configured questions.
-- Templates use ON CONFLICT (code) DO NOTHING.
-- Questions use ON CONFLICT (item_key) DO NOTHING.
-- Re-running this script will NEVER delete existing questions, duplicate rows,
-- or overwrite user edits in the database.
--
-- MANDATORY FOOD SAFETY GOVERNANCE NOTICE:
-- All numbers, concentrations, temperatures, timeframes, and procedural steps
-- below are UNVERIFIED EXAMPLES for software demonstration purposes only.
-- They MUST NOT be assumed to be universally valid, regulatory, or mandatory.
-- Facility-specific procedures, chemical concentrations, critical thermal limits,
-- and action thresholds MUST be established, validated, and formally approved
-- by the facility's responsible Food Safety Lead and aligned with the facility's
-- approved food safety plan (HACCP/HARPC) and applicable statutory regulations.
-- ------------------------------------------------------------------------------

DO $$
DECLARE
  v_san_dept_id UUID;
  v_cold_dept_id UUID;
  v_prod_dept_id UUID;
  v_wh_dept_id UUID;
  v_tpl_san_id UUID;
  v_tpl_ccp_id UUID;
  v_tpl_all_id UUID;
  v_tpl_rec_id UUID;
BEGIN
  -- Resilient department resolution: Match by code first, fallback to name, allow NULL if unassigned
  SELECT id INTO v_san_dept_id 
  FROM public.departments 
  WHERE code = 'SAN' OR name ILIKE '%Sanitation%'
  ORDER BY CASE WHEN code = 'SAN' THEN 1 ELSE 2 END
  LIMIT 1;

  SELECT id INTO v_cold_dept_id 
  FROM public.departments 
  WHERE code = 'COLD' OR name ILIKE '%Cold%'
  ORDER BY CASE WHEN code = 'COLD' THEN 1 ELSE 2 END
  LIMIT 1;

  SELECT id INTO v_prod_dept_id 
  FROM public.departments 
  WHERE code = 'PROD-A' OR code = 'PROD' OR name ILIKE '%Production Line A%' OR name ILIKE '%Production%'
  ORDER BY CASE WHEN code = 'PROD-A' THEN 1 WHEN code = 'PROD' THEN 2 ELSE 3 END
  LIMIT 1;

  SELECT id INTO v_wh_dept_id 
  FROM public.departments 
  WHERE code = 'WH' OR name ILIKE '%Warehouse%' OR name ILIKE '%Receiving%'
  ORDER BY CASE WHEN code = 'WH' THEN 1 ELSE 2 END
  LIMIT 1;

  IF v_san_dept_id IS NULL THEN
    RAISE NOTICE 'Department resolution: Sanitation department (SAN) not found. Template CHK-SAN-001 will have NULL department_id.';
  END IF;
  IF v_cold_dept_id IS NULL THEN
    RAISE NOTICE 'Department resolution: Cold Chain department (COLD) not found. Template CHK-CCP-001 will have NULL department_id.';
  END IF;
  IF v_prod_dept_id IS NULL THEN
    RAISE NOTICE 'Department resolution: Production Line A department (PROD-A) not found. Template CHK-ALL-001 will have NULL department_id.';
  END IF;
  IF v_wh_dept_id IS NULL THEN
    RAISE NOTICE 'Department resolution: Warehouse/Receiving department (WH) not found. Template CHK-REC-001 will have NULL department_id.';
  END IF;

  -- ----------------------------------------------------------------------------
  -- Template 1: Daily Pre-Operational Sanitation Verification
  -- ----------------------------------------------------------------------------
  INSERT INTO public.checklist_templates (code, title, description, department_id, category, version, is_active, metadata)
  VALUES (
    'CHK-SAN-001',
    'Daily Pre-Operational Sanitation Verification',
    'Pre-shift food contact surface inspection, ATP bioluminescence monitoring, and chemical sanitizer titration verifications.',
    v_san_dept_id,
    'Sanitation',
    1,
    true,
    '{"estimated_minutes": 25, "frequency": "Daily - Pre-Operational"}'::jsonb
  )
  ON CONFLICT (code) DO NOTHING;

  SELECT id INTO v_tpl_san_id FROM public.checklist_templates WHERE code = 'CHK-SAN-001';

  IF v_tpl_san_id IS NOT NULL THEN
    INSERT INTO public.checklist_items (item_key, template_id, item_order, section_title, question, instruction, response_type, is_critical, min_value, max_value, unit, options)
    VALUES
      (
        'CHK-SAN-001-Q1', v_tpl_san_id, 1, 'Physical Zone Inspection',
        'Visual Inspection: Inspect food contact surfaces, conveyor belts, and product chutes for visible cleanliness.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Visual inspection criteria, light levels, and dismantle depths must be specified in the facility''s approved Sanitation Standard Operating Procedures (SSOP).',
        'pass_fail', true, NULL, NULL, NULL, '[]'::jsonb
      ),
      (
        'CHK-SAN-001-Q2', v_tpl_san_id, 2, 'Chemical Sanitation',
        'Sanitizer Concentration Check: Measure active sanitizer concentration at designated application points.',
        '[UNVERIFIED EXAMPLE SPECIFICATION] Baseline range 150.00-200.00 ppm is an illustrative example only. Chemical type, target concentration, titration methods, and minimum contact times must be approved by the facility Food Safety Lead in accordance with chemical manufacturer instructions and regulatory standards.',
        'numeric', true, 150.00, 200.00, 'ppm', '[]'::jsonb
      ),
      (
        'CHK-SAN-001-Q3', v_tpl_san_id, 3, 'Microbial & Environmental Swabbing',
        'Pre-Operational Environmental Swabbing: Measure ATP bioluminescence reading at selected high-risk food contact points.',
        '[UNVERIFIED EXAMPLE SPECIFICATION] Baseline range 0.00-30.00 RLU is an illustrative manufacturer benchmark. Action limits, sampling sites, corrective action thresholds, and swabbing frequencies must be established and approved by the facility Food Safety Lead based on luminometer calibration.',
        'numeric', true, 0.00, 30.00, 'RLU', '[]'::jsonb
      ),
      (
        'CHK-SAN-001-Q4', v_tpl_san_id, 4, 'Chemical Safety & Storage',
        'Sanitation Chemical Storage: Verify chemicals are properly stored in designated areas with SDS accessible.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Storage requirements, secondary containment, and SDS access must comply with local chemical safety regulations and facility safety plans.',
        'pass_fail', false, NULL, NULL, NULL, '[]'::jsonb
      )
    ON CONFLICT (item_key) DO NOTHING;
  END IF;

  -- ----------------------------------------------------------------------------
  -- Template 2: Critical Control Point: Cold Chain & Blast Chilling
  -- ----------------------------------------------------------------------------
  INSERT INTO public.checklist_templates (code, title, description, department_id, category, version, is_active, metadata)
  VALUES (
    'CHK-CCP-001',
    'Critical Control Point: Blast Chilling & Cold Storage',
    'HACCP CCP monitoring for blast chill cycle time-temperature parameters and deep freezer holding storage.',
    v_cold_dept_id,
    'Thermal CCP',
    1,
    true,
    '{"estimated_minutes": 15, "frequency": "Per Production Batch / Every 2 Hours"}'::jsonb
  )
  ON CONFLICT (code) DO NOTHING;

  SELECT id INTO v_tpl_ccp_id FROM public.checklist_templates WHERE code = 'CHK-CCP-001';

  IF v_tpl_ccp_id IS NOT NULL THEN
    INSERT INTO public.checklist_items (item_key, template_id, item_order, section_title, question, instruction, response_type, is_critical, min_value, max_value, unit, options)
    VALUES
      (
        'CHK-CCP-001-Q1', v_tpl_ccp_id, 1, 'Critical Control Point (Thermal)',
        'Cooling / Thermal Process Check: Measure core product temperature following thermal processing.',
        '[UNVERIFIED EXAMPLE SPECIFICATION] Core chill target range -2.00°C to 4.0°C within 120 minutes is an illustrative reference only. Actual Critical Control Point (CCP) limits, validation studies, probe penetration protocols, and monitoring intervals must be defined in the facility''s validated HACCP plan and approved by the Food Safety Lead.',
        'numeric', true, -2.00, 4.00, '°C', '[]'::jsonb
      ),
      (
        'CHK-CCP-001-Q2', v_tpl_ccp_id, 2, 'Telemetry Verification',
        'Continuous Temperature Recording Verification: Confirm operational status of chilling and refrigeration temperature loggers.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Verification frequencies, calibration tolerance (e.g. +/- 0.5°C), and alarm response protocols must be approved by the facility Food Safety Lead.',
        'pass_fail', true, NULL, NULL, NULL, '[]'::jsonb
      ),
      (
        'CHK-CCP-001-Q3', v_tpl_ccp_id, 3, 'Cold Holding Zone',
        'Chilled Storage Holding Temperature: Verify ambient air temperature of finished product holding storage.',
        '[UNVERIFIED EXAMPLE SPECIFICATION] Baseline range 0.00°C to 3.0°C is an illustrative holding reference. Air temperature limits and defrost allowances must be established by facility refrigeration engineering and approved by the Food Safety Lead.',
        'numeric', false, 0.00, 3.00, '°C', '[]'::jsonb
      ),
      (
        'CHK-CCP-001-Q4', v_tpl_ccp_id, 4, 'Facility Hygiene Barrier',
        'Condensation Control: Inspect overhead refrigeration units and ceiling structures above product zones.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Condensate prevention protocols, drip pan inspections, and product protection measures must align with facility GMP and hygiene barrier guidelines.',
        'pass_fail', true, NULL, NULL, NULL, '[]'::jsonb
      )
    ON CONFLICT (item_key) DO NOTHING;
  END IF;

  -- ----------------------------------------------------------------------------
  -- Template 3: Allergen Changeover & Line Clearance Protocol
  -- ----------------------------------------------------------------------------
  INSERT INTO public.checklist_templates (code, title, description, department_id, category, version, is_active, metadata)
  VALUES (
    'CHK-ALL-001',
    'Allergen Changeover & Line Clearance Protocol',
    'Validation procedure when transitioning production lines between allergen profiles (e.g., dairy/nut to non-allergen).',
    v_prod_dept_id,
    'Allergen Control',
    1,
    true,
    '{"estimated_minutes": 35, "frequency": "Post-Allergen Run / Prior to Changeover"}'::jsonb
  )
  ON CONFLICT (code) DO NOTHING;

  SELECT id INTO v_tpl_all_id FROM public.checklist_templates WHERE code = 'CHK-ALL-001';

  IF v_tpl_all_id IS NOT NULL THEN
    INSERT INTO public.checklist_items (item_key, template_id, item_order, section_title, question, instruction, response_type, is_critical, min_value, max_value, unit, options)
    VALUES
      (
        'CHK-ALL-001-Q1', v_tpl_all_id, 1, 'Line Clearance',
        'Line Clearance & Ingredient Segregation: Verify removal of prior production ingredients, packaging, and labels.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Clearance checklists and segregation buffers must be approved by the facility Food Safety Lead under the facility''s Allergen Management Program.',
        'pass_fail', true, NULL, NULL, NULL, '[]'::jsonb
      ),
      (
        'CHK-ALL-001-Q2', v_tpl_all_id, 2, 'Deep Wet Clean',
        'Allergen Sanitation Wash-Down: Execute validated wet sanitation protocol on product contact surfaces and transfer lines.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Cleaning procedures, teardown depth, chemical selection, and water temperatures must be validated for allergen removal and approved by the Food Safety Lead.',
        'pass_fail', true, NULL, NULL, NULL, '[]'::jsonb
      ),
      (
        'CHK-ALL-001-Q3', v_tpl_all_id, 3, 'Rapid Lateral Flow Verification',
        'Rapid Allergen Residue Test: Test critical line dead-leg or product contact surface for allergen protein residue.',
        '[UNVERIFIED EXAMPLE PROTOCOL] Swab locations, test kit sensitivity, and positive result hold/re-clean protocols must be specified in the approved Allergen Management Plan.',
        'multiple_choice', true, NULL, NULL, NULL,
        '["Negative / Undetected (Passed)", "Positive / Trace Detected (Hold & Re-clean)"]'::jsonb
      ),
      (
        'CHK-ALL-001-Q4', v_tpl_all_id, 4, 'Quality Sign-Off',
        'Allergen Changeover Release Sign-Off: Document quality verification and line release authorization.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Sign-off authority, documentation requirements, and record retention must follow facility Quality Assurance policy.',
        'text', false, NULL, NULL, NULL, '[]'::jsonb
      )
    ON CONFLICT (item_key) DO NOTHING;
  END IF;

  -- ----------------------------------------------------------------------------
  -- Template 4: Raw Material Receiving & Inbound Quality Verification
  -- ----------------------------------------------------------------------------
  INSERT INTO public.checklist_templates (code, title, description, department_id, category, version, is_active, metadata)
  VALUES (
    'CHK-REC-001',
    'Raw Material Intake & Inbound Logistics Verification',
    'Inbound ingredient quality control, transport vehicle sanitization, temperature upon receipt, and COA matching.',
    v_wh_dept_id,
    'Receiving',
    1,
    true,
    '{"estimated_minutes": 20, "frequency": "Per Inbound Freight Shipment"}'::jsonb
  )
  ON CONFLICT (code) DO NOTHING;

  SELECT id INTO v_tpl_rec_id FROM public.checklist_templates WHERE code = 'CHK-REC-001';

  IF v_tpl_rec_id IS NOT NULL THEN
    INSERT INTO public.checklist_items (item_key, template_id, item_order, section_title, question, instruction, response_type, is_critical, min_value, max_value, unit, options)
    VALUES
      (
        'CHK-REC-001-Q1', v_tpl_rec_id, 1, 'Trailer Inspection',
        'Transport Vehicle Condition: Inspect inbound freight carrier for general cleanliness, structural integrity, and absence of contamination.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Inbound transport criteria, pest inspection standards, and carrier rejection thresholds must be defined in the facility''s Supplier & Receiving SOP.',
        'pass_fail', false, NULL, NULL, NULL, '[]'::jsonb
      ),
      (
        'CHK-REC-001-Q2', v_tpl_rec_id, 2, 'Tamper Security',
        'Security Seal Verification: Confirm cargo seal integrity and verify seal number against shipping documentation.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Cargo security protocols, seal discrepancy handling, and food defense procedures must be approved by facility management.',
        'pass_fail', true, NULL, NULL, NULL, '[]'::jsonb
      ),
      (
        'CHK-REC-001-Q3', v_tpl_rec_id, 3, 'Thermal Integrity',
        'Inbound Raw Material Temperature: Measure surface or internal temperature of temperature-sensitive inbound goods upon arrival.',
        '[UNVERIFIED EXAMPLE SPECIFICATION] Baseline range 0.00°C to 4.50°C is an illustrative receiving reference. Critical temperature limits, acceptance thresholds, and probe insertion methods must be approved by the Food Safety Lead based on product specifications.',
        'numeric', true, 0.00, 4.50, '°C', '[]'::jsonb
      ),
      (
        'CHK-REC-001-Q4', v_tpl_rec_id, 4, 'Traceability & Compliance',
        'Certificate of Analysis & Lot Documentation: Verify COA, lot numbers, and shelf-life parameters match purchase specifications.',
        '[UNVERIFIED EXAMPLE PROCEDURE] Shelf-life minimums, COA parameter verification, and quarantine holds must follow approved raw material intake specifications.',
        'pass_fail', false, NULL, NULL, NULL, '[]'::jsonb
      )
    ON CONFLICT (item_key) DO NOTHING;
  END IF;

END $$;

COMMIT;

-- ------------------------------------------------------------------------------
-- 8. VERIFICATION QUERY (Run after execution to inspect created templates & items)
-- Checks all four seeded templates, their department names, active status,
-- total question counts, and critical question counts.
-- ------------------------------------------------------------------------------
SELECT 
  t.code,
  t.title,
  t.category,
  t.is_active,
  COALESCE(d.name, 'Unassigned') AS department_name,
  COUNT(i.id) AS total_items,
  COUNT(i.id) FILTER (WHERE i.is_critical = true) AS critical_items
FROM public.checklist_templates t
LEFT JOIN public.departments d ON d.id = t.department_id
LEFT JOIN public.checklist_items i ON i.template_id = t.id
WHERE t.code IN ('CHK-SAN-001', 'CHK-CCP-001', 'CHK-ALL-001', 'CHK-REC-001')
GROUP BY t.id, t.code, t.title, t.category, t.is_active, d.name
ORDER BY t.code;
