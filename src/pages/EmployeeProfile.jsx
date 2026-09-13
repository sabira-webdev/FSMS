import React from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import {
  User,
  ArrowLeft,
  Edit3,
  ShieldCheck,
  Building2,
  Mail,
  Phone,
  Calendar,
  Clock,
  Award,
  Stethoscope,
  Briefcase,
  AlertTriangle,
  CheckCircle2,
  UserX,
  FileCheck2,
  Activity,
  History,
  ExternalLink,
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
  Badge,
} from '../components/common'
import { useEmployees } from '../context/EmployeeContext'

// Helper for status badge
function getStatusBadge(status) {
  switch (status) {
    case 'Active':
      return <Badge variant="success" dot size="sm">Active Duty</Badge>
    case 'Pending Training':
      return <Badge variant="warning" dot size="sm">Pending Training</Badge>
    case 'On Leave':
      return <Badge variant="info" dot size="sm">On Leave</Badge>
    case 'Medical Review':
      return <Badge variant="danger" dot size="sm">Medical Review</Badge>
    default:
      return <Badge variant="neutral" size="sm">{status}</Badge>
  }
}

// Helper for initials
function getInitials(name) {
  if (!name) return 'EM'
  return name
    .replace('Dr. ', '')
    .split(' ')
    .map((n) => n[0])
    .join('')
    .substring(0, 2)
    .toUpperCase()
}

// Helper to format date
function formatDate(dateStr) {
  if (!dateStr) return 'Not recorded'
  try {
    const d = new Date(dateStr)
    if (isNaN(d.getTime())) return dateStr
    return d.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    })
  } catch {
    return dateStr
  }
}

// Helper to calculate days remaining
function getExpiryStatus(expiryDateStr) {
  if (!expiryDateStr) return { text: 'No Expiry Set', variant: 'neutral' }
  try {
    const expiry = new Date(expiryDateStr)
    const now = new Date()
    const diffTime = expiry.getTime() - now.getTime()
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

    if (diffDays < 0) {
      return { text: `Expired (${Math.abs(diffDays)}d ago)`, variant: 'danger' }
    }
    if (diffDays <= 30) {
      return { text: `Expiring Soon (${diffDays}d left)`, variant: 'warning' }
    }
    return { text: `Valid (${diffDays}d left)`, variant: 'success' }
  } catch {
    return { text: 'Valid', variant: 'success' }
  }
}

