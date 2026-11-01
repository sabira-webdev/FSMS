-- ==============================================================================
-- FSMS (Food Safety Management System) - Inspections & Audit Infrastructure
-- File: scripts/05_inspections_infrastructure_v3_8.sql
-- Target: Supabase PostgreSQL 15+ / PostgREST / GoTrue Auth Integration
-- Version: 3.8 (Universal Compliance Retention, pg_trigger_depth() Cascade Verification,
--               Order-Independent & Schema-Qualified Constraint Validation,
--               Separated Result DML RLS Policies, Commutative Index & RLS Preflight Audit)
-- Safety: Preserves existing departments, employees, profiles, checklist templates,
--         checklist items, and custom RLS policies on unrelated tables;
--         NO DESTRUCTIVE DROPS of existing tables or operational data;
--         Deterministic, fail-closed preflight schema, function, constraint, and RLS policy validation;
--         Transactional execution (BEGIN / COMMIT).
-- Dependencies: Requires public.departments, public.profiles,
--               public.checklist_templates, public.checklist_items,
--               public.handle_updated_at(), public.is_active_user(),
--               and public.is_active_role(TEXT[]).
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. PREFLIGHT SCHEMA & PREREQUISITE VALIDATION
-- Halts execution immediately with clear error if prerequisites, exact function
-- signatures, referenced column types, single-column primary keys, exact foreign
-- keys, permitted check constraints, or unapproved RLS policies fail.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_col_rec RECORD;
  v_fk_rec RECORD;
  v_con_rec RECORD;
  v_custom_pol RECORD;
  v_actual_type TEXT;
  v_actual_udt TEXT;
  v_actual_nullable TEXT;
  v_val TEXT;
  v_norm_def TEXT;
  v_fk_found BOOLEAN;
  v_found_status_con BOOLEAN;
  v_found_result_con BOOLEAN;
  v_eval_success BOOLEAN;
  v_dynamic_eval_ok BOOLEAN;
  v_bool_result BOOLEAN;
  v_extracted_values TEXT[];
  v_extracted_count INTEGER;
