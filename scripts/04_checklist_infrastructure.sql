-- ==============================================================================
-- FSMS (Food Safety Management System) - Checklist Management Infrastructure
-- File: scripts/04_checklist_infrastructure.sql
-- Target: Supabase PostgreSQL 15+ / PostgREST / GoTrue Auth Integration
-- Version: 5.2 (Exact Default Validation, Strict RLS & Trigger Verification, Idempotent)
-- Safety: Preserves existing departments, employees, profiles, and RLS policies;
--         NO DESTRUCTIVE DROPS of existing tables, data, triggers, or policies;
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
-- Halts execution immediately with clear error if prerequisites or schema
-- compatibility checks fail, preventing partial or corrupt migrations.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_missing_depts TEXT;
  v_col_rec RECORD;
  v_actual_type TEXT;
  v_actual_nullable TEXT;
  v_actual_default TEXT;
  v_clean_actual_default TEXT;
  v_con_oid OID;
  v_con_def TEXT;
  v_clean_def TEXT;
  v_cat_total_check_count INT;
  v_resp_total_check_count INT;
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

  -- 1.3 Verify all 4 required department codes exist (SAN, COLD, PROD-A, WH)
  SELECT string_agg(req_code, ', ') INTO v_missing_depts
  FROM (
    SELECT unnest(ARRAY['SAN', 'COLD', 'PROD-A', 'WH']) AS req_code
  ) r
  WHERE NOT EXISTS (
    SELECT 1 FROM public.departments d WHERE d.code = r.req_code
  );

  IF v_missing_depts IS NOT NULL AND v_missing_depts <> '' THEN
    RAISE EXCEPTION 'Preflight validation failed: Required department code(s) missing from public.departments: [%]. Cannot create starter templates with NULL department assignments. Please ensure departments are seeded.', v_missing_depts;
  END IF;

  -- 1.4 Validate complete schema compatibility if public.checklist_templates already exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'checklist_templates'
  ) THEN
    -- A. Validate all required columns, data types, nullability, and exact defaults
    FOR v_col_rec IN (
      SELECT * FROM (VALUES
        ('id', 'uuid', 'NO', 'gen_random_uuid()'),
        ('code', 'text', 'NO', NULL),
        ('title', 'text', 'NO', NULL),
        ('description', 'text', 'YES', NULL),
        ('department_id', 'uuid', 'YES', NULL),
        ('category', 'text', 'NO', '''Sanitation''::text'),
        ('version', 'integer', 'NO', '1'),
        ('is_active', 'boolean', 'NO', 'true'),
        ('created_by', 'uuid', 'YES', NULL),
        ('metadata', 'jsonb', 'NO', '''{}''::jsonb'),
        ('created_at', 'timestamp with time zone', 'NO', 'now()'),
        ('updated_at', 'timestamp with time zone', 'NO', 'now()')
      ) AS t(col_name, expected_type, expected_nullable, expected_default)
    ) LOOP
      SELECT data_type, is_nullable, column_default 
      INTO v_actual_type, v_actual_nullable, v_actual_default
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

      -- Validate default expression if required
      IF v_col_rec.expected_default IS NOT NULL THEN
        IF v_actual_default IS NULL THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."%" is missing required default definition (expected "%").', v_col_rec.col_name, v_col_rec.expected_default;
        END IF;

        v_clean_actual_default := trim(replace(replace(v_actual_default, 'pg_catalog.', ''), '::boolean', ''));

        IF v_col_rec.col_name = 'id' AND v_clean_actual_default NOT IN ('gen_random_uuid()', 'public.gen_random_uuid()') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."id" has incompatible default [%] (expected gen_random_uuid()).', v_actual_default;
        ELSIF v_col_rec.col_name = 'category' AND v_clean_actual_default NOT IN ('''Sanitation''::text', '''Sanitation''') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."category" has incompatible default [%] (expected ''Sanitation'').', v_actual_default;
        ELSIF v_col_rec.col_name = 'version' AND v_clean_actual_default <> '1' THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."version" has incompatible default [%] (expected 1).', v_actual_default;
        ELSIF v_col_rec.col_name = 'is_active' AND v_clean_actual_default <> 'true' THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."is_active" has incompatible default [%] (expected true).', v_actual_default;
        ELSIF v_col_rec.col_name = 'metadata' AND v_clean_actual_default NOT IN ('''{}''::jsonb', '''{}''') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."metadata" has incompatible default [%] (expected ''{}''::jsonb).', v_actual_default;
        ELSIF v_col_rec.col_name IN ('created_at', 'updated_at') AND lower(v_clean_actual_default) NOT IN ('now()', 'current_timestamp') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_templates."%" has incompatible default [%] (expected now()).', v_col_rec.col_name, v_actual_default;
        END IF;
      END IF;
    END LOOP;

    -- B. Validate Primary Key constraint on id (must be single-column PK on id)
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

    -- D. Validate Foreign Key on department_id referencing public.departments(id) with ON DELETE SET NULL
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      JOIN information_schema.constraint_column_usage ccu 
        ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
      JOIN information_schema.referential_constraints rc
        ON rc.constraint_name = tc.constraint_name AND rc.constraint_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'checklist_templates' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'department_id' 
        AND ccu.table_name = 'departments' 
        AND ccu.column_name = 'id'
        AND rc.delete_rule = 'SET NULL'
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_templates has an invalid or missing FOREIGN KEY on "department_id" (expected references public.departments(id) ON DELETE SET NULL).';
    END IF;

    -- E. Validate CHECK constraint on category strictly enforces the expected category set
    -- Count all CHECK constraints referencing 'category' to prevent arbitrary constraint selection
    SELECT COUNT(*) INTO v_cat_total_check_count
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    JOIN pg_attribute a ON a.attrelid = rel.oid AND a.attnum = ANY(con.conkey)
    WHERE nsp.nspname = 'public' 
      AND rel.relname = 'checklist_templates' 
      AND con.contype = 'c'
      AND a.attname = 'category';

    IF v_cat_total_check_count = 0 THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_templates lacks a CHECK constraint on "category".';
    ELSIF v_cat_total_check_count > 1 THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_templates has multiple (%) CHECK constraints referencing "category". Manual review required to resolve conflicting or redundant constraints before migration.', v_cat_total_check_count;
    END IF;

    -- Retrieve definition of the single identified category CHECK constraint
    SELECT con.oid, pg_get_constraintdef(con.oid)
    INTO STRICT v_con_oid, v_con_def
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    JOIN pg_attribute a ON a.attrelid = rel.oid AND a.attnum = con.conkey[1]
    WHERE nsp.nspname = 'public' 
      AND rel.relname = 'checklist_templates' 
      AND con.contype = 'c'
      AND cardinality(con.conkey) = 1
      AND a.attname = 'category';

    -- Normalize identifier quotes while strictly preserving whitespace within string literals
    v_clean_def := replace(trim(v_con_def), '"', '');

    IF v_clean_def NOT IN (
      'CHECK ((category = ANY (ARRAY[''Sanitation''::text, ''HACCP Prerequisite''::text, ''Thermal CCP''::text, ''GMP Audit''::text, ''Allergen Control''::text, ''Receiving''::text])))',
      'CHECK (category = ANY (ARRAY[''Sanitation''::text, ''HACCP Prerequisite''::text, ''Thermal CCP''::text, ''GMP Audit''::text, ''Allergen Control''::text, ''Receiving''::text]))',
      'CHECK ((category = ANY (ARRAY[''Sanitation'', ''HACCP Prerequisite'', ''Thermal CCP'', ''GMP Audit'', ''Allergen Control'', ''Receiving'']::text[])))',
      'CHECK (category = ANY (ARRAY[''Sanitation'', ''HACCP Prerequisite'', ''Thermal CCP'', ''GMP Audit'', ''Allergen Control'', ''Receiving'']::text[]))',
      'CHECK ((category IN (''Sanitation'', ''HACCP Prerequisite'', ''Thermal CCP'', ''GMP Audit'', ''Allergen Control'', ''Receiving'')))',
      'CHECK (category IN (''Sanitation'', ''HACCP Prerequisite'', ''Thermal CCP'', ''GMP Audit'', ''Allergen Control'', ''Receiving''))'
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing CHECK constraint on public.checklist_templates."category" has an unverified definition [%]. Manual review required to confirm it strictly enforces the expected category set [Sanitation, HACCP Prerequisite, Thermal CCP, GMP Audit, Allergen Control, Receiving] before proceeding.', v_con_def;
    END IF;
  END IF;

  -- 1.5 Validate complete schema compatibility if public.checklist_items already exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'checklist_items'
  ) THEN
    -- A. Validate all required columns, data types, nullability, and exact defaults
    FOR v_col_rec IN (
      SELECT * FROM (VALUES
        ('id', 'uuid', 'NO', 'gen_random_uuid()'),
        ('template_id', 'uuid', 'NO', NULL),
        ('item_order', 'integer', 'NO', '1'),
        ('section_title', 'text', 'NO', '''General Inspection''::text'),
        ('question', 'text', 'NO', NULL),
        ('instruction', 'text', 'YES', NULL),
        ('response_type', 'text', 'NO', '''pass_fail''::text'),
        ('is_critical', 'boolean', 'NO', 'false'),
        ('min_value', 'numeric', 'YES', NULL),
        ('max_value', 'numeric', 'YES', NULL),
        ('unit', 'text', 'YES', NULL),
        ('options', 'jsonb', 'NO', '''[]''::jsonb'),
        ('created_at', 'timestamp with time zone', 'NO', 'now()')
      ) AS t(col_name, expected_type, expected_nullable, expected_default)
    ) LOOP
      SELECT data_type, is_nullable, column_default 
      INTO v_actual_type, v_actual_nullable, v_actual_default
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

      -- Validate default expression if required
      IF v_col_rec.expected_default IS NOT NULL THEN
        IF v_actual_default IS NULL THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."%" is missing required default definition (expected "%").', v_col_rec.col_name, v_col_rec.expected_default;
        END IF;

        v_clean_actual_default := trim(replace(replace(v_actual_default, 'pg_catalog.', ''), '::boolean', ''));

        IF v_col_rec.col_name = 'id' AND v_clean_actual_default NOT IN ('gen_random_uuid()', 'public.gen_random_uuid()') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."id" has incompatible default [%] (expected gen_random_uuid()).', v_actual_default;
        ELSIF v_col_rec.col_name = 'item_order' AND v_clean_actual_default <> '1' THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."item_order" has incompatible default [%] (expected 1).', v_actual_default;
        ELSIF v_col_rec.col_name = 'section_title' AND v_clean_actual_default NOT IN ('''General Inspection''::text', '''General Inspection''') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."section_title" has incompatible default [%] (expected ''General Inspection'').', v_actual_default;
        ELSIF v_col_rec.col_name = 'response_type' AND v_clean_actual_default NOT IN ('''pass_fail''::text', '''pass_fail''') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."response_type" has incompatible default [%] (expected ''pass_fail'').', v_actual_default;
        ELSIF v_col_rec.col_name = 'is_critical' AND v_clean_actual_default <> 'false' THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."is_critical" has incompatible default [%] (expected false).', v_actual_default;
        ELSIF v_col_rec.col_name = 'options' AND v_clean_actual_default NOT IN ('''[]''::jsonb', '''[]''') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."options" has incompatible default [%] (expected ''[]''::jsonb).', v_actual_default;
        ELSIF v_col_rec.col_name = 'created_at' AND lower(v_clean_actual_default) NOT IN ('now()', 'current_timestamp') THEN
          RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."created_at" has incompatible default [%] (expected now()).', v_actual_default;
        END IF;
      END IF;
    END LOOP;

    -- B. Validate Primary Key constraint on id (must be single-column PK on id)
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

    -- C. Validate Foreign Key on template_id referencing public.checklist_templates(id) with ON DELETE CASCADE
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      JOIN information_schema.constraint_column_usage ccu 
        ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
      JOIN information_schema.referential_constraints rc
        ON rc.constraint_name = tc.constraint_name AND rc.constraint_schema = tc.table_schema
      WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'checklist_items' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'template_id' 
        AND ccu.table_name = 'checklist_templates' 
        AND ccu.column_name = 'id'
        AND rc.delete_rule = 'CASCADE'
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_items has an invalid or missing FOREIGN KEY on "template_id" (expected references public.checklist_templates(id) ON DELETE CASCADE).';
    END IF;

    -- D. Validate CHECK constraint on response_type strictly enforces the 4 supported types
    -- Count all CHECK constraints referencing 'response_type' to prevent arbitrary constraint selection
    SELECT COUNT(*) INTO v_resp_total_check_count
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    JOIN pg_attribute a ON a.attrelid = rel.oid AND a.attnum = ANY(con.conkey)
    WHERE nsp.nspname = 'public' 
      AND rel.relname = 'checklist_items' 
      AND con.contype = 'c'
      AND a.attname = 'response_type';

    IF v_resp_total_check_count = 0 THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_items lacks a CHECK constraint on "response_type".';
    ELSIF v_resp_total_check_count > 1 THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing table public.checklist_items has multiple (%) CHECK constraints referencing "response_type". Manual review required to resolve conflicting or redundant constraints before migration.', v_resp_total_check_count;
    END IF;

    -- Retrieve definition of the single identified response_type CHECK constraint
    SELECT con.oid, pg_get_constraintdef(con.oid)
    INTO STRICT v_con_oid, v_con_def
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    JOIN pg_attribute a ON a.attrelid = rel.oid AND a.attnum = con.conkey[1]
    WHERE nsp.nspname = 'public' 
      AND rel.relname = 'checklist_items' 
      AND con.contype = 'c'
      AND cardinality(con.conkey) = 1
      AND a.attname = 'response_type';

    -- Normalize identifier quotes while strictly preserving whitespace within string literals
    v_clean_def := replace(trim(v_con_def), '"', '');

    IF v_clean_def NOT IN (
      'CHECK ((response_type = ANY (ARRAY[''pass_fail''::text, ''numeric''::text, ''text''::text, ''multiple_choice''::text])))',
      'CHECK (response_type = ANY (ARRAY[''pass_fail''::text, ''numeric''::text, ''text''::text, ''multiple_choice''::text]))',
      'CHECK ((response_type = ANY (ARRAY[''pass_fail'', ''numeric'', ''text'', ''multiple_choice'']::text[])))',
      'CHECK (response_type = ANY (ARRAY[''pass_fail'', ''numeric'', ''text'', ''multiple_choice'']::text[]))',
      'CHECK ((response_type IN (''pass_fail'', ''numeric'', ''text'', ''multiple_choice'')))',
      'CHECK (response_type IN (''pass_fail'', ''numeric'', ''text'', ''multiple_choice''))'
    ) THEN
      RAISE EXCEPTION 'Preflight validation failed: Existing CHECK constraint on public.checklist_items."response_type" has an unverified definition [%]. Manual review required to confirm it strictly enforces the expected response-type set [pass_fail, numeric, text, multiple_choice] before proceeding.', v_con_def;
    END IF;

    -- E. Validate item_key column type, absence of duplicates, and unconditional uniqueness if it already exists
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' 
        AND table_name = 'checklist_items' 
        AND column_name = 'item_key'
    ) THEN
      -- Validate type
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

      -- Validate standalone unconditional uniqueness on item_key (supports ON CONFLICT (item_key) without predicate)
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
          ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
        WHERE tc.table_schema = 'public' 
          AND tc.table_name = 'checklist_items' 
          AND tc.constraint_type = 'UNIQUE' 
          AND kcu.column_name = 'item_key'
        GROUP BY tc.constraint_name
        HAVING COUNT(*) = 1
      ) AND NOT EXISTS (
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
        RAISE EXCEPTION 'Preflight validation failed: Column public.checklist_items."item_key" exists but lacks an unconditional, single-column UNIQUE constraint or unique index on item_key alone (required for ON CONFLICT (item_key) resolution).';
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

-- Validate existing updated_at trigger or create if missing (does not drop or silently replace)
DO $$
DECLARE
  v_tg_rec RECORD;
BEGIN
  SELECT t.oid, t.tgenabled, t.tgtype, pg_get_triggerdef(t.oid) AS tgdef, p.proname, n.nspname
  INTO v_tg_rec
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
  JOIN pg_namespace tn ON tn.oid = c.relnamespace
  JOIN pg_proc p ON p.oid = t.tgfoid
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE tn.nspname = 'public' 
    AND c.relname = 'checklist_templates' 
    AND t.tgname = 'tr_checklist_templates_updated_at'
    AND NOT t.tgisinternal;

  IF FOUND THEN
    -- Verify function is public.handle_updated_at
    IF v_tg_rec.nspname <> 'public' OR v_tg_rec.proname <> 'handle_updated_at' THEN
      RAISE EXCEPTION 'Trigger "tr_checklist_templates_updated_at" on public.checklist_templates calls unexpected function "%.%" (expected public.handle_updated_at). Manual review required.', v_tg_rec.nspname, v_tg_rec.proname;
    END IF;

    -- Verify trigger is enabled ('O' = default/origin, 'A' = always)
    IF v_tg_rec.tgenabled NOT IN ('O', 'A') THEN
      RAISE EXCEPTION 'Trigger "tr_checklist_templates_updated_at" on public.checklist_templates is disabled (status: "%"). Manual review required.', v_tg_rec.tgenabled;
    END IF;

    -- Verify trigger event is strictly BEFORE UPDATE FOR EACH ROW (Postgres tgtype bitmask: 19 = ROW (1) + BEFORE (2) + UPDATE (16))
    IF v_tg_rec.tgtype <> 19 THEN
      RAISE EXCEPTION 'Trigger "tr_checklist_templates_updated_at" on public.checklist_templates has unexpected trigger timing/event flags (tgtype: %, definition: [%]). Expected BEFORE UPDATE FOR EACH ROW. Manual review required.', v_tg_rec.tgtype, v_tg_rec.tgdef;
    END IF;
  ELSE
    CREATE TRIGGER tr_checklist_templates_updated_at
      BEFORE UPDATE ON public.checklist_templates
      FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
  END IF;
END $$;

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

-- Safely add item_key column with unconditional UNIQUE constraint if checklist_items pre-existed without it
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

-- ------------------------------------------------------------------------------
-- 4. PERFORMANCE INDEXES
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_checklist_templates_dept ON public.checklist_templates(department_id);
CREATE INDEX IF NOT EXISTS idx_checklist_templates_category ON public.checklist_templates(category);
CREATE INDEX IF NOT EXISTS idx_checklist_templates_active ON public.checklist_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_checklist_items_template ON public.checklist_items(template_id, item_order);

-- ------------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- Inspects existing policies with full semantic validation (command, roles, USING, WITH CHECK).
-- Safely creates missing policies. Does not blindly drop, replace, or weaken existing policies.
-- ------------------------------------------------------------------------------
ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  v_pol RECORD;
  v_has_tpl_select BOOLEAN := false;
  v_has_tpl_manage BOOLEAN := false;
  v_has_item_select BOOLEAN := false;
  v_has_item_manage BOOLEAN := false;
  v_clean_qual TEXT;
  v_clean_check TEXT;
BEGIN
  -- 5.1 Inspect existing policies on public.checklist_templates
  FOR v_pol IN (
    SELECT p.polname, p.polcmd,
           ARRAY(
             SELECT COALESCE(r.rolname, 'public')::text 
             FROM unnest(p.polroles) AS u(role_oid)
             LEFT JOIN pg_roles r ON r.oid = u.role_oid
           ) AS roles,
           pg_get_expr(p.polqual, p.polrelid) AS qual,
           pg_get_expr(p.polwithcheck, p.polrelid) AS with_check
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'checklist_templates'
  ) LOOP
    v_clean_qual := trim(replace(COALESCE(v_pol.qual, ''), 'public.', ''));
    v_clean_check := trim(replace(COALESCE(v_pol.with_check, ''), 'public.', ''));

    IF v_pol.polname = 'Checklist Templates: Read for active authenticated users' THEN
      -- Validate: Command must be SELECT ('r'), target role authenticated, USING is_active_user(), no WITH CHECK
      IF v_pol.polcmd <> 'r' 
         OR v_pol.roles <> ARRAY['authenticated']::text[]
         OR v_clean_qual <> 'is_active_user()'
         OR v_pol.with_check IS NOT NULL THEN
        RAISE EXCEPTION 'Existing policy "%" on public.checklist_templates has an incompatible definition (cmd: %, roles: %, USING: [%], WITH CHECK: [%]). Expected FOR SELECT TO authenticated USING (public.is_active_user()). Manual review required.',
          v_pol.polname, v_pol.polcmd, v_pol.roles, v_pol.qual, v_pol.with_check;
      END IF;
      v_has_tpl_select := true;

    ELSIF v_pol.polname = 'Checklist Templates: Manage by active Admins, QM, & Lead Auditors' THEN
      -- Validate: Command must be ALL ('*'), target role authenticated, USING and WITH CHECK require is_active_role with exact 3 roles
      IF v_pol.polcmd <> '*'
         OR v_pol.roles <> ARRAY['authenticated']::text[]
         OR v_clean_qual NOT IN (
              'is_active_role(ARRAY[''Super Admin''::text, ''Quality Manager''::text, ''Lead Auditor''::text])',
              'is_active_role(ARRAY[''Super Admin'', ''Quality Manager'', ''Lead Auditor'']::text[])'
            )
         OR v_clean_check NOT IN (
              'is_active_role(ARRAY[''Super Admin''::text, ''Quality Manager''::text, ''Lead Auditor''::text])',
              'is_active_role(ARRAY[''Super Admin'', ''Quality Manager'', ''Lead Auditor'']::text[])'
            ) THEN
        RAISE EXCEPTION 'Existing policy "%" on public.checklist_templates has an incompatible definition (cmd: %, roles: %, USING: [%], WITH CHECK: [%]). Expected FOR ALL TO authenticated USING/WITH CHECK (public.is_active_role(ARRAY[''Super Admin'', ''Quality Manager'', ''Lead Auditor''])). Manual review required.',
          v_pol.polname, v_pol.polcmd, v_pol.roles, v_pol.qual, v_pol.with_check;
      END IF;
      v_has_tpl_manage := true;

    ELSE
      RAISE EXCEPTION 'Existing unexpected or custom policy "%" found on public.checklist_templates (cmd: %, roles: %, USING: [%], WITH CHECK: [%]). Migration will not drop, replace, or weaken custom policies without manual review.',
        v_pol.polname, v_pol.polcmd, v_pol.roles, v_pol.qual, v_pol.with_check;
    END IF;
  END LOOP;

  -- Create SELECT policy for checklist_templates if not already present
  IF NOT v_has_tpl_select THEN
    CREATE POLICY "Checklist Templates: Read for active authenticated users"
      ON public.checklist_templates FOR SELECT
      TO authenticated
      USING (public.is_active_user());
  END IF;

  -- Create ALL/Manage policy for checklist_templates if not already present
  IF NOT v_has_tpl_manage THEN
    CREATE POLICY "Checklist Templates: Manage by active Admins, QM, & Lead Auditors"
      ON public.checklist_templates FOR ALL
      TO authenticated
      USING (public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']))
      WITH CHECK (public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']));
  END IF;

  -- 5.2 Inspect existing policies on public.checklist_items
  FOR v_pol IN (
    SELECT p.polname, p.polcmd,
           ARRAY(
             SELECT COALESCE(r.rolname, 'public')::text 
             FROM unnest(p.polroles) AS u(role_oid)
             LEFT JOIN pg_roles r ON r.oid = u.role_oid
           ) AS roles,
           pg_get_expr(p.polqual, p.polrelid) AS qual,
           pg_get_expr(p.polwithcheck, p.polrelid) AS with_check
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'checklist_items'
  ) LOOP
    v_clean_qual := trim(replace(COALESCE(v_pol.qual, ''), 'public.', ''));
    v_clean_check := trim(replace(COALESCE(v_pol.with_check, ''), 'public.', ''));

    IF v_pol.polname = 'Checklist Items: Read for active authenticated users' THEN
      -- Validate: Command must be SELECT ('r'), target role authenticated, USING is_active_user(), no WITH CHECK
      IF v_pol.polcmd <> 'r' 
         OR v_pol.roles <> ARRAY['authenticated']::text[]
         OR v_clean_qual <> 'is_active_user()'
         OR v_pol.with_check IS NOT NULL THEN
        RAISE EXCEPTION 'Existing policy "%" on public.checklist_items has an incompatible definition (cmd: %, roles: %, USING: [%], WITH CHECK: [%]). Expected FOR SELECT TO authenticated USING (public.is_active_user()). Manual review required.',
          v_pol.polname, v_pol.polcmd, v_pol.roles, v_pol.qual, v_pol.with_check;
      END IF;
      v_has_item_select := true;

    ELSIF v_pol.polname = 'Checklist Items: Manage by active Admins, QM, & Lead Auditors' THEN
      -- Validate: Command must be ALL ('*'), target role authenticated, USING and WITH CHECK require is_active_role with exact 3 roles
      IF v_pol.polcmd <> '*'
         OR v_pol.roles <> ARRAY['authenticated']::text[]
         OR v_clean_qual NOT IN (
              'is_active_role(ARRAY[''Super Admin''::text, ''Quality Manager''::text, ''Lead Auditor''::text])',
              'is_active_role(ARRAY[''Super Admin'', ''Quality Manager'', ''Lead Auditor'']::text[])'
            )
         OR v_clean_check NOT IN (
              'is_active_role(ARRAY[''Super Admin''::text, ''Quality Manager''::text, ''Lead Auditor''::text])',
              'is_active_role(ARRAY[''Super Admin'', ''Quality Manager'', ''Lead Auditor'']::text[])'
            ) THEN
        RAISE EXCEPTION 'Existing policy "%" on public.checklist_items has an incompatible definition (cmd: %, roles: %, USING: [%], WITH CHECK: [%]). Expected FOR ALL TO authenticated USING/WITH CHECK (public.is_active_role(ARRAY[''Super Admin'', ''Quality Manager'', ''Lead Auditor''])). Manual review required.',
          v_pol.polname, v_pol.polcmd, v_pol.roles, v_pol.qual, v_pol.with_check;
      END IF;
      v_has_item_manage := true;

    ELSE
      RAISE EXCEPTION 'Existing unexpected or custom policy "%" found on public.checklist_items (cmd: %, roles: %, USING: [%], WITH CHECK: [%]). Migration will not drop, replace, or weaken custom policies without manual review.',
        v_pol.polname, v_pol.polcmd, v_pol.roles, v_pol.qual, v_pol.with_check;
    END IF;
  END LOOP;

  -- Create SELECT policy for checklist_items if not already present
  IF NOT v_has_item_select THEN
    CREATE POLICY "Checklist Items: Read for active authenticated users"
      ON public.checklist_items FOR SELECT
      TO authenticated
      USING (public.is_active_user());
  END IF;

  -- Create ALL/Manage policy for checklist_items if not already present
  IF NOT v_has_item_manage THEN
    CREATE POLICY "Checklist Items: Manage by active Admins, QM, & Lead Auditors"
      ON public.checklist_items FOR ALL
      TO authenticated
      USING (public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']))
      WITH CHECK (public.is_active_role(ARRAY['Super Admin', 'Quality Manager', 'Lead Auditor']));
  END IF;

END $$;

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
  -- Resolve verified department UUIDs
  SELECT id INTO v_san_dept_id FROM public.departments WHERE code = 'SAN';
  SELECT id INTO v_cold_dept_id FROM public.departments WHERE code = 'COLD';
  SELECT id INTO v_prod_dept_id FROM public.departments WHERE code = 'PROD-A';
  SELECT id INTO v_wh_dept_id FROM public.departments WHERE code = 'WH';

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
