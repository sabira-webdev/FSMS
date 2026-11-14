import { supabase } from '../lib/supabase'

// ---------------------------------------------------------------------------
// 1. CONSTANTS
// ---------------------------------------------------------------------------

export const INSPECTION_STATUSES = [
  { value: 'Draft', label: 'Draft', badgeVariant: 'neutral', isMutable: true },
  { value: 'In Progress', label: 'In Progress', badgeVariant: 'info', isMutable: true },
  { value: 'In Review', label: 'In Review', badgeVariant: 'warning', isMutable: true },
  { value: 'Passed', label: 'Passed', badgeVariant: 'success', isMutable: false },
  { value: 'CAPA Required', label: 'CAPA Required', badgeVariant: 'danger', isMutable: false },
  { value: 'Failed', label: 'Failed', badgeVariant: 'danger', isMutable: false },
]

export const RESULT_STATUSES = [
  { value: 'Pass', label: 'Pass', badgeVariant: 'success' },
  { value: 'Fail', label: 'Fail', badgeVariant: 'danger' },
  { value: 'N/A', label: 'N/A', badgeVariant: 'neutral' },
  { value: 'Pending', label: 'Pending', badgeVariant: 'warning' },
]

export const OPERATING_SHIFTS = [
  'Morning (Shift A)',
  'Afternoon (Shift B)',
  'Night (Shift C)',
]

export const MANAGEMENT_ROLES = ['Super Admin', 'Quality Manager', 'Lead Auditor']

export const PASSING_SCORE_THRESHOLD = 85.0

// ---------------------------------------------------------------------------
// 2. ERROR TRANSLATION
// ---------------------------------------------------------------------------

export function formatInspectionError(error) {
  if (!error) return 'An unexpected error occurred.'
  const code = error.code || ''
  const message = error.message || ''

  if (code === '42P01' || message.includes('does not exist')) {
    return 'Database Infrastructure Pending: Inspection tables have not been provisioned. Please apply the inspections migration.'
  }
  if (code === '42501' || message.includes('row-level security')) {
    return 'Permission Denied: Your role does not have authorization for this action.'
  }
  if (message.includes('Audit integrity violation') || message.includes('permanently sealed')) {
    return message
  }
  if (message.includes('Privilege violation')) {
    return message
  }
  if (message.includes('Workflow violation')) {
    return message
  }
  if (message.includes('Configuration error')) {
    return message
  }
  if (message.includes('Validation error') || message.includes('Validation failure')) {
    return message
  }
  if (message.includes('Integrity violation')) {
    return message
  }
  if (code === '23505') {
    if (message.includes('inspection_code')) {
      return 'Inspection Code in Use: An inspection with this code already exists.'
    }
    if (message.includes('uq_inspection_results_item')) {
      return 'Duplicate Response: A result for this question already exists.'
    }
    return 'Unique constraint violation.'
  }
  if (code === '23503') {
    return 'Referenced entity not found.'
  }

  return message || 'Database request failed.'
}

// ---------------------------------------------------------------------------
// 3. STRICT NUMERIC PARSER
// ---------------------------------------------------------------------------

/**
 * Parses a value as a strict finite number. Rejects trailing characters,
 * empty strings, Infinity, NaN. Mirrors PostgreSQL NUMERIC casting.
 */
function parseStrictNumeric(val) {
  if (val === null || val === undefined) return null
  if (typeof val === 'number') {
    return Number.isFinite(val) ? val : null
  }
  const str = String(val).trim()
  if (str === '') return null
  // Reject anything that is not a valid decimal number
  if (!/^[+-]?(\d+\.?\d*|\.\d+)$/.test(str)) return null
  const num = Number(str)
  return Number.isFinite(num) ? num : null
}

// ---------------------------------------------------------------------------
// 4. SCORING & COMPLIANCE EVALUATION
// ---------------------------------------------------------------------------

/**
 * Evaluates a single checklist item answer. Mirrors the database trigger
 * public.validate_inspection_result_response() for instant UI preview.
 *
 * @param {Object} item  - Checklist item definition (from checklist_items)
 * @param {Object} answer - { result_status, numeric_value, text_value }
 * @returns {{ result_status: string, is_deviation: boolean, feedback: string|null }}
 */
