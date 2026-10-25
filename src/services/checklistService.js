import { supabase } from '../lib/supabase'

/**
 * Valid checklist categories enforced by public.checklist_templates:
 * CHECK (category IN ('Sanitation', 'HACCP Prerequisite', 'Thermal CCP', 'GMP Audit', 'Allergen Control', 'Receiving'))
 */
export const CHECKLIST_CATEGORIES = [
  {
    value: 'Sanitation',
    label: 'Sanitation',
    badgeVariant: 'info',
    badgeColor: 'bg-sky-50 text-sky-700 border-sky-200',
    iconColor: 'text-sky-600 bg-sky-50 border-sky-100',
    description: 'Pre-operational hygiene, SSOPs, chemical sanitizer titration, and ATP swabbing.',
  },
  {
    value: 'HACCP Prerequisite',
    label: 'HACCP Prerequisite',
    badgeVariant: 'purple',
    badgeColor: 'bg-purple-50 text-purple-700 border-purple-200',
    iconColor: 'text-purple-600 bg-purple-50 border-purple-100',
    description: 'Good manufacturing practices (GMP), pest control, water potability, and maintenance prerequisites.',
  },
  {
    value: 'Thermal CCP',
    label: 'Thermal CCP',
    badgeVariant: 'danger',
    badgeColor: 'bg-rose-50 text-rose-700 border-rose-200',
    iconColor: 'text-rose-600 bg-rose-50 border-rose-100',
    description: 'Critical Control Points: blast chilling, cooking core temperature, and pasteurization logging.',
  },
  {
    value: 'GMP Audit',
    label: 'GMP Audit',
    badgeVariant: 'success',
    badgeColor: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    iconColor: 'text-emerald-600 bg-emerald-50 border-emerald-100',
    description: 'Personnel hygiene, glove usage, jewelry policy, hairnets, and structural facility audits.',
  },
  {
    value: 'Allergen Control',
    label: 'Allergen Control',
    badgeVariant: 'warning',
    badgeColor: 'bg-amber-50 text-amber-700 border-amber-200',
    iconColor: 'text-amber-600 bg-amber-50 border-amber-100',
    description: 'Line clearance, protein residue swab tests, dedicated tool segregation, and label verification.',
  },
  {
    value: 'Receiving',
    label: 'Receiving',
    badgeVariant: 'neutral',
    badgeColor: 'bg-slate-100 text-slate-700 border-slate-200',
    iconColor: 'text-slate-600 bg-slate-100 border-slate-200',
    description: 'Inbound trailer inspection, security seals, raw material receiving temperatures, and COA matching.',
  },
]

/**
 * Valid response types enforced by public.checklist_items:
 * CHECK (response_type IN ('pass_fail', 'numeric', 'text', 'multiple_choice'))
 */
export const RESPONSE_TYPES = [
  { value: 'pass_fail', label: 'Pass / Fail', description: 'Binary compliance verification (Compliant / Non-Compliant)' },
  { value: 'numeric', label: 'Numeric Reading', description: 'Quantitative measurement with min/max range limits and unit' },
  { value: 'multiple_choice', label: 'Multiple Choice', description: 'Selectable set of predefined observation options' },
  { value: 'text', label: 'Text / Notes', description: 'Free-form descriptive notation or audit sign-off' },
]

/**
 * Translates PostgreSQL and PostgREST errors into clean enterprise notifications.
 */
export function formatChecklistError(error) {
  if (!error) return 'An unexpected error occurred.'

  const code = error.code || ''
  const message = error.message || ''

  // Row-Level Security permission violation
  if (code === '42501' || message.includes('row-level security') || message.includes('violates row-level security policy')) {
    return 'Permission Denied: Your account role does not have authorization to manage checklist templates. Row-Level Security requires an active Super Admin, Quality Manager, or Lead Auditor profile.'
  }

  // Unique constraint violation (duplicate template code or item_key)
  if (code === '23505' || message.includes('unique constraint') || message.includes('duplicate key')) {
    if (message.includes('code') || message.includes('checklist_templates_code_key')) {
      return 'Checklist Code in Use: Each checklist template must have a unique code identifier (e.g. CHK-SAN-002).'
    }
    if (message.includes('item_key') || message.includes('checklist_items_item_key_key')) {
      return 'Question Key in Use: A question with this item key already exists in the system.'
    }
    return 'A checklist record with this unique identifier already exists in the database.'
  }

  // Foreign key constraint violation
  if (code === '23503' || message.includes('foreign key constraint')) {
    return 'Action Blocked: Referenced department or parent template was not found, or template is locked by operational inspection records.'
  }

  // Check constraint violation
  if (code === '23514' || message.includes('check constraint')) {
    if (message.includes('category')) {
      return 'Validation Error: Invalid category. Must be one of Sanitation, HACCP Prerequisite, Thermal CCP, GMP Audit, Allergen Control, or Receiving.'
    }
    if (message.includes('response_type')) {
      return 'Validation Error: Invalid response type. Must be pass_fail, numeric, multiple_choice, or text.'
    }
    return 'Validation Error: One or more fields violate database validation constraints.'
  }

  return message || 'Database request failed. Please check your network connection.'
}

