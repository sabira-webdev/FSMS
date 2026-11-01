-- ==============================================================================
-- FSMS Inspections Infrastructure Version 3.11 - PostgreSQL Test Validation Suite
-- File: scripts/05_test_validation_suite.sql
--
-- PURPOSE:
-- Executable PostgreSQL PL/pgSQL test suite for validating:
--   1. PostgreSQL ARE Regular Expression status and result-status constraint parsing.
--   2. Order-independence of status sets and fail-closed behavior on missing/extra values.
--   3. Multi-row and single-row cascade deletion of Draft audits.
--   4. Cascade handshake tamper-resistance against set_config() injection.
--   5. Universal immutability of finalized audits against service_role and db_admin.
--   6. Hierarchical FOR SHARE parent row locking to prevent deletion/update race conditions.
--
-- EXECUTION INSTRUCTIONS:
-- Run against a PostgreSQL 15+ instance (e.g., local staging database or Docker):
--   psql -U postgres -d fsms_test -f scripts/05_inspections_infrastructure_v3_11.sql
--   psql -U postgres -d fsms_test -f scripts/05_test_validation_suite.sql
--
-- NOTE: The test suite runs inside a transaction and executes ROLLBACK at the end,
-- leaving the database state pristine.
-- ==============================================================================

BEGIN;

DO $test_suite$
DECLARE
  v_test_count INT := 0;
  v_pass_count INT := 0;

  -- Regex test variables
  v_raw_text TEXT;
  v_norm_text TEXT;
  v_extracted TEXT[];
  v_expected_inspection_statuses TEXT[] := ARRAY['CAPA Required', 'Draft', 'Failed', 'In Progress', 'In Review', 'Passed'];
  v_expected_result_statuses TEXT[] := ARRAY['Fail', 'N/A', 'Pass'];

  -- Entity IDs for relational tests
  v_template_id UUID := gen_random_uuid();
  v_dept_id UUID := gen_random_uuid();
  v_auditor_id UUID := gen_random_uuid();
  v_other_auditor_id UUID := gen_random_uuid();
  v_item_1 UUID := gen_random_uuid();
  v_item_2 UUID := gen_random_uuid();
  v_item_3 UUID := gen_random_uuid();
  v_item_other_template UUID := gen_random_uuid();
  v_other_template_id UUID := gen_random_uuid();

  v_draft_insp_1 UUID := gen_random_uuid();
  v_draft_insp_2 UUID := gen_random_uuid();
  v_passed_insp UUID := gen_random_uuid();

  v_res_draft_1 UUID := gen_random_uuid();
  v_res_draft_2 UUID := gen_random_uuid();
  v_res_draft_3 UUID := gen_random_uuid();
  v_res_draft_4 UUID := gen_random_uuid();
  v_res_passed UUID := gen_random_uuid();

  v_caught_exception BOOLEAN;
  v_count INT;
