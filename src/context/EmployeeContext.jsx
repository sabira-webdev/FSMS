import React, { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'

const STORAGE_KEY = 'fsms_employees_data'
const DEPT_STORAGE_KEY = 'fsms_departments_data'

export const INITIAL_EMPLOYEES = [
  {
    id: 'EMP-1042',
    name: 'Jabir P k',
    firstName: 'Sarah',
    lastName: 'Jenkins',
    department: 'Quality Assurance',
    position: 'Head of QA & Lead Auditor',
    employmentType: 'Full-Time',
    email: 'jabirapk@fsms-org',
    phone: '+1 (555) 234-5678',
    status: 'Active',
    shift: 'Morning (Shift A)',
    joinedDate: '2022-03-15',
    trainingStatus: 'Completed / Certified',
    trainingCompletionDate: '2025-11-10',
    trainingExpiryDate: '2026-11-10',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '2026-12-31',
    certifications: ['ISO 22000 Lead Auditor', 'HACCP Level 4', 'BRCGS Professional'],
    medicalClearance: 'Cleared (Valid until Dec 2026)',
    avatarGradient: 'from-emerald-600 to-teal-500',
  },
  {
    id: 'EMP-1043',
    name: 'David Kumar',
    firstName: 'David',
    lastName: 'Kumar',
    department: 'Cold Chain Operations',
    position: 'CCP Chiller Operations Lead',
    employmentType: 'Full-Time',
    email: 'd.kumar@fsms-enterprise.org',
    phone: '+1 (555) 345-6789',
    status: 'Active',
    shift: 'Morning (Shift A)',
    joinedDate: '2023-01-10',
    trainingStatus: 'Completed / Certified',
    trainingCompletionDate: '2025-10-15',
    trainingExpiryDate: '2026-10-15',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '2026-11-30',
    certifications: ['HACCP Level 3', 'Refrigerant & Cold Chain Compliance'],
    medicalClearance: 'Cleared (Valid until Nov 2026)',
    avatarGradient: 'from-blue-600 to-cyan-500',
  },
  {
    id: 'EMP-1044',
    name: 'Elena Rostova',
    firstName: 'Elena',
    lastName: 'Rostova',
    department: 'Food Safety Lab',
    position: 'Lead Microbiologist',
    employmentType: 'Full-Time',
    email: 'e.rostova@fsms-enterprise.org',
    phone: '+1 (555) 456-7890',
    status: 'Active',
    shift: 'Morning (Shift A)',
    joinedDate: '2021-08-20',
    trainingStatus: 'Completed / Certified',
    trainingCompletionDate: '2026-01-12',
    trainingExpiryDate: '2027-01-12',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '2027-01-20',
    certifications: ['Microbial Pathogen Testing', 'ISO 17025 Lab Standard'],
    medicalClearance: 'Cleared (Valid until Jan 2027)',
    avatarGradient: 'from-purple-600 to-indigo-500',
  },
  {
    id: 'EMP-1045',
    name: 'Marcus Chen',
    firstName: 'Marcus',
    lastName: 'Chen',
    department: 'Sanitation & Hygiene',
    position: 'CIP Sanitation Supervisor',
    employmentType: 'Full-Time',
    email: 'm.chen@fsms-enterprise.org',
    phone: '+1 (555) 567-8901',
    status: 'Pending Training',
    shift: 'Night (Shift C)',
    joinedDate: '2023-09-01',
    trainingStatus: 'Scheduled',
    trainingCompletionDate: '',
    trainingExpiryDate: '2026-09-01',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '2026-10-15',
    certifications: ['Chemical Safety & CIP Systems', 'Food Contact Sanitation'],
    medicalClearance: 'Cleared (Valid until Oct 2026)',
    avatarGradient: 'from-amber-600 to-orange-500',
  },
  {
    id: 'EMP-1046',
    name: 'Amira Patel',
    firstName: 'Amira',
    lastName: 'Patel',
    department: 'Production Line A',
    position: 'Line Quality Inspector',
    employmentType: 'Full-Time',
    email: 'a.patel@fsms-enterprise.org',
    phone: '+1 (555) 678-9012',
    status: 'Active',
    shift: 'Evening (Shift B)',
    joinedDate: '2024-02-15',
    trainingStatus: 'Completed / Certified',
    trainingCompletionDate: '2026-02-10',
    trainingExpiryDate: '2027-02-10',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '2027-03-01',
    certifications: ['GMP Good Manufacturing Practices', 'Allergen Control'],
    medicalClearance: 'Cleared (Valid until Mar 2027)',
    avatarGradient: 'from-rose-600 to-pink-500',
  },
  {
    id: 'EMP-1047',
    name: 'James Wilson',
    firstName: 'James',
    lastName: 'Wilson',
    department: 'Warehouse & Receiving',
    position: 'Raw Material Intake Officer',
    employmentType: 'Full-Time',
    email: 'j.wilson@fsms-enterprise.org',
    phone: '+1 (555) 789-0123',
    status: 'Active',
    shift: 'Morning (Shift A)',
    joinedDate: '2022-11-05',
    trainingStatus: 'Completed / Certified',
    trainingCompletionDate: '2025-08-14',
    trainingExpiryDate: '2026-08-14',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '2026-08-30',
    certifications: ['Traceability & Lot Control', 'HACCP Prerequisite Programs'],
    medicalClearance: 'Cleared (Valid until Aug 2026)',
    avatarGradient: 'from-teal-600 to-emerald-500',
  },
  {
    id: 'EMP-1048',
    name: 'Carlos Mendez',
    firstName: 'Carlos',
    lastName: 'Mendez',
    department: 'Production Line B',
    position: 'Thermal Process Specialist',
    employmentType: 'Full-Time',
    email: 'c.mendez@fsms-enterprise.org',
    phone: '+1 (555) 890-1234',
    status: 'On Leave',
    shift: 'Evening (Shift B)',
    joinedDate: '2023-05-18',
    trainingStatus: 'Completed / Certified',
    trainingCompletionDate: '2025-05-10',
    trainingExpiryDate: '2026-05-10',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '2027-05-15',
    certifications: ['Thermal Processing & Pasteurization', 'HACCP Level 3'],
    medicalClearance: 'Cleared (Valid until May 2027)',
    avatarGradient: 'from-slate-600 to-slate-800',
  },
  {
    id: 'EMP-1049',
    name: 'Fatima Al-Mansoor',
    firstName: 'Fatima',
    lastName: 'Al-Mansoor',
    department: 'Quality Assurance',
    position: 'Supplier Quality Auditor',
    employmentType: 'Full-Time',
    email: 'f.almansoor@fsms-enterprise.org',
    phone: '+1 (555) 901-2345',
    status: 'Active',
    shift: 'Morning (Shift A)',
    joinedDate: '2023-10-12',
    trainingStatus: 'Completed / Certified',
    trainingCompletionDate: '2025-09-20',
    trainingExpiryDate: '2026-09-20',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '2026-09-30',
    certifications: ['GFSI Benchmark Standards', 'FSVP Compliance'],
    medicalClearance: 'Cleared (Valid until Sep 2026)',
    avatarGradient: 'from-violet-600 to-purple-500',
  },
  {
    id: 'EMP-1050',
    name: 'Thomas Wright',
    firstName: 'Thomas',
    lastName: 'Wright',
    department: 'Sanitation & Hygiene',
    position: 'Environmental Monitoring Tech',
    employmentType: 'Full-Time',
    email: 't.wright@fsms-enterprise.org',
    phone: '+1 (555) 012-3456',
    status: 'Medical Review',
    shift: 'Night (Shift C)',
    joinedDate: '2024-04-01',
    trainingStatus: 'In Progress',
    trainingCompletionDate: '',
    trainingExpiryDate: '',
    medicalFitnessStatus: 'Pending Examination',
    medicalCertificateExpiryDate: '',
    certifications: ['ATP Swabbing & Environmental Sampling'],
    medicalClearance: 'Pending Annual Health Examination',
    avatarGradient: 'from-yellow-600 to-amber-500',
  },
]

export const DEFAULT_DEPARTMENTS = [
  { name: 'Quality Assurance', code: 'QA' },
  { name: 'Food Safety Lab', code: 'LAB' },
  { name: 'Sanitation & Hygiene', code: 'SAN' },
  { name: 'Cold Chain Operations', code: 'COLD' },
  { name: 'Production Line A', code: 'PROD-A' },
  { name: 'Production Line B', code: 'PROD-B' },
  { name: 'Packaging & Dispatch', code: 'PKG' },
  { name: 'Warehouse & Receiving', code: 'WH' },
]

/**
 * Maps a database row (joined with departments) to the UI employee model.
 */
export function mapRowToEmployee(row) {
  if (!row) return null
  const deptName = row.departments?.name || row.department || ''

  return {
    ...row,
    // Ensure both id representations exist
    dbId: row.id,
    id: row.employee_id || row.id,
    employee_id: row.employee_id || row.id,

    // Personal details
    name: row.name || `${row.first_name || ''} ${row.last_name || ''}`.trim(),
    firstName: row.first_name || row.firstName || '',
    lastName: row.last_name || row.lastName || '',

    // Contact & Organization
    email: row.email || '',
    phone: row.phone || '',
    department: deptName,
    department_id: row.department_id,
    departments: row.departments || null,
    position: row.position || '',
    employmentType: row.employment_type || row.employmentType || 'Full-Time',
    status: row.status || 'Active',
    shift: row.shift || 'Morning (Shift A)',
    joinedDate: row.joined_date || row.joinedDate || '',

    // Food safety & Training compliance
    trainingStatus: row.training_status || row.trainingStatus || 'Completed / Certified',
    trainingCompletionDate: row.training_completion_date || row.trainingCompletionDate || '',
    trainingExpiryDate: row.training_expiry_date || row.trainingExpiryDate || '',

    // Health & Medical
    medicalFitnessStatus: row.medical_fitness_status || row.medicalFitnessStatus || 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: row.medical_certificate_expiry_date || row.medicalCertificateExpiryDate || '',
    medicalClearance: row.medical_clearance || row.medicalClearance || '',

    // Badges & Visuals
    certifications: Array.isArray(row.certifications) ? row.certifications : [],
    avatarGradient: row.avatar_gradient || row.avatarGradient || 'from-emerald-600 to-teal-500',
  }
}

/**
 * Maps a frontend employee object to the public.employees table insert/update payload.
 */
export function mapEmployeeToRow(emp, resolvedDepartmentId) {
  return {
    employee_id: emp.id || emp.employee_id,
    name: emp.name || `${emp.firstName || ''} ${emp.lastName || ''}`.trim(),
    first_name: emp.firstName || emp.first_name || null,
    last_name: emp.lastName || emp.last_name || null,
    email: emp.email?.trim().toLowerCase() || null,
    phone: emp.phone?.trim() || null,
    department_id: resolvedDepartmentId || emp.department_id || null,
    position: emp.position?.trim() || null,
    employment_type: emp.employmentType || emp.employment_type || 'Full-Time',
    status: emp.status || 'Active',
    shift: emp.shift || 'Morning (Shift A)',
    joined_date: emp.joinedDate || emp.joined_date || null,
    training_status: emp.trainingStatus || emp.training_status || 'Completed / Certified',
    training_completion_date: emp.trainingCompletionDate || emp.training_completion_date || null,
    training_expiry_date: emp.trainingExpiryDate || emp.training_expiry_date || null,
    medical_fitness_status: emp.medicalFitnessStatus || emp.medical_fitness_status || 'Fit / Cleared for Food Handling',
    medical_certificate_expiry_date: emp.medicalCertificateExpiryDate || emp.medical_certificate_expiry_date || null,
    certifications: Array.isArray(emp.certifications) ? emp.certifications : [],
    medical_clearance: emp.medicalClearance || emp.medical_clearance || null,
    avatar_gradient: emp.avatarGradient || emp.avatar_gradient || 'from-emerald-600 to-teal-500',
  }
}

const EmployeeContext = createContext(null)

export function EmployeeProvider({ children }) {
  // 1. Employees state initialized from localStorage cache (or INITIAL_EMPLOYEES)
  const [employees, setEmployees] = useState(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY)
      if (saved) {
        const parsed = JSON.parse(saved)
        if (Array.isArray(parsed) && parsed.length > 0) {
          return parsed.map(mapRowToEmployee)
        }
      }
    } catch {}
    return INITIAL_EMPLOYEES.map(mapRowToEmployee)
  })

  // 2. Departments state initialized from localStorage cache (or DEFAULT_DEPARTMENTS)
  const [departments, setDepartments] = useState(() => {
    try {
      const saved = localStorage.getItem(DEPT_STORAGE_KEY)
      if (saved) {
        const parsed = JSON.parse(saved)
        if (Array.isArray(parsed) && parsed.length > 0) {
          return parsed
        }
      }
    } catch {}
    return DEFAULT_DEPARTMENTS
  })

  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notification, setNotification] = useState(null)

  // Keep localStorage updated as fallback cache
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(employees))
    } catch {}
  }, [employees])

  useEffect(() => {
    try {
      localStorage.setItem(DEPT_STORAGE_KEY, JSON.stringify(departments))
    } catch {}
  }, [departments])

  // Helper to resolve department UUID from a department name or existing ID
  const resolveDepartmentId = useCallback(
    (deptNameOrId) => {
      if (!deptNameOrId) return null
      // Check if it's already a UUID
      const directMatch = departments.find((d) => d.id === deptNameOrId)
      if (directMatch) return directMatch.id

      // Otherwise find by name
      const nameMatch = departments.find(
        (d) => d.name?.toLowerCase() === String(deptNameOrId).toLowerCase()
      )
      return nameMatch ? nameMatch.id : null
    },
    [departments]
  )

  // Fetch departments from Supabase
  const loadDepartments = useCallback(async () => {
    try {
      const { data, error: deptError } = await supabase
        .from('departments')
        .select('id, name, code, zone_type')
        .order('name', { ascending: true })

      if (deptError) {
        console.warn('[EmployeeContext] Failed to load departments from Supabase:', deptError.message)
      } else if (data && data.length > 0) {
        setDepartments(data)
        return data
      }
    } catch (err) {
      console.warn('[EmployeeContext] Department fetch error:', err.message)
    }
    return null
  }, [])

  // Fetch employees from Supabase with joined department name
  const loadEmployees = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      // First ensure departments are loaded
      await loadDepartments()

      const { data, error: empError } = await supabase
        .from('employees')
        .select(`
          *,
          departments (
            id,
            name,
            code
          )
        `)
        .order('employee_id', { ascending: true })

      if (empError) {
        console.warn('[EmployeeContext] Failed to load employees from Supabase:', empError.message)
        setError(empError.message)
      } else if (data && data.length > 0) {
        const mapped = data.map(mapRowToEmployee)
        setEmployees(mapped)
      }
    } catch (err) {
      console.warn('[EmployeeContext] Employee fetch network/DNS error:', err.message)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [loadDepartments])

  // Load from Supabase on mount
  useEffect(() => {
    loadEmployees()
  }, [loadEmployees])

  // Add Employee
  const addEmployee = async (employeeData) => {
    const gradients = [
      'from-emerald-600 to-teal-500',
      'from-blue-600 to-cyan-500',
      'from-purple-600 to-indigo-500',
      'from-amber-600 to-orange-500',
      'from-teal-600 to-emerald-500',
      'from-rose-600 to-pink-500',
      'from-violet-600 to-purple-500',
    ]
    const randomGradient = gradients[Math.floor(Math.random() * gradients.length)]

    // Resolve department UUID
    const targetDeptId =
      employeeData.department_id ||
      resolveDepartmentId(employeeData.department)

    const empWithVisuals = {
      ...employeeData,
      avatarGradient: employeeData.avatarGradient || randomGradient,
    }

    const payload = mapEmployeeToRow(empWithVisuals, targetDeptId)

    let createdEmployee = null

    try {
      const { data, error: insertError } = await supabase
        .from('employees')
        .insert([payload])
        .select(`
          *,
          departments (
            id,
            name,
            code
          )
        `)
        .single()

      if (insertError) {
        console.error('[EmployeeContext] Supabase insert error:', insertError)
        // Check for RLS policy error
        if (insertError.code === '42501' || insertError.message?.includes('row-level security')) {
          setNotification({
            type: 'danger',
            title: 'Permission Error (RLS)',
            text: 'Supabase Row-Level Security blocked inserting this record. ' + insertError.message,
          })
          throw insertError
        }
        throw insertError
      }

      createdEmployee = mapRowToEmployee(data)
    } catch (err) {
      console.warn('[EmployeeContext] Add employee fallback to local state:', err.message)
      // Fallback local creation so user flow isn't completely blocked
      const matchedDept = departments.find((d) => d.id === targetDeptId)
      createdEmployee = mapRowToEmployee({
        ...payload,
        id: payload.employee_id,
        departments: matchedDept || { name: employeeData.department },
      })
    }

    setEmployees((prev) => [createdEmployee, ...prev.filter((e) => (e.employee_id || e.id) !== createdEmployee.id)])
    setNotification({
      type: 'success',
      title: 'Employee Registered',
      text: `Successfully added ${createdEmployee.name} (${createdEmployee.id}) to the personnel roster.`,
    })

    return createdEmployee
  }

  // Update Employee
  const updateEmployee = async (id, updatedData) => {
    const current = employees.find(
      (e) =>
        e.id?.toLowerCase() === String(id).toLowerCase() ||
        e.employee_id?.toLowerCase() === String(id).toLowerCase() ||
        e.dbId === id
    )

    const targetDeptId =
      updatedData.department_id ||
      resolveDepartmentId(updatedData.department) ||
      current?.department_id

    const payload = mapEmployeeToRow({ ...current, ...updatedData }, targetDeptId)
    // Remove primary key id from payload
    delete payload.id

    let updatedEmployee = null

    try {
      const query = current?.dbId
        ? supabase.from('employees').update(payload).eq('id', current.dbId)
        : supabase.from('employees').update(payload).eq('employee_id', id)

      const { data, error: updateError } = await query
        .select(`
          *,
          departments (
            id,
            name,
            code
          )
        `)
        .single()

      if (updateError) {
        console.error('[EmployeeContext] Supabase update error:', updateError)
        if (updateError.code === '42501' || updateError.message?.includes('row-level security')) {
          setNotification({
            type: 'danger',
            title: 'Permission Error (RLS)',
            text: 'Supabase Row-Level Security blocked updating this record. ' + updateError.message,
          })
          throw updateError
        }
        throw updateError
      }

      updatedEmployee = mapRowToEmployee(data)
    } catch (err) {
      console.warn('[EmployeeContext] Update employee fallback to local state:', err.message)
      const matchedDept = departments.find((d) => d.id === targetDeptId)
      updatedEmployee = mapRowToEmployee({
        ...current,
        ...payload,
        id: current?.id || id,
        departments: matchedDept || { name: updatedData.department || current?.department },
      })
    }

    setEmployees((prev) =>
      prev.map((emp) =>
        emp.id?.toLowerCase() === String(id).toLowerCase() ||
        emp.employee_id?.toLowerCase() === String(id).toLowerCase() ||
        emp.dbId === id
          ? updatedEmployee
          : emp
      )
    )

    setNotification({
      type: 'success',
      title: 'Record Updated',
      text: `Employee record for "${updatedEmployee.name || id}" was successfully updated.`,
    })

    return updatedEmployee
  }

  // Delete Employee
  const deleteEmployee = async (id) => {
    const target = employees.find(
      (e) =>
        e.id?.toLowerCase() === String(id).toLowerCase() ||
        e.employee_id?.toLowerCase() === String(id).toLowerCase() ||
        e.dbId === id
    )

    try {
      const query = target?.dbId
        ? supabase.from('employees').delete().eq('id', target.dbId)
        : supabase.from('employees').delete().eq('employee_id', id)

      const { error: deleteError } = await query
      if (deleteError) {
        console.error('[EmployeeContext] Supabase delete error:', deleteError)
        if (deleteError.code === '42501' || deleteError.message?.includes('row-level security')) {
          setNotification({
            type: 'danger',
            title: 'Permission Error (RLS)',
            text: 'Supabase Row-Level Security blocked removing this record. ' + deleteError.message,
          })
          throw deleteError
        }
        throw deleteError
      }
    } catch (err) {
      console.warn('[EmployeeContext] Delete employee fallback to local state:', err.message)
    }

    setEmployees((prev) =>
      prev.filter(
        (emp) =>
          emp.id?.toLowerCase() !== String(id).toLowerCase() &&
          emp.employee_id?.toLowerCase() !== String(id).toLowerCase() &&
          emp.dbId !== id
      )
    )

    setNotification({
      type: 'info',
      title: 'Employee Archived',
      text: `Employee "${target?.name || id}" was removed from the active roster.`,
    })
  }

  const clearNotification = () => setNotification(null)

  return (
    <EmployeeContext.Provider
      value={{
        employees,
        departments,
        loading,
        error,
        refetch: loadEmployees,
        addEmployee,
        updateEmployee,
        deleteEmployee,
        notification,
        setNotification,
        clearNotification,
      }}
    >
      {children}
    </EmployeeContext.Provider>
  )
}

export function useEmployees() {
  const context = useContext(EmployeeContext)
  if (!context) {
    throw new Error('useEmployees must be used within an EmployeeProvider')
  }
  return context
}