/**
 * Fetches all checklist templates with department associations and computed question counts.
 * Pure Supabase query; never uses mock data or localStorage.
 */
export async function fetchChecklistTemplates() {
  // 1. Fetch templates with department details
  const { data: templates, error: tplError } = await supabase
    .from('checklist_templates')
    .select(`
      id,
      code,
      title,
      description,
      department_id,
      category,
      version,
      is_active,
      created_by,
      metadata,
      created_at,
      updated_at,
      departments:department_id (id, name, code)
    `)
    .order('code', { ascending: true })

  if (tplError) {
    throw new Error(formatChecklistError(tplError))
  }

  // 2. Fetch all checklist items to calculate real-time item counts and critical flags
  const { data: items, error: itemError } = await supabase
    .from('checklist_items')
    .select('id, template_id, is_critical')

  const countMap = {}
  const criticalMap = {}

  if (!itemError && Array.isArray(items)) {
    for (const item of items) {
      if (!item.template_id) continue
      countMap[item.template_id] = (countMap[item.template_id] || 0) + 1
      if (item.is_critical) {
        criticalMap[item.template_id] = (criticalMap[item.template_id] || 0) + 1
      }
    }
  }

  return (templates || []).map((tpl) => ({
    ...tpl,
    department_name: tpl.departments?.name || 'Unassigned',
    department_code: tpl.departments?.code || null,
    itemCount: countMap[tpl.id] || 0,
    criticalItemCount: criticalMap[tpl.id] || 0,
  }))
}

/**
 * Fetches a single checklist template along with all its ordered questions.
 */
export async function fetchChecklistWithItems(templateId) {
  if (!templateId) throw new Error('Template ID is required.')

  const { data: template, error: tplError } = await supabase
    .from('checklist_templates')
    .select(`
      id,
      code,
      title,
      description,
      department_id,
      category,
      version,
      is_active,
      created_by,
      metadata,
      created_at,
      updated_at,
      departments:department_id (id, name, code)
    `)
    .eq('id', templateId)
    .single()

  if (tplError) {
    throw new Error(formatChecklistError(tplError))
  }

  const { data: items, error: itemError } = await supabase
    .from('checklist_items')
    .select('*')
    .eq('template_id', templateId)
    .order('item_order', { ascending: true })

  if (itemError) {
    throw new Error(formatChecklistError(itemError))
  }

  return {
    ...template,
    department_name: template.departments?.name || 'Unassigned',
    department_code: template.departments?.code || null,
    items: items || [],
  }
}

/**
 * Creates a new checklist template and optionally inserts starter questions.
 */
export async function createChecklistTemplate(templateData, questions = []) {
  const cleanCode = (templateData.code || '').trim().toUpperCase()
  const cleanTitle = (templateData.title || '').trim()
  const cleanCategory = (templateData.category || 'Sanitation').trim()
  const cleanDesc = (templateData.description || '').trim() || null
  const deptId = templateData.department_id || null
  const version = parseInt(templateData.version, 10) || 1
  const isActive = templateData.is_active !== false

  if (!cleanCode || cleanCode.length < 3) {
    throw new Error('Checklist code must be at least 3 characters (e.g. CHK-SAN-002).')
  }
  if (!cleanTitle || cleanTitle.length < 3) {
    throw new Error('Checklist title must be at least 3 characters long.')
  }

  const metadata = {
    frequency: templateData.frequency || 'Daily',
    estimated_minutes: parseInt(templateData.estimated_minutes, 10) || 15,
  }

  // Insert template
  const { data: newTemplate, error: tplError } = await supabase
    .from('checklist_templates')
    .insert([
      {
        code: cleanCode,
        title: cleanTitle,
        description: cleanDesc,
        department_id: deptId,
        category: cleanCategory,
        version,
        is_active: isActive,
        metadata,
      },
    ])
    .select('id, code, title, description, department_id, category, version, is_active, metadata, created_at, updated_at')
    .single()

  if (tplError) {
    throw new Error(formatChecklistError(tplError))
  }

  // Insert questions if provided
  if (Array.isArray(questions) && questions.length > 0) {
    const formattedQuestions = questions.map((q, idx) => ({
      template_id: newTemplate.id,
      item_key: q.item_key || `${cleanCode}-Q${idx + 1}-${Date.now().toString().slice(-4)}`,
      item_order: idx + 1,
      section_title: (q.section_title || 'General Inspection').trim(),
      question: (q.question || '').trim(),
      instruction: (q.instruction || '').trim() || null,
      response_type: q.response_type || 'pass_fail',
      is_critical: Boolean(q.is_critical),
      min_value: q.response_type === 'numeric' && q.min_value !== '' && q.min_value !== null ? parseFloat(q.min_value) : null,
      max_value: q.response_type === 'numeric' && q.max_value !== '' && q.max_value !== null ? parseFloat(q.max_value) : null,
      unit: q.response_type === 'numeric' ? (q.unit || '').trim() || null : null,
      options: q.response_type === 'multiple_choice' && Array.isArray(q.options) ? q.options : [],
    }))

    const { error: itemError } = await supabase
      .from('checklist_items')
      .insert(formattedQuestions)

    if (itemError) {
      console.warn('[checklistService] Error inserting questions for new template:', itemError.message)
      throw new Error(`Template was created, but questions failed to save: ${formatChecklistError(itemError)}`)
    }
  }

  return newTemplate
}

