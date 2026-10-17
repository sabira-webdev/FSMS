import React, { useState, useMemo } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import {
  Users,
  Plus,
  Search,
  Filter,
  ShieldCheck,
  Mail,
  Phone,
  Eye,
  Edit3,
  Trash2,
  Building2,
  Award,
  CheckCircle2,
  AlertTriangle,
  Clock,
  Calendar,
  X,
  ChevronDown,
  UserCheck,
  Stethoscope,
} from 'lucide-react'
import {
  PageHeader,
  StatCard,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
  Badge,
  Button,
  Input,
  Modal,
  Alert,
} from '../components/common'
import { useEmployees } from '../context/EmployeeContext'

const DEPARTMENTS = [
  'All Departments',
  'Quality Assurance',
  'Food Safety Lab',
  'Sanitation & Hygiene',
  'Cold Chain Operations',
  'Production Line A',
  'Production Line B',
  'Packaging & Dispatch',
  'Warehouse & Receiving',
]

const STATUS_OPTIONS = [
  'All Statuses',
  'Active',
  'Pending Training',
  'On Leave',
  'Medical Review',
]

// Helper for status badge variant
function getStatusBadge(status) {
  switch (status) {
    case 'Active':
      return <Badge variant="success" dot size="sm">Active</Badge>
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

export function Employees() {
  const navigate = useNavigate()
  const {
    employees,
    departments: dbDepartments,
    deleteEmployee,
    notification,
    clearNotification,
  } = useEmployees()

  const departmentList = useMemo(() => {
    if (dbDepartments && dbDepartments.length > 0) {
      return ['All Departments', ...dbDepartments.map((d) => d.name)]
    }
    return DEPARTMENTS
  }, [dbDepartments])

  const [searchTerm, setSearchTerm] = useState('')
  const [selectedDept, setSelectedDept] = useState('All Departments')
  const [selectedStatus, setSelectedStatus] = useState('All Statuses')

  // Delete Modal State
  const [deletingEmployee, setDeletingEmployee] = useState(null)

  // Filtered Employees
  const filteredEmployees = useMemo(() => {
    return employees.filter((emp) => {
      const matchesSearch =
        (emp.name && emp.name.toLowerCase().includes(searchTerm.toLowerCase())) ||
        (emp.id && emp.id.toLowerCase().includes(searchTerm.toLowerCase())) ||
        (emp.position && emp.position.toLowerCase().includes(searchTerm.toLowerCase())) ||
        (emp.email && emp.email.toLowerCase().includes(searchTerm.toLowerCase())) ||
        (emp.department && emp.department.toLowerCase().includes(searchTerm.toLowerCase()))

      const matchesDept =
        selectedDept === 'All Departments' || emp.department === selectedDept

      const matchesStatus =
        selectedStatus === 'All Statuses' || emp.status === selectedStatus

      return matchesSearch && matchesDept && matchesStatus
    })
  }, [employees, searchTerm, selectedDept, selectedStatus])

  // Summary Metrics
  const stats = useMemo(() => {
    const total = employees.length
    const active = employees.filter((e) => e.status === 'Active').length
    const pendingTraining = employees.filter((e) => e.status === 'Pending Training').length
    const medicalClearedCount = employees.filter(
      (e) => e.medicalClearance && !e.medicalClearance.startsWith('Pending')
    ).length
    const medicalComplianceRate = total > 0 ? Math.round((medicalClearedCount / total) * 100) : 100

    return {
      total,
      active,
      pendingTraining,
      medicalComplianceRate,
    }
  }, [employees])

  // Delete / Remove Employee
  const handleConfirmDelete = async () => {
    if (!deletingEmployee) return
    try {
      await deleteEmployee(deletingEmployee.id)
    } catch (err) {
      console.warn('[Employees] Delete employee failed:', err.message)
    } finally {
      setDeletingEmployee(null)
    }
  }

  // Reset Filters
  const handleResetFilters = () => {
    setSearchTerm('')
    setSelectedDept('All Departments')
    setSelectedStatus('All Statuses')
  }

  const isFiltered =
    searchTerm !== '' ||
    selectedDept !== 'All Departments' ||
    selectedStatus !== 'All Statuses'

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <PageHeader
        title="Personnel & Food Handlers"
        subtitle="Manage food safety certifications, hygiene credentials, shift rosters, and medical clearances."
        badge={<Badge variant="success" dot size="sm">{employees.length} Registered Staff</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Employees' }]}
        actions={
          <Button
            variant="primary"
            size="sm"
            icon={Plus}
            onClick={() => navigate('/employees/new')}
          >
            Add Employee
          </Button>
        }
      />

      {/* Global Alert Notification */}
      {notification && (
        <Alert
          type={notification.type}
          title={notification.title}
          onDismiss={clearNotification}
        >
          {notification.text}
        </Alert>
      )}

      {/* Metric KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total Personnel"
          value={stats.total}
          change={`${stats.total} staff`}
          changeType="neutral"
          changeLabel="in facility database"
          icon={Users}
          iconBg="bg-slate-50 text-slate-700 border-slate-200"
        />
        <StatCard
          title="Active Food Handlers"
          value={stats.active}
          change={`${Math.round((stats.active / (stats.total || 1)) * 100)}%`}
          changeType="increase"
          changeLabel="active duty roster"
          icon={UserCheck}
          iconBg="bg-emerald-50 text-emerald-600 border-emerald-200"
        />
        <StatCard
          title="Medical Clearance"
          value={`${stats.medicalComplianceRate}%`}
          change="+2.1%"
          changeType="increase"
          changeLabel="annual hygiene clearance"
          icon={Stethoscope}
          iconBg="bg-blue-50 text-blue-600 border-blue-200"
        />
        <StatCard
          title="Pending Training"
          value={stats.pendingTraining}
          change={stats.pendingTraining > 0 ? `${stats.pendingTraining} actions` : 'Zero backlog'}
          changeType={stats.pendingTraining > 0 ? 'decrease' : 'increase'}
          changeLabel="certification refresh"
          icon={Award}
          iconBg="bg-amber-50 text-amber-600 border-amber-200"
        />
      </div>

      {/* Main Roster Card */}
      <Card>
        <CardHeader className="flex flex-col gap-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <CardTitle>Staff & Auditor Roster</CardTitle>
              <CardDescription>
                Search and filter certified personnel across quality, production, hygiene, and lab stations.
              </CardDescription>
            </div>
            <div className="text-xs text-slate-500 font-medium">
              Showing <span className="font-bold text-slate-800">{filteredEmployees.length}</span> of {employees.length} employees
            </div>
          </div>

          {/* Search & Filter Bar */}
          <div className="grid grid-cols-1 md:grid-cols-12 gap-3 pt-2">
            {/* Search Input */}
            <div className="md:col-span-5">
              <Input
                icon={Search}
                placeholder="Search by name, ID, position, or email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full"
              />
            </div>

            {/* Department Filter */}
            <div className="md:col-span-3">
              <div className="relative">
                <select
                  value={selectedDept}
                  onChange={(e) => setSelectedDept(e.target.value)}
                  className="w-full h-9.5 rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs font-medium text-slate-800 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors cursor-pointer appearance-none pr-8"
                >
                  {departmentList.map((dept) => (
                    <option key={dept} value={dept}>
                      {dept}
                    </option>
                  ))}
                </select>
                <ChevronDown className="w-4 h-4 text-slate-400 absolute right-2.5 top-3 pointer-events-none" />
              </div>
            </div>

            {/* Status Filter */}
            <div className="md:col-span-3">
              <div className="relative">
                <select
                  value={selectedStatus}
                  onChange={(e) => setSelectedStatus(e.target.value)}
                  className="w-full h-9.5 rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs font-medium text-slate-800 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors cursor-pointer appearance-none pr-8"
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

            {/* Reset / Action */}
            <div className="md:col-span-1 flex items-center">
              {isFiltered ? (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handleResetFilters}
                  className="w-full text-slate-500 hover:text-slate-800 px-2 text-xs"
                  title="Reset search & filters"
                >
                  Reset
                </Button>
              ) : (
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={handleResetFilters}
                  disabled
                  className="w-full px-2 text-xs opacity-50 cursor-not-allowed"
                >
                  Filter
                </Button>
              )}
            </div>
          </div>
        </CardHeader>

        {/* Table Content */}
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs sm:text-sm">
              <thead className="bg-slate-50 text-slate-600 text-[11px] uppercase tracking-wider font-semibold border-b border-slate-200">
                <tr>
                  <th className="px-5 py-3">Employee ID</th>
                  <th className="px-5 py-3">Name & Role</th>
                  <th className="px-5 py-3">Department</th>
                  <th className="px-5 py-3">Contact Email</th>
                  <th className="px-5 py-3">Shift</th>
                  <th className="px-5 py-3">Status</th>
                  <th className="px-5 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 font-normal">
                {filteredEmployees.length > 0 ? (
                  filteredEmployees.map((emp) => (
                    <tr
                      key={emp.id}
                      className="hover:bg-slate-50/70 transition-colors group"
                    >
                      {/* Employee ID */}
                      <td className="px-5 py-3.5 whitespace-nowrap">
                        <Link
                          to={`/employees/${emp.id}`}
                          className="font-mono font-semibold text-slate-800 hover:text-emerald-700 bg-slate-100 hover:bg-emerald-50 px-2 py-1 rounded text-xs border border-slate-200/80 transition-colors"
                        >
                          {emp.id}
                        </Link>
                      </td>

                      {/* Name & Position */}
                      <td className="px-5 py-3.5">
                        <div className="flex items-center gap-3">
                          <Link
                            to={`/employees/${emp.id}`}
                            className={`w-9 h-9 rounded-xl bg-gradient-to-tr ${
                              emp.avatarGradient || 'from-emerald-600 to-teal-500'
                            } text-white font-bold text-xs flex items-center justify-center shrink-0 shadow-xs hover:scale-105 transition-transform`}
                          >
                            {getInitials(emp.name)}
                          </Link>
                          <div>
                            <Link
                              to={`/employees/${emp.id}`}
                              className="font-semibold text-slate-900 hover:text-emerald-700 transition-colors flex items-center gap-1.5"
                            >
                              {emp.name}
                            </Link>
                            <div className="text-xs text-slate-500">
                              {emp.position}
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Department */}
                      <td className="px-5 py-3.5 whitespace-nowrap">
                        <div className="flex items-center gap-1.5 text-slate-700 font-medium text-xs">
                          <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                          <span>{emp.department}</span>
                        </div>
                      </td>

                      {/* Contact Email */}
                      <td className="px-5 py-3.5 whitespace-nowrap text-slate-600 text-xs">
                        <div className="flex items-center gap-1.5">
                          <Mail className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                          <span>{emp.email}</span>
                        </div>
                      </td>

                      {/* Shift */}
                      <td className="px-5 py-3.5 whitespace-nowrap text-slate-600 text-xs">
                        <div className="flex items-center gap-1.5">
                          <Clock className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                          <span>{emp.shift}</span>
                        </div>
                      </td>

                      {/* Status */}
                      <td className="px-5 py-3.5 whitespace-nowrap">
                        {getStatusBadge(emp.status)}
                      </td>

                      {/* Action Buttons */}
                      <td className="px-5 py-3.5 text-right whitespace-nowrap">
                        <div className="flex items-center justify-end gap-1">
                          <button
                            type="button"
                            onClick={() => navigate(`/employees/${emp.id}`)}
                            className="p-1.5 rounded-lg text-slate-500 hover:text-emerald-700 hover:bg-emerald-50 transition-colors cursor-pointer"
                            title="View Full Profile Dossier"
                            aria-label={`View ${emp.name}`}
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button
                            type="button"
                            onClick={() => navigate(`/employees/${emp.id}/edit`)}
                            className="p-1.5 rounded-lg text-slate-500 hover:text-blue-700 hover:bg-blue-50 transition-colors cursor-pointer"
                            title="Edit Employee Record"
                            aria-label={`Edit ${emp.name}`}
                          >
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button
                            type="button"
                            onClick={() => setDeletingEmployee(emp)}
                            className="p-1.5 rounded-lg text-slate-500 hover:text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer"
                            title="Remove from Roster"
                            aria-label={`Delete ${emp.name}`}
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={7} className="px-5 py-12 text-center">
                      <div className="max-w-sm mx-auto flex flex-col items-center space-y-3">
                        <div className="w-12 h-12 rounded-2xl bg-slate-100 text-slate-400 flex items-center justify-center">
                          <Users className="w-6 h-6" />
                        </div>
                        <h4 className="text-sm font-semibold text-slate-800">
                          No matching personnel found
                        </h4>
                        <p className="text-xs text-slate-500">
                          No staff records matched your search query or selected department filters.
                        </p>
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={handleResetFilters}
                        >
                          Clear Filters
                        </Button>
                      </div>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </CardContent>

        <CardFooter className="flex flex-col sm:flex-row items-center justify-between gap-3">
          <span className="text-xs text-slate-500">
            Showing {filteredEmployees.length} of {employees.length} registered personnel
          </span>
          <div className="flex items-center gap-2">
            <Badge variant="neutral" size="sm">
              Shift Roster: Active
            </Badge>
            <Badge variant="success" size="sm">
              HACCP Audited
            </Badge>
          </div>
        </CardFooter>
      </Card>

      {/* ========================================================================= */}
      {/* DELETE CONFIRMATION MODAL                                                 */}
      {/* ========================================================================= */}
      {deletingEmployee && (
        <Modal
          isOpen={Boolean(deletingEmployee)}
          onClose={() => setDeletingEmployee(null)}
          title="Remove Employee from Roster"
          description={`Are you sure you want to deactivate and remove ${deletingEmployee.name}?`}
          maxWidth="max-w-md"
          footer={
            <>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => setDeletingEmployee(null)}
              >
                Cancel
              </Button>
              <Button
                variant="danger"
                size="sm"
                onClick={handleConfirmDelete}
              >
                Confirm Deactivate
              </Button>
            </>
          }
        >
          <div className="space-y-3">
            <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-100 flex items-start gap-3">
              <AlertTriangle className="w-5 h-5 text-rose-600 shrink-0 mt-0.5" />
              <div className="text-xs text-rose-800 space-y-1">
                <p className="font-semibold">
                  This will archive {deletingEmployee.name} ({deletingEmployee.id}).
                </p>
                <p>
                  Their past audit logs and inspection sign-offs will be preserved for compliance traceability.
                </p>
              </div>
            </div>
          </div>
        </Modal>
      )}
    </div>
  )
}
