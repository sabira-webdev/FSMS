-- ==============================================================================
-- FSMS: Employee Data Migration & Seeding to Supabase
-- Target Table: public.employees
-- Schema: id (UUID), employee_id (TEXT, EMP-XXXX), department_id (UUID)
-- Department Relationship: UUID resolved via JOIN on public.departments.name
-- Duplicate Handling: WHERE NOT EXISTS on employee_id and email
-- ==============================================================================

INSERT INTO public.employees (
  employee_id,
  name,
  first_name,
  last_name,
  email,
  phone,
  department_id,
  position,
  employment_type,
  status,
  shift,
  joined_date,
  training_status,
  training_completion_date,
  training_expiry_date,
  medical_fitness_status,
  medical_certificate_expiry_date,
  certifications,
  medical_clearance,
  avatar_gradient
)
SELECT
  emp.employee_id,
  emp.name,
  emp.first_name,
  emp.last_name,
  emp.email,
  emp.phone,
  d.id AS department_id,
  emp.position,
  emp.employment_type,
  emp.status,
  emp.shift,
  emp.joined_date::DATE,
  emp.training_status,
  emp.training_completion_date::DATE,
  emp.training_expiry_date::DATE,
  emp.medical_fitness_status,
  emp.medical_certificate_expiry_date::DATE,
  emp.certifications,
  emp.medical_clearance,
  emp.avatar_gradient