BEGIN
  -- 1.1 Verify prerequisite helper functions exist with EXACT signatures and return types
  -- A. handle_updated_at() -> trigger
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' 
      AND p.proname = 'handle_updated_at'
      AND p.pronargs = 0
      AND p.prorettype = 'trigger'::regtype
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Function public.handle_updated_at() returning trigger was not found. Please ensure scripts/02_auth_infrastructure.sql has been executed.';
  END IF;

  -- B. is_active_user() -> boolean
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' 
      AND p.proname = 'is_active_user'
      AND p.pronargs = 0
      AND p.prorettype = 'boolean'::regtype
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Function public.is_active_user() returning boolean was not found. Please ensure scripts/03_employee_department_rls.sql has been executed.';
  END IF;

  -- C. is_active_role(text[]) -> boolean
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' 
      AND p.proname = 'is_active_role'
      AND p.pronargs = 1
      AND p.proargtypes[0] = 'text[]'::regtype
      AND p.prorettype = 'boolean'::regtype
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Function public.is_active_role(TEXT[]) returning boolean was not found. Please ensure scripts/03_employee_department_rls.sql has been executed.';
  END IF;

  -- 1.2 Verify prerequisite tables exist, have UUID id column, and have EXACTLY ONE primary key column named "id"
  -- Table: public.departments (single-column PK on id UUID, name TEXT, code TEXT)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'departments'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.departments was not found. Department foundation must exist before creating inspections.';
  END IF;

  SELECT data_type, is_nullable
  INTO v_actual_type, v_actual_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'departments' AND column_name = 'id';

  IF v_actual_type IS NULL THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.departments is missing required column "id".';
  ELSIF v_actual_type <> 'uuid' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.departments.id must be of type UUID (found "%").', v_actual_type;
  ELSIF v_actual_nullable <> 'NO' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.departments.id must be NOT NULL.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
    WHERE c.conrelid = 'public.departments'::regclass
      AND c.contype = 'p'
      AND cardinality(c.conkey) = 1
      AND a.attname = 'id'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
      ON kcu.constraint_name = tc.constraint_name 
     AND kcu.constraint_schema = tc.constraint_schema
     AND kcu.table_name = tc.table_name
     AND kcu.table_schema = tc.table_schema
    WHERE tc.table_schema = 'public' 
      AND tc.table_name = 'departments' 
      AND tc.constraint_type = 'PRIMARY KEY' 
    GROUP BY tc.constraint_name
    HAVING COUNT(*) = 1 AND MAX(kcu.column_name) = 'id'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.departments must have exactly one PRIMARY KEY column, and that column must be "id".';
  END IF;

  -- Table: public.profiles (single-column PK on id UUID, role TEXT, is_active BOOLEAN)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'profiles'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.profiles was not found. Auth profiles infrastructure must exist.';
  END IF;

  SELECT data_type, is_nullable
  INTO v_actual_type, v_actual_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'id';

  IF v_actual_type IS NULL THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.profiles is missing required column "id".';
  ELSIF v_actual_type <> 'uuid' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.profiles.id must be of type UUID (found "%").', v_actual_type;
  ELSIF v_actual_nullable <> 'NO' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.profiles.id must be NOT NULL.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
    WHERE c.conrelid = 'public.profiles'::regclass
      AND c.contype = 'p'
      AND cardinality(c.conkey) = 1
      AND a.attname = 'id'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
      ON kcu.constraint_name = tc.constraint_name 
     AND kcu.constraint_schema = tc.constraint_schema
     AND kcu.table_name = tc.table_name
     AND kcu.table_schema = tc.table_schema
    WHERE tc.table_schema = 'public' 
      AND tc.table_name = 'profiles' 
      AND tc.constraint_type = 'PRIMARY KEY' 
    GROUP BY tc.constraint_name
    HAVING COUNT(*) = 1 AND MAX(kcu.column_name) = 'id'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.profiles must have exactly one PRIMARY KEY column, and that column must be "id".';
  END IF;

  -- Table: public.checklist_templates (single-column PK on id UUID, code TEXT, is_active BOOLEAN)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'checklist_templates'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.checklist_templates was not found. Checklist template infrastructure must exist before creating inspections.';
  END IF;

  SELECT data_type, is_nullable
  INTO v_actual_type, v_actual_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'checklist_templates' AND column_name = 'id';

  IF v_actual_type IS NULL THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.checklist_templates is missing required column "id".';
  ELSIF v_actual_type <> 'uuid' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates.id must be of type UUID (found "%").', v_actual_type;
  ELSIF v_actual_nullable <> 'NO' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates.id must be NOT NULL.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
    WHERE c.conrelid = 'public.checklist_templates'::regclass
      AND c.contype = 'p'
      AND cardinality(c.conkey) = 1
      AND a.attname = 'id'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
      ON kcu.constraint_name = tc.constraint_name 
     AND kcu.constraint_schema = tc.constraint_schema
     AND kcu.table_name = tc.table_name
     AND kcu.table_schema = tc.table_schema
    WHERE tc.table_schema = 'public' 
      AND tc.table_name = 'checklist_templates' 
      AND tc.constraint_type = 'PRIMARY KEY' 
    GROUP BY tc.constraint_name
    HAVING COUNT(*) = 1 AND MAX(kcu.column_name) = 'id'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.checklist_templates must have exactly one PRIMARY KEY column, and that column must be "id".';
  END IF;

  -- Table: public.checklist_items (single-column PK on id UUID, template_id UUID)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'checklist_items'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.checklist_items was not found. Checklist item infrastructure must exist before creating inspections.';
  END IF;

  SELECT data_type, is_nullable
  INTO v_actual_type, v_actual_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'checklist_items' AND column_name = 'id';

  IF v_actual_type IS NULL THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.checklist_items is missing required column "id".';
  ELSIF v_actual_type <> 'uuid' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items.id must be of type UUID (found "%").', v_actual_type;
  ELSIF v_actual_nullable <> 'NO' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items.id must be NOT NULL.';
  END IF;

  SELECT data_type, is_nullable
  INTO v_actual_type, v_actual_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'checklist_items' AND column_name = 'template_id';

  IF v_actual_type IS NULL THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.checklist_items is missing required column "template_id".';
  ELSIF v_actual_type <> 'uuid' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items.template_id must be of type UUID (found "%").', v_actual_type;
  ELSIF v_actual_nullable <> 'NO' THEN
    RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items.template_id must be NOT NULL.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
    WHERE c.conrelid = 'public.checklist_items'::regclass
      AND c.contype = 'p'
      AND cardinality(c.conkey) = 1
      AND a.attname = 'id'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
      ON kcu.constraint_name = tc.constraint_name 
     AND kcu.constraint_schema = tc.constraint_schema
     AND kcu.table_name = tc.table_name
     AND kcu.table_schema = tc.table_schema
    WHERE tc.table_schema = 'public' 
      AND tc.table_name = 'checklist_items' 
      AND tc.constraint_type = 'PRIMARY KEY' 
    GROUP BY tc.constraint_name
    HAVING COUNT(*) = 1 AND MAX(kcu.column_name) = 'id'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.checklist_items must have exactly one PRIMARY KEY column, and that column must be "id".';
  END IF;

  -- Verify checklist_items.template_id single-column foreign key to public.checklist_templates(id)
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_attribute src_a ON src_a.attrelid = c.conrelid AND src_a.attnum = c.conkey[1]
    JOIN pg_attribute dst_a ON dst_a.attrelid = c.confrelid AND dst_a.attnum = c.confkey[1]
    WHERE c.conrelid = 'public.checklist_items'::regclass
      AND c.confrelid = 'public.checklist_templates'::regclass
      AND c.contype = 'f'
      AND cardinality(c.conkey) = 1
      AND cardinality(c.confkey) = 1
      AND src_a.attname = 'template_id'
      AND dst_a.attname = 'id'
  ) THEN
    RAISE EXCEPTION 'Preflight validation failed: Table public.checklist_items is missing single-column foreign key on "template_id" referencing public.checklist_templates(id).';
  END IF;

  -- 1.3 Validate schema compatibility if public.inspections pre-exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'inspections'
  ) THEN
    -- A. Single-column Primary Key on id
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint c
      JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
      WHERE c.conrelid = 'public.inspections'::regclass
        AND c.contype = 'p'
        AND cardinality(c.conkey) = 1
        AND a.attname = 'id'
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name 
       AND kcu.constraint_schema = tc.constraint_schema
       AND kcu.table_name = tc.table_name
       AND kcu.table_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'inspections' 
        AND tc.constraint_type = 'PRIMARY KEY' 
      GROUP BY tc.constraint_name
      HAVING COUNT(*) = 1 AND MAX(kcu.column_name) = 'id'
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspections must have exactly one PRIMARY KEY column on "id".';
    END IF;

    -- B. Required columns, data types, and nullability
    FOR v_col_rec IN (
      SELECT * FROM (VALUES
        ('id', 'uuid', 'NO'),
        ('inspection_code', 'text', 'NO'),
        ('template_id', 'uuid', 'NO'),
        ('department_id', 'uuid', 'NO'),
        ('auditor_id', 'uuid', 'NO'),
        ('scheduled_date', 'date', 'NO'),
        ('conducted_at', 'timestamp with time zone', 'YES'),
        ('status', 'text', 'NO'),
        ('score', 'numeric', 'YES'),
        ('total_items', 'integer', 'NO'),
        ('passed_items', 'integer', 'NO'),
        ('failed_items', 'integer', 'NO'),
        ('facility_zone', 'text', 'YES'),
        ('shift', 'text', 'YES'),
        ('summary_notes', 'text', 'YES'),
        ('digital_signature_url', 'text', 'YES'),
        ('created_at', 'timestamp with time zone', 'NO'),
        ('updated_at', 'timestamp with time zone', 'NO')
      ) AS t(col_name, expected_type, expected_nullable)
    ) LOOP
      SELECT data_type, is_nullable 
      INTO v_actual_type, v_actual_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public' 
        AND table_name = 'inspections' 
        AND column_name = v_col_rec.col_name;

      IF v_actual_type IS NULL THEN
        RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspections is missing required column "%".', v_col_rec.col_name;
      ELSIF v_actual_type <> v_col_rec.expected_type THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.inspections."%" has incompatible type "%" (expected "%").', v_col_rec.col_name, v_actual_type, v_col_rec.expected_type;
      ELSIF v_col_rec.expected_nullable = 'NO' AND v_actual_nullable <> 'NO' THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.inspections."%" is nullable, but required NOT NULL constraint is missing.', v_col_rec.col_name;
      END IF;
    END LOOP;

    -- C. Unique constraint or index on inspection_code
    IF NOT EXISTS (
      SELECT 1 FROM pg_index i
      JOIN pg_class c ON c.oid = i.indrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = i.indkey[0]
      WHERE n.nspname = 'public' 
        AND c.relname = 'inspections'
        AND i.indisunique = true 
        AND i.indisvalid = true
        AND i.indnatts = 1 
        AND a.attname = 'inspection_code'
        AND i.indpred IS NULL
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspections must have a valid single-column UNIQUE constraint or unique index on "inspection_code".';
    END IF;

    -- D. Single-column Foreign Keys validation with exact target in public schema and ON DELETE action:
    --    - template_id -> checklist_templates(id) ON DELETE RESTRICT ('r' or 'a')
    --    - department_id -> departments(id) ON DELETE RESTRICT ('r' or 'a')
    --    - auditor_id -> profiles(id) ON DELETE RESTRICT ('r' or 'a')
    FOR v_fk_rec IN (
      SELECT * FROM (VALUES
        ('template_id', 'checklist_templates', 'id', ARRAY['r', 'a'], 'ON DELETE RESTRICT'),
        ('department_id', 'departments', 'id', ARRAY['r', 'a'], 'ON DELETE RESTRICT'),
        ('auditor_id', 'profiles', 'id', ARRAY['r', 'a'], 'ON DELETE RESTRICT')
      ) AS t(src_col, dst_table, dst_col, valid_del_types, del_desc)
    ) LOOP
      v_fk_found := false;
      FOR v_con_rec IN (
        SELECT c.conname, c.confdeltype,
               cardinality(c.conkey) AS src_col_count,
               cardinality(c.confkey) AS dst_col_count,
               dst_nsp.nspname AS dst_nsp_name,
               dst_cls.relname AS dst_tbl_name,
               dst_att.attname AS dst_col_name
        FROM pg_constraint c
        JOIN pg_class dst_cls ON dst_cls.oid = c.confrelid
        JOIN pg_namespace dst_nsp ON dst_nsp.oid = dst_cls.relnamespace
        JOIN pg_attribute src_att ON src_att.attrelid = c.conrelid AND src_att.attnum = c.conkey[1]
        JOIN pg_attribute dst_att ON dst_att.attrelid = c.confrelid AND dst_att.attnum = c.confkey[1]
        WHERE c.conrelid = 'public.inspections'::regclass
          AND c.contype = 'f'
          AND src_att.attname = v_fk_rec.src_col
      ) LOOP
        IF v_con_rec.src_col_count <> 1 OR v_con_rec.dst_col_count <> 1 THEN
          RAISE EXCEPTION 'Preflight validation failed: Incompatible composite foreign key "%" found on public.inspections(%). A single-column foreign key is required.',
            v_con_rec.conname, v_fk_rec.src_col;
        END IF;

        IF v_con_rec.dst_nsp_name <> 'public' OR v_con_rec.dst_tbl_name <> v_fk_rec.dst_table OR v_con_rec.dst_col_name <> v_fk_rec.dst_col THEN
          RAISE EXCEPTION 'Preflight validation failed: Foreign key "%" on public.inspections(%) references %.%(%) instead of public.%(%).',
            v_con_rec.conname, v_fk_rec.src_col,
            v_con_rec.dst_nsp_name, v_con_rec.dst_tbl_name, v_con_rec.dst_col_name,
            v_fk_rec.dst_table, v_fk_rec.dst_col;
        END IF;

        IF NOT (v_con_rec.confdeltype = ANY(v_fk_rec.valid_del_types)) THEN
          RAISE EXCEPTION 'Preflight validation failed: Foreign key "%" on public.inspections(%) has incompatible ON DELETE action "%" (expected %).',
            v_con_rec.conname, v_fk_rec.src_col,
            v_con_rec.confdeltype, v_fk_rec.del_desc;
        END IF;

        v_fk_found := true;
        EXIT;
      END LOOP;

      IF NOT v_fk_found THEN
        RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspections is missing single-column FOREIGN KEY constraint on "%" referencing public.%(%) with %.',
          v_fk_rec.src_col, v_fk_rec.dst_table, v_fk_rec.dst_col, v_fk_rec.del_desc;
      END IF;
    END LOOP;

    -- E. Strict Check constraint validation on status:
    --    Verifies single-column constraint, positive set-membership syntax,
    --    normalization of schema-qualified array and type casts (e.g. ::pg_catalog.text, ::text[]),
    --    parenthesized column identifiers (((status)) -> status),
    --    order-independent validation matching the exact canonical set of 6 approved values,
    --    and comprehensive dynamic expression testing against permitted and forbidden matrices.
    v_found_status_con := false;
    FOR v_con_rec IN (
      SELECT c.oid, c.conname, 
             pg_get_expr(c.conbin, c.conrelid) AS expr,
             pg_get_constraintdef(c.oid) AS def
      FROM pg_constraint c
      JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
      WHERE c.conrelid = 'public.inspections'::regclass
        AND c.contype = 'c'
        AND cardinality(c.conkey) = 1
        AND a.attname = 'status'
    ) LOOP
      -- 1. Structural check: Must be a positive set-membership expression, not an inverted/negative check
      IF v_con_rec.def ILIKE '%NOT IN%' 
         OR v_con_rec.def ILIKE '%<> ALL%' 
         OR v_con_rec.def ILIKE '%!= ALL%'
         OR v_con_rec.def ILIKE '%NOT%ANY%' THEN
        CONTINUE; -- Reject inverted or negative check constraints
      END IF;

      -- Must contain explicit set-membership keywords
      IF NOT (v_con_rec.def ILIKE '%ANY%' OR v_con_rec.def ILIKE '%IN%' OR v_con_rec.def ILIKE '%status =%') THEN
        CONTINUE;
      END IF;

      -- 2. Order-independent exact value set extraction:
      -- Extract all single-quoted string literals from the constraint definition and sort them.
      -- To guarantee weaker constraints permitting extra unapproved values fail closed,
      -- the set of extracted values MUST match the exact canonical set of 6 approved values.
      SELECT array_agg(m[1] ORDER BY m[1]), count(*)
      INTO v_extracted_values, v_extracted_count
      FROM (
        SELECT (regexp_matches(v_con_rec.def, '''([^'']+)''', 'g'))[1] AS m
      ) sub;

      IF v_extracted_count <> 6 OR v_extracted_values IS DISTINCT FROM ARRAY['CAPA Required', 'Draft', 'Failed', 'In Progress', 'In Review', 'Passed'] THEN
        CONTINUE; -- Does not match exact canonical set; reject weaker, incomplete, or non-conforming definition
      END IF;

      -- 3. Normalize definition: strip schema-qualified and array type casts
      -- (e.g. ::text, ::pg_catalog.text, ::character varying, ::text[]),
      -- normalize wrapped column identifier (((status)) -> status), and strip redundant whitespaces
      v_norm_def := regexp_replace(v_con_rec.def, '::("?[a-zA-Z0-9_]+"刚?\.)*"?[a-zA-Z0-9_ ]+"刚?(\([0-9\s,]+\))?(\[[0-9]*\])?', '', 'g');
      v_norm_def := regexp_replace(v_norm_def, '\(+\s*status\s*\)+', 'status', 'g');

      -- Structural syntax check: Must be a standard ANY(ARRAY[...]) or IN (...) construct
      IF NOT (
        v_norm_def ~* '^CHECK\s*\(+\s*status\s*=\s*ANY\s*\(+\s*ARRAY\s*\[.+\]\s*\)+\s*\)+$'
        OR v_norm_def ~* '^CHECK\s*\(+\s*status\s+IN\s*\(.+\)\s*\)+$'
      ) THEN
        CONTINUE;
      END IF;

      v_eval_success := true;
      v_dynamic_eval_ok := true;

      -- 4. Test every required permitted status value dynamically (MUST evaluate to TRUE)
      FOREACH v_val IN ARRAY ARRAY['Draft', 'In Progress', 'Passed', 'CAPA Required', 'Failed', 'In Review'] LOOP
        BEGIN
          EXECUTE format('SELECT (%s) FROM (SELECT $1::text AS status) t', v_con_rec.expr)
            USING v_val INTO v_bool_result;
          IF v_bool_result IS NOT TRUE THEN
            v_eval_success := false;
            EXIT;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          v_dynamic_eval_ok := false;
          EXIT;
        END;
      END LOOP;

      -- 5. Test disallowed values dynamically (MUST evaluate to FALSE)
      IF v_eval_success AND v_dynamic_eval_ok THEN
        FOREACH v_val IN ARRAY ARRAY[
          '', ' ', '__INVALID_STATUS__',
          'draft', 'in progress', 'passed', 'failed',
          'Pending', 'Pass', 'Fail', 'Closed', 'Open', 'Archived', 
          'Cancelled', 'Approved', 'Rejected', 'Submitted', 'Active', 'Completed'
        ] LOOP
          BEGIN
            EXECUTE format('SELECT (%s) FROM (SELECT $1::text AS status) t', v_con_rec.expr)
              USING v_val INTO v_bool_result;
            IF v_bool_result IS NOT FALSE THEN
              v_eval_success := false;
              EXIT;
            END IF;
          EXCEPTION WHEN OTHERS THEN
            v_eval_success := false;
            EXIT;
          END;
        END LOOP;
      END IF;

      IF v_eval_success THEN
        v_found_status_con := true;
        EXIT;
      END IF;
    END LOOP;

    IF NOT v_found_status_con THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspections is missing single-column CHECK constraint on "status" enforcing all 6 permitted values (Draft, In Progress, Passed, CAPA Required, Failed, In Review). A canonical constraint definition is required.';
    END IF;

    -- Verify no existing rows contain invalid or NULL status values
    IF EXISTS (
      SELECT 1 FROM public.inspections
      WHERE status IS NULL OR status NOT IN ('Draft', 'In Progress', 'Passed', 'CAPA Required', 'Failed', 'In Review')
      LIMIT 1
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing rows in public.inspections contain invalid or NULL status values.';
    END IF;
  END IF;

  -- 1.4 Validate schema compatibility if public.inspection_results pre-exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'inspection_results'
  ) THEN
    -- A. Single-column Primary Key on id
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint c
      JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
      WHERE c.conrelid = 'public.inspection_results'::regclass
        AND c.contype = 'p'
        AND cardinality(c.conkey) = 1
        AND a.attname = 'id'
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name 
       AND kcu.constraint_schema = tc.constraint_schema
       AND kcu.table_name = tc.table_name
       AND kcu.table_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'inspection_results' 
        AND tc.constraint_type = 'PRIMARY KEY' 
      GROUP BY tc.constraint_name
      HAVING COUNT(*) = 1 AND MAX(kcu.column_name) = 'id'
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspection_results must have exactly one PRIMARY KEY column on "id".';
    END IF;

    -- B. Required columns, data types, and nullability (with strict text[] validation for photo_evidence_urls)
    FOR v_col_rec IN (
      SELECT * FROM (VALUES
        ('id', 'uuid', 'NO'),
        ('inspection_id', 'uuid', 'NO'),
        ('item_id', 'uuid', 'NO'),
        ('result_status', 'text', 'NO'),
        ('numeric_value', 'numeric', 'YES'),
        ('text_value', 'text', 'YES'),
        ('comment', 'text', 'YES'),
        ('photo_evidence_urls', 'ARRAY', 'NO'),
        ('is_deviation', 'boolean', 'NO'),
        ('created_at', 'timestamp with time zone', 'NO')
      ) AS t(col_name, expected_type, expected_nullable)
    ) LOOP
      SELECT data_type, udt_name, is_nullable 
      INTO v_actual_type, v_actual_udt, v_actual_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public' 
        AND table_name = 'inspection_results' 
        AND column_name = v_col_rec.col_name;

      IF v_actual_type IS NULL THEN
        RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspection_results is missing required column "%".', v_col_rec.col_name;
      ELSIF v_col_rec.col_name = 'photo_evidence_urls' THEN
        IF v_actual_type <> 'ARRAY' OR v_actual_udt <> '_text' THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.inspection_results.photo_evidence_urls must have exact type text[] (found data_type="%", udt_name="%").',
            v_actual_type, v_actual_udt;
        END IF;
      ELSIF v_actual_type <> v_col_rec.expected_type THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.inspection_results."%" has incompatible type "%" (expected "%").', v_col_rec.col_name, v_actual_type, v_col_rec.expected_type;
      END IF;

      IF v_col_rec.expected_nullable = 'NO' AND v_actual_nullable <> 'NO' THEN
        RAISE EXCEPTION 'Preflight validation failed: Column public.inspection_results."%" is nullable, but required NOT NULL constraint is missing.', v_col_rec.col_name;
      END IF;
    END LOOP;

    -- C. Single-column Foreign Keys validation with exact target in public schema and ON DELETE action:
    --    - inspection_id -> public.inspections(id) ON DELETE CASCADE ('c')
    --    - item_id -> public.checklist_items(id) ON DELETE RESTRICT ('r' or 'a')
    FOR v_fk_rec IN (
      SELECT * FROM (VALUES
        ('inspection_id', 'inspections', 'id', ARRAY['c'], 'ON DELETE CASCADE'),
        ('item_id', 'checklist_items', 'id', ARRAY['r', 'a'], 'ON DELETE RESTRICT')
      ) AS t(src_col, dst_table, dst_col, valid_del_types, del_desc)
    ) LOOP
      v_fk_found := false;
      FOR v_con_rec IN (
        SELECT c.conname, c.confdeltype,
               cardinality(c.conkey) AS src_col_count,
               cardinality(c.confkey) AS dst_col_count,
               dst_nsp.nspname AS dst_nsp_name,
               dst_cls.relname AS dst_tbl_name,
               dst_att.attname AS dst_col_name
        FROM pg_constraint c
        JOIN pg_class dst_cls ON dst_cls.oid = c.confrelid
        JOIN pg_namespace dst_nsp ON dst_nsp.oid = dst_cls.relnamespace
        JOIN pg_attribute src_att ON src_att.attrelid = c.conrelid AND src_att.attnum = c.conkey[1]
        JOIN pg_attribute dst_att ON dst_att.attrelid = c.confrelid AND dst_att.attnum = c.confkey[1]
        WHERE c.conrelid = 'public.inspection_results'::regclass
          AND c.contype = 'f'
          AND src_att.attname = v_fk_rec.src_col
      ) LOOP
        IF v_con_rec.src_col_count <> 1 OR v_con_rec.dst_col_count <> 1 THEN
          RAISE EXCEPTION 'Preflight validation failed: Incompatible composite foreign key "%" found on public.inspection_results(%). A single-column foreign key is required.',
            v_con_rec.conname, v_fk_rec.src_col;
        END IF;

        IF v_con_rec.dst_nsp_name <> 'public' OR v_con_rec.dst_tbl_name <> v_fk_rec.dst_table OR v_con_rec.dst_col_name <> v_fk_rec.dst_col THEN
          RAISE EXCEPTION 'Preflight validation failed: Foreign key "%" on public.inspection_results(%) references %.%(%) instead of public.%(%).',
            v_con_rec.conname, v_fk_rec.src_col,
            v_con_rec.dst_nsp_name, v_con_rec.dst_tbl_name, v_con_rec.dst_col_name,
            v_fk_rec.dst_table, v_fk_rec.dst_col;
        END IF;

        IF NOT (v_con_rec.confdeltype = ANY(v_fk_rec.valid_del_types)) THEN
          RAISE EXCEPTION 'Preflight validation failed: Foreign key "%" on public.inspection_results(%) has incompatible ON DELETE action "%" (expected %).',
            v_con_rec.conname, v_fk_rec.src_col,
            v_con_rec.confdeltype, v_fk_rec.del_desc;
        END IF;

        v_fk_found := true;
        EXIT;
      END LOOP;

      IF NOT v_fk_found THEN
        RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspection_results is missing single-column FOREIGN KEY constraint on "%" referencing public.%(%) with %.',
          v_fk_rec.src_col, v_fk_rec.dst_table, v_fk_rec.dst_col, v_fk_rec.del_desc;
      END IF;
    END LOOP;

    -- D. Strict Check constraint validation on result_status:
    --    Verifies single-column constraint, positive set-membership syntax,
    --    normalization of schema-qualified array and type casts (e.g. ::pg_catalog.text, ::text[]),
    --    parenthesized column identifiers (((result_status)) -> result_status),
    --    order-independent validation matching the exact canonical set of 4 approved values,
    --    and comprehensive dynamic expression testing against permitted and forbidden matrices.
    v_found_result_con := false;
    FOR v_con_rec IN (
      SELECT c.oid, c.conname,
             pg_get_expr(c.conbin, c.conrelid) AS expr,
             pg_get_constraintdef(c.oid) AS def
      FROM pg_constraint c
      JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
      WHERE c.conrelid = 'public.inspection_results'::regclass
        AND c.contype = 'c'
        AND cardinality(c.conkey) = 1
        AND a.attname = 'result_status'
    ) LOOP
      IF v_con_rec.def ILIKE '%NOT IN%' 
         OR v_con_rec.def ILIKE '%<> ALL%' 
         OR v_con_rec.def ILIKE '%!= ALL%'
         OR v_con_rec.def ILIKE '%NOT%ANY%' THEN
        CONTINUE;
      END IF;

      IF NOT (v_con_rec.def ILIKE '%ANY%' OR v_con_rec.def ILIKE '%IN%' OR v_con_rec.def ILIKE '%result_status =%') THEN
        CONTINUE;
      END IF;

      -- Order-independent value set extraction
      SELECT array_agg(m[1] ORDER BY m[1]), count(*)
      INTO v_extracted_values, v_extracted_count
      FROM (
        SELECT (regexp_matches(v_con_rec.def, '''([^'']+)''', 'g'))[1] AS m
      ) sub;

      IF v_extracted_count <> 4 OR v_extracted_values IS DISTINCT FROM ARRAY['Fail', 'N/A', 'Pass', 'Pending'] THEN
        CONTINUE;
      END IF;

      -- Normalize definition
      v_norm_def := regexp_replace(v_con_rec.def, '::("?[a-zA-Z0-9_]+"刚?\.)*"?[a-zA-Z0-9_ ]+"刚?(\([0-9\s,]+\))?(\[[0-9]*\])?', '', 'g');
      v_norm_def := regexp_replace(v_norm_def, '\(+\s*result_status\s*\)+', 'result_status', 'g');

      IF NOT (
        v_norm_def ~* '^CHECK\s*\(+\s*result_status\s*=\s*ANY\s*\(+\s*ARRAY\s*\[.+\]\s*\)+\s*\)+$'
        OR v_norm_def ~* '^CHECK\s*\(+\s*result_status\s+IN\s*\(.+\)\s*\)+$'
      ) THEN
        CONTINUE;
      END IF;

      v_eval_success := true;
      v_dynamic_eval_ok := true;

      -- Test every required permitted result_status value dynamically
      FOREACH v_val IN ARRAY ARRAY['Pass', 'Fail', 'N/A', 'Pending'] LOOP
        BEGIN
          EXECUTE format('SELECT (%s) FROM (SELECT $1::text AS result_status) t', v_con_rec.expr)
            USING v_val INTO v_bool_result;
          IF v_bool_result IS NOT TRUE THEN
            v_eval_success := false;
            EXIT;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          v_dynamic_eval_ok := false;
          EXIT;
        END;
      END LOOP;

      -- Test disallowed values dynamically
      IF v_eval_success AND v_dynamic_eval_ok THEN
        FOREACH v_val IN ARRAY ARRAY[
          '', ' ', '__INVALID_RESULT__',
          'pass', 'fail', 'n/a', 'pending',
          'Draft', 'In Progress', 'Passed', 'Failed', 'In Review', 'CAPA Required',
          'Approved', 'Rejected', 'Completed', 'Done'
        ] LOOP
          BEGIN
            EXECUTE format('SELECT (%s) FROM (SELECT $1::text AS result_status) t', v_con_rec.expr)
              USING v_val INTO v_bool_result;
            IF v_bool_result IS NOT FALSE THEN
              v_eval_success := false;
              EXIT;
            END IF;
          EXCEPTION WHEN OTHERS THEN
            v_eval_success := false;
            EXIT;
          END;
        END LOOP;
      END IF;

      IF v_eval_success THEN
        v_found_result_con := true;
        EXIT;
      END IF;
    END LOOP;

    IF NOT v_found_result_con THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.inspection_results is missing single-column CHECK constraint on "result_status" enforcing all 4 permitted values (Pass, Fail, N/A, Pending). A canonical constraint definition is required.';
    END IF;

    -- Verify no existing rows contain invalid or NULL result_status values
    IF EXISTS (
      SELECT 1 FROM public.inspection_results
      WHERE result_status IS NULL OR result_status NOT IN ('Pass', 'Fail', 'N/A', 'Pending')
      LIMIT 1
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing rows in public.inspection_results contain invalid or NULL result_status values.';
    END IF;

    -- E. Verify no duplicate (inspection_id, item_id) rows exist before enforcing UNIQUE constraint
    IF EXISTS (
      SELECT 1 FROM public.inspection_results
      GROUP BY inspection_id, item_id
      HAVING COUNT(*) > 1
      LIMIT 1
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Table public.inspection_results contains duplicate (inspection_id, item_id) rows. Duplicate checklist responses must be resolved before enforcing UNIQUE (inspection_id, item_id).';
    END IF;
  END IF;

  -- 1.5 Preflight check for unexpected permissive RLS policies on inspections infrastructure
  -- In PostgreSQL, multiple permissive policies for the same role and command combine with
  -- boolean OR. Unrecognized custom policies could unintentionally broaden permissions.
  FOR v_custom_pol IN (
    SELECT schemaname, tablename, policyname, permissive, cmd
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('inspections', 'inspection_results')
      AND policyname NOT IN (
        -- Known legacy policy names from scripts/01_complete_fsms_schema.sql
        'Inspections: Read for authenticated users',
        'Inspections: Insert & conduct by qualified auditors & inspectors',
        'Inspections: Update own in-progress audits or by management',
        'Results: Read for authenticated users',
        'Results: Manage answers by auditor or management',
        -- Canonical migration policy names (v3.1 through v3.8)
        'Inspections: Read for active authenticated users',
        'Inspections: Create by authorized auditors & managers',
        'Inspections: Update own audits or by management',
        'Inspections: Delete by Super Admin & Quality Manager',
        'Results: Read for active authenticated users',
        'Results: Insert answers for active audits',
        'Results: Update answers for active audits',
        'Results: Delete answers for draft or in-progress audits'
      )
  ) LOOP
    RAISE EXCEPTION 'Preflight validation failed: Unexpected custom RLS policy "%" (table: public.%, cmd: %, permissive: %) detected. Because PostgreSQL combines permissive policies with boolean OR, unvetted custom policies can broaden permissions. Please review, migrate, or remove this custom policy before proceeding.',
      v_custom_pol.policyname, v_custom_pol.tablename, v_custom_pol.cmd, v_custom_pol.permissive;
  END LOOP;

  RAISE NOTICE 'Preflight validation passed: All prerequisite tables, foreign keys, constraints, helper signatures, and RLS policies verified.';
END $$;

-- ------------------------------------------------------------------------------
-- 2. INSPECTIONS TABLE (Conducted On-Site Audits & Operational Records)
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- Idempotently configure updated_at trigger on inspections
DROP TRIGGER IF EXISTS tr_inspections_updated_at ON public.inspections;
CREATE TRIGGER tr_inspections_updated_at
  BEFORE UPDATE ON public.inspections
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ------------------------------------------------------------------------------
-- 3. INSPECTION RESULTS TABLE (Individual Check-Item Answers & Non-Conformance Evidence)
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- Idempotently validate and enforce UNIQUE (inspection_id, item_id)
-- Recognizes commutative column ordering: (inspection_id, item_id) OR (item_id, inspection_id).
-- Confirms the index is unique, valid, non-partial, and non-expression.
DO $$
DECLARE
  v_con_def TEXT;
  v_con_type CHAR;
  v_has_unique_index BOOLEAN := false;
BEGIN
  -- 1. Check if named constraint already exists
  SELECT contype, pg_get_constraintdef(c.oid)
  INTO v_con_type, v_con_def
  FROM pg_constraint c
  WHERE c.conrelid = 'public.inspection_results'::regclass
    AND c.conname = 'uq_inspection_results_item';

  IF FOUND THEN
    IF v_con_type <> 'u' OR (
      v_con_def NOT LIKE 'UNIQUE (inspection_id, item_id)%' 
      AND v_con_def NOT LIKE 'UNIQUE (item_id, inspection_id)%'
    ) THEN
      RAISE EXCEPTION 'Constraint validation failed: An existing constraint "uq_inspection_results_item" exists on public.inspection_results but does not enforce UNIQUE on (inspection_id, item_id). Definition: %', v_con_def;
    ELSE
      RAISE NOTICE 'Constraint validation passed: Existing constraint "uq_inspection_results_item" verified.';
      RETURN;
    END IF;
  END IF;

  -- 2. Check if another unique constraint or unique index already covers (inspection_id, item_id) commutatively
  SELECT true INTO v_has_unique_index
  FROM pg_index i
  JOIN pg_class c ON c.oid = i.indrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a1 ON a1.attrelid = c.oid AND a1.attnum = i.indkey[0]
  JOIN pg_attribute a2 ON a2.attrelid = c.oid AND a2.attnum = i.indkey[1]
  WHERE n.nspname = 'public' 
    AND c.relname = 'inspection_results'
    AND i.indisunique = true 
    AND i.indisvalid = true
    AND i.indnatts = 2 
    AND (
      (a1.attname = 'inspection_id' AND a2.attname = 'item_id')
      OR
      (a1.attname = 'item_id' AND a2.attname = 'inspection_id')
    )
    AND i.indpred IS NULL 
    AND i.indexprs IS NULL
  LIMIT 1;

  IF v_has_unique_index THEN
    RAISE NOTICE 'Index validation passed: An equivalent valid unique index already covers (inspection_id, item_id) on public.inspection_results. Redundant constraint creation skipped.';
  ELSE
    ALTER TABLE public.inspection_results
      ADD CONSTRAINT uq_inspection_results_item UNIQUE (inspection_id, item_id);
    RAISE NOTICE 'Created constraint uq_inspection_results_item UNIQUE (inspection_id, item_id).';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 4. DATABASE-SIDE INTEGRITY ENFORCEMENT TRIGGERS
-- Prevents privilege escalation, auditor ownership hijacking, status tampering,
-- cross-template contamination, and modifications to completed audit records.
-- ------------------------------------------------------------------------------

-- 4.1 INSPECTIONS INTEGRITY & OWNERSHIP TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.protect_inspection_integrity()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_session_user TEXT;
  v_is_db_admin BOOLEAN;
  v_is_manager_or_lead BOOLEAN;
BEGIN
  -- Standard SQL SESSION_USER evaluation
  v_session_user := SESSION_USER;
  v_is_db_admin := (v_session_user IN ('postgres', 'supabase_admin')) AND (auth.role() IS NULL);

  -- 1. DELETION RULES (Strict Compliance Retention Guard):
  -- Universal Immutability: Completed, evaluated, or in-review audits can NEVER be deleted
  -- through standard DML by ANY caller (including Super Admin, Quality Manager, service_role, and db admin).
  IF TG_OP = 'DELETE' THEN
    IF OLD.status IS DISTINCT FROM 'Draft' THEN
      RAISE EXCEPTION 'Audit integrity violation: Inspection record "%" is in "%" status and cannot be deleted. Completed or conducted inspection audits are subject to permanent compliance retention.',
        OLD.inspection_code, OLD.status;
    END IF;

    -- Trusted backend service-role operations or direct database maintenance in SQL Editor on Draft records
    IF v_is_db_admin OR auth.role() = 'service_role' THEN
      RETURN OLD;
    END IF;

    -- Authenticated users: Only Super Admin and Quality Manager can delete Draft inspections
    IF NOT public.is_active_role(ARRAY['Super Admin', 'Quality Manager']) THEN
      RAISE EXCEPTION 'Privilege violation: Only Super Admins and Quality Managers are authorized to delete inspection records.';
    END IF;

    RETURN OLD;
  END IF;

  -- 2. Trusted backend service-role operations or direct database maintenance in SQL Editor (INSERT/UPDATE)
  IF v_is_db_admin OR auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Determine if caller is an active manager or lead auditor
  v_is_manager_or_lead := public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']);

  -- 3. INSERTION RULES:
  IF TG_OP = 'INSERT' THEN
    IF NOT v_is_manager_or_lead THEN
      -- Explicitly verify caller is an active Inspector
      IF NOT public.is_active_role(ARRAY['Inspector']) THEN
        RAISE EXCEPTION 'Privilege violation: Only authorized active Inspectors, Lead Auditors, Quality Managers, and Super Admins can create inspections.';
      END IF;

      -- Non-managers (Inspectors) can only create inspections assigned to themselves
      IF NEW.auditor_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Privilege violation: Inspectors can only create inspections assigned to their own profile.';
      END IF;

      -- Non-managers can only initiate inspections in Draft or In Progress status
      IF NEW.status NOT IN ('Draft', 'In Progress') THEN
        RAISE EXCEPTION 'Privilege violation: Inspectors can only create inspections in "Draft" or "In Progress" status (attempted: "%").', NEW.status;
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  -- 4. UPDATE RULES:
  IF TG_OP = 'UPDATE' THEN
    -- A. Structural immutability: inspection_code and template_id cannot be changed once created
    IF (NEW.inspection_code IS DISTINCT FROM OLD.inspection_code) THEN
      RAISE EXCEPTION 'Audit integrity violation: inspection_code is immutable and cannot be changed.';
    END IF;

    IF (NEW.template_id IS DISTINCT FROM OLD.template_id) THEN
      RAISE EXCEPTION 'Audit integrity violation: template_id is immutable. Changing checklist templates on an existing inspection is not permitted.';
    END IF;

    -- B. Auditor Ownership & Assignment Protection:
    -- Non-managers can only update inspections assigned to their own profile, and cannot reassign auditor_id.
    -- Only Super Admin, Quality Manager, and Lead Auditor can reassign an inspection's auditor_id or update audits assigned to other auditors.
    IF NOT v_is_manager_or_lead THEN
      IF NOT public.is_active_role(ARRAY['Inspector']) THEN
        RAISE EXCEPTION 'Privilege violation: Only authorized active Inspectors, Lead Auditors, Quality Managers, and Super Admins can update inspections.';
      END IF;

      IF OLD.auditor_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Privilege violation: Inspectors can only modify inspection records assigned to their own profile.';
      END IF;

      IF NEW.auditor_id IS DISTINCT FROM OLD.auditor_id THEN
        RAISE EXCEPTION 'Privilege violation: Only Super Admins, Quality Managers, and Lead Auditors can reassign the auditor on an inspection.';
      END IF;
    END IF;

    -- C. Inspector Status-Transition Authorization Rules:
    -- Ordinary Inspectors can only update audits assigned to them that are in Draft or In Progress.
    -- Permitted transitions for Inspectors:
    --   - Draft <-> In Progress (conducting the audit)
    --   - Draft or In Progress -> In Review (submitting audit for managerial review)
    -- FORBIDDEN transitions for Inspectors:
    --   - Direct setting of terminal evaluation statuses: Passed, Failed, CAPA Required.
    --   - Any modification or reopening of audits in In Review, Passed, Failed, or CAPA Required.
    IF NOT v_is_manager_or_lead THEN
      IF OLD.status IN ('Passed', 'Failed', 'CAPA Required', 'In Review') THEN
        RAISE EXCEPTION 'Audit integrity violation: Inspection record "%" is in "%" status and cannot be modified or reopened by an Inspector.', OLD.inspection_code, OLD.status;
      END IF;

      IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NEW.status IN ('Passed', 'Failed', 'CAPA Required') THEN
          RAISE EXCEPTION 'Privilege violation: Inspectors cannot set inspection status to "%". Final audit determinations require Super Admin, Quality Manager, or Lead Auditor authorization.', NEW.status;
        END IF;

        IF NEW.status NOT IN ('Draft', 'In Progress', 'In Review') THEN
          RAISE EXCEPTION 'Privilege violation: Invalid status transition from "%" to "%" for role Inspector.', OLD.status, NEW.status;
        END IF;
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.protect_inspection_integrity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protect_inspection_integrity() TO authenticated, service_role;

DROP TRIGGER IF EXISTS tr_protect_inspection_integrity ON public.inspections;
CREATE TRIGGER tr_protect_inspection_integrity
  BEFORE INSERT OR UPDATE OR DELETE ON public.inspections
  FOR EACH ROW EXECUTE FUNCTION public.protect_inspection_integrity();

-- 4.2 INSPECTION RESULTS INTEGRITY, TEMPLATE VALIDATION & CASCADE SUPPORT TRIGGER
CREATE OR REPLACE FUNCTION public.protect_inspection_results_integrity()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_session_user TEXT;
  v_is_db_admin BOOLEAN;
  v_is_manager_or_lead BOOLEAN;
  v_target_inspection_id UUID;
  v_inspection_status TEXT;
  v_inspection_template_id UUID;
  v_item_template_id UUID;
  v_auditor_id UUID;
BEGIN
  -- Standard SQL SESSION_USER evaluation
  v_session_user := SESSION_USER;
  v_is_db_admin := (v_session_user IN ('postgres', 'supabase_admin')) AND (auth.role() IS NULL);

  v_target_inspection_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.inspection_id ELSE NEW.inspection_id END;

  -- Retrieve parent inspection status, auditor, and assigned template.
  -- Consistent Locking Order: Lock parent inspection FIRST via FOR SHARE on INSERT/UPDATE.
  -- On DELETE, avoid FOR SHARE to permit seamless cascade execution.
  IF TG_OP = 'DELETE' THEN
    SELECT status, auditor_id, template_id 
    INTO v_inspection_status, v_auditor_id, v_inspection_template_id
    FROM public.inspections
    WHERE id = v_target_inspection_id;
  ELSE
    SELECT status, auditor_id, template_id 
    INTO v_inspection_status, v_auditor_id, v_inspection_template_id
    FROM public.inspections
    WHERE id = v_target_inspection_id
    FOR SHARE;
  END IF;

  -- 1. DELETION RULES & CASCADING DELETION SUPPORT:
  IF TG_OP = 'DELETE' THEN
    -- A. Legitimate Foreign Key Cascade Deletion:
    -- During an ON DELETE CASCADE from public.inspections, PostgreSQL's internal RI engine
    -- fires at pg_trigger_depth() > 1. The parent inspection has already been deleted in the
    -- current transaction (NOT FOUND), and its deletion was strictly vetted by
    -- public.protect_inspection_integrity() (requiring status = 'Draft' and authorized manager).
    IF pg_trigger_depth() > 1 AND NOT FOUND THEN
      RETURN OLD;
    END IF;

    -- B. Direct Statement targeting non-existent parent:
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Foreign key integrity violation: Referenced inspection record was not found.';
    END IF;

    -- C. Direct Statement Deletion Guard on Completed / In-Review Audits:
    -- Completed, evaluated, or in-review inspection results are permanently retained and CANNOT
    -- be deleted by ANY role (including Super Admin, Quality Manager, service_role, and db admin).
    IF v_inspection_status IN ('Passed', 'Failed', 'CAPA Required', 'In Review') THEN
      RAISE EXCEPTION 'Audit integrity violation: Inspection results for audit "%" (status: "%") cannot be deleted. Completed and submitted audit responses are permanently retained for regulatory compliance.',
        OLD.inspection_id, v_inspection_status;
    END IF;

    -- D. Trusted Backend / DB Admin bypass for Draft / In Progress results
    IF v_is_db_admin OR auth.role() = 'service_role' THEN
      RETURN OLD;
    END IF;

    v_is_manager_or_lead := public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']);

    -- E. Direct Statement Role & Ownership Authorization (Draft / In Progress only):
    IF v_is_manager_or_lead THEN
      RETURN OLD;
    END IF;

    IF public.is_active_role(ARRAY['Inspector']) THEN
      IF v_auditor_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Privilege violation: Inspectors can only delete checklist answers on audits assigned to their own profile.';
      END IF;
      RETURN OLD;
    END IF;

    RAISE EXCEPTION 'Privilege violation: Not authorized to delete checklist results.';
  END IF;

  -- 2. Trusted administrative operations bypass for INSERT and UPDATE
  IF v_is_db_admin OR auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Parent inspection must exist for INSERT and UPDATE
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Foreign key integrity violation: Referenced inspection record was not found.';
  END IF;

  v_is_manager_or_lead := public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']);

  -- 3. COMPLETED AUDIT IMMUTABILITY ON INSERT / UPDATE:
  -- Once an audit is finalized (Passed, Failed, CAPA Required), results cannot be added or modified.
  IF v_inspection_status IN ('Passed', 'Failed', 'CAPA Required') THEN
    RAISE EXCEPTION 'Audit integrity violation: Inspection "%" is in terminal "%" status. Checklist results are sealed and cannot be added or modified.',
      v_target_inspection_id, v_inspection_status;
  END IF;

  -- If audit is In Review, only management / lead auditor can add or update review corrections
  IF v_inspection_status = 'In Review' AND NOT v_is_manager_or_lead THEN
    RAISE EXCEPTION 'Audit integrity violation: Inspection "%" is In Review. Non-managers cannot add or modify checklist answers while audit is pending review.',
      v_target_inspection_id;
  END IF;

  -- 4. AUDITOR ASSIGNMENT VERIFICATION:
  -- Non-managers can only modify answers on inspections specifically assigned to their own user ID.
  IF NOT v_is_manager_or_lead THEN
    IF v_auditor_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Privilege violation: You are not authorized to alter checklist answers for an inspection assigned to another auditor.';
    END IF;
  END IF;

  -- 5. CHECKLIST ITEM OWNERSHIP & TEMPLATE VALIDATION (ON INSERT):
  -- Ensures every recorded answer references a checklist item belonging to the parent inspection's template.
  -- Consistent Locking Order: Lock checklist_items SECOND via FOR SHARE.
  -- FOR SHARE conflicts with FOR NO KEY UPDATE (acquired by concurrent UPDATE of template_id),
  -- serializing concurrent template re-parenting and answer insertion without deadlocks.
  IF TG_OP = 'INSERT' THEN
    SELECT template_id INTO v_item_template_id
    FROM public.checklist_items
    WHERE id = NEW.item_id
    FOR SHARE;

    IF NOT FOUND OR v_item_template_id IS NULL THEN
      RAISE EXCEPTION 'Foreign key integrity violation: Referenced checklist item "%" does not exist.', NEW.item_id;
    END IF;

    IF v_inspection_template_id IS DISTINCT FROM v_item_template_id THEN
      RAISE EXCEPTION 'Template integrity violation: Checklist item "%" belongs to template "%", which does not match inspection template "%".',
        NEW.item_id, v_item_template_id, v_inspection_template_id;
    END IF;
  END IF;

  -- 6. IMMUTABILITY OF FOREIGN KEYS ON UPDATE:
  -- Once an answer row is created, inspection_id and item_id cannot be altered.
  IF TG_OP = 'UPDATE' THEN
    IF (NEW.inspection_id IS DISTINCT FROM OLD.inspection_id) OR (NEW.item_id IS DISTINCT FROM OLD.item_id) THEN
      RAISE EXCEPTION 'Audit integrity violation: inspection_id and item_id references on inspection_results are immutable.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.protect_inspection_results_integrity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protect_inspection_results_integrity() TO authenticated, service_role;

DROP TRIGGER IF EXISTS tr_protect_inspection_results_integrity ON public.inspection_results;
CREATE TRIGGER tr_protect_inspection_results_integrity
  BEFORE INSERT OR UPDATE OR DELETE ON public.inspection_results
  FOR EACH ROW EXECUTE FUNCTION public.protect_inspection_results_integrity();

-- 4.3 CHECKLIST ITEM TEMPLATE IMMUTABILITY TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.protect_checklist_item_template_integrity()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF (NEW.template_id IS DISTINCT FROM OLD.template_id) THEN
    IF EXISTS (
      SELECT 1 FROM public.inspection_results
      WHERE item_id = OLD.id
    ) THEN
      RAISE EXCEPTION 'Integrity violation: Cannot change template_id on checklist item "%" because it is referenced by existing inspection results.', OLD.id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.protect_checklist_item_template_integrity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protect_checklist_item_template_integrity() TO authenticated, service_role;

DROP TRIGGER IF EXISTS tr_protect_checklist_item_template ON public.checklist_items;
CREATE TRIGGER tr_protect_checklist_item_template
  BEFORE UPDATE OF template_id ON public.checklist_items
  FOR EACH ROW EXECUTE FUNCTION public.protect_checklist_item_template_integrity();

-- ------------------------------------------------------------------------------
-- 5. PERFORMANCE & LOOKUP INDEXES
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_inspections_dept ON public.inspections(department_id);
CREATE INDEX IF NOT EXISTS idx_inspections_auditor ON public.inspections(auditor_id);
CREATE INDEX IF NOT EXISTS idx_inspections_template ON public.inspections(template_id);
CREATE INDEX IF NOT EXISTS idx_inspections_status ON public.inspections(status);
CREATE INDEX IF NOT EXISTS idx_inspections_scheduled_date ON public.inspections(scheduled_date DESC);
CREATE INDEX IF NOT EXISTS idx_inspection_results_audit ON public.inspection_results(inspection_id);
CREATE INDEX IF NOT EXISTS idx_inspection_results_item ON public.inspection_results(item_id);
CREATE INDEX IF NOT EXISTS idx_inspection_results_deviation ON public.inspection_results(inspection_id, is_deviation);

-- ------------------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- Hardened security using public.is_active_user() and public.is_active_role(TEXT[]).
-- Strictly adheres to FSMS role definitions:
--   'Super Admin', 'Quality Manager', 'Lead Auditor', 'Inspector', 'Operator'.
-- ------------------------------------------------------------------------------
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_results ENABLE ROW LEVEL SECURITY;

-- 6.1 INSPECTIONS POLICIES

-- Remove known legacy policy names from scripts/01_complete_fsms_schema.sql
DROP POLICY IF EXISTS "Inspections: Read for authenticated users" ON public.inspections;
DROP POLICY IF EXISTS "Inspections: Insert & conduct by qualified auditors & inspectors" ON public.inspections;
DROP POLICY IF EXISTS "Inspections: Update own in-progress audits or by management" ON public.inspections;

-- Remove current policy names for clean idempotent recreation
DROP POLICY IF EXISTS "Inspections: Read for active authenticated users" ON public.inspections;
DROP POLICY IF EXISTS "Inspections: Create by authorized auditors & managers" ON public.inspections;
DROP POLICY IF EXISTS "Inspections: Update own audits or by management" ON public.inspections;
DROP POLICY IF EXISTS "Inspections: Delete by Super Admin & Quality Manager" ON public.inspections;

-- Read: Active authenticated users can view inspection audits
CREATE POLICY "Inspections: Read for active authenticated users"
  ON public.inspections FOR SELECT
  TO authenticated
  USING (public.is_active_user());

-- Insert: Management can create any audit; Inspectors can ONLY create self-assigned Draft or In Progress audits
CREATE POLICY "Inspections: Create by authorized auditors & managers"
  ON public.inspections FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor'])
    OR (
      public.is_active_role(ARRAY['Inspector'])
      AND auditor_id = auth.uid()
      AND status IN ('Draft', 'In Progress')
    )
  );

-- Update: Management or assigned auditor updating their active audit
-- USING: Inspectors can only target their own audits while in Draft or In Progress.
-- WITH CHECK: Inspectors can only save audits assigned to themselves with status Draft, In Progress, or In Review (submission).
--             Inspectors cannot set Passed, Failed, or CAPA Required.
CREATE POLICY "Inspections: Update own audits or by management"
  ON public.inspections FOR UPDATE
  TO authenticated
  USING (
    public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor'])
    OR (
      public.is_active_role(ARRAY['Inspector'])
      AND auditor_id = auth.uid()
      AND status IN ('Draft', 'In Progress')
    )
  )
  WITH CHECK (
    public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor'])
    OR (
      public.is_active_role(ARRAY['Inspector'])
      AND auditor_id = auth.uid()
      AND status IN ('Draft', 'In Progress', 'In Review')
    )
  );

-- Delete: Restricted strictly to Super Admin & Quality Manager for Draft inspections only
CREATE POLICY "Inspections: Delete by Super Admin & Quality Manager"
  ON public.inspections FOR DELETE
  TO authenticated
  USING (
    public.is_active_role(ARRAY['Super Admin', 'Quality Manager'])
    AND status = 'Draft'
  );

-- 6.2 INSPECTION RESULTS POLICIES

-- Remove known legacy policies from scripts/01_complete_fsms_schema.sql
DROP POLICY IF EXISTS "Results: Read for authenticated users" ON public.inspection_results;
DROP POLICY IF EXISTS "Results: Manage answers by auditor or management" ON public.inspection_results;

-- Remove prior version policy names for clean idempotent recreation
DROP POLICY IF EXISTS "Results: Read for active authenticated users" ON public.inspection_results;
DROP POLICY IF EXISTS "Results: Manage answers by auditor or management" ON public.inspection_results;
DROP POLICY IF EXISTS "Results: Insert answers for active audits" ON public.inspection_results;
DROP POLICY IF EXISTS "Results: Update answers for active audits" ON public.inspection_results;
DROP POLICY IF EXISTS "Results: Delete answers for draft or in-progress audits" ON public.inspection_results;

-- 1. Read: Active authenticated users can read inspection check-item answers
CREATE POLICY "Results: Read for active authenticated users"
  ON public.inspection_results FOR SELECT
  TO authenticated
  USING (public.is_active_user());

-- 2. Insert: Management or assigned auditor while audit is Draft or In Progress
-- Prohibits inserting answers into audits that are In Review, Passed, Failed, or CAPA Required
CREATE POLICY "Results: Insert answers for active audits"
  ON public.inspection_results FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.inspections i
      WHERE i.id = inspection_id
        AND i.status IN ('Draft', 'In Progress')
        AND (
          public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor'])
          OR (
            public.is_active_role(ARRAY['Inspector'])
            AND i.auditor_id = auth.uid()
          )
        )
    )
  );

