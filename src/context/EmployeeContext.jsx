import React, { createContext, useContext, useState, useEffect } from 'react'

const STORAGE_KEY = 'fsms_employees_data'

export const INITIAL_EMPLOYEES = [
  {
    id: 'EMP-1042',
    name: 'Dr. Sarah Jenkins',
    firstName: 'Sarah',
    lastName: 'Jenkins',
    department: 'Quality Assurance',
    position: 'Head of QA & Lead Auditor',
    employmentType: 'Full-Time',
    email: 's.jenkins@fsms-enterprise.org',
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

const EmployeeContext = createContext(null)

export function EmployeeProvider({ children }) {
  const [employees, setEmployees] = useState(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY)
      if (saved) {
        const parsed = JSON.parse(saved)
        if (Array.isArray(parsed) && parsed.length > 0) {
          return parsed
        }
      }
    } catch {
      // Fallback
    }
    return INITIAL_EMPLOYEES
  })

  const [notification, setNotification] = useState(null)

  // Persist to localStorage
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(employees))
    } catch {
      // Ignore
    }
  }, [employees])

  // Add Employee
  const addEmployee = (employeeData) => {
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

    const newEmployee = {
      ...employeeData,
      name: employeeData.name || `${employeeData.firstName} ${employeeData.lastName}`.trim(),
      avatarGradient: employeeData.avatarGradient || randomGradient,
    }

    setEmployees((prev) => [newEmployee, ...prev])
    setNotification({
      type: 'success',
      title: 'Employee Registered',
      text: `Successfully added ${newEmployee.name} (${newEmployee.id}) to the personnel roster.`,
    })

    return newEmployee
  }

  // Update Employee
  const updateEmployee = (id, updatedData) => {
    setEmployees((prev) =>
      prev.map((emp) =>
        emp.id === id
          ? {
              ...emp,
              ...updatedData,
              name: updatedData.name || `${updatedData.firstName || emp.firstName} ${updatedData.lastName || emp.lastName}`.trim(),
            }
          : emp
      )
    )
    setNotification({
      type: 'success',
      title: 'Record Updated',
      text: `Employee record for "${updatedData.name || id}" was successfully updated.`,
    })
  }

  // Delete Employee
  const deleteEmployee = (id) => {
    const target = employees.find((e) => e.id === id)
    setEmployees((prev) => prev.filter((emp) => emp.id !== id))
    setNotification({
      type: 'info',
      title: 'Employee Archived',
      text: `Employee "${target?.name || id}" was removed from the active roster.`,
    })
  }

  // Helper to clear notification
  const clearNotification = () => setNotification(null)

  return (
    <EmployeeContext.Provider
      value={{
        employees,
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