FROM (
  VALUES
    (
      'EMP-1042', 'Jabir P k', 'Sarah', 'Jenkins', 'jabirapk@fsms-org', '+1 (555) 234-5678',
      'Quality Assurance', 'Head of QA & Lead Auditor', 'Full-Time', 'Active', 'Morning (Shift A)',
      '2022-03-15', 'Completed / Certified', '2025-11-10', '2026-11-10',
      'Fit / Cleared for Food Handling', '2026-12-31',
      ARRAY['ISO 22000 Lead Auditor', 'HACCP Level 4', 'BRCGS Professional']::TEXT[],
      'Cleared (Valid until Dec 2026)', 'from-emerald-600 to-teal-500'
    ),
    (
      'EMP-1043', 'David Kumar', 'David', 'Kumar', 'd.kumar@fsms-enterprise.org', '+1 (555) 345-6789',
      'Cold Chain Operations', 'CCP Chiller Operations Lead', 'Full-Time', 'Active', 'Morning (Shift A)',
      '2023-01-10', 'Completed / Certified', '2025-10-15', '2026-10-15',
      'Fit / Cleared for Food Handling', '2026-11-30',
      ARRAY['HACCP Level 3', 'Refrigerant & Cold Chain Compliance']::TEXT[],
      'Cleared (Valid until Nov 2026)', 'from-blue-600 to-cyan-500'
    ),
    (
      'EMP-1044', 'Elena Rostova', 'Elena', 'Rostova', 'e.rostova@fsms-enterprise.org', '+1 (555) 456-7890',
      'Food Safety Lab', 'Lead Microbiologist', 'Full-Time', 'Active', 'Morning (Shift A)',
      '2021-08-20', 'Completed / Certified', '2026-01-12', '2027-01-12',
      'Fit / Cleared for Food Handling', '2027-01-20',
      ARRAY['Microbial Pathogen Testing', 'ISO 17025 Lab Standard']::TEXT[],
      'Cleared (Valid until Jan 2027)', 'from-purple-600 to-indigo-500'
    ),
    (
      'EMP-1045', 'Marcus Chen', 'Marcus', 'Chen', 'm.chen@fsms-enterprise.org', '+1 (555) 567-8901',
      'Sanitation & Hygiene', 'CIP Sanitation Supervisor', 'Full-Time', 'Pending Training', 'Night (Shift C)',
      '2023-09-01', 'Scheduled', NULL, '2026-09-01',
      'Fit / Cleared for Food Handling', '2026-10-15',
      ARRAY['Chemical Safety & CIP Systems', 'Food Contact Sanitation']::TEXT[],
      'Cleared (Valid until Oct 2026)', 'from-amber-600 to-orange-500'
    ),
    (
      'EMP-1046', 'Amira Patel', 'Amira', 'Patel', 'a.patel@fsms-enterprise.org', '+1 (555) 678-9012',
      'Production Line A', 'Line Quality Inspector', 'Full-Time', 'Active', 'Evening (Shift B)',
      '2024-02-15', 'Completed / Certified', '2026-02-10', '2027-02-10',
      'Fit / Cleared for Food Handling', '2027-03-01',
      ARRAY['GMP Good Manufacturing Practices', 'Allergen Control']::TEXT[],
      'Cleared (Valid until Mar 2027)', 'from-rose-600 to-pink-500'
    ),
    (
      'EMP-1047', 'James Wilson', 'James', 'Wilson', 'j.wilson@fsms-enterprise.org', '+1 (555) 789-0123',
      'Warehouse & Receiving', 'Raw Material Intake Officer', 'Full-Time', 'Active', 'Morning (Shift A)',
      '2022-11-05', 'Completed / Certified', '2025-08-14', '2026-08-14',
      'Fit / Cleared for Food Handling', '2026-08-30',
      ARRAY['Traceability & Lot Control', 'HACCP Prerequisite Programs']::TEXT[],
      'Cleared (Valid until Aug 2026)', 'from-teal-600 to-emerald-500'
    ),
    (
      'EMP-1048', 'Carlos Mendez', 'Carlos', 'Mendez', 'c.mendez@fsms-enterprise.org', '+1 (555) 890-1234',
      'Production Line B', 'Thermal Process Specialist', 'Full-Time', 'On Leave', 'Evening (Shift B)',
      '2023-05-18', 'Completed / Certified', '2025-05-10', '2026-05-10',
      'Fit / Cleared for Food Handling', '2027-05-15',
      ARRAY['Thermal Processing & Pasteurization', 'HACCP Level 3']::TEXT[],
      'Cleared (Valid until May 2027)', 'from-slate-600 to-slate-800'
    ),
    (
      'EMP-1049', 'Fatima Al-Mansoor', 'Fatima', 'Al-Mansoor', 'f.almansoor@fsms-enterprise.org', '+1 (555) 901-2345',
      'Quality Assurance', 'Supplier Quality Auditor', 'Full-Time', 'Active', 'Morning (Shift A)',
      '2023-10-12', 'Completed / Certified', '2025-09-20', '2026-09-20',
      'Fit / Cleared for Food Handling', '2026-09-30',
      ARRAY['GFSI Benchmark Standards', 'FSVP Compliance']::TEXT[],
      'Cleared (Valid until Sep 2026)', 'from-violet-600 to-purple-500'
    ),
    (
      'EMP-1050', 'Thomas Wright', 'Thomas', 'Wright', 't.wright@fsms-enterprise.org', '+1 (555) 012-3456',
      'Sanitation & Hygiene', 'Environmental Monitoring Tech', 'Full-Time', 'Medical Review', 'Night (Shift C)',
      '2024-04-01', 'In Progress', NULL, NULL,
      'Pending Examination', NULL,
      ARRAY['ATP Swabbing & Environmental Sampling']::TEXT[],
      'Pending Annual Health Examination', 'from-yellow-600 to-amber-500'
    )
) AS emp(
  employee_id, name, first_name, last_name, email, phone,
  department_name, position, employment_type, status, shift,
  joined_date, training_status, training_completion_date, training_expiry_date,
  medical_fitness_status, medical_certificate_expiry_date,
  certifications, medical_clearance, avatar_gradient
)
JOIN public.departments d ON d.name = emp.department_name
WHERE NOT EXISTS (
  SELECT 1 FROM public.employees e 
  WHERE e.employee_id = emp.employee_id OR e.email = emp.email
);

-- Verify migration result
SELECT 
  e.employee_id,
  e.name,
  e.email,
  d.name AS department_name,
  e.position,
  e.status,
  e.training_status,
  e.medical_fitness_status
FROM public.employees e
LEFT JOIN public.departments d ON d.id = e.department_id
ORDER BY e.employee_id ASC;

