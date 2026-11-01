import React, { useState, useEffect, useMemo, useCallback } from 'react'
import {
  Building2,
  Plus,
  Search,
  Filter,
  Edit3,
  Users,
  ShieldAlert,
  ShieldCheck,
  Layers,
  Sparkles,
  RefreshCw,
  AlertTriangle,
  CheckCircle2,
  Lock,
  LayoutGrid,
  Table as TableIcon,
  X,
  Info,
} from 'lucide-react'
import {
  PageHeader,
  StatCard,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  Badge,
  Button,
  Input,
  Modal,
  Alert,
} from '../components/common'
import { useAuth } from '../context/AuthContext'
import { useEmployees } from '../context/EmployeeContext'
import {
  fetchDepartmentsWithEmployeeCounts,
  createDepartment,
  updateDepartment,
  ZONE_TYPES,
} from '../services/departmentService'

export function Departments() {
  const { role } = useAuth()
  const { refetch: refetchEmployees } = useEmployees()

  // Data & State
  const [departments, setDepartments] = useState([])
  const [loading, setLoading] = useState(true)
  const [dbError, setDbError] = useState(null)
  const [notification, setNotification] = useState(null)

  // Filters & Search
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedZone, setSelectedZone] = useState('All Zones')
  const [viewMode, setViewMode] = useState('grid') // 'grid' | 'table'

  // Modals state
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false)
  const [editingDept, setEditingDept] = useState(null)

  // Form states for Create/Edit
  const [formData, setFormData] = useState({
    name: '',
    code: '',
    zone_type: 'Medium Care',
    description: '',
  })
  const [formErrors, setFormErrors] = useState({})
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [modalError, setModalError] = useState(null)

  // Fetch departments from Supabase
  const loadData = useCallback(async () => {
    setLoading(true)
    setDbError(null)
    try {
      const data = await fetchDepartmentsWithEmployeeCounts()
      setDepartments(data)
    } catch (err) {
      console.error('[Departments] Failed to load departments:', err.message)
      setDbError(err.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadData()
  }, [loadData])

  // Filtered departments
  const filteredDepartments = useMemo(() => {
    return departments.filter((dept) => {
      const term = searchTerm.toLowerCase().trim()
      const matchesSearch =
        !term ||
        dept.name?.toLowerCase().includes(term) ||
        dept.code?.toLowerCase().includes(term) ||
        dept.description?.toLowerCase().includes(term)

      const matchesZone =
        selectedZone === 'All Zones' || dept.zone_type === selectedZone

      return matchesSearch && matchesZone
    })
  }, [departments, searchTerm, selectedZone])

  // Summary Metrics
  const stats = useMemo(() => {
    const total = departments.length
    const criticalHygiene = departments.filter(
      (d) => d.zone_type === 'High Risk' || d.zone_type === 'High Care'
    ).length
    const processingStorage = departments.filter(
      (d) => d.zone_type === 'Medium Care' || d.zone_type === 'Low Care'
    ).length
    const totalStaff = departments.reduce((acc, d) => acc + (d.employeeCount || 0), 0)

    return {
      total,
      criticalHygiene,
      processingStorage,
      totalStaff,
    }
  }, [departments])

  // Helper for Zone Badge
  const getZoneBadge = (zoneType) => {
    const config = ZONE_TYPES.find((z) => z.value === zoneType)
    if (!config) {
      return <Badge variant="neutral" size="sm">{zoneType}</Badge>
    }
    return (
      <Badge variant={config.badgeVariant} dot size="sm">
        {config.label}
      </Badge>
    )
  }

  // Handle open Create Modal
  const handleOpenCreateModal = () => {
    setFormData({
      name: '',
      code: '',
      zone_type: 'Medium Care',
      description: '',
    })
    setFormErrors({})
    setModalError(null)
    setIsCreateModalOpen(true)
  }

  // Handle open Edit Modal
  const handleOpenEditModal = (dept) => {
    setEditingDept(dept)
    setFormData({
      name: dept.name || '',
      code: dept.code || '',
      zone_type: dept.zone_type || 'Medium Care',
      description: dept.description || '',
    })
    setFormErrors({})
    setModalError(null)
  }

  // Validate Form
  const validateForm = (isEditing = false, currentDeptId = null) => {
    const errors = {}

    if (!formData.name.trim()) {
      errors.name = 'Department name is required.'
    } else if (formData.name.trim().length < 2) {
      errors.name = 'Department name must be at least 2 characters.'
    } else {
      // Check for duplicate name
      const duplicateName = departments.find(
        (d) =>
          d.name.toLowerCase() === formData.name.trim().toLowerCase() &&
          (!isEditing || d.id !== currentDeptId)
      )
      if (duplicateName) {
        errors.name = 'A department with this name already exists.'
      }
    }

    if (!formData.code.trim()) {
      errors.code = 'Department code is required.'
    } else if (formData.code.trim().length < 2 || formData.code.trim().length > 10) {
      errors.code = 'Code must be between 2 and 10 characters.'
    } else if (!/^[A-Za-z0-9-]+$/.test(formData.code.trim())) {
      errors.code = 'Code can only contain letters, numbers, and hyphens.'
    } else {
      // Check for duplicate code
      const duplicateCode = departments.find(
        (d) =>
          d.code.toLowerCase() === formData.code.trim().toLowerCase() &&
          (!isEditing || d.id !== currentDeptId)
      )
      if (duplicateCode) {
        errors.code = 'A department with this code already exists.'
      }
    }

    if (!formData.zone_type) {
      errors.zone_type = 'Hygiene zone type is required.'
    }

    setFormErrors(errors)
    return Object.keys(errors).length === 0
  }

  // Submit Create
  const handleCreateSubmit = async (e) => {
    e.preventDefault()
    setModalError(null)

    if (!validateForm(false)) return

    setIsSubmitting(true)
    try {
      const created = await createDepartment(formData)
      setDepartments((prev) => [...prev, created].sort((a, b) => a.name.localeCompare(b.name)))
      setIsCreateModalOpen(false)
      setNotification({
        type: 'success',
        title: 'Department Created',
        text: `Facility department "${created.name}" (${created.code}) successfully saved to Supabase.`,
      })
      // Sync with employee context so employee dropdowns pick up the new department
      if (refetchEmployees) refetchEmployees()
    } catch (err) {
      setModalError(err.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  // Submit Edit
  const handleEditSubmit = async (e) => {
    e.preventDefault()
    if (!editingDept) return
    setModalError(null)

    if (!validateForm(true, editingDept.id)) return

    setIsSubmitting(true)
    try {
      const updated = await updateDepartment(editingDept.id, formData)
      setDepartments((prev) =>
        prev
          .map((d) => (d.id === editingDept.id ? { ...d, ...updated } : d))
          .sort((a, b) => a.name.localeCompare(b.name))
      )
      setEditingDept(null)
      setNotification({
        type: 'success',
        title: 'Department Updated',
        text: `Facility department "${updated.name}" (${updated.code}) successfully updated in Supabase.`,
      })
      // Sync with employee context
      if (refetchEmployees) refetchEmployees()
    } catch (err) {
      setModalError(err.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  // Reset Filters
  const handleResetFilters = () => {
    setSearchTerm('')
    setSelectedZone('All Zones')
  }

  const isFiltered = searchTerm !== '' || selectedZone !== 'All Zones'
  const isAuthorizedManager = role === 'Super Admin' || role === 'Quality Manager'

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <PageHeader
        title="Departments & Facility Zones"
        subtitle="Manage facility hygiene barrier zones, processing departments, and HACCP operational areas."
        badge={
          <Badge variant="success" dot size="sm">
            {departments.length} Zones Registered
          </Badge>
        }
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Departments' }]}
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              icon={RefreshCw}
              onClick={loadData}
              disabled={loading}
              title="Refresh database records"
            >
              Sync
            </Button>
            <Button
              variant="primary"
              size="sm"
              icon={Plus}
              onClick={handleOpenCreateModal}
            >
              New Department
            </Button>
          </div>
        }
      />

      {/* Global Success / Info Notification */}
      {notification && (
        <Alert
          type={notification.type}
          title={notification.title}
          dismissible
          onDismiss={() => setNotification(null)}
        >
          {notification.text}
        </Alert>
      )}

      {/* Database Error Banner */}
      {dbError && (
        <Alert
          type="danger"
          title="Supabase Connection Error"
          icon={AlertTriangle}
          action={
            <Button variant="secondary" size="sm" onClick={loadData}>
              Retry Connection
            </Button>
          }
        >
          {dbError}
        </Alert>
      )}

      {/* Role Security Note */}
      {!isAuthorizedManager && (
        <div className="flex items-start gap-3 p-3.5 bg-slate-900 border border-slate-800 rounded-xl text-slate-300 text-xs shadow-xs">
          <ShieldAlert className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
          <div className="space-y-1">
            <p className="font-semibold text-slate-100">
              Role Notice: Current role is <span className="text-emerald-400 font-bold">{role}</span>
            </p>
            <p className="text-slate-400 leading-relaxed">
              Row Level Security (RLS) allows all active personnel to browse facility zones. Creating or modifying departments requires an authorized <span className="text-slate-200 font-medium">Super Admin</span> or <span className="text-slate-200 font-medium">Quality Manager</span> profile in Supabase.
            </p>
          </div>
        </div>
      )}

      {/* Key Metric Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total Departments"
          value={stats.total}
          icon={Building2}
          color="emerald"
          subtitle="Registered facility zones"
        />
        <StatCard
          title="Critical Hygiene Zones"
          value={stats.criticalHygiene}
          icon={ShieldAlert}
          color="amber"
          subtitle="High Risk & High Care CCPs"
        />
        <StatCard
          title="Processing & Intake"
          value={stats.processingStorage}
          icon={Layers}
          color="blue"
          subtitle="Medium & Low Care Units"
        />
        <StatCard
          title="Assigned Personnel"
          value={stats.totalStaff}
          icon={Users}
          color="purple"
          subtitle="Food handlers mapped to zones"
        />
      </div>

      {/* Filter and View Controls Card */}
      <Card>
        <CardHeader className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <CardTitle>Facility Zones & HACCP Areas</CardTitle>
            <CardDescription>
              Hierarchical food safety zoning for allergen barriers, path control, and staff placement.
            </CardDescription>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            {/* Search Input */}
            <div className="w-full sm:w-64">
              <Input
                icon={Search}
                placeholder="Search name, code, notes..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>

            {/* Zone Filter */}
            <div className="relative">
              <select
                value={selectedZone}
                onChange={(e) => setSelectedZone(e.target.value)}
                className="rounded-lg border border-slate-300 bg-white py-2 pl-3 pr-8 text-xs font-medium text-slate-700 hover:border-slate-400 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors cursor-pointer appearance-none shadow-xs"
              >
                <option value="All Zones">All Zones ({departments.length})</option>
                {ZONE_TYPES.map((z) => (
                  <option key={z.value} value={z.value}>
                    {z.label}
                  </option>
                ))}
              </select>
              <Filter className="w-3.5 h-3.5 text-slate-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>

            {/* View Mode Toggle */}
            <div className="flex items-center rounded-lg border border-slate-200 bg-slate-50 p-0.5">
              <button
                type="button"
                onClick={() => setViewMode('grid')}
                className={`p-1.5 rounded-md transition-colors cursor-pointer ${
                  viewMode === 'grid'
                    ? 'bg-white text-emerald-700 shadow-xs'
                    : 'text-slate-400 hover:text-slate-600'
                }`}
                title="Grid View"
              >
                <LayoutGrid className="w-4 h-4" />
              </button>
              <button
                type="button"
                onClick={() => setViewMode('table')}
                className={`p-1.5 rounded-md transition-colors cursor-pointer ${
                  viewMode === 'table'
                    ? 'bg-white text-emerald-700 shadow-xs'
                    : 'text-slate-400 hover:text-slate-600'
                }`}
                title="Table View"
              >
                <TableIcon className="w-4 h-4" />
              </button>
            </div>

            {/* Reset Filters */}
            {isFiltered && (
              <Button
                variant="ghost"
                size="sm"
                icon={X}
                onClick={handleResetFilters}
                className="text-xs text-rose-600 hover:text-rose-700 hover:bg-rose-50"
              >
                Reset
              </Button>
            )}
          </div>
        </CardHeader>

        <CardContent>
          {/* Loading Skeleton */}
          {loading && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 py-4">
              {[1, 2, 3, 4, 5, 6].map((i) => (
                <div
                  key={i}
                  className="rounded-xl border border-slate-200 p-5 space-y-4 animate-pulse bg-slate-50/50"
                >
                  <div className="flex items-center justify-between">
                    <div className="h-6 w-16 bg-slate-200 rounded-md" />
                    <div className="h-5 w-24 bg-slate-200 rounded-full" />
                  </div>
                  <div className="space-y-2">
                    <div className="h-5 w-40 bg-slate-200 rounded" />
                    <div className="h-3 w-full bg-slate-200 rounded" />
                    <div className="h-3 w-3/4 bg-slate-200 rounded" />
                  </div>
                  <div className="h-8 bg-slate-200 rounded-lg" />
                </div>
              ))}
            </div>
          )}

          {/* Empty State */}
          {!loading && filteredDepartments.length === 0 && (
            <div className="py-16 flex flex-col items-center justify-center text-center max-w-md mx-auto space-y-3">
              <div className="w-14 h-14 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center border border-emerald-100">
                <Building2 className="w-7 h-7" />
              </div>
              <h4 className="text-base font-bold text-slate-800">
                {isFiltered ? 'No matching departments found' : 'No departments registered in Supabase'}
              </h4>
              <p className="text-xs text-slate-500 leading-relaxed">
                {isFiltered
                  ? 'Try modifying your search term or zone filter to locate the desired facility unit.'
                  : 'Start by creating your first processing zone, laboratory, or intake department to map your food safety workflows.'}
              </p>
              {isFiltered ? (
                <Button variant="secondary" size="sm" onClick={handleResetFilters}>
                  Clear Filters
                </Button>
              ) : (
                <Button variant="primary" size="sm" icon={Plus} onClick={handleOpenCreateModal}>
                  Create Department
                </Button>
              )}
            </div>
          )}

          {/* GRID VIEW */}
          {!loading && filteredDepartments.length > 0 && viewMode === 'grid' && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredDepartments.map((dept) => (
                <div
                  key={dept.id}
                  className="group relative rounded-xl border border-slate-200 bg-white p-5 hover:border-emerald-300 hover:shadow-md transition-all duration-200 flex flex-col justify-between text-left"
                >
                  <div className="space-y-3">
                    {/* Header: Code & Zone Badge */}
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-xs font-bold px-2 py-0.5 rounded-md bg-slate-900 text-emerald-400 border border-slate-800">
                          {dept.code}
                        </span>
                        <div className="w-1.5 h-1.5 rounded-full bg-slate-300" />
                        <span className="text-[11px] text-slate-400 font-medium">
                          ID: {dept.id.substring(0, 8)}…
                        </span>
                      </div>
                      <div>{getZoneBadge(dept.zone_type)}</div>
                    </div>

                    {/* Department Title */}
                    <div>
                      <h3 className="text-base font-bold text-slate-900 group-hover:text-emerald-700 transition-colors">
                        {dept.name}
                      </h3>
                      <p className="text-xs text-slate-500 mt-1 line-clamp-2 leading-relaxed">
                        {dept.description || 'No specific hazard scope or description assigned for this department.'}
                      </p>
                    </div>
                  </div>

                  {/* Footer Stats & Actions */}
                  <div className="mt-5 pt-3.5 border-t border-slate-100 flex items-center justify-between text-xs">
                    <div className="flex items-center gap-1.5 text-slate-600">
                      <Users className="w-3.5 h-3.5 text-emerald-600" />
                      <span className="font-semibold text-slate-800">
                        {dept.employeeCount || 0}
                      </span>
                      <span className="text-slate-400">
                        {dept.employeeCount === 1 ? 'employee' : 'employees'}
                      </span>
                    </div>

                    <div className="flex items-center gap-2">
                      {/* Security lock indicator: deletion disabled per compliance constraints */}
                      <span
                        className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] text-slate-400 bg-slate-100"
                        title="Deletion disabled to preserve employee and audit foreign key integrity (ON DELETE RESTRICT)"
                      >
                        <Lock className="w-2.5 h-2.5" />
                        Protected
                      </span>

                      <Button
                        variant="ghost"
                        size="sm"
                        icon={Edit3}
                        onClick={() => handleOpenEditModal(dept)}
                        className="h-7 px-2 text-xs text-emerald-700 hover:bg-emerald-50"
                      >
                        Edit
                      </Button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* TABLE VIEW */}
          {!loading && filteredDepartments.length > 0 && viewMode === 'table' && (
            <div className="overflow-x-auto rounded-xl border border-slate-200">
              <table className="w-full text-left text-xs text-slate-600">
                <thead className="bg-slate-50 text-[11px] uppercase tracking-wider text-slate-500 border-b border-slate-200">
                  <tr>
                    <th className="py-3 px-4 font-semibold">Code</th>
                    <th className="py-3 px-4 font-semibold">Department Name</th>
                    <th className="py-3 px-4 font-semibold">Hygiene Zone</th>
                    <th className="py-3 px-4 font-semibold">Description</th>
                    <th className="py-3 px-4 font-semibold text-center">Staff Count</th>
                    <th className="py-3 px-4 font-semibold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 bg-white">
                  {filteredDepartments.map((dept) => (
                    <tr
                      key={dept.id}
                      className="hover:bg-slate-50/80 transition-colors"
                    >
                      <td className="py-3 px-4 whitespace-nowrap">
                        <span className="font-mono text-xs font-bold px-2 py-0.5 rounded bg-slate-900 text-emerald-400 border border-slate-800">
                          {dept.code}
                        </span>
                      </td>
                      <td className="py-3 px-4 font-semibold text-slate-900 whitespace-nowrap">
                        {dept.name}
                      </td>
                      <td className="py-3 px-4 whitespace-nowrap">
                        {getZoneBadge(dept.zone_type)}
                      </td>
                      <td className="py-3 px-4 max-w-xs truncate text-slate-500">
                        {dept.description || '—'}
                      </td>
                      <td className="py-3 px-4 text-center whitespace-nowrap">
                        <span className="inline-flex items-center gap-1 font-semibold text-slate-800">
                          <Users className="w-3.5 h-3.5 text-emerald-600" />
                          {dept.employeeCount || 0}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-right whitespace-nowrap">
                        <div className="inline-flex items-center gap-1.5 justify-end">
                          <span
                            className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] text-slate-400 bg-slate-100"
                            title="Deletion disabled to preserve employee and audit foreign key integrity"
                          >
                            <Lock className="w-2.5 h-2.5" />
                          </span>
                          <Button
                            variant="ghost"
                            size="sm"
                            icon={Edit3}
                            onClick={() => handleOpenEditModal(dept)}
                            className="h-7 px-2 text-xs text-emerald-700 hover:bg-emerald-50"
                          >
                            Edit
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* CREATE DEPARTMENT MODAL */}
      <Modal
        isOpen={isCreateModalOpen}
        onClose={() => !isSubmitting && setIsCreateModalOpen(false)}
        title="Add Facility Department"
        description="Register a new processing zone, laboratory, or storage unit in Supabase."
        footer={
          <>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setIsCreateModalOpen(false)}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              size="sm"
              onClick={handleCreateSubmit}
              loading={isSubmitting}
            >
              Create Department
            </Button>
          </>
        }
      >
        <form onSubmit={handleCreateSubmit} className="space-y-4 text-left">
          {modalError && (
            <Alert type="danger" title="Save Failed">
              {modalError}
            </Alert>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div className="sm:col-span-2">
              <Input
                label="Department Name"
                required
                placeholder="e.g. Microbiology Testing Lab"
                value={formData.name}
                error={formErrors.name}
                onChange={(e) => {
                  setFormData({ ...formData, name: e.target.value })
                  if (formErrors.name) setFormErrors({ ...formErrors, name: null })
                }}
              />
            </div>
            <div>
              <Input
                label="Code"
                required
                placeholder="e.g. MIC-LAB"
                value={formData.code}
                error={formErrors.code}
                onChange={(e) => {
                  setFormData({ ...formData, code: e.target.value.toUpperCase() })
                  if (formErrors.code) setFormErrors({ ...formErrors, code: null })
                }}
                helperText="2–10 uppercase chars"
              />
            </div>
          </div>

          {/* Zone Type Selection */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-slate-700 flex items-center gap-1">
              Hygiene Zone Type <span className="text-rose-500">*</span>
            </label>
            <select
              value={formData.zone_type}
              onChange={(e) => setFormData({ ...formData, zone_type: e.target.value })}
              className="w-full rounded-lg border border-slate-300 bg-white py-2 px-3 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors"
            >
              {ZONE_TYPES.map((z) => (
                <option key={z.value} value={z.value}>
                  {z.label} — {z.description}
                </option>
              ))}
            </select>
            {formErrors.zone_type && (
              <p className="text-xs text-rose-600 font-medium">{formErrors.zone_type}</p>
            )}
          </div>

          {/* Description */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-slate-700">
              Operational Scope & Hazard Notes (Optional)
            </label>
            <textarea
              rows={3}
              placeholder="e.g. Environmental pathogen monitoring, ATP swabs, and allergen release testing."
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full rounded-lg border border-slate-300 bg-white p-2.5 text-sm text-slate-900 placeholder:text-slate-400 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors resize-none"
            />
          </div>

          {/* Compliance Info Banner inside Modal */}
          <div className="flex items-start gap-2.5 p-3 rounded-lg bg-emerald-50/70 border border-emerald-100 text-[11px] text-emerald-800">
            <Info className="w-4 h-4 shrink-0 text-emerald-600 mt-0.5" />
            <p className="leading-relaxed">
              This department will be immediately available in the employee assignment dropdowns and audit inspection checklists across the FSMS platform.
            </p>
          </div>
        </form>
      </Modal>

      {/* EDIT DEPARTMENT MODAL */}
      <Modal
        isOpen={Boolean(editingDept)}
        onClose={() => !isSubmitting && setEditingDept(null)}
        title="Edit Facility Department"
        description={`Update attributes for ${editingDept?.name || 'department'} in Supabase.`}
        footer={
          <>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setEditingDept(null)}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              size="sm"
              onClick={handleEditSubmit}
              loading={isSubmitting}
            >
              Save Changes
            </Button>
          </>
        }
      >
        <form onSubmit={handleEditSubmit} className="space-y-4 text-left">
          {modalError && (
            <Alert type="danger" title="Update Failed">
              {modalError}
            </Alert>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div className="sm:col-span-2">
              <Input
                label="Department Name"
                required
                value={formData.name}
                error={formErrors.name}
                onChange={(e) => {
                  setFormData({ ...formData, name: e.target.value })
                  if (formErrors.name) setFormErrors({ ...formErrors, name: null })
                }}
              />
            </div>
            <div>
              <Input
                label="Code"
                required
                value={formData.code}
                error={formErrors.code}
                onChange={(e) => {
                  setFormData({ ...formData, code: e.target.value.toUpperCase() })
                  if (formErrors.code) setFormErrors({ ...formErrors, code: null })
                }}
              />
            </div>
          </div>

          {/* Zone Type Selection */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-slate-700 flex items-center gap-1">
              Hygiene Zone Type <span className="text-rose-500">*</span>
            </label>
            <select
              value={formData.zone_type}
              onChange={(e) => setFormData({ ...formData, zone_type: e.target.value })}
              className="w-full rounded-lg border border-slate-300 bg-white py-2 px-3 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors"
            >
              {ZONE_TYPES.map((z) => (
                <option key={z.value} value={z.value}>
                  {z.label} — {z.description}
                </option>
              ))}
            </select>
            {formErrors.zone_type && (
              <p className="text-xs text-rose-600 font-medium">{formErrors.zone_type}</p>
            )}
          </div>

          {/* Description */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-slate-700">
              Operational Scope & Hazard Notes
            </label>
            <textarea
              rows={3}
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full rounded-lg border border-slate-300 bg-white p-2.5 text-sm text-slate-900 placeholder:text-slate-400 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors resize-none"
            />
          </div>

          {/* Personnel linkage reminder */}
          <div className="flex items-center gap-2 p-2.5 rounded-lg bg-slate-50 border border-slate-200 text-xs text-slate-600">
            <Users className="w-4 h-4 text-emerald-600 shrink-0" />
            <span>
              Currently assigned: <strong className="text-slate-900">{editingDept?.employeeCount || 0} employees</strong>
            </span>
          </div>
        </form>
      </Modal>
    </div>
  )
}