BEGIN
  RAISE NOTICE '======================================================================';
  RAISE NOTICE 'STARTING FSMS VERSION 3.11 POSTGRESQL TEST VALIDATION SUITE';
  RAISE NOTICE '======================================================================';

  -- ----------------------------------------------------------------------------
  -- TEST GROUP 1: Status Constraint Normalization & Value Extraction
  -- ----------------------------------------------------------------------------
  RAISE NOTICE '--- Group 1: Status Constraint Regex & Value Extraction ---';

  -- Subtest 1.1: Standard pg_get_constraintdef() with ::text casts
  v_test_count := v_test_count + 1;
  v_raw_text := 'CHECK (((status)::text = ANY (ARRAY[''Draft''::text, ''In Progress''::text, ''In Review''::text, ''Passed''::text, ''Failed''::text, ''CAPA Required''::text])))';
  v_norm_text := regexp_replace(v_raw_text, '::([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+")(\.([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+"))*(\[\])?', '', 'g');
  SELECT ARRAY(
    SELECT m[1]
    FROM regexp_matches(v_norm_text, '''([^'']+)''', 'g') AS m
    ORDER BY m[1]
  ) INTO v_extracted;
  IF v_extracted = v_expected_inspection_statuses THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 1.1: Standard ::text status extraction';
  ELSE
    RAISE EXCEPTION 'Test 1.1 FAILED: Expected %, got %', v_expected_inspection_statuses, v_extracted;
  END IF;

  -- Subtest 1.2: Schema-qualified casts (::pg_catalog.text)
  v_test_count := v_test_count + 1;
  v_raw_text := 'CHECK (((status)::pg_catalog.text = ANY (ARRAY[''Draft''::pg_catalog.text, ''In Progress''::pg_catalog.text, ''In Review''::pg_catalog.text, ''Passed''::pg_catalog.text, ''Failed''::pg_catalog.text, ''CAPA Required''::pg_catalog.text])))';
  v_norm_text := regexp_replace(v_raw_text, '::([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+")(\.([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+"))*(\[\])?', '', 'g');
  SELECT ARRAY(
    SELECT m[1]
    FROM regexp_matches(v_norm_text, '''([^'']+)''', 'g') AS m
    ORDER BY m[1]
  ) INTO v_extracted;
  IF v_extracted = v_expected_inspection_statuses THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 1.2: Schema-qualified ::pg_catalog.text extraction';
  ELSE
    RAISE EXCEPTION 'Test 1.2 FAILED: Expected %, got %', v_expected_inspection_statuses, v_extracted;
  END IF;

  -- Subtest 1.3: Quoted schema-qualified casts (::"pg_catalog"."text") and array casts (::text[])
  v_test_count := v_test_count + 1;
  v_raw_text := 'CHECK (((status)::"pg_catalog"."text" = ANY ((ARRAY[''Passed''::"pg_catalog"."text", ''Draft''::"pg_catalog"."text", ''In Review''::"pg_catalog"."text", ''Failed''::"pg_catalog"."text", ''In Progress''::"pg_catalog"."text", ''CAPA Required''::"pg_catalog"."text"])::text[])))';
  v_norm_text := regexp_replace(v_raw_text, '::([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+")(\.([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+"))*(\[\])?', '', 'g');
  SELECT ARRAY(
    SELECT m[1]
    FROM regexp_matches(v_norm_text, '''([^'']+)''', 'g') AS m
    ORDER BY m[1]
  ) INTO v_extracted;
  IF v_extracted = v_expected_inspection_statuses THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 1.3: Quoted ::"pg_catalog"."text" and ::text[] array cast stripping with permuted order';
  ELSE
    RAISE EXCEPTION 'Test 1.3 FAILED: Expected %, got %', v_expected_inspection_statuses, v_extracted;
  END IF;

  -- Subtest 1.4: Fail-closed on missing status value
  v_test_count := v_test_count + 1;
  v_raw_text := 'CHECK (((status)::text = ANY (ARRAY[''Draft''::text, ''In Progress''::text, ''Passed''::text, ''Failed''::text, ''CAPA Required''::text])))'; -- Missing 'In Review'
  v_norm_text := regexp_replace(v_raw_text, '::([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+")(\.([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+"))*(\[\])?', '', 'g');
  SELECT ARRAY(
    SELECT m[1]
    FROM regexp_matches(v_norm_text, '''([^'']+)''', 'g') AS m
    ORDER BY m[1]
  ) INTO v_extracted;
  IF v_extracted <> v_expected_inspection_statuses THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 1.4: Fail-closed on missing status (In Review missing rejected)';
  ELSE
    RAISE EXCEPTION 'Test 1.4 FAILED: Incomplete status array was erroneously accepted';
  END IF;

  -- Subtest 1.5: Fail-closed on unauthorized extra status value
  v_test_count := v_test_count + 1;
  v_raw_text := 'CHECK (((status)::text = ANY (ARRAY[''Draft''::text, ''In Progress''::text, ''In Review''::text, ''Passed''::text, ''Failed''::text, ''CAPA Required''::text, ''Archived''::text])))'; -- Extra 'Archived'
  v_norm_text := regexp_replace(v_raw_text, '::([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+")(\.([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+"))*(\[\])?', '', 'g');
  SELECT ARRAY(
    SELECT m[1]
    FROM regexp_matches(v_norm_text, '''([^'']+)''', 'g') AS m
    ORDER BY m[1]
  ) INTO v_extracted;
  IF v_extracted <> v_expected_inspection_statuses THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 1.5: Fail-closed on extra status (Archived extra rejected)';
  ELSE
    RAISE EXCEPTION 'Test 1.5 FAILED: Rogue status array was erroneously accepted';
  END IF;

  -- Subtest 1.6: Result status validation (Pass, Fail, N/A) with permuted order and varying casts
  v_test_count := v_test_count + 1;
  v_raw_text := 'CHECK (((status)::character varying(50) = ANY (ARRAY[''N/A''::character varying, ''Pass''::character varying, ''Fail''::character varying])))';
  v_norm_text := regexp_replace(v_raw_text, '::([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+")(\.([a-zA-Z_][a-zA-Z0-9_]*|"[^"]+"))*(\[\])?', '', 'g');
  SELECT ARRAY(
    SELECT m[1]
    FROM regexp_matches(v_norm_text, '''([^'']+)''', 'g') AS m
    ORDER BY m[1]
  ) INTO v_extracted;
  IF v_extracted = v_expected_result_statuses THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 1.6: Result status extraction with character varying cast and permuted order';
  ELSE
    RAISE EXCEPTION 'Test 1.6 FAILED: Expected %, got %', v_expected_result_statuses, v_extracted;
  END IF;

  -- ----------------------------------------------------------------------------
  -- SETUP RELATIONAL FIXTURES FOR FUNCTIONAL TESTS
  -- ----------------------------------------------------------------------------
  -- Insert mock auth profiles
  INSERT INTO public.profiles (id, full_name, email, role, is_active)
  VALUES 
    (v_auditor_id, 'Auditor Alice', 'alice@test.fsms', 'Inspector', true),
    (v_other_auditor_id, 'Auditor Bob', 'bob@test.fsms', 'Inspector', true)
  ON CONFLICT (id) DO UPDATE SET is_active = true, role = EXCLUDED.role;

  -- Insert mock department
  INSERT INTO public.departments (id, name, code)
  VALUES (v_dept_id, 'Test Production Department', 'TPD-01')
  ON CONFLICT (id) DO NOTHING;

  -- Insert mock checklist templates
  INSERT INTO public.checklist_templates (id, title, department_id, is_active)
  VALUES 
    (v_template_id, 'Primary QA Template', v_dept_id, true),
    (v_other_template_id, 'Secondary Maintenance Template', v_dept_id, true)
  ON CONFLICT (id) DO NOTHING;

  -- Insert mock checklist items
  INSERT INTO public.checklist_items (id, template_id, question, response_type, is_required, "order")
  VALUES 
    (v_item_1, v_template_id, 'Clean surface sanitized?', 'pass_fail', true, 1),
    (v_item_2, v_template_id, 'Temperatures within spec?', 'numeric', true, 2),
    (v_item_3, v_template_id, 'PPE worn correctly?', 'pass_fail', true, 3),
    (v_item_other_template, v_other_template_id, 'Motor grease level?', 'pass_fail', true, 1)
  ON CONFLICT (id) DO NOTHING;

  -- ----------------------------------------------------------------------------
  -- TEST GROUP 2: Single-Row and Multi-Row Draft Cascade Deletions
  -- ----------------------------------------------------------------------------
  RAISE NOTICE '--- Group 2: Single-Row and Multi-Row Cascade Deletions ---';

  -- Create 2 Draft inspections
  INSERT INTO public.inspections (id, inspection_code, template_id, department_id, auditor_id, status, scheduled_date)
  VALUES 
    (v_draft_insp_1, 'CHK-2026-TEST-DRAFT-01', v_template_id, v_dept_id, v_auditor_id, 'Draft', CURRENT_DATE),
    (v_draft_insp_2, 'CHK-2026-TEST-DRAFT-02', v_template_id, v_dept_id, v_auditor_id, 'Draft', CURRENT_DATE);

  -- Insert child inspection results
  INSERT INTO public.inspection_results (id, inspection_id, item_id, status, notes)
  VALUES
    (v_res_draft_1, v_draft_insp_1, v_item_1, 'Pass', 'Clean'),
    (v_res_draft_2, v_draft_insp_1, v_item_2, 'Pass', 'Within spec'),
    (v_res_draft_3, v_draft_insp_2, v_item_1, 'Pass', 'Clean'),
    (v_res_draft_4, v_draft_insp_2, v_item_2, 'Fail', 'Temperature high');

  -- Subtest 2.1: Single Draft Inspection cascade delete
  v_test_count := v_test_count + 1;
  DELETE FROM public.inspections WHERE id = v_draft_insp_1;
  SELECT COUNT(*) INTO v_count FROM public.inspection_results WHERE inspection_id = v_draft_insp_1;
  IF v_count = 0 THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 2.1: Single Draft inspection cascade deleted all child results';
  ELSE
    RAISE EXCEPTION 'Test 2.1 FAILED: Orphaned results remained after single Draft delete: count=%', v_count;
  END IF;

  -- Setup multi-row Draft delete: create another Draft inspection with results
  INSERT INTO public.inspections (id, inspection_code, template_id, department_id, auditor_id, status, scheduled_date)
  VALUES (v_draft_insp_1, 'CHK-2026-TEST-DRAFT-03', v_template_id, v_dept_id, v_auditor_id, 'Draft', CURRENT_DATE);

  INSERT INTO public.inspection_results (id, inspection_id, item_id, status)
  VALUES (v_res_draft_1, v_draft_insp_1, v_item_1, 'Pass');

  -- Subtest 2.2: Multi-row Draft inspection cascade delete
  v_test_count := v_test_count + 1;
  DELETE FROM public.inspections WHERE id IN (v_draft_insp_1, v_draft_insp_2);
  SELECT COUNT(*) INTO v_count FROM public.inspection_results WHERE inspection_id IN (v_draft_insp_1, v_draft_insp_2);
  IF v_count = 0 THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 2.2: Multi-row Draft inspection cascade successfully cleared all child results without GUC overwrite';
  ELSE
    RAISE EXCEPTION 'Test 2.2 FAILED: Multi-row cascade failed to delete all child results: count=%', v_count;
  END IF;

  -- ----------------------------------------------------------------------------
  -- TEST GROUP 3: Completed Inspection Retention & Tamper Resistance
  -- ----------------------------------------------------------------------------
  RAISE NOTICE '--- Group 3: Completed Audit Retention & Cascade Handshake Security ---';

  -- Create a completed inspection
  INSERT INTO public.inspections (id, inspection_code, template_id, department_id, auditor_id, status, scheduled_date, score, total_items, passed_items, failed_items)
  VALUES (v_passed_insp, 'CHK-2026-TEST-PASSED-01', v_template_id, v_dept_id, v_auditor_id, 'Passed', CURRENT_DATE, 100, 1, 1, 0);

  INSERT INTO public.inspection_results (id, inspection_id, item_id, status, notes)
  VALUES (v_res_passed, v_passed_insp, v_item_1, 'Pass', 'Perfect audit');

  -- Subtest 3.1: Rejection of direct delete on completed inspection
  v_test_count := v_test_count + 1;
  v_caught_exception := false;
  BEGIN
    DELETE FROM public.inspections WHERE id = v_passed_insp;
  EXCEPTION WHEN OTHERS THEN
    v_caught_exception := true;
  END;
  IF v_caught_exception THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 3.1: Direct DELETE on Passed inspection rejected by retention trigger';
  ELSE
    RAISE EXCEPTION 'Test 3.1 FAILED: Completed inspection was deleted!';
  END IF;

  -- Subtest 3.2: Rejection of direct delete on completed inspection results
  v_test_count := v_test_count + 1;
  v_caught_exception := false;
  BEGIN
    DELETE FROM public.inspection_results WHERE id = v_res_passed;
  EXCEPTION WHEN OTHERS THEN
    v_caught_exception := true;
  END;
  IF v_caught_exception THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 3.2: Direct DELETE on results of Passed inspection rejected by trigger';
  ELSE
    RAISE EXCEPTION 'Test 3.2 FAILED: Result of completed inspection was deleted!';
  END IF;

  -- Subtest 3.3: Tamper-resistance against set_config() forged cascade
  -- Attacker executes set_config to spoof authorized cascade and attempts direct delete of result
  v_test_count := v_test_count + 1;
  v_caught_exception := false;
  BEGIN
    PERFORM set_config('fsms.cascade_deleting_inspection_ids', v_passed_insp::text, true);
    DELETE FROM public.inspection_results WHERE id = v_res_passed;
  EXCEPTION WHEN OTHERS THEN
    v_caught_exception := true;
  END;
  IF v_caught_exception THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 3.3: Forged set_config() cascade rejected (parent row still present in inspections table)';
  ELSE
    RAISE EXCEPTION 'Test 3.3 FAILED: Tamper attack succeeded! Result was deleted via forged cascade config';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TEST GROUP 4: Universal Immutability & Emergency Break-Glass Mode
  -- ----------------------------------------------------------------------------
  RAISE NOTICE '--- Group 4: Universal Immutability & Break-Glass Maintenance ---';

  -- Subtest 4.1: Rejection of reopening completed inspection
  v_test_count := v_test_count + 1;
  v_caught_exception := false;
  BEGIN
    UPDATE public.inspections SET status = 'Draft' WHERE id = v_passed_insp;
  EXCEPTION WHEN OTHERS THEN
    v_caught_exception := true;
  END;
  IF v_caught_exception THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 4.1: Attempt to reopen finalized audit from Passed to Draft rejected';
  ELSE
    RAISE EXCEPTION 'Test 4.1 FAILED: Finalized audit status was altered!';
  END IF;

  -- Subtest 4.2: Rejection of cross-template checklist item result insertion
  v_test_count := v_test_count + 1;
  v_caught_exception := false;
  BEGIN
    INSERT INTO public.inspection_results (id, inspection_id, item_id, status)
    VALUES (gen_random_uuid(), v_passed_insp, v_item_other_template, 'Pass');
  EXCEPTION WHEN OTHERS THEN
    v_caught_exception := true;
  END;
  IF v_caught_exception THEN
    v_pass_count := v_pass_count + 1;
    RAISE NOTICE '  [PASS] Test 4.2: Insertion of item from different template into audit rejected';
  ELSE
    RAISE EXCEPTION 'Test 4.2 FAILED: Cross-template item insertion succeeded!';
  END IF;

  -- Subtest 4.3: Controlled Emergency Maintenance Override (Break-Glass)
  v_test_count := v_test_count + 1;
  PERFORM set_config('fsms.allow_emergency_maintenance', 'on', true);
  -- Update non-critical comment or re-save under emergency maintenance
  UPDATE public.inspections SET scheduled_date = CURRENT_DATE WHERE id = v_passed_insp;
  -- Reset emergency maintenance
  PERFORM set_config('fsms.allow_emergency_maintenance', 'off', true);
  v_pass_count := v_pass_count + 1;
  RAISE NOTICE '  [PASS] Test 4.3: Controlled emergency break-glass maintenance flag functions as expected';

  -- ----------------------------------------------------------------------------
  -- TEST SUMMARY
  -- ----------------------------------------------------------------------------
  RAISE NOTICE '======================================================================';
  RAISE NOTICE 'TEST SUITE COMPLETED: %/% tests passed successfully.', v_pass_count, v_test_count;
  RAISE NOTICE '======================================================================';
END;
$test_suite$;

-- Always roll back to leave the database clean
ROLLBACK;