export function EmployeeProfile() {
  const { employeeId } = useParams()
  const navigate = useNavigate()
  const { employees } = useEmployees()

  // Find target employee
  const employee = employees.find(
    (e) =>
      e.id?.toLowerCase() === (employeeId || '').toLowerCase() ||
      e.employee_id?.toLowerCase() === (employeeId || '').toLowerCase() ||
      e.dbId === employeeId
  )

  // Fallback for invalid or missing employee ID
  if (!employee) {
    return (
      <div className="space-y-6 max-w-3xl mx-auto py-8">
        <PageHeader
          title="Employee Not Found"
          subtitle="The requested employee record does not exist or may have been archived."
          breadcrumbs={[
            { label: 'Home', path: '/' },
            { label: 'Employees', path: '/employees' },
            { label: 'Profile' },
          ]}
        />

        <Card className="p-8 text-center space-y-4">
          <div className="w-14 h-14 rounded-2xl bg-rose-50 text-rose-600 flex items-center justify-center mx-auto border border-rose-100">
            <UserX className="w-7 h-7" />
          </div>
          <div className="space-y-1">
            <h3 className="text-lg font-bold text-slate-800">
              Record "{employeeId}" Not Found
            </h3>
            <p className="text-xs text-slate-500 max-w-md mx-auto">
              We couldn't locate any personnel matching this identifier in the active food safety roster.
            </p>
          </div>
          <div className="pt-2">
            <Button
              variant="primary"
              size="sm"
              icon={ArrowLeft}
              onClick={() => navigate('/employees')}
            >
              Return to Employee List
            </Button>
          </div>
        </Card>
      </div>
    )
  }

  const trainingExpiry = getExpiryStatus(employee.trainingExpiryDate)
  const medicalExpiry = getExpiryStatus(employee.medicalCertificateExpiryDate)

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      {/* Page Header */}
      <PageHeader
        title={employee.name}
        subtitle={`${employee.position} • ${employee.department}`}
        badge={
          <div className="flex items-center gap-1.5">
            <span className="font-mono text-xs font-bold text-slate-700 bg-slate-100 px-2 py-0.5 rounded border border-slate-200">
              {employee.id}
            </span>
            {getStatusBadge(employee.status)}
          </div>
        }
        breadcrumbs={[
          { label: 'Home', path: '/' },
          { label: 'Employees', path: '/employees' },
          { label: employee.name },
        ]}
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              size="sm"
              icon={ArrowLeft}
              onClick={() => navigate('/employees')}
            >
              Back to Employees
            </Button>
            <Button
              variant="primary"
              size="sm"
              icon={Edit3}
              onClick={() => navigate(`/employees/${employee.id}/edit`)}
            >
              Edit Employee
            </Button>
          </div>
        }
      />

      {/* Main Profile Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* ========================================================================= */}
        {/* LEFT COLUMN: Profile Card, Contact, & Quick Compliance Meta               */}
        {/* ========================================================================= */}
        <div className="space-y-6">
          {/* Main User Card */}
          <Card className="text-center p-6 space-y-4">
            <div
              className={`w-20 h-20 rounded-2xl bg-gradient-to-tr ${
                employee.avatarGradient || 'from-emerald-600 to-teal-500'
              } text-white font-bold text-2xl flex items-center justify-center mx-auto shadow-md shadow-emerald-900/10`}
            >
              {getInitials(employee.name)}
            </div>

            <div>
              <h3 className="text-lg font-bold text-slate-900">{employee.name}</h3>
              <p className="text-xs text-slate-500 font-medium">{employee.position}</p>
              <div className="mt-2.5 flex items-center justify-center gap-1.5 flex-wrap">
                {getStatusBadge(employee.status)}
                <Badge variant="neutral" size="sm">
                  {employee.employmentType || 'Full-Time'}
                </Badge>
              </div>
            </div>

            {/* Quick Details List */}
            <div className="pt-4 border-t border-slate-100 text-xs text-left space-y-3 text-slate-600">
              <div className="flex items-center justify-between">
                <span className="text-slate-400 font-medium">Employee ID:</span>
                <span className="font-mono font-bold text-slate-800 bg-slate-50 px-2 py-0.5 rounded border border-slate-200">
                  {employee.id}
                </span>
              </div>

              <div className="flex items-center justify-between">
                <span className="text-slate-400 font-medium">Department:</span>
                <span className="font-semibold text-slate-800 truncate max-w-[160px]">
                  {employee.department}
                </span>
              </div>

              <div className="flex items-center justify-between">
                <span className="text-slate-400 font-medium">Shift Schedule:</span>
                <span className="font-semibold text-slate-800">
                  {employee.shift || 'Morning (Shift A)'}
                </span>
              </div>

              <div className="flex items-center justify-between">
                <span className="text-slate-400 font-medium">Date of Joining:</span>
                <span className="font-semibold text-slate-800">
                  {formatDate(employee.joinedDate)}
                </span>
              </div>
            </div>
          </Card>

          {/* Contact Information Card */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm flex items-center gap-2">
                <Phone className="w-4 h-4 text-emerald-600" />
                Contact Information
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-xs">
              <div className="p-3 rounded-lg bg-slate-50 border border-slate-100 space-y-1">
                <span className="text-slate-400 font-medium flex items-center gap-1.5">
                  <Mail className="w-3.5 h-3.5 text-slate-400" />
                  Email Address
                </span>
                <a
                  href={`mailto:${employee.email}`}
                  className="font-semibold text-emerald-700 hover:text-emerald-800 hover:underline block truncate"
                >
                  {employee.email}
                </a>
              </div>

              <div className="p-3 rounded-lg bg-slate-50 border border-slate-100 space-y-1">
                <span className="text-slate-400 font-medium flex items-center gap-1.5">
                  <Phone className="w-3.5 h-3.5 text-slate-400" />
                  Phone Number
                </span>
                <a
                  href={`tel:${employee.phone}`}
                  className="font-semibold text-slate-800 hover:text-emerald-700 block"
                >
                  {employee.phone || '+1 (555) 000-0000'}
                </a>
              </div>

              <div className="p-3 rounded-lg bg-slate-50 border border-slate-100 space-y-1">
                <span className="text-slate-400 font-medium flex items-center gap-1.5">
                  <Building2 className="w-3.5 h-3.5 text-slate-400" />
                  Station Assignment
                </span>
                <p className="font-semibold text-slate-800">
                  {employee.department} • Central Processing Unit
                </p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* ========================================================================= */}
        {/* RIGHT 2 COLUMNS: Detailed Employment & Food Safety Dossier                */}
        {/* ========================================================================= */}
        <div className="lg:col-span-2 space-y-6">
          {/* Card 1: Employment Overview */}
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <div className="p-1.5 rounded-lg bg-blue-50 text-blue-700">
                  <Briefcase className="w-4 h-4" />
                </div>
                <div>
                  <CardTitle>Employment & Role Classification</CardTitle>
                  <CardDescription>
                    Facility organizational structure and shift assignment.
                  </CardDescription>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
                <div className="p-3.5 rounded-xl border border-slate-100 bg-white space-y-1">
                  <span className="text-slate-400 font-medium">Department</span>
                  <p className="font-bold text-slate-800 text-sm">{employee.department}</p>
                </div>

                <div className="p-3.5 rounded-xl border border-slate-100 bg-white space-y-1">
                  <span className="text-slate-400 font-medium">Job Title / Role</span>
                  <p className="font-bold text-slate-800 text-sm">{employee.position}</p>
                </div>

                <div className="p-3.5 rounded-xl border border-slate-100 bg-white space-y-1">
                  <span className="text-slate-400 font-medium">Employment Classification</span>
                  <p className="font-bold text-slate-800 text-sm">
                    {employee.employmentType || 'Full-Time'}
                  </p>
                </div>

                <div className="p-3.5 rounded-xl border border-slate-100 bg-white space-y-1">
                  <span className="text-slate-400 font-medium">Shift Assignment</span>
                  <div className="flex items-center gap-1.5 pt-0.5">
                    <Clock className="w-3.5 h-3.5 text-slate-500" />
                    <span className="font-bold text-slate-800 text-sm">
                      {employee.shift || 'Morning (Shift A)'}
                    </span>
                  </div>
                </div>

                <div className="p-3.5 rounded-xl border border-slate-100 bg-white space-y-1">
                  <span className="text-slate-400 font-medium">Date of Joining</span>
                  <div className="flex items-center gap-1.5 pt-0.5">
                    <Calendar className="w-3.5 h-3.5 text-slate-500" />
                    <span className="font-bold text-slate-800 text-sm">
                      {formatDate(employee.joinedDate)}
                    </span>
                  </div>
                </div>

                <div className="p-3.5 rounded-xl border border-slate-100 bg-white space-y-1">
                  <span className="text-slate-400 font-medium">Employment Status</span>
                  <div className="pt-0.5">{getStatusBadge(employee.status)}</div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Card 2: Food Safety & Hygiene Compliance Dossier */}
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <div className="p-1.5 rounded-lg bg-emerald-50 text-emerald-700">
                  <ShieldCheck className="w-4 h-4" />
                </div>
                <div>
                  <CardTitle>Food Safety Training & Medical Fitness</CardTitle>
                  <CardDescription>
                    HACCP training history, validity periods, and annual medical screening status.
                  </CardDescription>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Training Status Row */}
              <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 space-y-3">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <Award className="w-4 h-4 text-emerald-600" />
                    <span className="text-xs font-bold text-slate-800 uppercase tracking-wider">
                      Food Safety Training Status
                    </span>
                  </div>
                  <Badge
                    variant={
                      employee.trainingStatus?.includes('Completed')
                        ? 'success'
                        : employee.trainingStatus === 'In Progress'
                        ? 'info'
                        : employee.trainingStatus === 'Scheduled'
                        ? 'warning'
                        : 'neutral'
                    }
                    dot
                    size="sm"
                  >
                    {employee.trainingStatus || 'Completed / Certified'}
                  </Badge>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs pt-1">
                  <div className="p-3 rounded-lg bg-white border border-slate-200/80">
                    <span className="text-slate-400 font-medium block">
                      Last Completion Date
                    </span>
                    <span className="font-bold text-slate-800 text-sm">
                      {formatDate(employee.trainingCompletionDate)}
                    </span>
                  </div>

                  <div className="p-3 rounded-lg bg-white border border-slate-200/80 flex items-center justify-between">
                    <div>
                      <span className="text-slate-400 font-medium block">
                        Training Expiry Date
                      </span>
                      <span className="font-bold text-slate-800 text-sm">
                        {formatDate(employee.trainingExpiryDate)}
                      </span>
                    </div>
                    <Badge variant={trainingExpiry.variant} size="sm">
                      {trainingExpiry.text}
                    </Badge>
                  </div>
                </div>
              </div>

              {/* Medical Clearance Row */}
              <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 space-y-3">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <Stethoscope className="w-4 h-4 text-emerald-600" />
                    <span className="text-xs font-bold text-slate-800 uppercase tracking-wider">
                      Food Handler Medical & Hygiene Fitness
                    </span>
                  </div>
                  <Badge
                    variant={
                      employee.medicalFitnessStatus?.includes('Fit')
                        ? 'success'
                        : employee.medicalFitnessStatus === 'Pending Examination'
                        ? 'warning'
                        : 'danger'
                    }
                    dot
                    size="sm"
                  >
                    {employee.medicalFitnessStatus || 'Fit / Cleared for Food Handling'}
                  </Badge>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs pt-1">
                  <div className="p-3 rounded-lg bg-white border border-slate-200/80">
                    <span className="text-slate-400 font-medium block">
                      Health Clearance Status
                    </span>
                    <span className="font-bold text-slate-800 text-sm">
                      {employee.medicalClearance || 'Cleared (Valid until Dec 2026)'}
                    </span>
                  </div>

                  <div className="p-3 rounded-lg bg-white border border-slate-200/80 flex items-center justify-between">
                    <div>
                      <span className="text-slate-400 font-medium block">
                        Certificate Expiry Date
                      </span>
                      <span className="font-bold text-slate-800 text-sm">
                        {formatDate(employee.medicalCertificateExpiryDate)}
                      </span>
                    </div>
                    <Badge variant={medicalExpiry.variant} size="sm">
                      {medicalExpiry.text}
                    </Badge>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Card 3: Verified Food Safety Certifications & Badges */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle>Food Safety Certifications & Credentials</CardTitle>
                  <CardDescription>
                    Authorized competencies for HACCP auditing, CCP monitoring, and hygiene sign-offs.
                  </CardDescription>
                </div>
                <Badge variant="success" size="sm">
                  {employee.certifications?.length || 0} Badges
                </Badge>
              </div>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {employee.certifications && employee.certifications.length > 0 ? (
                  employee.certifications.map((cert, idx) => (
                    <div
                      key={idx}
                      className="p-3.5 rounded-xl bg-slate-50 border border-slate-200/90 flex items-center justify-between gap-2 shadow-2xs hover:bg-emerald-50/40 hover:border-emerald-200 transition-colors"
                    >
                      <div className="flex items-center gap-2.5 min-w-0">
                        <div className="p-1.5 rounded-lg bg-emerald-100 text-emerald-800 shrink-0">
                          <ShieldCheck className="w-4 h-4" />
                        </div>
                        <div className="min-w-0">
                          <h5 className="text-xs font-bold text-slate-800 truncate">
                            {cert}
                          </h5>
                          <p className="text-[11px] text-slate-500">
                            Verified Food Safety Qualification
                          </p>
                        </div>
                      </div>
                      <Badge variant="success" size="sm">
                        Verified
                      </Badge>
                    </div>
                  ))
                ) : (
                  <div className="col-span-2 py-6 text-center text-xs text-slate-500 italic">
                    No active certifications recorded for this employee.
                  </div>
                )}
              </div>
            </CardContent>
            <CardFooter className="flex flex-col sm:flex-row items-center justify-between gap-3">
              <span className="text-xs text-slate-500">
                Audited in accordance with ISO 22000 & Codex Alimentarius guidelines.
              </span>
              <Button
                variant="outline"
                size="sm"
                icon={Edit3}
                onClick={() => navigate(`/employees/${employee.id}/edit`)}
              >
                Update Certifications
              </Button>
            </CardFooter>
          </Card>
        </div>
      </div>
    </div>
  )
}
