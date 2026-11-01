import { supabase } from '../lib/supabase'

/**
 * Valid zone types permitted by the public.departments schema constraint:
 * CHECK (zone_type IN ('Low Care', 'Medium Care', 'High Care', 'High Risk', 'Non-Food Contact'))
 */
export const ZONE_TYPES = [
  {
    value: 'High Risk',
    label: 'High Risk',
    badgeVariant: 'danger',
    description: 'Ready-to-eat food handling with strict pathogen barrier controls.',
  },
  {
    value: 'High Care',
    label: 'High Care',
    badgeVariant: 'warning',
    description: 'Chilled sensitive products requiring segregation and strict hygiene.',
  },
  {
    value: 'Medium Care',
    label: 'Medium Care',
    badgeVariant: 'success',
    description: 'Primary processing, cooking, mixing, and thermal operations.',
  },
  {
    value: 'Low Care',
    label: 'Low Care',
    badgeVariant: 'info',
    description: 'Raw material intake, warehousing, dry ambient goods, and dispatch.',
  },
  {
    value: 'Non-Food Contact',
    label: 'Non-Food Contact',
    badgeVariant: 'neutral',
    description: 'Facility maintenance, microbiology labs, and quality offices.',
  },
]

/**
 * Translates PostgreSQL and Supabase errors into human-readable enterprise notifications.
 */
export function formatDepartmentError(error) {
  if (!error) return 'An unknown error occurred.'

  const code = error.code || ''
  const message = error.message || ''

  // Row-Level Security permission violation
  if (code === '42501' || message.includes('row-level security') || message.includes('violates row-level security policy')) {
    return 'Permission Denied: Your account role does not have authorization to modify departments. Row-Level Security (RLS) requires an active Super Admin or Quality Manager profile.'
  }

  // Unique constraint violation (duplicate name or code)
  if (code === '23505' || message.includes('unique constraint') || message.includes('duplicate key')) {
    if (message.includes('code') || message.includes('departments_code_key')) {
      return 'Department Code already in use. Each facility department must have a unique code identifier.'
    }
    if (message.includes('name') || message.includes('departments_name_key')) {
      return 'Department Name already exists. Please choose a unique name for this facility department.'
    }
    return 'A department with this name or code already exists in the system.'
  }

  // Foreign key constraint violation (e.g. deletion prevented)
  if (code === '23503' || message.includes('foreign key constraint')) {
    return 'Action Blocked: This department is referenced by active employees, audits, or CAPA records and cannot be deleted or disconnected (ON DELETE RESTRICT).'
  }

  // Check constraint violation
  if (code === '23514' || message.includes('check constraint')) {
    return 'Validation Error: One or more fields violate the database constraint (e.g. invalid zone_type).'
  }

  return message || 'Database request failed. Please check your network connection.'
}

/**
 * Fetches all departments from public.departments along with real employee counts from public.employees.
 * Does NOT use mock data or localStorage.
 */
export async function fetchDepartmentsWithEmployeeCounts() {
  // 1. Fetch departments
  const { data: departments, error: deptError } = await supabase
    .from('departments')
    .select('id, name, code, zone_type, description, created_at, updated_at')
    .order('name', { ascending: true })

  if (deptError) {
    throw new Error(formatDepartmentError(deptError))
  }

  // 2. Fetch employee records to compute real-time employee counts per department
  const { data: employees, error: empError } = await supabase
    .from('employees')
    .select('id, department_id, status')

  // Build employee count aggregation
  const countMap = {}
  const activeCountMap = {}

  if (!empError && Array.isArray(employees)) {
    for (const emp of employees) {
      if (!emp.department_id) continue
      countMap[emp.department_id] = (countMap[emp.department_id] || 0) + 1
      if (emp.status === 'Active') {
        activeCountMap[emp.department_id] = (activeCountMap[emp.department_id] || 0) + 1
      }
    }
  }

  // 3. Attach computed counts to department objects
  return (departments || []).map((dept) => ({
    ...dept,
    employeeCount: countMap[dept.id] || 0,
    activeEmployeeCount: activeCountMap[dept.id] || 0,
  }))
}

/**
 * Inserts a new department into Supabase public.departments.
 */
export async function createDepartment({ name, code, zone_type, description }) {
  const cleanName = (name || '').trim()
  const cleanCode = (code || '').trim().toUpperCase()
  const cleanZoneType = (zone_type || 'Medium Care').trim()
  const cleanDesc = (description || '').trim() || null

  if (!cleanName || cleanName.length < 2) {
    throw new Error('Department name must be at least 2 characters long.')
  }
  if (!cleanCode || cleanCode.length < 2 || cleanCode.length > 10) {
    throw new Error('Department code must be between 2 and 10 characters long.')
  }

  const { data, error } = await supabase
    .from('departments')
    .insert([
      {
        name: cleanName,
        code: cleanCode,
        zone_type: cleanZoneType,
        description: cleanDesc,
      },
    ])
    .select('id, name, code, zone_type, description, created_at, updated_at')
    .single()

  if (error) {
    throw new Error(formatDepartmentError(error))
  }

  return {
    ...data,
    employeeCount: 0,
    activeEmployeeCount: 0,
  }
}

/**
 * Updates an existing department in Supabase public.departments.
 */
export async function updateDepartment(id, { name, code, zone_type, description }) {
  if (!id) {
    throw new Error('Department ID is required for updating.')
  }

  const cleanName = (name || '').trim()
  const cleanCode = (code || '').trim().toUpperCase()
  const cleanZoneType = (zone_type || 'Medium Care').trim()
  const cleanDesc = (description || '').trim() || null

  if (!cleanName || cleanName.length < 2) {
    throw new Error('Department name must be at least 2 characters long.')
  }
  if (!cleanCode || cleanCode.length < 2 || cleanCode.length > 10) {
    throw new Error('Department code must be between 2 and 10 characters long.')
  }

  const { data, error } = await supabase
    .from('departments')
    .update({
      name: cleanName,
      code: cleanCode,
      zone_type: cleanZoneType,
      description: cleanDesc,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)
    .select('id, name, code, zone_type, description, created_at, updated_at')
    .single()

  if (error) {
    throw new Error(formatDepartmentError(error))
  }

  return data
}
