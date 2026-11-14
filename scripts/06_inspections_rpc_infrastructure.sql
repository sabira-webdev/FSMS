-- ==============================================================================
-- File: scripts/06_inspections_rpc_infrastructure.sql
-- Module: FSMS Inspections Infrastructure
-- Version: 3.12 (Safe Options Mapping, Strict State Machine, Metadata Guards,
--                Decoupled Concurrency Metrics, Bijective Recovery)
-- Target: Supabase PostgreSQL 15+ / PostgREST / GoTrue Auth
-- Depends: 05_inspections_infrastructure_v3_11.sql
-- ==============================================================================

BEGIN;

-- ============================================================================
-- 1. PREFLIGHT PREREQUISITE VALIDATION
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'inspections'
  ) THEN
    RAISE EXCEPTION 'Preflight: public.inspections not found. Run 05_inspections_infrastructure_v3_11.sql first.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'inspection_results'
  ) THEN
    RAISE EXCEPTION 'Preflight: public.inspection_results not found.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'checklist_items'
  ) THEN
    RAISE EXCEPTION 'Preflight: public.checklist_items not found.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'is_active_user'
    AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'Preflight: public.is_active_user() is missing.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'is_active_role'
    AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'Preflight: public.is_active_role() is missing.';
  END IF;

  RAISE NOTICE 'Preflight validation passed.';
END $$;

-- ============================================================================
-- 2. EMERGENCY ADMIN HELPER (Single Source of Truth)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fsms_is_emergency_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Emergency bypass requires BOTH conditions:
  -- 1. Direct database session user (not a PostgREST/GoTrue application request)
  -- 2. Explicit session flag set by the DBA
  RETURN (SESSION_USER IN ('postgres', 'supabase_admin'))
     AND (auth.role() IS NULL)
     AND (COALESCE(current_setting('fsms.allow_emergency_maintenance', true), 'off') = 'on');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fsms_is_emergency_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fsms_is_emergency_admin() TO authenticated, service_role;

-- ============================================================================
-- 3. OPTIONS MAPPING COLUMN ON CHECKLIST_ITEMS
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'checklist_items'
      AND column_name = 'options_mapped'
  ) THEN
    ALTER TABLE public.checklist_items
      ADD COLUMN options_mapped BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

-- Auto-mark items that already have valid structured options
DO $$
DECLARE
  v_item RECORD;
  v_valid BOOLEAN;
  v_elem JSONB;
  v_vals TEXT[] := '{}';
  v_val TEXT;
  v_count INT := 0;
BEGIN
  FOR v_item IN
    SELECT id, options
    FROM public.checklist_items
    WHERE response_type = 'multiple_choice'
      AND options IS NOT NULL
      AND jsonb_typeof(options) = 'array'
      AND jsonb_array_length(options) > 0
      AND options_mapped = false
  LOOP
    v_valid := true;
    v_vals := '{}';
    FOR v_elem IN SELECT jsonb_array_elements(v_item.options) LOOP
      IF jsonb_typeof(v_elem) <> 'object' THEN v_valid := false; EXIT; END IF;
      v_val := TRIM(COALESCE(v_elem->>'value', ''));
      IF v_val = '' THEN v_valid := false; EXIT; END IF;
      IF TRIM(COALESCE(v_elem->>'label', '')) = '' THEN v_valid := false; EXIT; END IF;
      IF TRIM(COALESCE(v_elem->>'status', '')) NOT IN ('Pass', 'Fail') THEN v_valid := false; EXIT; END IF;
      IF v_val = ANY(v_vals) THEN v_valid := false; EXIT; END IF;
      v_vals := array_append(v_vals, v_val);
    END LOOP;

    IF v_valid THEN
      UPDATE public.checklist_items SET options_mapped = true WHERE id = v_item.id;
      v_count := v_count + 1;
    END IF;
  END LOOP;

  -- Non-multiple-choice items are trivially mapped
  UPDATE public.checklist_items SET options_mapped = true
  WHERE response_type <> 'multiple_choice' AND options_mapped = false;

  RAISE NOTICE 'Options mapping scan complete. % multiple-choice items auto-verified.', v_count;
END $$;

-- Report unmapped items for QM review
DO $$
DECLARE
  v_unmapped INT;
BEGIN
  SELECT COUNT(*) INTO v_unmapped
  FROM public.checklist_items
  WHERE response_type = 'multiple_choice' AND options_mapped = false;

  IF v_unmapped > 0 THEN
    RAISE NOTICE 'WARNING: % multiple-choice checklist items have unmapped options requiring Quality Manager review.', v_unmapped;
    RAISE NOTICE 'Run: SELECT ci.id, ct.code, ct.title, ci.question, ci.options FROM public.checklist_items ci JOIN public.checklist_templates ct ON ct.id = ci.template_id WHERE ci.response_type = ''multiple_choice'' AND ci.options_mapped = false;';
  END IF;
END $$;

