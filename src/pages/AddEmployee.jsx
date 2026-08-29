import React, { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import {
  UserPlus,
  ArrowLeft,
  Save,
  X,
  ShieldCheck,
  Building2,
  Mail,
  Phone,
  Calendar,
  Clock,
  Award,
  Stethoscope,
  Briefcase,
  UserCheck,
  AlertCircle,
  FileCheck,
  ChevronDown,
} from 'lucide-react'
import {
  PageHeader,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
  Button,
  Input,
  Badge,
  Alert,
} from '../components/common'
import { useEmployees } from '../context/EmployeeContext'

const DEPARTMENTS = [
  'Quality Assurance',
  'Food Safety Lab',
  'Sanitation & Hygiene',
  'Cold Chain Operations',
  'Production Line A',
  'Production Line B',
  'Packaging & Dispatch',
  'Warehouse & Receiving',
]

const EMPLOYMENT_TYPES = [
  'Full-Time',
  'Part-Time',
  'Contract',
  'Seasonal',
  'Apprentice',
]

const STATUS_OPTIONS = [
  'Active',
  'Pending Training',
  'On Leave',
  'Medical Review',
]

const SHIFTS = [
  'Morning (Shift A)',
  'Evening (Shift B)',
  'Night (Shift C)',
]

const TRAINING_STATUSES = [
  'Completed / Certified',
  'In Progress',
  'Scheduled',
  'Expired',
  'Not Started',
]

const MEDICAL_FITNESS_STATUSES = [
  'Fit / Cleared for Food Handling',
  'Conditionally Fit',
  'Pending Examination',
  'Unfit / Restricted',
]

const AVAILABLE_CERTIFICATIONS = [
  'ISO 22000 Lead Auditor',
  'HACCP Level 2',
  'HACCP Level 3',
  'HACCP Level 4',
  'BRCGS Professional',
  'GMP Food Safety',
  'Allergen Management',
  'CIP Chemical Safety',
  'Microbial Pathogen Testing',
  'Traceability & Lot Control',
]

export function AddEmployee() {
  const navigate = useNavigate()
  const { employees, addEmployee } = useEmployees()

  // Generate next default ID
  const nextId = `EMP-${1042 + employees.length + 1}`

  // Form State
  const [formData, setFormData] = useState({
    // Basic Information
    id: nextId,
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    joinedDate: new Date().toISOString().split('T')[0],

    // Employment Information
    department: 'Quality Assurance',
    position: '',
    employmentType: 'Full-Time',
    status: 'Active',
    shift: 'Morning (Shift A)',

    // Food Safety & Training Information
    trainingStatus: 'Completed / Certified',
    trainingCompletionDate: '',
    trainingExpiryDate: '',
    medicalFitnessStatus: 'Fit / Cleared for Food Handling',
    medicalCertificateExpiryDate: '',
    certifications: ['GMP Food Safety'],
    customCert: '',
  })

  const [errors, setErrors] = useState({})
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [formAlert, setFormAlert] = useState(null)

  // Handle Input Changes
  const handleChange = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }))
    // Clear error for that field if exists
    if (errors[field]) {
      setErrors((prev) => {
        const next = { ...prev }
        delete next[field]
        return next
      })
    }
  }

  // Toggle Certification
  const handleToggleCert = (cert) => {
    setFormData((prev) => {
      const exists = prev.certifications.includes(cert)
      const updated = exists
        ? prev.certifications.filter((c) => c !== cert)
        : [...prev.certifications, cert]
      return { ...prev, certifications: updated }
    })
  }

  // Add Custom Certification
  const handleAddCustomCert = (e) => {
    e.preventDefault()
    if (formData.customCert.trim()) {
      const newCert = formData.customCert.trim()
      if (!formData.certifications.includes(newCert)) {
        setFormData((prev) => ({
          ...prev,
          certifications: [...prev.certifications, newCert],
          customCert: '',
        }))
      } else {
        setFormData((prev) => ({ ...prev, customCert: '' }))
      }
    }
  }

  // Form Validation
  const validateForm = () => {
    const newErrors = {}

    // Basic Info Validations
    if (!formData.id.trim()) {
      newErrors.id = 'Employee ID is required'
    }
    if (!formData.firstName.trim()) {
      newErrors.firstName = 'First name is required'
    }
    if (!formData.lastName.trim()) {
      newErrors.lastName = 'Last name is required'
    }
    if (!formData.email.trim()) {
      newErrors.email = 'Email address is required'
    } else if (!/\S+@\S+\.\S+/.test(formData.email.trim())) {
      newErrors.email = 'Please provide a valid email address'
    }
    if (!formData.joinedDate) {
      newErrors.joinedDate = 'Date of joining is required'
    }

    // Employment Validations
    if (!formData.position.trim()) {
      newErrors.position = 'Position / Job Title is required'
    }
    if (!formData.department) {
      newErrors.department = 'Department is required'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  // Submit Handler
  const handleSubmit = (e) => {
    e.preventDefault()
    setFormAlert(null)

    if (!validateForm()) {
      setFormAlert({
        type: 'danger',
        message: 'Please resolve the highlighted required fields before saving.',
      })
      // Scroll to top of window
      window.scrollTo({ top: 0, behavior: 'smooth' })
      return
    }

    setIsSubmitting(true)

    try {
      const fullName = `${formData.firstName.trim()} ${formData.lastName.trim()}`
      const medicalClearanceSummary =
        formData.medicalFitnessStatus === 'Fit / Cleared for Food Handling'
          ? `Cleared (Valid until ${formData.medicalCertificateExpiryDate ? new Date(formData.medicalCertificateExpiryDate).toLocaleDateString('en-US', { month: 'short', year: 'numeric' }) : 'Next Audit'})`
          : formData.medicalFitnessStatus

      const newEmployeeData = {
        id: formData.id.trim(),
        name: fullName,
        firstName: formData.firstName.trim(),
        lastName: formData.lastName.trim(),
        email: formData.email.trim().toLowerCase(),
        phone: formData.phone.trim() || '+1 (555) 000-0000',
        joinedDate: formData.joinedDate,
        department: formData.department,
        position: formData.position.trim(),
        employmentType: formData.employmentType,
        status: formData.status,
        shift: formData.shift,
        trainingStatus: formData.trainingStatus,
        trainingCompletionDate: formData.trainingCompletionDate,
        trainingExpiryDate: formData.trainingExpiryDate,
        medicalFitnessStatus: formData.medicalFitnessStatus,
        medicalCertificateExpiryDate: formData.medicalCertificateExpiryDate,
        certifications:
          formData.certifications.length > 0
            ? formData.certifications
            : ['Basic Hygiene & GMP'],
        medicalClearance: medicalClearanceSummary,
      }

      addEmployee(newEmployeeData)

      // Navigate back to employee list
      navigate('/employees')
    } catch (err) {
      setFormAlert({
        type: 'danger',
        message: 'Failed to create employee record. Please try again.',
      })
      setIsSubmitting(false)
    }
  }

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Page Header */}
      <PageHeader
        title="Add New Employee"
        subtitle="Register food safety personnel, assign shifts, and verify hygiene credentials."
        badge={<Badge variant="info" dot size="sm">New Personnel Dossier</Badge>}
        breadcrumbs={[
          { label: 'Home', path: '/' },
          { label: 'Employees', path: '/employees' },
          { label: 'Add Employee' },
        ]}
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              size="sm"
              icon={ArrowLeft}
              onClick={() => navigate('/employees')}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              size="sm"
              icon={Save}
              loading={isSubmitting}
              onClick={handleSubmit}
            >
              Save Employee
            </Button>
          </div>
        }
      />

      {/* Form Alert Feedback */}
      {formAlert && (
        <Alert
          type={formAlert.type}
          title={formAlert.type === 'danger' ? 'Validation Error' : 'Notice'}
          onDismiss={() => setFormAlert(null)}
        >
          {formAlert.message}
        </Alert>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* ========================================================================= */}
        {/* CARD 1: BASIC INFORMATION                                                 */}
        {/* ========================================================================= */}
        <Card>
          <CardHeader>
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded-lg bg-emerald-50 text-emerald-700">
                <UserCheck className="w-5 h-5" />
              </div>
              <div>
                <CardTitle>Basic Information</CardTitle>
                <CardDescription>
                  Personal details, identifier, and contact credentials for the personnel directory.
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Employee ID */}
              <Input
                label="Employee ID"
                value={formData.id}
                onChange={(e) => handleChange('id', e.target.value)}
                error={errors.id}
                placeholder="e.g. EMP-1051"
                required
                helperText="Unique facility identifier code"
              />

              {/* First Name */}
              <Input
                label="First Name"
                value={formData.firstName}
                onChange={(e) => handleChange('firstName', e.target.value)}
                error={errors.firstName}
                placeholder="e.g. Maria"
                required
              />

              {/* Last Name */}
              <Input
                label="Last Name"
                value={formData.lastName}
                onChange={(e) => handleChange('lastName', e.target.value)}
                error={errors.lastName}
                placeholder="e.g. Gonzalez"
                required
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Email Address */}
              <Input
                label="Email Address"
                type="email"
                icon={Mail}
                value={formData.email}
                onChange={(e) => handleChange('email', e.target.value)}
                error={errors.email}
                placeholder="m.gonzalez@fsms-enterprise.org"
                required
              />

              {/* Phone Number */}
              <Input
                label="Phone Number"
                type="tel"
                icon={Phone}
                value={formData.phone}
                onChange={(e) => handleChange('phone', e.target.value)}
                error={errors.phone}
                placeholder="+1 (555) 000-0000"
              />

              {/* Date of Joining */}
              <Input
                label="Date of Joining"
                type="date"
                icon={Calendar}
                value={formData.joinedDate}
                onChange={(e) => handleChange('joinedDate', e.target.value)}
                error={errors.joinedDate}
                required
              />
            </div>
          </CardContent>
        </Card>

        {/* ========================================================================= */}
        {/* CARD 2: EMPLOYMENT INFORMATION                                            */}
        {/* ========================================================================= */}
        <Card>
          <CardHeader>
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded-lg bg-blue-50 text-blue-700">
                <Briefcase className="w-5 h-5" />
              </div>
              <div>
                <CardTitle>Employment Information</CardTitle>
                <CardDescription>
                  Organizational department, role title, shift scheduling, and contract classification.
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Department */}
              <div className="w-full flex flex-col gap-1.5 text-left">
                <label className="text-xs font-semibold text-slate-700 flex items-center gap-1">
                  Department <span className="text-rose-500">*</span>
                </label>
                <div className="relative">
                  <select
                    value={formData.department}
                    onChange={(e) => handleChange('department', e.target.value)}
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors appearance-none pr-8 cursor-pointer"
                  >
                    {DEPARTMENTS.map((dept) => (
                      <option key={dept} value={dept}>
                        {dept}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="w-4 h-4 text-slate-400 absolute right-2.5 top-3 pointer-events-none" />
                </div>
                {errors.department && (
                  <p className="text-xs text-rose-600 font-medium">{errors.department}</p>
                )}
              </div>

              {/* Position / Job Title */}
              <Input
                label="Position / Job Title"
                value={formData.position}
                onChange={(e) => handleChange('position', e.target.value)}
                error={errors.position}
                placeholder="e.g. HACCP Coordinator & Internal Auditor"
                required
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Employment Type */}
              <div className="w-full flex flex-col gap-1.5 text-left">
                <label className="text-xs font-semibold text-slate-700">
                  Employment Type
                </label>
                <div className="relative">
                  <select
                    value={formData.employmentType}
                    onChange={(e) => handleChange('employmentType', e.target.value)}
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors appearance-none pr-8 cursor-pointer"
                  >
                    {EMPLOYMENT_TYPES.map((type) => (
                      <option key={type} value={type}>
                        {type}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="w-4 h-4 text-slate-400 absolute right-2.5 top-3 pointer-events-none" />
                </div>
              </div>

              {/* Employee Status */}
              <div className="w-full flex flex-col gap-1.5 text-left">
                <label className="text-xs font-semibold text-slate-700">
                  Employee Status
                </label>
                <div className="relative">
                  <select
                    value={formData.status}
                    onChange={(e) => handleChange('status', e.target.value)}
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors appearance-none pr-8 cursor-pointer"
                  >
                    {STATUS_OPTIONS.map((status) => (
                      <option key={status} value={status}>
                        {status}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="w-4 h-4 text-slate-400 absolute right-2.5 top-3 pointer-events-none" />
                </div>
              </div>

              {/* Shift Assignment */}
              <div className="w-full flex flex-col gap-1.5 text-left">
                <label className="text-xs font-semibold text-slate-700">
                  Shift Assignment
                </label>
                <div className="relative">
                  <select
                    value={formData.shift}
                    onChange={(e) => handleChange('shift', e.target.value)}
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors appearance-none pr-8 cursor-pointer"
                  >
                    {SHIFTS.map((shift) => (
                      <option key={shift} value={shift}>
                        {shift}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="w-4 h-4 text-slate-400 absolute right-2.5 top-3 pointer-events-none" />
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* ========================================================================= */}
        {/* CARD 3: FOOD SAFETY & TRAINING INFORMATION                                 */}
        {/* ========================================================================= */}
        <Card>
          <CardHeader>
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded-lg bg-teal-50 text-teal-700">
                <ShieldCheck className="w-5 h-5" />
              </div>
              <div>
                <CardTitle>Food Safety, Hygiene & Training Compliance</CardTitle>
                <CardDescription>
                  HACCP competence, health fitness clearance, and certified qualifications.
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-5">
            {/* Training Status & Dates */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Training Status */}
              <div className="w-full flex flex-col gap-1.5 text-left">
                <label className="text-xs font-semibold text-slate-700">
                  Food Safety Training Status
                </label>
                <div className="relative">
                  <select
                    value={formData.trainingStatus}
                    onChange={(e) => handleChange('trainingStatus', e.target.value)}
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors appearance-none pr-8 cursor-pointer"
                  >
                    {TRAINING_STATUSES.map((status) => (
                      <option key={status} value={status}>
                        {status}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="w-4 h-4 text-slate-400 absolute right-2.5 top-3 pointer-events-none" />
                </div>
              </div>

              {/* Training Completion Date */}
              <Input
                label="Training Completion Date"
                type="date"
                icon={Calendar}
                value={formData.trainingCompletionDate}
                onChange={(e) => handleChange('trainingCompletionDate', e.target.value)}
                helperText="Date of last passed certification"
              />

              {/* Training Expiry Date */}
              <Input
                label="Training Expiry Date"
                type="date"
                icon={Calendar}
                value={formData.trainingExpiryDate}
                onChange={(e) => handleChange('trainingExpiryDate', e.target.value)}
                helperText="Renewal due date"
              />
            </div>

            {/* Medical Clearance Section */}
            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 space-y-3">
              <div className="flex items-center gap-2">
                <Stethoscope className="w-4 h-4 text-emerald-700" />
                <h4 className="text-xs font-bold text-slate-800 uppercase tracking-wider">
                  Medical Fitness & Health Clearance
                </h4>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Medical Fitness Status */}
                <div className="w-full flex flex-col gap-1.5 text-left">
                  <label className="text-xs font-semibold text-slate-700">
                    Medical Fitness Status
                  </label>
                  <div className="relative">
                    <select
                      value={formData.medicalFitnessStatus}
                      onChange={(e) =>
                        handleChange('medicalFitnessStatus', e.target.value)
                      }
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors appearance-none pr-8 cursor-pointer"
                    >
                      {MEDICAL_FITNESS_STATUSES.map((status) => (
                        <option key={status} value={status}>
                          {status}
                        </option>
                      ))}
                    </select>
                    <ChevronDown className="w-4 h-4 text-slate-400 absolute right-2.5 top-3 pointer-events-none" />
                  </div>
                </div>

                {/* Medical Certificate Expiry Date */}
                <Input
                  label="Medical Certificate Expiry Date"
                  type="date"
                  icon={Calendar}
                  value={formData.medicalCertificateExpiryDate}
                  onChange={(e) =>
                    handleChange('medicalCertificateExpiryDate', e.target.value)
                  }
                  helperText="Annual health screening validity"
                />
              </div>
            </div>

            {/* Certifications Selection */}
            <div className="space-y-3">
              <label className="text-xs font-semibold text-slate-700 flex items-center justify-between">
                <span>Food Safety Certifications & Badges</span>
                <span className="text-slate-400 font-normal text-[11px]">
                  Select all applicable qualifications
                </span>
              </label>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2.5">
                {AVAILABLE_CERTIFICATIONS.map((cert) => {
                  const isChecked = formData.certifications.includes(cert)
                  return (
                    <button
                      type="button"
                      key={cert}
                      onClick={() => handleToggleCert(cert)}
                      className={`p-2.5 rounded-xl border text-left text-xs font-medium flex items-center justify-between transition-all cursor-pointer ${
                        isChecked
                          ? 'bg-emerald-50/80 border-emerald-300 text-emerald-900 shadow-2xs font-semibold'
                          : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                      }`}
                    >
                      <div className="flex items-center gap-2 min-w-0 pr-1">
                        <Award
                          className={`w-3.5 h-3.5 shrink-0 ${
                            isChecked ? 'text-emerald-600' : 'text-slate-400'
                          }`}
                        />
                        <span className="truncate">{cert}</span>
                      </div>
                      <div
                        className={`w-4 h-4 rounded-md border flex items-center justify-center shrink-0 ${
                          isChecked
                            ? 'bg-emerald-600 border-emerald-600 text-white'
                            : 'border-slate-300 bg-white'
                        }`}
                      >
                        {isChecked && (
                          <svg
                            className="w-3 h-3 stroke-current stroke-2 fill-none"
                            viewBox="0 0 24 24"
                          >
                            <path d="M5 13l4 4L19 7" />
                          </svg>
                        )}
                      </div>
                    </button>
                  )
                })}
              </div>

              {/* Custom Certification Input */}
              <div className="pt-2 flex items-center gap-2">
                <Input
                  placeholder="Add custom certification (e.g. Chemical Handling Specialist)..."
                  value={formData.customCert}
                  onChange={(e) => handleChange('customCert', e.target.value)}
                  className="text-xs"
                />
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  onClick={handleAddCustomCert}
                  className="shrink-0 text-xs"
                >
                  Add Badge
                </Button>
              </div>
            </div>
          </CardContent>

          {/* Card Footer Actions */}
          <CardFooter className="flex flex-col sm:flex-row items-center justify-between gap-3">
            <p className="text-xs text-slate-500">
              Ensure all information complies with facility QA SOPs and ISO 22000 requirements.
            </p>
            <div className="flex items-center gap-2.5 w-full sm:w-auto justify-end">
              <Button
                type="button"
                variant="secondary"
                size="md"
                onClick={() => navigate('/employees')}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                variant="primary"
                size="md"
                icon={Save}
                loading={isSubmitting}
              >
                Save Employee
              </Button>
            </div>
          </CardFooter>
        </Card>
      </form>
    </div>
  )
}