-- 3. Update: Management (Draft, In Progress, In Review) or assigned auditor (Draft, In Progress)
-- Completed audits (Passed, Failed, CAPA Required) are sealed and cannot be modified
CREATE POLICY "Results: Update answers for active audits"
  ON public.inspection_results FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.inspections i
      WHERE i.id = inspection_id
        AND (
          (
            public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor'])
            AND i.status IN ('Draft', 'In Progress', 'In Review')
          )
          OR (
            public.is_active_role(ARRAY['Inspector'])
            AND i.auditor_id = auth.uid()
            AND i.status IN ('Draft', 'In Progress')
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.inspections i
      WHERE i.id = inspection_id
        AND (
          (
            public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor'])
            AND i.status IN ('Draft', 'In Progress', 'In Review')
          )
          OR (
            public.is_active_role(ARRAY['Inspector'])
            AND i.auditor_id = auth.uid()
            AND i.status IN ('Draft', 'In Progress')
          )
        )
    )
  );

-- 4. Delete: Strictly restricted to Draft or In Progress audits.
-- Results belonging to In Review, Passed, Failed, or CAPA Required audits CANNOT be deleted by ANY user.
CREATE POLICY "Results: Delete answers for draft or in-progress audits"
  ON public.inspection_results FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.inspections i
      WHERE i.id = inspection_id
        AND i.status IN ('Draft', 'In Progress')
        AND (
          public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor'])
          OR (
            public.is_active_role(ARRAY['Inspector'])
            AND i.auditor_id = auth.uid()
          )
        )
    )
  );