-- ============================================================================
-- 4. OPTIONS SCHEMA VALIDATOR
-- ============================================================================
CREATE OR REPLACE FUNCTION public.validate_checklist_item_options(p_options JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_elem JSONB;
  v_val TEXT;
  v_label TEXT;
  v_status TEXT;
  v_seen_values TEXT[] := '{}';
  v_seen_labels TEXT[] := '{}';
  v_val_lower TEXT;
  v_label_lower TEXT;
BEGIN
  IF p_options IS NULL OR jsonb_typeof(p_options) <> 'array' THEN
    RAISE EXCEPTION 'Schema violation: options must be a JSON array.';
  END IF;

  IF jsonb_array_length(p_options) = 0 THEN
    RAISE EXCEPTION 'Schema violation: options array cannot be empty.';
  END IF;

  FOR v_elem IN SELECT jsonb_array_elements(p_options) LOOP
    IF jsonb_typeof(v_elem) <> 'object' THEN
      RAISE EXCEPTION 'Schema violation: each option must be a JSON object.';
    END IF;

    v_val := TRIM(COALESCE(v_elem->>'value', ''));
    v_label := TRIM(COALESCE(v_elem->>'label', ''));
    v_status := TRIM(COALESCE(v_elem->>'status', ''));

    IF v_val = '' THEN
      RAISE EXCEPTION 'Schema violation: option is missing non-empty "value".';
    END IF;
    IF v_label = '' THEN
      RAISE EXCEPTION 'Schema violation: option "%" is missing non-empty "label".', v_val;
    END IF;
    IF v_status NOT IN ('Pass', 'Fail') THEN
      RAISE EXCEPTION 'Schema violation: option "%" has invalid status "%". Must be "Pass" or "Fail".', v_val, v_status;
    END IF;

    v_val_lower := lower(v_val);
    v_label_lower := lower(v_label);

    IF v_val_lower = ANY(v_seen_values) THEN
      RAISE EXCEPTION 'Schema violation: duplicate option value "%" (case-insensitive).', v_val;
    END IF;
    IF v_label_lower = ANY(v_seen_labels) THEN
      RAISE EXCEPTION 'Schema violation: duplicate option label "%" (case-insensitive).', v_label;
    END IF;

    -- Ensure value and label from different options cannot collide
    IF v_val_lower = ANY(v_seen_labels) OR v_label_lower = ANY(v_seen_values) THEN
      RAISE EXCEPTION 'Schema violation: ambiguous match. Value "%" or label "%" collides with another option''s label or value.', v_val, v_label;
    END IF;

    v_seen_values := array_append(v_seen_values, v_val_lower);
    v_seen_labels := array_append(v_seen_labels, v_label_lower);
  END LOOP;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.validate_checklist_item_options(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_checklist_item_options(JSONB) TO authenticated, service_role;

-- ============================================================================
-- 5. CHECKLIST ITEMS OPTIONS INTEGRITY TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.protect_checklist_item_options_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.response_type = 'multiple_choice' THEN
    IF NEW.options_mapped = true THEN
      PERFORM public.validate_checklist_item_options(NEW.options);
    END IF;
    -- Unmapped items are allowed to retain legacy string arrays
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.protect_checklist_item_options_integrity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protect_checklist_item_options_integrity() TO authenticated, service_role;

DROP TRIGGER IF EXISTS tr_protect_checklist_item_options_integrity ON public.checklist_items;
CREATE TRIGGER tr_protect_checklist_item_options_integrity
  BEFORE INSERT OR UPDATE ON public.checklist_items
  FOR EACH ROW EXECUTE FUNCTION public.protect_checklist_item_options_integrity();

-- ============================================================================
-- 6. INSPECTION CODE SEQUENCE
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS public.seq_inspection_code_number
  START WITH 1 INCREMENT BY 1;

-- Initialize sequence from existing codes for the current year
DO $$
DECLARE
  v_max_num INT := 0;
  v_yr TEXT := to_char(CURRENT_DATE, 'YYYY');
BEGIN
  SELECT COALESCE(MAX(
    CASE
      WHEN inspection_code ~ ('^FSMS-INSP-' || v_yr || '-\d{4}$')
      THEN CAST(SPLIT_PART(inspection_code, '-', 4) AS INTEGER)
      ELSE 0
    END
  ), 0)
  INTO v_max_num
  FROM public.inspections;

  IF v_max_num > 0 THEN
    PERFORM setval('public.seq_inspection_code_number', v_max_num, true);
  END IF;
END $$;

-- ============================================================================
-- 7. STATE MACHINE & METADATA MUTATION TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.enforce_inspection_status_transitions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_uid UUID;
  v_is_service BOOLEAN;
BEGIN
  -- Emergency admin bypass (requires direct postgres session + explicit flag)
  IF public.fsms_is_emergency_admin() THEN
    RETURN NEW;
  END IF;

  v_caller_uid := auth.uid();
  v_is_service := (auth.role() = 'service_role');

  -- ---- PART A: STATUS TRANSITION ENFORCEMENT ----
  IF NEW.status IS DISTINCT FROM OLD.status THEN

    -- A1. Sealed terminal audits: nobody can modify, including service_role
    IF OLD.status IN ('Passed', 'Failed', 'CAPA Required') THEN
      RAISE EXCEPTION 'Audit integrity violation: Inspection "%" is sealed in "%" status.',
        OLD.inspection_code, OLD.status;
    END IF;

    -- Application callers must be authenticated and active
    IF NOT v_is_service THEN
      IF v_caller_uid IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.';
      END IF;
      IF NOT public.is_active_user() THEN
        RAISE EXCEPTION 'Access denied: User profile is inactive.';
      END IF;
    END IF;

    -- A2. Draft -> In Progress
    IF OLD.status = 'Draft' THEN
      IF NEW.status <> 'In Progress' THEN
        RAISE EXCEPTION 'Workflow violation: "%" cannot go from Draft to "%". Allowed: In Progress.',
          OLD.inspection_code, NEW.status;
      END IF;
      IF NOT v_is_service THEN
        IF NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor','Inspector']) THEN
          RAISE EXCEPTION 'Privilege violation: Role not authorized to start inspections.';
        END IF;
        IF public.is_active_role(ARRAY['Inspector'])
           AND NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor'])
           AND OLD.auditor_id IS DISTINCT FROM v_caller_uid THEN
          RAISE EXCEPTION 'Privilege violation: Inspectors can only start their own assigned inspections.';
        END IF;
      END IF;

    -- A3. In Progress -> In Review
    ELSIF OLD.status = 'In Progress' THEN
      IF NEW.status <> 'In Review' THEN
        RAISE EXCEPTION 'Workflow violation: "%" cannot go from In Progress to "%". Allowed: In Review.',
          OLD.inspection_code, NEW.status;
      END IF;
      IF NOT v_is_service THEN
        IF NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor','Inspector']) THEN
          RAISE EXCEPTION 'Privilege violation: Role not authorized to submit inspections.';
        END IF;
        IF public.is_active_role(ARRAY['Inspector'])
           AND NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor'])
           AND OLD.auditor_id IS DISTINCT FROM v_caller_uid THEN
          RAISE EXCEPTION 'Privilege violation: Inspectors can only submit their own assigned inspections.';
        END IF;
      END IF;

    -- A4. In Review -> Reopen or Finalize
    ELSIF OLD.status = 'In Review' THEN
      IF NEW.status NOT IN ('In Progress', 'Passed', 'Failed', 'CAPA Required') THEN
        RAISE EXCEPTION 'Workflow violation: "%" cannot go from In Review to "%".',
          OLD.inspection_code, NEW.status;
      END IF;
      IF NOT v_is_service THEN
        IF NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor']) THEN
          RAISE EXCEPTION 'Privilege violation: Only management can reopen or finalize inspections.';
        END IF;
      END IF;

    ELSE
      RAISE EXCEPTION 'Workflow violation: Unknown source status "%".', OLD.status;
    END IF;
  END IF;

  -- ---- PART B: METADATA MUTATION GUARDS ----
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN

    -- B1. Sealed audits: no metadata changes for anyone (including service_role)
    IF OLD.status IN ('Passed', 'Failed', 'CAPA Required') THEN
      IF (NEW.auditor_id IS DISTINCT FROM OLD.auditor_id)
         OR (NEW.department_id IS DISTINCT FROM OLD.department_id)
         OR (NEW.scheduled_date IS DISTINCT FROM OLD.scheduled_date)
         OR (NEW.shift IS DISTINCT FROM OLD.shift)
         OR (NEW.facility_zone IS DISTINCT FROM OLD.facility_zone)
         OR (NEW.summary_notes IS DISTINCT FROM OLD.summary_notes)
         OR (NEW.score IS DISTINCT FROM OLD.score)
         OR (NEW.total_items IS DISTINCT FROM OLD.total_items)
         OR (NEW.passed_items IS DISTINCT FROM OLD.passed_items)
         OR (NEW.failed_items IS DISTINCT FROM OLD.failed_items)
         OR (NEW.digital_signature_url IS DISTINCT FROM OLD.digital_signature_url) THEN
        RAISE EXCEPTION 'Audit integrity violation: Inspection "%" is sealed and cannot be modified.',
          OLD.inspection_code;
      END IF;
    END IF;

    -- Service role and DB admin may update non-sealed audits freely
    IF v_is_service THEN
      RETURN NEW;
    END IF;

    -- Application caller guards for non-sealed audits
    IF v_caller_uid IS NOT NULL THEN

      -- B2. Department: only Draft, only managers
      IF NEW.department_id IS DISTINCT FROM OLD.department_id THEN
        IF OLD.status <> 'Draft' THEN
          RAISE EXCEPTION 'Workflow violation: department cannot be changed after inspection starts (status: "%").', OLD.status;
        END IF;
        IF NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor']) THEN
          RAISE EXCEPTION 'Privilege violation: Only management can change inspection department.';
        END IF;
      END IF;

      -- B3. Auditor: Draft or In Progress, only managers
      IF NEW.auditor_id IS DISTINCT FROM OLD.auditor_id THEN
        IF OLD.status NOT IN ('Draft', 'In Progress') THEN
          RAISE EXCEPTION 'Workflow violation: auditor cannot be reassigned in "%" status.', OLD.status;
        END IF;
        IF NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor']) THEN
          RAISE EXCEPTION 'Privilege violation: Only management can reassign auditors.';
        END IF;
      END IF;

      -- B4. Scheduling: not in review or terminal
      IF (NEW.scheduled_date IS DISTINCT FROM OLD.scheduled_date)
         OR (NEW.shift IS DISTINCT FROM OLD.shift)
         OR (NEW.facility_zone IS DISTINCT FROM OLD.facility_zone) THEN
        IF OLD.status IN ('In Review', 'Passed', 'Failed', 'CAPA Required') THEN
          RAISE EXCEPTION 'Workflow violation: scheduling details locked in "%" status.', OLD.status;
        END IF;
        IF public.is_active_role(ARRAY['Inspector'])
           AND NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor'])
           AND OLD.auditor_id IS DISTINCT FROM v_caller_uid THEN
          RAISE EXCEPTION 'Privilege violation: Inspectors can only modify their own inspection details.';
        END IF;
      END IF;

      -- B5. Notes: Inspector blocked in review
      IF NEW.summary_notes IS DISTINCT FROM OLD.summary_notes THEN
        IF OLD.status = 'In Review'
           AND public.is_active_role(ARRAY['Inspector'])
           AND NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor']) THEN
          RAISE EXCEPTION 'Privilege violation: Inspectors cannot edit notes on inspections in review.';
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.enforce_inspection_status_transitions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enforce_inspection_status_transitions() TO authenticated, service_role;

DROP TRIGGER IF EXISTS tr_enforce_inspection_status_transitions ON public.inspections;
CREATE TRIGGER tr_enforce_inspection_status_transitions
  BEFORE UPDATE ON public.inspections
  FOR EACH ROW EXECUTE FUNCTION public.enforce_inspection_status_transitions();

-- ============================================================================
-- 8. RESPONSE VALIDATION TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.validate_inspection_result_response()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_item RECORD;
  v_input TEXT;
  v_input_lower TEXT;
  v_matched_status TEXT;
  v_canonical_val TEXT;
  v_is_failed BOOLEAN := false;
BEGIN
  IF public.fsms_is_emergency_admin() THEN
    RETURN NEW;
  END IF;

  SELECT id, response_type, is_critical, min_value, max_value, unit, options, options_mapped
  INTO v_item
  FROM public.checklist_items
  WHERE id = NEW.item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Integrity violation: checklist item "%" does not exist.', NEW.item_id;
  END IF;

  IF v_item.response_type NOT IN ('pass_fail', 'numeric', 'text', 'multiple_choice') THEN
    RAISE EXCEPTION 'Schema violation: unsupported response_type "%" on item "%".', v_item.response_type, NEW.item_id;
  END IF;

  -- Validate options schema for mapped multiple-choice items, even on Pending/NA
  IF v_item.response_type = 'multiple_choice' AND v_item.options_mapped = true THEN
    PERFORM public.validate_checklist_item_options(v_item.options);
  END IF;

  -- Pending / N/A: cleanse response data
  IF NEW.result_status IN ('Pending', 'N/A') THEN
    NEW.numeric_value := NULL;
    NEW.text_value := NULL;
    NEW.photo_evidence_urls := '{}'::TEXT[];
    NEW.is_deviation := false;
    RETURN NEW;
  END IF;

  -- ---- Scored Responses ----

  IF v_item.response_type = 'pass_fail' THEN
    v_input := lower(TRIM(COALESCE(NEW.text_value, '')));
    IF v_input IN ('pass', 'passes', 'passed') THEN
      NEW.result_status := 'Pass';
      NEW.text_value := 'Pass';
      NEW.is_deviation := false;
    ELSIF v_input IN ('fail', 'fails', 'failed') THEN
      NEW.result_status := 'Fail';
      NEW.text_value := 'Fail';
      NEW.is_deviation := true;
    ELSE
      RAISE EXCEPTION 'Validation error: pass_fail question "%" requires "Pass" or "Fail", got "%".', NEW.item_id, COALESCE(NEW.text_value, '');
    END IF;
    NEW.numeric_value := NULL;

  ELSIF v_item.response_type = 'numeric' THEN
    IF NEW.numeric_value IS NULL THEN
      RAISE EXCEPTION 'Validation error: numeric question "%" requires a numeric_value.', NEW.item_id;
    END IF;

    IF v_item.min_value IS NOT NULL AND NEW.numeric_value < v_item.min_value THEN
      v_is_failed := true;
    END IF;
    IF v_item.max_value IS NOT NULL AND NEW.numeric_value > v_item.max_value THEN
      v_is_failed := true;
    END IF;

    IF v_is_failed THEN
      NEW.result_status := 'Fail';
      NEW.is_deviation := true;
    ELSE
      NEW.result_status := 'Pass';
      NEW.is_deviation := false;
    END IF;
    NEW.text_value := NEW.numeric_value::TEXT;

  ELSIF v_item.response_type = 'multiple_choice' THEN
    IF NOT v_item.options_mapped THEN
      RAISE EXCEPTION 'Configuration error: multiple-choice question "%" has unmapped options. A Quality Manager must configure explicit Pass/Fail outcomes before this question can be answered.', NEW.item_id;
    END IF;

    v_input := TRIM(COALESCE(NEW.text_value, ''));
    IF v_input = '' THEN
      RAISE EXCEPTION 'Validation error: multiple-choice question "%" requires a selection.', NEW.item_id;
    END IF;

    v_input_lower := lower(v_input);

    SELECT elem->>'status', elem->>'value'
    INTO v_matched_status, v_canonical_val
    FROM jsonb_array_elements(v_item.options) AS elem
    WHERE lower(TRIM(elem->>'value')) = v_input_lower
       OR lower(TRIM(elem->>'label')) = v_input_lower;

    IF v_matched_status IS NULL THEN
      RAISE EXCEPTION 'Validation error: "%" is not a configured option for question "%".', v_input, NEW.item_id;
    END IF;

    IF v_matched_status = 'Pass' THEN
      NEW.result_status := 'Pass';
      NEW.is_deviation := false;
    ELSE
      NEW.result_status := 'Fail';
      NEW.is_deviation := true;
    END IF;
    NEW.text_value := v_canonical_val;
    NEW.numeric_value := NULL;

  ELSIF v_item.response_type = 'text' THEN
    v_input := TRIM(COALESCE(NEW.text_value, ''));
    IF v_input = '' THEN
      RAISE EXCEPTION 'Validation error: text question "%" requires a non-empty response.', NEW.item_id;
    END IF;
    NEW.result_status := 'Pass';
    NEW.is_deviation := false;
    NEW.numeric_value := NULL;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.validate_inspection_result_response() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_inspection_result_response() TO authenticated, service_role;

DROP TRIGGER IF EXISTS tr_validate_inspection_result_response ON public.inspection_results;
CREATE TRIGGER tr_validate_inspection_result_response
  BEFORE INSERT OR UPDATE ON public.inspection_results
  FOR EACH ROW EXECUTE FUNCTION public.validate_inspection_result_response();

-- ============================================================================
-- 9. WORKFLOW RPCs
-- ============================================================================

-- 9.1 CREATE INSPECTION ATOMIC
CREATE OR REPLACE FUNCTION public.create_inspection_atomic(
  p_template_id UUID,
  p_department_id UUID,
  p_auditor_id UUID,
  p_scheduled_date DATE,
  p_shift TEXT DEFAULT 'Morning (Shift A)',
  p_facility_zone TEXT DEFAULT NULL,
  p_summary_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inspection_id UUID;
  v_inspection_code TEXT;
  v_next_num BIGINT;
  v_current_year TEXT;
  v_items_count INT := 0;
  v_unmapped_count INT := 0;
  v_created_row public.inspections%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Access denied: Unauthenticated.';
  END IF;
  IF NOT public.is_active_user() THEN
    RAISE EXCEPTION 'Access denied: User inactive.';
  END IF;
  IF NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor','Inspector']) THEN
    RAISE EXCEPTION 'Access denied: Insufficient privileges.';
  END IF;
  IF public.is_active_role(ARRAY['Inspector'])
     AND NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor'])
     AND p_auditor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Privilege violation: Inspectors can only create self-assigned inspections.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.checklist_templates WHERE id = p_template_id AND is_active = true) THEN
    RAISE EXCEPTION 'Validation error: Template "%" not found or inactive.', p_template_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.departments WHERE id = p_department_id AND is_active = true) THEN
    RAISE EXCEPTION 'Validation error: Department "%" not found or inactive.', p_department_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_auditor_id AND is_active = true) THEN
    RAISE EXCEPTION 'Validation error: Auditor "%" not found or inactive.', p_auditor_id;
  END IF;

  SELECT COUNT(*) INTO v_items_count
  FROM public.checklist_items WHERE template_id = p_template_id;
  IF v_items_count = 0 THEN
    RAISE EXCEPTION 'Validation error: Template "%" has no checklist items.', p_template_id;
  END IF;

  -- Block templates with unmapped multiple-choice options
  SELECT COUNT(*) INTO v_unmapped_count
  FROM public.checklist_items
  WHERE template_id = p_template_id
    AND response_type = 'multiple_choice'
    AND options_mapped = false;

  IF v_unmapped_count > 0 THEN
    RAISE EXCEPTION 'Configuration error: Template has % multiple-choice question(s) with unmapped Pass/Fail options. A Quality Manager must map option outcomes before this template can be used for inspections.', v_unmapped_count;
  END IF;

  v_next_num := nextval('public.seq_inspection_code_number');
  v_current_year := to_char(CURRENT_DATE, 'YYYY');
  v_inspection_code := 'FSMS-INSP-' || v_current_year || '-' || LPAD(v_next_num::TEXT, 4, '0');

  INSERT INTO public.inspections (
    template_id, department_id, auditor_id, inspection_code,
    scheduled_date, shift, facility_zone, summary_notes,
    status, total_items, passed_items, failed_items, score
  ) VALUES (
    p_template_id, p_department_id, p_auditor_id, v_inspection_code,
    p_scheduled_date, p_shift, p_facility_zone, p_summary_notes,
    'Draft', v_items_count, 0, 0, NULL
  )
  RETURNING * INTO v_created_row;

  v_inspection_id := v_created_row.id;

  INSERT INTO public.inspection_results (inspection_id, item_id, result_status, photo_evidence_urls, is_deviation)
  SELECT v_inspection_id, i.id, 'Pending', '{}'::TEXT[], false
  FROM public.checklist_items i
  WHERE i.template_id = p_template_id
  ORDER BY i.item_order ASC;

  RETURN to_jsonb(v_created_row);