export function evaluateItemResult(item, answer) {
  if (!item || !answer) {
    return { result_status: 'Pending', is_deviation: false, feedback: null }
  }

  const { response_type, min_value, max_value, options } = item
  const { result_status, numeric_value, text_value } = answer

  // Pending / N/A
  if (result_status === 'Pending' || result_status === 'N/A') {
    return {
      result_status,
      is_deviation: false,
      feedback: result_status === 'N/A' ? 'Marked as Not Applicable' : null,
    }
  }

  // Reject unsupported response types
  if (!['pass_fail', 'numeric', 'text', 'multiple_choice'].includes(response_type)) {
    return { result_status: 'Pending', is_deviation: false, feedback: 'Unsupported response type' }
  }

  // Pass / Fail
  if (response_type === 'pass_fail') {
    const raw = String(text_value ?? result_status ?? '').trim().toLowerCase()
    if (['pass', 'passes', 'passed'].includes(raw)) {
      return { result_status: 'Pass', is_deviation: false, feedback: null }
    }
    if (['fail', 'fails', 'failed'].includes(raw)) {
      return { result_status: 'Fail', is_deviation: true, feedback: 'Non-conformance detected' }
    }
    return { result_status: 'Pending', is_deviation: false, feedback: 'Must be Pass or Fail' }
  }

  // Numeric
  if (response_type === 'numeric') {
    const num = parseStrictNumeric(numeric_value)
    if (num === null) {
      return { result_status: 'Pending', is_deviation: false, feedback: 'Valid numeric reading required' }
    }

    const min = parseStrictNumeric(min_value)
    const max = parseStrictNumeric(max_value)

    if (min !== null && num < min) {
      return { result_status: 'Fail', is_deviation: true, feedback: `${num} below minimum ${min}` }
    }
    if (max !== null && num > max) {
      return { result_status: 'Fail', is_deviation: true, feedback: `${num} above maximum ${max}` }
    }
    return { result_status: 'Pass', is_deviation: false, feedback: null }
  }

  // Multiple Choice — structured objects only, no keyword fallback
  if (response_type === 'multiple_choice') {
    const selected = String(text_value ?? '').trim()
    if (!selected) {
      return { result_status: 'Pending', is_deviation: false, feedback: 'Selection required' }
    }

    const optsArray = Array.isArray(options) ? options : []
    if (optsArray.length === 0) {
      return { result_status: 'Pending', is_deviation: false, feedback: 'No options configured' }
    }

    const selectedLower = selected.toLowerCase()
    const matched = optsArray.find((opt) => {
      if (!opt || typeof opt !== 'object') return false
      return (
        String(opt.value ?? '').trim().toLowerCase() === selectedLower ||
        String(opt.label ?? '').trim().toLowerCase() === selectedLower
      )
    })

    if (!matched) {
      return { result_status: 'Pending', is_deviation: false, feedback: 'Selected option not in configured choices' }
    }

    const optStatus = String(matched.status ?? '').trim()
    if (optStatus === 'Pass') {
      return { result_status: 'Pass', is_deviation: false, feedback: null }
    }
    if (optStatus === 'Fail') {
      return { result_status: 'Fail', is_deviation: true, feedback: 'Non-compliant option' }
    }

    return { result_status: 'Pending', is_deviation: false, feedback: 'Option missing Pass/Fail status' }
  }

  // Text
  if (response_type === 'text') {
    const text = String(text_value ?? '').trim()
    if (!text) {
      return { result_status: 'Pending', is_deviation: false, feedback: 'Text response required' }
    }
    return { result_status: 'Pass', is_deviation: false, feedback: null }
  }

  return { result_status: 'Pending', is_deviation: false, feedback: null }
}

/**
 * Calculates aggregate audit metrics for UI display.
 */
export function calculateInspectionScore(results = [], items = []) {
  const itemMap = {}
  for (const it of items) {
    if (it.id) itemMap[it.id] = it
  }

  let passedItems = 0
  let failedItems = 0
  let naItems = 0
  let pendingItems = 0
  let criticalFailures = 0

  for (const it of items) {
    const res = results.find((r) => r.item_id === it.id)
    const st = res?.result_status || 'Pending'
    if (st === 'Pass') passedItems++
    else if (st === 'Fail') {
      failedItems++
      if (it.is_critical) criticalFailures++
    } else if (st === 'N/A') naItems++
    else pendingItems++
  }

  const scoredItems = passedItems + failedItems
  const score = scoredItems > 0 ? parseFloat(((passedItems / scoredItems) * 100).toFixed(2)) : null
  const isAllAnswered = pendingItems === 0 && items.length > 0

  let suggestedStatus = 'In Progress'
  if (isAllAnswered) {
    if (criticalFailures > 0) suggestedStatus = 'CAPA Required'
    else if (score !== null && score >= PASSING_SCORE_THRESHOLD) suggestedStatus = 'Passed'
    else suggestedStatus = 'Failed'
  }

  return {
    score,
    totalItems: items.length,
    passedItems,
    failedItems,
    naItems,
    pendingItems,
    criticalFailures,
    scoredItems,
    isAllAnswered,
    suggestedStatus,
  }
}