-- ------------------------------------------------------------------------------
-- 7. AUDIT TRAIL & RELATIONAL INTEGRITY DOCUMENTATION
-- - public.inspections.template_id -> ON DELETE RESTRICT:
--     Templates referenced by audits cannot be deleted.
-- - public.inspections.department_id -> ON DELETE RESTRICT:
--     Departments referenced by audits cannot be deleted.
-- - public.inspections.auditor_id -> ON DELETE RESTRICT:
--     Profiles associated with conducted audits cannot be hard-deleted.
-- - public.inspections:
--     Hard deletion restricted strictly to 'Draft' status across ALL roles (including service-role).
--     Completed, evaluated, or in-review inspection records and their child results are permanently preserved.
-- - public.inspection_results.inspection_id -> ON DELETE CASCADE:
--     Deleting a draft inspection cleanly cascades to all its item answers.
--     Cascade execution is verified via pg_trigger_depth() > 1 and parent row deletion.
-- - public.inspection_results.item_id -> ON DELETE RESTRICT:
--     Checklist questions that have recorded responses cannot be deleted.
-- - uq_inspection_results_item UNIQUE (inspection_id, item_id):
--     Guarantees exactly one response row per question per inspection (checked commutatively).
-- - tr_protect_inspection_results_integrity:
--     Enforces parent inspection row locking (FOR SHARE) and item row locking (FOR SHARE)
--     to serialize template validation and prevent cross-template answers.
-- - tr_protect_checklist_item_template:
--     Universally prevents altering template_id on checklist items that have recorded inspection results.
-- ------------------------------------------------------------------------------

COMMIT;