END;
$$;

-- 9.2 START INSPECTION ATOMIC
CREATE OR REPLACE FUNCTION public.start_inspection_atomic(p_inspection_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inspection public.inspections%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Access denied: Unauthenticated.'; END IF;
  IF NOT public.is_active_user() THEN RAISE EXCEPTION 'Access denied: User inactive.'; END IF;
  IF NOT public.is_active_role(ARRAY['Inspector','Lead Auditor','Quality Manager','Super Admin']) THEN
    RAISE EXCEPTION 'Access denied: Role not authorized to start inspections.';
  END IF;

  SELECT * INTO v_inspection FROM public.inspections WHERE id = p_inspection_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not found: Inspection "%" does not exist.', p_inspection_id; END IF;

  IF public.is_active_role(ARRAY['Inspector'])
     AND NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor'])
     AND v_inspection.auditor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Privilege violation: Inspectors can only start their own assigned inspections.';
  END IF;

  IF v_inspection.status <> 'Draft' THEN
    RAISE EXCEPTION 'Workflow violation: Cannot start "%" (status "%", expected "Draft").', v_inspection.inspection_code, v_inspection.status;
  END IF;

  UPDATE public.inspections SET status = 'In Progress' WHERE id = p_inspection_id RETURNING * INTO v_inspection;
  RETURN to_jsonb(v_inspection);
END;
$$;

-- 9.3 SYNC INSPECTION METRICS ATOMIC
CREATE OR REPLACE FUNCTION public.sync_inspection_metrics_atomic(p_inspection_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inspection public.inspections%ROWTYPE;
  v_total INT; v_passed INT; v_failed INT; v_scored INT;
  v_score NUMERIC(5,2);
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Access denied: Unauthenticated.'; END IF;
  IF NOT public.is_active_user() THEN RAISE EXCEPTION 'Access denied: User inactive.'; END IF;
  IF NOT public.is_active_role(ARRAY['Inspector','Lead Auditor','Quality Manager','Super Admin']) THEN
    RAISE EXCEPTION 'Access denied: Role not authorized.';
  END IF;

  SELECT * INTO v_inspection FROM public.inspections WHERE id = p_inspection_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not found: Inspection does not exist.'; END IF;

  IF public.is_active_role(ARRAY['Inspector'])
     AND NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor'])
     AND v_inspection.auditor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Privilege violation: Inspectors can only sync their own inspections.';
  END IF;

  IF v_inspection.status IN ('Passed', 'Failed', 'CAPA Required') THEN
    RAISE EXCEPTION 'Integrity violation: Inspection "%" is sealed.', v_inspection.inspection_code;
  END IF;

  SELECT COUNT(*),
    COUNT(*) FILTER (WHERE result_status = 'Pass'),
    COUNT(*) FILTER (WHERE result_status = 'Fail')
  INTO v_total, v_passed, v_failed
  FROM public.inspection_results WHERE inspection_id = p_inspection_id;

  v_scored := v_passed + v_failed;
  v_score := CASE WHEN v_scored > 0 THEN ROUND((v_passed::NUMERIC / v_scored) * 100.0, 2) ELSE NULL END;

  UPDATE public.inspections
  SET total_items = v_total, passed_items = v_passed, failed_items = v_failed,
      score = v_score
  WHERE id = p_inspection_id RETURNING * INTO v_inspection;

  RETURN to_jsonb(v_inspection);
END;
$$;

-- 9.4 SUBMIT INSPECTION ATOMIC
CREATE OR REPLACE FUNCTION public.submit_inspection_atomic(
  p_inspection_id UUID,
  p_summary_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inspection public.inspections%ROWTYPE;
  v_expected INT; v_actual INT; v_pending INT;
  v_missing UUID; v_foreign UUID;
  v_total INT; v_passed INT; v_failed INT; v_scored INT;
  v_score NUMERIC(5,2);
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Access denied: Unauthenticated.'; END IF;
  IF NOT public.is_active_user() THEN RAISE EXCEPTION 'Access denied: User inactive.'; END IF;
  IF NOT public.is_active_role(ARRAY['Inspector','Lead Auditor','Quality Manager','Super Admin']) THEN
    RAISE EXCEPTION 'Access denied: Role not authorized to submit inspections.';
  END IF;

  SELECT * INTO v_inspection FROM public.inspections WHERE id = p_inspection_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not found: Inspection does not exist.'; END IF;

  IF public.is_active_role(ARRAY['Inspector'])
     AND NOT public.is_active_role(ARRAY['Super Admin','Quality Manager','Lead Auditor'])
     AND v_inspection.auditor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Privilege violation: Inspectors can only submit their own inspections.';
  END IF;

  IF v_inspection.status <> 'In Progress' THEN
    RAISE EXCEPTION 'Workflow violation: Cannot submit "%" (status "%", expected "In Progress").', v_inspection.inspection_code, v_inspection.status;
  END IF;

  -- Bijective checks
  SELECT COUNT(*) INTO v_expected FROM public.checklist_items WHERE template_id = v_inspection.template_id;
  SELECT COUNT(*) INTO v_actual FROM public.inspection_results WHERE inspection_id = p_inspection_id;
  IF v_actual <> v_expected THEN
    RAISE EXCEPTION 'Integrity violation: expected % results, found %.', v_expected, v_actual;
  END IF;

  SELECT i.id INTO v_missing FROM public.checklist_items i
  WHERE i.template_id = v_inspection.template_id
    AND NOT EXISTS (SELECT 1 FROM public.inspection_results r WHERE r.inspection_id = p_inspection_id AND r.item_id = i.id)
  LIMIT 1;
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Integrity violation: missing result for item "%".', v_missing;
  END IF;

  SELECT r.item_id INTO v_foreign FROM public.inspection_results r
  JOIN public.checklist_items ci ON ci.id = r.item_id
  WHERE r.inspection_id = p_inspection_id AND ci.template_id <> v_inspection.template_id
  LIMIT 1;
  IF v_foreign IS NOT NULL THEN
    RAISE EXCEPTION 'Integrity violation: foreign item "%" in results.', v_foreign;
  END IF;

  SELECT COUNT(*) INTO v_pending FROM public.inspection_results
  WHERE inspection_id = p_inspection_id AND result_status = 'Pending';
  IF v_pending > 0 THEN
    RAISE EXCEPTION 'Validation failure: % question(s) unanswered.', v_pending;
  END IF;

  -- Metrics
  SELECT COUNT(*),
    COUNT(*) FILTER (WHERE result_status = 'Pass'),
    COUNT(*) FILTER (WHERE result_status = 'Fail')
  INTO v_total, v_passed, v_failed
  FROM public.inspection_results WHERE inspection_id = p_inspection_id;

  v_scored := v_passed + v_failed;
  v_score := CASE WHEN v_scored > 0 THEN ROUND((v_passed::NUMERIC / v_scored) * 100.0, 2) ELSE NULL END;

  UPDATE public.inspections
  SET status = 'In Review',
      total_items = v_total, passed_items = v_passed, failed_items = v_failed,
      score = v_score,
      summary_notes = COALESCE(p_summary_notes, summary_notes),
      conducted_at = pg_catalog.now()
  WHERE id = p_inspection_id RETURNING * INTO v_inspection;

  RETURN to_jsonb(v_inspection);
END;
$$;

-- 9.5 REOPEN INSPECTION ATOMIC
CREATE OR REPLACE FUNCTION public.reopen_inspection_atomic(
  p_inspection_id UUID, p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inspection public.inspections%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Access denied: Unauthenticated.'; END IF;
  IF NOT public.is_active_user() THEN RAISE EXCEPTION 'Access denied: User inactive.'; END IF;
  IF NOT public.is_active_role(ARRAY['Lead Auditor','Quality Manager','Super Admin']) THEN
    RAISE EXCEPTION 'Access denied: Only management can reopen inspections.';
  END IF;
  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RAISE EXCEPTION 'Validation error: Reopen reason is required.';
  END IF;

  SELECT * INTO v_inspection FROM public.inspections WHERE id = p_inspection_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not found.'; END IF;

  IF v_inspection.status <> 'In Review' THEN
    RAISE EXCEPTION 'Workflow violation: Cannot reopen "%" (status "%", expected "In Review").', v_inspection.inspection_code, v_inspection.status;
  END IF;

  UPDATE public.inspections
  SET status = 'In Progress',
      summary_notes = COALESCE(summary_notes || E'\n', '') || '[Reopened]: ' || TRIM(p_reason)
  WHERE id = p_inspection_id RETURNING * INTO v_inspection;

  RETURN to_jsonb(v_inspection);
END;
$$;

-- 9.6 FINALIZE INSPECTION ATOMIC
CREATE OR REPLACE FUNCTION public.finalize_inspection_atomic(
  p_inspection_id UUID,
  p_final_status TEXT,
  p_summary_notes TEXT DEFAULT NULL,
  p_digital_signature_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inspection public.inspections%ROWTYPE;
  v_expected INT; v_actual INT; v_pending INT; v_critical_failures INT;
  v_total INT; v_passed INT; v_failed INT; v_scored INT;
  v_score NUMERIC(5,2);
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Access denied: Unauthenticated.'; END IF;
  IF NOT public.is_active_user() THEN RAISE EXCEPTION 'Access denied: User inactive.'; END IF;
  IF NOT public.is_active_role(ARRAY['Lead Auditor','Quality Manager','Super Admin']) THEN
    RAISE EXCEPTION 'Access denied: Only management can finalize inspections.';
  END IF;
  IF p_final_status NOT IN ('Passed', 'Failed', 'CAPA Required') THEN
    RAISE EXCEPTION 'Validation error: Invalid final status "%".', p_final_status;
  END IF;

  SELECT * INTO v_inspection FROM public.inspections WHERE id = p_inspection_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not found.'; END IF;

  IF v_inspection.status <> 'In Review' THEN
    RAISE EXCEPTION 'Workflow violation: Cannot finalize "%" (status "%", expected "In Review").', v_inspection.inspection_code, v_inspection.status;
  END IF;

  -- Bijective checks
  SELECT COUNT(*) INTO v_expected FROM public.checklist_items WHERE template_id = v_inspection.template_id;
  SELECT COUNT(*) INTO v_actual FROM public.inspection_results WHERE inspection_id = p_inspection_id;
  IF v_actual <> v_expected THEN RAISE EXCEPTION 'Integrity violation: result count mismatch.'; END IF;

  SELECT COUNT(*) INTO v_pending FROM public.inspection_results
  WHERE inspection_id = p_inspection_id AND result_status = 'Pending';
  IF v_pending > 0 THEN RAISE EXCEPTION 'Validation failure: % question(s) unanswered.', v_pending; END IF;

  SELECT COUNT(*) INTO v_critical_failures FROM public.inspection_results r
  JOIN public.checklist_items i ON i.id = r.item_id
  WHERE r.inspection_id = p_inspection_id AND i.is_critical = true AND r.result_status = 'Fail';

  SELECT COUNT(*),
    COUNT(*) FILTER (WHERE result_status = 'Pass'),
    COUNT(*) FILTER (WHERE result_status = 'Fail')
  INTO v_total, v_passed, v_failed
  FROM public.inspection_results WHERE inspection_id = p_inspection_id;

  v_scored := v_passed + v_failed;
  v_score := CASE WHEN v_scored > 0 THEN ROUND((v_passed::NUMERIC / v_scored) * 100.0, 2) ELSE NULL END;

  IF p_final_status = 'Passed' THEN
    IF v_score IS NULL THEN
      RAISE EXCEPTION 'Approval rejected: No scored responses. Cannot approve with NULL score.';
    END IF;
    IF v_score < 85.0 THEN
      RAISE EXCEPTION 'Approval rejected: Score % is below 85% threshold.', v_score;
    END IF;
    IF v_critical_failures > 0 THEN
      RAISE EXCEPTION 'Approval rejected: % critical failure(s).', v_critical_failures;
    END IF;
  END IF;

  UPDATE public.inspections
  SET status = p_final_status,
      total_items = v_total, passed_items = v_passed, failed_items = v_failed,
      score = v_score,
      summary_notes = COALESCE(p_summary_notes, summary_notes),
      digital_signature_url = COALESCE(p_digital_signature_url, digital_signature_url),
      conducted_at = COALESCE(conducted_at, pg_catalog.now())
  WHERE id = p_inspection_id RETURNING * INTO v_inspection;

  RETURN to_jsonb(v_inspection);
END;
$$;

-- 9.7 REPAIR INSPECTION RESULTS ATOMIC
CREATE OR REPLACE FUNCTION public.repair_inspection_results_atomic(p_inspection_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inspection public.inspections%ROWTYPE;
  v_inserted INT := 0; v_deleted INT := 0;
  v_total INT; v_passed INT; v_failed INT; v_scored INT;
  v_score NUMERIC(5,2);
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Access denied: Unauthenticated.'; END IF;
  IF NOT public.is_active_user() THEN RAISE EXCEPTION 'Access denied: User inactive.'; END IF;
  IF NOT public.is_active_role(ARRAY['Lead Auditor','Quality Manager','Super Admin']) THEN
    RAISE EXCEPTION 'Access denied: Only management can execute recovery.';
  END IF;

  SELECT * INTO v_inspection FROM public.inspections WHERE id = p_inspection_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not found.'; END IF;

  IF v_inspection.status IN ('Passed', 'Failed', 'CAPA Required') THEN
    RAISE EXCEPTION 'Integrity violation: sealed inspection cannot undergo recovery.';
  END IF;

  WITH ins AS (
    INSERT INTO public.inspection_results (inspection_id, item_id, result_status, photo_evidence_urls, is_deviation)
    SELECT p_inspection_id, i.id, 'Pending', '{}'::TEXT[], false
    FROM public.checklist_items i
    WHERE i.template_id = v_inspection.template_id
      AND NOT EXISTS (SELECT 1 FROM public.inspection_results r WHERE r.inspection_id = p_inspection_id AND r.item_id = i.id)
    RETURNING id
  )
  SELECT COUNT(*) INTO v_inserted FROM ins;

  WITH del AS (
    DELETE FROM public.inspection_results
    WHERE inspection_id = p_inspection_id
      AND item_id NOT IN (SELECT id FROM public.checklist_items WHERE template_id = v_inspection.template_id)
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted FROM del;

  SELECT COUNT(*),
    COUNT(*) FILTER (WHERE result_status = 'Pass'),
    COUNT(*) FILTER (WHERE result_status = 'Fail')
  INTO v_total, v_passed, v_failed
  FROM public.inspection_results WHERE inspection_id = p_inspection_id;

  v_scored := v_passed + v_failed;
  v_score := CASE WHEN v_scored > 0 THEN ROUND((v_passed::NUMERIC / v_scored) * 100.0, 2) ELSE NULL END;

  UPDATE public.inspections
  SET total_items = v_total, passed_items = v_passed, failed_items = v_failed, score = v_score
  WHERE id = p_inspection_id RETURNING * INTO v_inspection;

  RETURN jsonb_build_object(
    'inspection', to_jsonb(v_inspection),
    'inserted', v_inserted,
    'deleted', v_deleted
  );
END;
$$;

-- Permissions
DO $$
DECLARE
  v_fn TEXT;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'create_inspection_atomic',
    'start_inspection_atomic',
    'sync_inspection_metrics_atomic',
    'submit_inspection_atomic',
    'reopen_inspection_atomic',
    'finalize_inspection_atomic',
    'repair_inspection_results_atomic'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%s FROM PUBLIC, anon', v_fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated, service_role', v_fn);
  END LOOP;
END $$;

COMMIT;