// ---------------------------------------------------------------------------
// 5. QUERY OPERATIONS
// ---------------------------------------------------------------------------

export async function fetchInspections(filters = {}) {
  let query = supabase
    .from('inspections')
    .select(`
      id, inspection_code, template_id, department_id, auditor_id,
      scheduled_date, conducted_at, status, score,
      total_items, passed_items, failed_items,
      facility_zone, shift, summary_notes, digital_signature_url,
      created_at, updated_at,
      departments:department_id (id, name, code),
      checklist_templates:template_id (id, code, title, category, version),
      profiles:auditor_id (id, full_name, email, role)
    `, { count: 'exact' })
    .order('scheduled_date', { ascending: false })
    .order('created_at', { ascending: false })

  if (filters.status && filters.status !== 'All Statuses') query = query.eq('status', filters.status)
  if (filters.departmentId && filters.departmentId !== 'All Departments') query = query.eq('department_id', filters.departmentId)
  if (filters.auditorId) query = query.eq('auditor_id', filters.auditorId)
  if (filters.shift && filters.shift !== 'All Shifts') query = query.eq('shift', filters.shift)
  if (filters.dateFrom) query = query.gte('scheduled_date', filters.dateFrom)
  if (filters.dateTo) query = query.lte('scheduled_date', filters.dateTo)
  if (filters.page && filters.pageSize) {
    const from = (filters.page - 1) * filters.pageSize
    query = query.range(from, from + filters.pageSize - 1)
  }

  const { data, error, count } = await query
  if (error) throw new Error(formatInspectionError(error))

  let list = data || []
  if (filters.searchTerm?.trim()) {
    const term = filters.searchTerm.toLowerCase().trim()
    list = list.filter((r) =>
      r.inspection_code?.toLowerCase().includes(term) ||
      r.checklist_templates?.title?.toLowerCase().includes(term) ||
      r.departments?.name?.toLowerCase().includes(term) ||
      r.profiles?.full_name?.toLowerCase().includes(term) ||
      r.summary_notes?.toLowerCase().includes(term)
    )
  }

  return { data: list, count: count || 0, error: null }
}

export async function fetchInspectionById(inspectionId) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  const { data, error } = await supabase
    .from('inspections')
    .select(`
      *,
      departments:department_id (id, name, code),
      checklist_templates:template_id (id, code, title, category, version, description),
      profiles:auditor_id (id, full_name, email, role)
    `)
    .eq('id', inspectionId)
    .single()
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function fetchInspectionResults(inspectionId) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  const { data, error } = await supabase
    .from('inspection_results')
    .select(`
      id, inspection_id, item_id, result_status,
      numeric_value, text_value, comment,
      photo_evidence_urls, is_deviation, created_at,
      checklist_items:item_id (
        id, template_id, item_key, item_order, section_title,
        question, instruction, response_type, is_critical,
        min_value, max_value, unit, options, options_mapped
      )
    `)
    .eq('inspection_id', inspectionId)
  if (error) throw new Error(formatInspectionError(error))
  const results = data || []
  results.sort((a, b) => (a.checklist_items?.item_order ?? 9999) - (b.checklist_items?.item_order ?? 9999))
  return results
}

export async function fetchAuditorProfiles() {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, full_name, email, role, is_active')
    .eq('is_active', true)
    .in('role', ['Inspector', 'Lead Auditor', 'Quality Manager', 'Super Admin'])
    .order('full_name', { ascending: true })
  if (error) throw new Error(formatInspectionError(error))
  return data || []
}

export async function fetchActiveChecklistTemplates(departmentId = null) {
  let query = supabase
    .from('checklist_templates')
    .select('id, code, title, category, department_id, is_active, version, departments:department_id (id, name, code)')
    .eq('is_active', true)
    .order('title', { ascending: true })
  if (departmentId) query = query.or(`department_id.eq.${departmentId},department_id.is.null`)
  const { data, error } = await query
  if (error) throw new Error(formatInspectionError(error))
  return data || []
}

// ---------------------------------------------------------------------------
// 6. MUTATION & WORKFLOW OPERATIONS
// ---------------------------------------------------------------------------

