import { createClient } from '@supabase/supabase-js'

const url = process.env.VITE_SUPABASE_URL
const key = process.env.VITE_SUPABASE_PUBLISHABLE_KEY

if (!url || !key) {
  console.error('Error: VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY is missing in environment.')
  process.exit(1)
}

const supabase = createClient(url, key)

const INITIAL_EMPLOYEES = [
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
    trainingCompletionDate: null,
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
    trainingCompletionDate: null,
    trainingExpiryDate: null,
    medicalFitnessStatus: 'Pending Examination',
    medicalCertificateExpiryDate: null,
    certifications: ['ATP Swabbing & Environmental Sampling'],
    medicalClearance: 'Pending Annual Health Examination',
    avatarGradient: 'from-yellow-600 to-amber-500',
  },
]

async function seedEmployees() {
  console.log('--- Supabase Employee Data Migration ---')

  // 1. Fetch departments from Supabase
  console.log('Step 1: Fetching departments from public.departments...')
  const { data: departments, error: deptError } = await supabase
    .from('departments')
    .select('id, name')

  if (deptError) {
    console.error('Failed to query departments table:', deptError.message)
    process.exit(1)
  }

  if (!departments || departments.length === 0) {
    console.error('No departments found in public.departments table. Please seed departments first.')
    process.exit(1)
  }

  console.log(`Found ${departments.length} departments in Supabase:`)
  const deptMap = {}
  for (const dept of departments) {
    deptMap[dept.name] = dept.id
    console.log(`  - "${dept.name}" -> ${dept.id}`)
  }

  // 2. Verify all employee departments exist in public.departments
  console.log('\nStep 2: Validating employee department mappings...')
  for (const emp of INITIAL_EMPLOYEES) {
    if (!deptMap[emp.department]) {
      console.error(`Validation Error: Employee ${emp.id} (${emp.name}) department "${emp.department}" does not match any existing department in Supabase!`)
      process.exit(1)
    }
  }
  console.log('✓ All 9 employee records match valid existing departments in Supabase.')

  // 3. Inspect existing employees table structure and existing records
  console.log('\nStep 3: Checking existing employees in public.employees...')
  const { data: existingEmployees, error: checkError } = await supabase
    .from('employees')
    .select('*')

  if (checkError) {
    console.error('Failed to query employees table:', checkError.message)
    process.exit(1)
  }

  console.log(`Currently found ${existingEmployees.length} records in employees table.`)

  // Detect column naming style (snake_case vs camelCase, and employee_id vs id)
  let usesEmployeeIdCol = false
  let usesSnakeCase = true

  if (existingEmployees.length > 0) {
    const keys = Object.keys(existingEmployees[0])
    usesEmployeeIdCol = keys.includes('employee_id')
    usesSnakeCase = keys.includes('first_name') || keys.includes('department_id')
  }

  // Set of existing IDs to prevent duplicates
  const existingIds = new Set(
    existingEmployees.map((e) => e.employee_id || e.id || e.employeeId)
  )

  // 4. Map records for insertion
  console.log('\nStep 4: Mapping 9 employee records...')
  const recordsToInsert = []

  for (const emp of INITIAL_EMPLOYEES) {
    if (existingIds.has(emp.id)) {
      console.log(`  - Skipping ${emp.id} (${emp.name}): Record already exists in Supabase.`)
      continue
    }

    const deptId = deptMap[emp.department]

    // Construct record (supporting both standard snake_case schema)
    const record = {
      name: emp.name,
      first_name: emp.firstName,
      last_name: emp.lastName,
      email: emp.email,
      phone: emp.phone,
      department_id: deptId,
      position: emp.position,
      employment_type: emp.employmentType,
      status: emp.status,
      shift: emp.shift,
      joined_date: emp.joinedDate,
      training_status: emp.trainingStatus,
      training_completion_date: emp.trainingCompletionDate || null,
      training_expiry_date: emp.trainingExpiryDate || null,
      medical_fitness_status: emp.medicalFitnessStatus,
      medical_certificate_expiry_date: emp.medicalCertificateExpiryDate || null,
      certifications: emp.certifications,
      medical_clearance: emp.medicalClearance,
      avatar_gradient: emp.avatarGradient,
    }

    if (usesEmployeeIdCol) {
      record.employee_id = emp.id
    } else {
      record.id = emp.id
    }

    recordsToInsert.push(record)
  }

  if (recordsToInsert.length === 0) {
    console.log('\nAll 9 employees already exist in Supabase. Nothing to insert.')
    return
  }

  console.log(`\nStep 5: Inserting ${recordsToInsert.length} new records into public.employees...`)
  const { data: inserted, error: insertError } = await supabase
    .from('employees')
    .insert(recordsToInsert)
    .select()

  if (insertError) {
    // If insert failed due to column naming, attempt with employee_id alternate
    console.warn('Initial insert attempt message:', insertError.message)
    console.log('Attempting insert with fallback column configuration...')

    const fallbackRecords = recordsToInsert.map((r) => {
      const copy = { ...r }
      if (copy.id && !copy.employee_id) {
        copy.employee_id = copy.id
        delete copy.id
      }
      return copy
    })

    const { data: fallbackInserted, error: fallbackError } = await supabase
      .from('employees')
      .insert(fallbackRecords)
      .select()

    if (fallbackError) {
      console.error('Insert failed:', fallbackError.message)
      process.exit(1)
    }

    console.log(`✓ Successfully inserted ${fallbackInserted.length} employee records!`)
  } else {
    console.log(`✓ Successfully inserted ${inserted.length} employee records!`)
  }

  // 6. Final verification
  console.log('\nStep 6: Verifying total count in public.employees...')
  const { data: finalEmployees, error: finalError } = await supabase
    .from('employees')
    .select('id, employee_id, name, department_id, email, position')

  if (finalError) {
    console.error('Verification query failed:', finalError.message)
  } else {
    console.log(`Total employees in Supabase now: ${finalEmployees.length}`)
    console.table(
      finalEmployees.map((e) => ({
        ID: e.employee_id || e.id,
        Name: e.name,
        Position: e.position,
        Email: e.email,
        DepartmentID: e.department_id,
      }))
    )
  }

  console.log('\n--- Migration Finished Successfully ---')
}

seedEmployees().catch((err) => {
  console.error('Unexpected migration error:', err)
  process.exit(1)
})