/**
 * Updates an existing checklist template's header metadata.
 */
export async function updateChecklistTemplate(templateId, templateData) {
  if (!templateId) throw new Error('Template ID is required.')

  const cleanTitle = (templateData.title || '').trim()
  const cleanCategory = (templateData.category || 'Sanitation').trim()
  const cleanDesc = (templateData.description || '').trim() || null
  const deptId = templateData.department_id || null
  const version = parseInt(templateData.version, 10) || 1

  if (!cleanTitle || cleanTitle.length < 3) {
    throw new Error('Checklist title must be at least 3 characters long.')
  }

  const payload = {
    title: cleanTitle,
    description: cleanDesc,
    department_id: deptId,
    category: cleanCategory,
    version,
    updated_at: new Date().toISOString(),
  }

  if (templateData.frequency || templateData.estimated_minutes !== undefined) {
    payload.metadata = {
      ...(templateData.metadata || {}),
      frequency: templateData.frequency || templateData.metadata?.frequency || 'Daily',
      estimated_minutes: parseInt(templateData.estimated_minutes, 10) || templateData.metadata?.estimated_minutes || 15,
    }
  }

  const { data, error } = await supabase
    .from('checklist_templates')
    .update(payload)
    .eq('id', templateId)
    .select('id, code, title, description, department_id, category, version, is_active, metadata, created_at, updated_at')
    .single()

  if (error) {
    throw new Error(formatChecklistError(error))
  }

  return data
}

/**
 * Toggles a template's active state (Soft-deactivation).
 * Preserves all audit trails and inspection references.
 */
export async function toggleChecklistStatus(templateId, currentActiveStatus) {
  if (!templateId) throw new Error('Template ID is required.')

  const { data, error } = await supabase
    .from('checklist_templates')
    .update({
      is_active: !currentActiveStatus,
      updated_at: new Date().toISOString(),
    })
    .eq('id', templateId)
    .select('id, code, title, is_active, updated_at')
    .single()

  if (error) {
    throw new Error(formatChecklistError(error))
  }

  return data
}

/**
 * Saves (replaces/syncs) the set of questions for an existing template.
 */
export async function syncChecklistQuestions(templateId, templateCode, questions = []) {
  if (!templateId) throw new Error('Template ID is required.')

  // 1. Delete existing questions for this template
  const { error: delError } = await supabase
    .from('checklist_items')
    .delete()
    .eq('template_id', templateId)

  if (delError) {
    throw new Error(`Failed to update questions: ${formatChecklistError(delError)}`)
  }

  // 2. Insert new questions
  if (Array.isArray(questions) && questions.length > 0) {
    const formattedQuestions = questions.map((q, idx) => ({
      template_id: templateId,
      item_key: q.item_key || `${templateCode}-Q${idx + 1}-${Date.now().toString().slice(-4)}`,
      item_order: idx + 1,
      section_title: (q.section_title || 'General Inspection').trim(),
      question: (q.question || '').trim(),
      instruction: (q.instruction || '').trim() || null,
      response_type: q.response_type || 'pass_fail',
      is_critical: Boolean(q.is_critical),
      min_value: q.response_type === 'numeric' && q.min_value !== '' && q.min_value !== null ? parseFloat(q.min_value) : null,
      max_value: q.response_type === 'numeric' && q.max_value !== '' && q.max_value !== null ? parseFloat(q.max_value) : null,
      unit: q.response_type === 'numeric' ? (q.unit || '').trim() || null : null,
      options: q.response_type === 'multiple_choice' && Array.isArray(q.options) ? q.options : [],
    }))

    const { data, error: insError } = await supabase
      .from('checklist_items')
      .insert(formattedQuestions)
      .select('*')

    if (insError) {
      throw new Error(`Failed to insert questions: ${formatChecklistError(insError)}`)
    }

    return data
  }

  return []
}

/**
 * Fetches departments for the checklist department picker dropdown.
 */
export async function fetchDepartmentsList() {
  const { data, error } = await supabase
    .from('departments')
    .select('id, name, code')
    .order('name', { ascending: true })

  if (error) {
    console.warn('[checklistService] Could not fetch departments list:', error.message)
    return []
  }

  return data || []
}