export async function createInspection(payload) {
  if (!payload.template_id) throw new Error('Checklist Template is required.')
  if (!payload.department_id) throw new Error('Department is required.')
  if (!payload.auditor_id) throw new Error('Assigned inspector is required.')

  const { data, error } = await supabase.rpc('create_inspection_atomic', {
    p_template_id: payload.template_id,
    p_department_id: payload.department_id,
    p_auditor_id: payload.auditor_id,
    p_scheduled_date: payload.scheduled_date || new Date().toISOString().split('T')[0],
    p_shift: payload.shift || 'Morning (Shift A)',
    p_facility_zone: payload.facility_zone || null,
    p_summary_notes: payload.summary_notes?.trim() || null,
  })
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function startInspection(inspectionId) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  const { data, error } = await supabase.rpc('start_inspection_atomic', {
    p_inspection_id: inspectionId,
  })
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function updateInspection(inspectionId, updates) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  if (updates?.status) {
    throw new Error('Workflow violation: Direct status update not permitted. Use workflow RPCs.')
  }

  const allowed = ['scheduled_date', 'shift', 'facility_zone', 'summary_notes', 'department_id', 'auditor_id']
  const payload = {}
  allowed.forEach((f) => { if (updates[f] !== undefined) payload[f] = updates[f] })

  if (payload.summary_notes !== undefined) {
    payload.summary_notes = payload.summary_notes?.trim() || null
  }

  const { data, error } = await supabase
    .from('inspections')
    .update(payload)
    .eq('id', inspectionId)
    .select()
    .single()
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function saveInspectionResultItem(inspectionId, itemId, responseData) {
  if (!inspectionId || !itemId) throw new Error('Inspection ID and Item ID are required.')

  const payload = {
    inspection_id: inspectionId,
    item_id: itemId,
    result_status: responseData.result_status || 'Pending',
    numeric_value: parseStrictNumeric(responseData.numeric_value),
    text_value: responseData.text_value !== undefined ? responseData.text_value : null,
    comment: responseData.comment?.trim() || null,
    photo_evidence_urls: Array.isArray(responseData.photo_evidence_urls) ? responseData.photo_evidence_urls : [],
    is_deviation: Boolean(responseData.is_deviation),
  }

  const { data, error } = await supabase
    .from('inspection_results')
    .upsert(payload, { onConflict: 'inspection_id,item_id' })
    .select()
    .single()
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function batchSaveInspectionResults(inspectionId, resultsArray = []) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  if (!Array.isArray(resultsArray) || resultsArray.length === 0) return { savedCount: 0 }

  const CHUNK = 50
  const saved = []
  for (let i = 0; i < resultsArray.length; i += CHUNK) {
    const chunk = resultsArray.slice(i, i + CHUNK).map((r) => ({
      inspection_id: inspectionId,
      item_id: r.item_id,
      result_status: r.result_status || 'Pending',
      numeric_value: parseStrictNumeric(r.numeric_value),
      text_value: r.text_value !== undefined ? r.text_value : null,
      comment: r.comment?.trim() || null,
      photo_evidence_urls: Array.isArray(r.photo_evidence_urls) ? r.photo_evidence_urls : [],
      is_deviation: Boolean(r.is_deviation),
    }))
    const { data, error } = await supabase
      .from('inspection_results')
      .upsert(chunk, { onConflict: 'inspection_id,item_id' })
      .select()
    if (error) throw new Error(formatInspectionError(error))
    if (data) saved.push(...data)
  }
  return { savedCount: saved.length, data: saved }
}

export async function syncInspectionMetrics(inspectionId) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  const { data, error } = await supabase.rpc('sync_inspection_metrics_atomic', {
    p_inspection_id: inspectionId,
  })
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function submitInspectionForReview(inspectionId, options = {}) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  const { data, error } = await supabase.rpc('submit_inspection_atomic', {
    p_inspection_id: inspectionId,
    p_summary_notes: options.summaryNotes || null,
  })
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function reopenInspectionForCorrection(inspectionId, reason) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  if (!reason?.trim()) throw new Error('A reason is required to reopen.')
  const { data, error } = await supabase.rpc('reopen_inspection_atomic', {
    p_inspection_id: inspectionId,
    p_reason: reason.trim(),
  })
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function finalizeInspectionReview(inspectionId, decision) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  if (!decision?.status) throw new Error('Final status is required.')
  const { data, error } = await supabase.rpc('finalize_inspection_atomic', {
    p_inspection_id: inspectionId,
    p_final_status: decision.status,
    p_summary_notes: decision.summaryNotes || null,
    p_digital_signature_url: decision.digitalSignatureUrl || null,
  })
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function repairInspectionResults(inspectionId) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  const { data, error } = await supabase.rpc('repair_inspection_results_atomic', {
    p_inspection_id: inspectionId,
  })
  if (error) throw new Error(formatInspectionError(error))
  return data
}

export async function deleteDraftInspection(inspectionId) {
  if (!inspectionId) throw new Error('Inspection ID is required.')
  const { error } = await supabase
    .from('inspections')
    .delete()
    .eq('id', inspectionId)
    .eq('status', 'Draft')
  if (error) throw new Error(formatInspectionError(error))
  return true
}
