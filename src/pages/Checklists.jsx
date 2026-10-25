import React, { useState, useEffect, useMemo, useCallback } from 'react'
import {
  ClipboardCheck,
  Plus,
  Search,
  Filter,
  Edit3,
  Eye,
  Power,
  Building2,
  Clock,
  Calendar,
  AlertTriangle,
  CheckCircle2,
  ShieldAlert,
  ShieldCheck,
  Layers,
  Sparkles,
  RefreshCw,
  Lock,
  LayoutGrid,
  Table as TableIcon,
  X,
  Info,
  ChevronRight,
  ArrowUp,
  ArrowDown,
  Trash2,
  ListOrdered,
  HelpCircle,
  FileCheck,
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
import {
  fetchChecklistTemplates,
  fetchChecklistWithItems,
  createChecklistTemplate,
  updateChecklistTemplate,
  toggleChecklistStatus,
  syncChecklistQuestions,
  fetchDepartmentsList,
  CHECKLIST_CATEGORIES,
  RESPONSE_TYPES,
  formatChecklistError,
} from '../services/checklistService'

const MANAGE_ROLES = ['Super Admin', 'Quality Manager', 'Lead Auditor']

export function Checklists() {
  const { role } = useAuth()
  const canManage = MANAGE_ROLES.includes(role)

  // State
  const [checklists, setChecklists] = useState([])
  const [departments, setDepartments] = useState([])
  const [loading, setLoading] = useState(true)
  const [dbError, setDbError] = useState(null)
  const [notification, setNotification] = useState(null)

  // Filters
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('All Categories')
  const [selectedStatus, setSelectedStatus] = useState('All Statuses') // 'All Statuses' | 'Active' | 'Inactive'
  const [viewMode, setViewMode] = useState('grid') // 'grid' | 'table'

  // Modals
  const [detailsModalOpen, setDetailsModalOpen] = useState(false)
  const [selectedChecklist, setSelectedChecklist] = useState(null)
  const [detailsLoading, setDetailsLoading] = useState(false)

  const [formModalOpen, setFormModalOpen] = useState(false)
  const [isEditing, setIsEditing] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [activeFormTab, setActiveFormTab] = useState('info') // 'info' | 'questions'

  const [deactivateModalOpen, setDeactivateModalOpen] = useState(false)
  const [templateToToggle, setTemplateToToggle] = useState(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [modalError, setModalError] = useState(null)

  // Form State
  const [formData, setFormData] = useState({
    code: '',
    title: '',
    category: 'Sanitation',
    department_id: '',
    description: '',
    version: 1,
    frequency: 'Daily - Pre-Operational',
    estimated_minutes: 20,
    is_active: true,
  })
  const [questions, setQuestions] = useState([])
  const [formErrors, setFormErrors] = useState({})

  // Fetch all checklists
  const loadChecklists = useCallback(async () => {
    setLoading(true)
    setDbError(null)
    try {
      const [checklistData, deptData] = await Promise.all([
        fetchChecklistTemplates(),
        fetchDepartmentsList(),
      ])
      setChecklists(checklistData)
      setDepartments(deptData)
    } catch (err) {
      console.error('[Checklists] Load error:', err.message)
      setDbError(err.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadChecklists()
  }, [loadChecklists])

  // Filtered checklists
  const filteredChecklists = useMemo(() => {
    return checklists.filter((item) => {
      const term = searchTerm.toLowerCase().trim()
      const matchesSearch =
        !term ||
        item.code?.toLowerCase().includes(term) ||
        item.title?.toLowerCase().includes(term) ||
        item.description?.toLowerCase().includes(term) ||
        item.category?.toLowerCase().includes(term) ||
        item.department_name?.toLowerCase().includes(term)

      const matchesCategory =
        selectedCategory === 'All Categories' || item.category === selectedCategory

      const matchesStatus =
        selectedStatus === 'All Statuses' ||
        (selectedStatus === 'Active' && item.is_active) ||
        (selectedStatus === 'Inactive' && !item.is_active)

      return matchesSearch && matchesCategory && matchesStatus
    })
  }, [checklists, searchTerm, selectedCategory, selectedStatus])

  // Aggregate stats
  const stats = useMemo(() => {
    const total = checklists.length
    const active = checklists.filter((c) => c.is_active).length
    const ccp = checklists.filter((c) => c.category === 'Thermal CCP' || c.criticalItemCount > 0).length
    const totalQuestions = checklists.reduce((acc, c) => acc + (c.itemCount || 0), 0)

    return {
      total,
      active,
      ccp,
      totalQuestions,
    }
  }, [checklists])

  // Category Badge Helper
  const getCategoryBadge = (category) => {
    const config = CHECKLIST_CATEGORIES.find((c) => c.value === category)
    if (!config) {
      return <Badge variant="neutral" size="sm">{category}</Badge>
    }
    return (
      <Badge variant={config.badgeVariant} size="sm">
        {config.label}
      </Badge>
    )
  }

  // Handle View Details
  const handleViewDetails = async (checklist) => {
    setSelectedChecklist(checklist)
    setDetailsModalOpen(true)
    setDetailsLoading(true)
    try {
      const fullData = await fetchChecklistWithItems(checklist.id)
      setSelectedChecklist(fullData)
    } catch (err) {
      console.error('[Checklists] Details load error:', err.message)
      setModalError(err.message)
    } finally {
      setDetailsLoading(false)
    }
  }

  // Handle Open Create Modal
  const handleOpenCreateModal = () => {
    setIsEditing(false)
    setEditingId(null)
    setActiveFormTab('info')
    setModalError(null)
    setFormErrors({})
    setFormData({
      code: '',
      title: '',
      category: 'Sanitation',
      department_id: departments[0]?.id || '',
      description: '',
      version: 1,
      frequency: 'Daily - Pre-Operational',
      estimated_minutes: 20,
      is_active: true,
    })
    setQuestions([
      {
        section_title: 'General Inspection',
        question: '',
        instruction: '',
        response_type: 'pass_fail',
        is_critical: false,
        min_value: '',
        max_value: '',
        unit: '',
        options: [],
      },
    ])
    setFormModalOpen(true)
  }

  // Handle Open Edit Modal
  const handleOpenEditModal = async (checklist) => {
    setIsEditing(true)
    setEditingId(checklist.id)
    setActiveFormTab('info')
    setModalError(null)
    setFormErrors({})
    setFormData({
      code: checklist.code,
      title: checklist.title,
      category: checklist.category,
      department_id: checklist.department_id || '',
      description: checklist.description || '',
      version: checklist.version || 1,
      frequency: checklist.metadata?.frequency || 'Daily',
      estimated_minutes: checklist.metadata?.estimated_minutes || 20,
      is_active: checklist.is_active,
    })

    try {
      const fullData = await fetchChecklistWithItems(checklist.id)
      setQuestions(fullData.items || [])
    } catch {
      setQuestions([])
    }

    setFormModalOpen(true)
  }

  // Question Management Helpers in Form
  const handleAddQuestion = () => {
    setQuestions((prev) => [
      ...prev,
      {
        section_title: prev[prev.length - 1]?.section_title || 'General Inspection',
        question: '',
        instruction: '',
        response_type: 'pass_fail',
        is_critical: false,
        min_value: '',
        max_value: '',
        unit: '',
        options: [],
      },
    ])
  }

  const handleUpdateQuestion = (index, field, value) => {
    setQuestions((prev) => {
      const updated = [...prev]
      updated[index] = { ...updated[index], [field]: value }
      return updated
    })
  }

  const handleRemoveQuestion = (index) => {
    setQuestions((prev) => prev.filter((_, i) => i !== index))
  }

  const handleMoveQuestion = (index, direction) => {
    setQuestions((prev) => {
      const newIndex = index + direction
      if (newIndex < 0 || newIndex >= prev.length) return prev
      const updated = [...prev]
      const temp = updated[index]
      updated[index] = updated[newIndex]
      updated[newIndex] = temp
      return updated
    })
  }

  // Form Validation
  const validateForm = () => {
    const errors = {}
    if (!isEditing && (!formData.code || formData.code.trim().length < 3)) {
      errors.code = 'Template code is required (min 3 characters, e.g. CHK-SAN-002).'
    }
    if (!formData.title || formData.title.trim().length < 3) {
      errors.title = 'Title must be at least 3 characters long.'
    }
    if (!formData.category) {
      errors.category = 'Category selection is required.'
    }

    // Validate questions
    for (let i = 0; i < questions.length; i++) {
      if (!questions[i].question || !questions[i].question.trim()) {
        errors.questions = `Question #${i + 1} requires inspection text.`
        break
      }
    }

    setFormErrors(errors)
    return Object.keys(errors).length === 0
  }

  // Save Checklist
  const handleSaveChecklist = async (e) => {
    e.preventDefault()
    if (!validateForm()) return

    setIsSubmitting(true)
    setModalError(null)

    try {
      if (isEditing) {
        // Update header
        await updateChecklistTemplate(editingId, formData)
        // Sync questions
        await syncChecklistQuestions(editingId, formData.code, questions)
        setNotification({
          type: 'success',
          message: `Checklist "${formData.title}" and inspection questions updated successfully.`,
        })
      } else {
        // Create new
        await createChecklistTemplate(formData, questions)
        setNotification({
          type: 'success',
          message: `Checklist template "${formData.code}" created successfully.`,
        })
      }

      setFormModalOpen(false)
      loadChecklists()
    } catch (err) {
      console.error('[Checklists] Save error:', err.message)
      setModalError(err.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  // Soft Deactivate / Reactivate
  const handleOpenDeactivateModal = (checklist) => {
    setTemplateToToggle(checklist)
    setDeactivateModalOpen(true)
    setModalError(null)
  }

  const handleConfirmToggleStatus = async () => {
    if (!templateToToggle) return
    setIsSubmitting(true)
    setModalError(null)

    try {
      await toggleChecklistStatus(templateToToggle.id, templateToToggle.is_active)
      setNotification({
        type: 'success',
        message: `Template "${templateToToggle.code}" was ${
          templateToToggle.is_active ? 'deactivated' : 'reactivated'
        } successfully. Historical audit trails are fully preserved.`,
      })
      setDeactivateModalOpen(false)
      setTemplateToToggle(null)
      loadChecklists()
    } catch (err) {
      console.error('[Checklists] Status toggle error:', err.message)
      setModalError(err.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <PageHeader
        title="Checklists"
        subtitle="Standard operating procedures (SOPs), sanitation verification forms, and critical safety protocols."
        badge={<Badge variant="info" size="sm">HACCP & GMP Engine</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Checklists' }]}
        actions={
          canManage ? (
            <Button
              variant="primary"
              size="sm"
              icon={Plus}
              onClick={handleOpenCreateModal}
            >
              Create Checklist
            </Button>
          ) : (
            <Badge variant="neutral" className="gap-1.5 py-1 px-3">
              <Lock className="w-3.5 h-3.5 text-slate-400" />
              Read-Only Access ({role})
            </Badge>
          )
        }
      />

      {/* Global Notifications & Error Banners */}
      {notification && (
        <Alert
          type={notification.type}
          title={notification.type === 'success' ? 'Operation Completed' : 'Notice'}
          onDismiss={() => setNotification(null)}
        >
          {notification.message}
        </Alert>
      )}

      {dbError && (
        <Alert
          type="danger"
          title="Database Connection Error"
          onDismiss={() => setDbError(null)}
        >
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mt-1">
            <span>{dbError}</span>
            <Button
              variant="secondary"
              size="xs"
              icon={RefreshCw}
              onClick={loadChecklists}
              className="w-fit"
            >
              Retry Connection
            </Button>
          </div>
        </Alert>
      )}

      {/* Metric StatCards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Master Checklists"
          value={stats.total}
          changeLabel="total templates configured"
          icon={ClipboardCheck}
          iconBg="bg-sky-50 text-sky-600 border-sky-100"
        />
        <StatCard
          title="Active Protocols"
          value={stats.active}
          changeLabel="ready for production audits"
          icon={ShieldCheck}
          iconBg="bg-emerald-50 text-emerald-600 border-emerald-100"
        />
        <StatCard
          title="Critical Limit Protocols"
          value={stats.ccp}
          changeLabel="thermal CCP & critical checks"
          icon={ShieldAlert}
          iconBg="bg-rose-50 text-rose-600 border-rose-100"
        />
        <StatCard
          title="Inspection Questions"
          value={stats.totalQuestions}
          changeLabel="verification points across forms"
          icon={ListOrdered}
          iconBg="bg-purple-50 text-purple-600 border-purple-100"
        />
      </div>

      {/* Main Content Card: Filters & Checklist Directory */}
      <Card>
        <CardHeader className="flex flex-col gap-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <CardTitle>Master Checklist Directory</CardTitle>
              <CardDescription>
                Food safety inspection protocols, CCP verification criteria, and quality release standards.
              </CardDescription>
            </div>
            {/* View Mode & Refresh */}
            <div className="flex items-center gap-2 self-start sm:self-auto">
              <div className="flex items-center rounded-lg border border-slate-200 p-0.5 bg-slate-50">
                <button
                  onClick={() => setViewMode('grid')}
                  className={`p-1.5 rounded-md transition-colors ${
                    viewMode === 'grid'
                      ? 'bg-white shadow-xs text-emerald-600'
                      : 'text-slate-400 hover:text-slate-700'
                  }`}
                  title="Grid View"
                >
                  <LayoutGrid className="w-4 h-4" />
                </button>
                <button
                  onClick={() => setViewMode('table')}
                  className={`p-1.5 rounded-md transition-colors ${
                    viewMode === 'table'
                      ? 'bg-white shadow-xs text-emerald-600'
                      : 'text-slate-400 hover:text-slate-700'
                  }`}
                  title="Table View"
                >
                  <TableIcon className="w-4 h-4" />
                </button>
              </div>
              <Button
                variant="secondary"
                size="sm"
                icon={RefreshCw}
                onClick={loadChecklists}
                title="Refresh checklists from Supabase"
              >
                Refresh
              </Button>
            </div>
          </div>

          {/* Search & Filter Controls */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
            <Input
              icon={Search}
              placeholder="Search code, title, or department..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full"
            />

            {/* Category Filter */}
            <div className="relative">
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors"
              >
                <option value="All Categories">All Categories</option>
                {CHECKLIST_CATEGORIES.map((cat) => (
                  <option key={cat.value} value={cat.value}>
                    {cat.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Status Filter */}
            <div className="relative">
              <select
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors"
              >
                <option value="All Statuses">All Statuses</option>
                <option value="Active">Active Only</option>
                <option value="Inactive">Inactive Only</option>
              </select>
            </div>
          </div>
        </CardHeader>

        <CardContent>
          {loading ? (
            <div className="py-16 flex flex-col items-center justify-center text-center space-y-3">
              <RefreshCw className="w-8 h-8 text-emerald-600 animate-spin" />
              <p className="text-sm font-medium text-slate-600">Loading master checklists from Supabase...</p>
            </div>
          ) : filteredChecklists.length === 0 ? (
            <div className="py-14 flex flex-col items-center justify-center text-center max-w-md mx-auto space-y-3">
              <div className="w-12 h-12 rounded-2xl bg-slate-100 text-slate-400 flex items-center justify-center border border-slate-200">
                <ClipboardCheck className="w-6 h-6" />
              </div>
              <h4 className="text-base font-bold text-slate-800">No Checklists Found</h4>
              <p className="text-xs text-slate-500 leading-relaxed">
                {searchTerm || selectedCategory !== 'All Categories' || selectedStatus !== 'All Statuses'
                  ? 'No checklists match your active search and filter filters.'
                  : 'No checklist templates exist yet. Create your first template to begin.'}
              </p>
              {(searchTerm || selectedCategory !== 'All Categories' || selectedStatus !== 'All Statuses') && (
                <Button
                  variant="secondary"
                  size="xs"
                  onClick={() => {
                    setSearchTerm('')
                    setSelectedCategory('All Categories')
                    setSelectedStatus('All Statuses')
                  }}
                >
                  Clear Filters
                </Button>
              )}
            </div>
          ) : viewMode === 'grid' ? (
            /* Grid View */
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {filteredChecklists.map((item) => (
                <div
                  key={item.id}
                  className={`rounded-2xl border p-5 transition-all hover:shadow-md flex flex-col justify-between ${
                    item.is_active
                      ? 'border-slate-200 bg-white'
                      : 'border-slate-200/80 bg-slate-50/70 opacity-80'
                  }`}
                >
                  <div className="space-y-3">
                    {/* Top Row: Code, Version & Badges */}
                    <div className="flex items-start justify-between gap-2">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-mono text-xs font-bold px-2.5 py-1 rounded-md bg-slate-100 text-slate-800 border border-slate-200">
                          {item.code}
                        </span>
                        <span className="text-xs text-slate-400 font-medium">v{item.version}</span>
                        {getCategoryBadge(item.category)}
                      </div>
                      <Badge
                        variant={item.is_active ? 'success' : 'neutral'}
                        dot
                        size="sm"
                      >
                        {item.is_active ? 'Active' : 'Inactive'}
                      </Badge>
                    </div>

                    {/* Title & Description */}
                    <div>
                      <h4 className="text-base font-bold text-slate-900 group-hover:text-emerald-600 transition-colors">
                        {item.title}
                      </h4>
                      <p className="text-xs text-slate-500 line-clamp-2 mt-1 leading-relaxed">
                        {item.description || 'No detailed description provided.'}
                      </p>
                    </div>

                    {/* Metadata & Department pill */}
                    <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
                      <div className="flex items-center gap-1.5">
                        <Building2 className="w-3.5 h-3.5 text-slate-400" />
                        <span className="font-medium text-slate-700">{item.department_name}</span>
                      </div>
                      <div className="flex items-center gap-3">
                        {item.metadata?.estimated_minutes && (
                          <div className="flex items-center gap-1" title="Estimated time to complete">
                            <Clock className="w-3.5 h-3.5 text-slate-400" />
                            <span>{item.metadata.estimated_minutes} min</span>
                          </div>
                        )}
                        <span className="font-medium text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-100">
                          {item.itemCount} {item.itemCount === 1 ? 'Question' : 'Questions'}
                        </span>
                      </div>
                    </div>

                    {item.criticalItemCount > 0 && (
                      <div className="flex items-center gap-1 text-[11px] font-semibold text-rose-600 bg-rose-50/60 px-2.5 py-1 rounded-lg border border-rose-100">
                        <ShieldAlert className="w-3.5 h-3.5 shrink-0" />
                        <span>Includes {item.criticalItemCount} Critical Safety Checkpoints</span>
                      </div>
                    )}
                  </div>

                  {/* Actions Row */}
                  <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between gap-2">
                    <Button
                      variant="secondary"
                      size="xs"
                      icon={Eye}
                      onClick={() => handleViewDetails(item)}
                    >
                      View Protocol
                    </Button>

                    {canManage && (
                      <div className="flex items-center gap-1.5">
                        <Button
                          variant="ghost"
                          size="xs"
                          icon={Edit3}
                          onClick={() => handleOpenEditModal(item)}
                          title="Edit Template & Questions"
                        >
                          Edit
                        </Button>
                        <Button
                          variant="ghost"
                          size="xs"
                          icon={Power}
                          onClick={() => handleOpenDeactivateModal(item)}
                          className={item.is_active ? 'text-amber-600 hover:text-amber-700' : 'text-emerald-600 hover:text-emerald-700'}
                          title={item.is_active ? 'Deactivate Template' : 'Reactivate Template'}
                        >
                          {item.is_active ? 'Deactivate' : 'Activate'}
                        </Button>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            /* Table View */
            <div className="overflow-x-auto rounded-xl border border-slate-200">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 uppercase tracking-wider font-semibold">
                  <tr>
                    <th className="py-3 px-4">Code</th>
                    <th className="py-3 px-4">Title</th>
                    <th className="py-3 px-4">Category</th>
                    <th className="py-3 px-4">Department</th>
                    <th className="py-3 px-4 text-center">Version</th>
                    <th className="py-3 px-4 text-center">Questions</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredChecklists.map((item) => (
                    <tr
                      key={item.id}
                      className={`hover:bg-slate-50/80 transition-colors ${
                        !item.is_active ? 'opacity-70 bg-slate-50/40' : ''
                      }`}
                    >
                      <td className="py-3 px-4 font-mono font-bold text-slate-900">
                        {item.code}
                      </td>
                      <td className="py-3 px-4 font-semibold text-slate-900">
                        <div>{item.title}</div>
                        {item.metadata?.frequency && (
                          <div className="text-[11px] text-slate-400 font-normal">
                            {item.metadata.frequency}
                          </div>
                        )}
                      </td>
                      <td className="py-3 px-4">
                        {getCategoryBadge(item.category)}
                      </td>
                      <td className="py-3 px-4 text-slate-600">
                        {item.department_name}
                      </td>
                      <td className="py-3 px-4 text-center text-slate-500 font-medium">
                        v{item.version}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span className="font-semibold text-slate-800">
                          {item.itemCount}
                        </span>
                        {item.criticalItemCount > 0 && (
                          <span className="ml-1 text-[10px] text-rose-600 font-bold" title="Critical checkpoints">
                            ({item.criticalItemCount} CCP)
                          </span>
                        )}
                      </td>
                      <td className="py-3 px-4">
                        <Badge
                          variant={item.is_active ? 'success' : 'neutral'}
                          dot
                          size="sm"
                        >
                          {item.is_active ? 'Active' : 'Inactive'}
                        </Badge>
                      </td>
                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end gap-1">
                          <Button
                            variant="ghost"
                            size="xs"
                            icon={Eye}
                            onClick={() => handleViewDetails(item)}
                          >
                            View
                          </Button>
                          {canManage && (
                            <>
                              <Button
                                variant="ghost"
                                size="xs"
                                icon={Edit3}
                                onClick={() => handleOpenEditModal(item)}
                              />
                              <Button
                                variant="ghost"
                                size="xs"
                                icon={Power}
                                onClick={() => handleOpenDeactivateModal(item)}
                                className={item.is_active ? 'text-amber-600' : 'text-emerald-600'}
                              />
                            </>
                          )}
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

      {/* ========================================================================= */}
      {/* MODAL 1: CHECKLIST DETAILS & QUESTION SPECIFICATION VIEW                   */}
      {/* ========================================================================= */}
      <Modal
        isOpen={detailsModalOpen}
        onClose={() => setDetailsModalOpen(false)}
        title={selectedChecklist ? `${selectedChecklist.code} - ${selectedChecklist.title}` : 'Checklist Protocol'}
        description="Master inspection protocol specification and verification criteria."
        maxWidth="max-w-4xl"
        footer={
          <div className="flex items-center justify-between w-full">
            <div className="flex items-center gap-2 text-xs text-slate-500">
              <Building2 className="w-4 h-4 text-slate-400" />
              <span>Assigned Department: <strong>{selectedChecklist?.department_name || 'Unassigned'}</strong></span>
            </div>
            <div className="flex items-center gap-2">
              {canManage && selectedChecklist && (
                <Button
                  variant="secondary"
                  size="sm"
                  icon={Edit3}
                  onClick={() => {
                    setDetailsModalOpen(false)
                    handleOpenEditModal(selectedChecklist)
                  }}
                >
                  Edit Protocol
                </Button>
              )}
              <Button
                variant="primary"
                size="sm"
                onClick={() => setDetailsModalOpen(false)}
              >
                Close
              </Button>
            </div>
          </div>
        }
      >
        {detailsLoading ? (
          <div className="py-12 flex flex-col items-center justify-center text-center space-y-2">
            <RefreshCw className="w-6 h-6 text-emerald-600 animate-spin" />
            <p className="text-xs text-slate-500">Retrieving inspection checkpoints...</p>
          </div>
        ) : selectedChecklist ? (
          <div className="space-y-6">
            {/* Header Summary Banner */}
            <div className="rounded-xl bg-slate-50 border border-slate-200 p-4 space-y-3">
              <div className="flex items-center justify-between flex-wrap gap-2">
                <div className="flex items-center gap-2">
                  <span className="font-mono text-sm font-bold px-2.5 py-1 rounded-md bg-white border border-slate-300 text-slate-900">
                    {selectedChecklist.code}
                  </span>
                  {getCategoryBadge(selectedChecklist.category)}
                  <span className="text-xs font-semibold px-2 py-0.5 rounded bg-slate-200/70 text-slate-700">
                    Version {selectedChecklist.version}
                  </span>
                </div>
                <Badge
                  variant={selectedChecklist.is_active ? 'success' : 'neutral'}
                  dot
                  size="sm"
                >
                  {selectedChecklist.is_active ? 'Active SOP' : 'Inactive Protocol'}
                </Badge>
              </div>

              <p className="text-xs text-slate-600 leading-relaxed">
                {selectedChecklist.description || 'No SOP description entered.'}
              </p>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2 border-t border-slate-200 text-xs">
                <div>
                  <span className="text-slate-400 block">Frequency:</span>
                  <span className="font-semibold text-slate-800">{selectedChecklist.metadata?.frequency || 'Daily'}</span>
                </div>
                <div>
                  <span className="text-slate-400 block">Estimated Time:</span>
                  <span className="font-semibold text-slate-800">{selectedChecklist.metadata?.estimated_minutes || 20} minutes</span>
                </div>
                <div>
                  <span className="text-slate-400 block">Checkpoints:</span>
                  <span className="font-semibold text-slate-800">{selectedChecklist.items?.length || 0} Questions</span>
                </div>
                <div>
                  <span className="text-slate-400 block">Critical Checkpoints:</span>
                  <span className="font-semibold text-rose-700">
                    {selectedChecklist.items?.filter((i) => i.is_critical).length || 0} CCP Limits
                  </span>
                </div>
              </div>
            </div>

            {/* Questions List */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <h5 className="text-sm font-bold text-slate-900 flex items-center gap-2">
                  <ListOrdered className="w-4 h-4 text-emerald-600" />
                  Inspection Checkpoints & Verification Questions
                </h5>
                <span className="text-xs text-slate-400">Order-sequenced audit flow</span>
              </div>

              {selectedChecklist.items?.length === 0 ? (
                <div className="text-center py-8 border border-dashed rounded-xl border-slate-300 text-xs text-slate-400">
                  No inspection questions configured for this template.
                </div>
              ) : (
                <div className="space-y-3">
                  {selectedChecklist.items?.map((q, idx) => (
                    <div
                      key={q.id || idx}
                      className="rounded-xl border border-slate-200 p-4 space-y-2 bg-white shadow-xs hover:border-slate-300 transition-colors"
                    >
                      {/* Section & Tags */}
                      <div className="flex items-center justify-between gap-2 flex-wrap">
                        <div className="flex items-center gap-2">
                          <span className="w-5 h-5 rounded-full bg-slate-100 text-slate-700 font-bold text-xs flex items-center justify-center">
                            {q.item_order}
                          </span>
                          <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
                            {q.section_title || 'General Inspection'}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          {q.is_critical && (
                            <span className="inline-flex items-center gap-1 text-[11px] font-bold text-rose-700 bg-rose-50 px-2 py-0.5 rounded-full border border-rose-200">
                              <ShieldAlert className="w-3 h-3" />
                              CRITICAL LIMIT
                            </span>
                          )}
                          <span className="text-xs font-medium px-2 py-0.5 rounded bg-slate-100 text-slate-600">
                            {RESPONSE_TYPES.find((r) => r.value === q.response_type)?.label || q.response_type}
                          </span>
                        </div>
                      </div>

                      {/* Question Text */}
                      <p className="text-sm font-semibold text-slate-900 leading-snug">
                        {q.question}
                      </p>

                      {/* Instructions / SSOP benchmark */}
                      {q.instruction && (
                        <div className="rounded-lg bg-slate-50 border border-slate-100 p-2 text-xs text-slate-600 flex items-start gap-2">
                          <Info className="w-3.5 h-3.5 text-slate-400 mt-0.5 shrink-0" />
                          <span className="leading-relaxed">{q.instruction}</span>
                        </div>
                      )}

                      {/* Numeric Limits Range */}
                      {q.response_type === 'numeric' && (q.min_value !== null || q.max_value !== null) && (
                        <div className="inline-flex items-center gap-2 text-xs font-semibold px-3 py-1 rounded-md bg-emerald-50 text-emerald-800 border border-emerald-200">
                          <span>Target Verification Range:</span>
                          <span className="font-mono">
                            {q.min_value !== null ? q.min_value : '—'} to {q.max_value !== null ? q.max_value : '—'} {q.unit || ''}
                          </span>
                        </div>
                      )}

                      {/* Multiple Choice Options */}
                      {q.response_type === 'multiple_choice' && Array.isArray(q.options) && q.options.length > 0 && (
                        <div className="flex items-center gap-2 flex-wrap pt-1">
                          <span className="text-xs text-slate-400 font-medium">Evaluation Options:</span>
                          {q.options.map((opt, oIdx) => (
                            <span
                              key={oIdx}
                              className="text-xs px-2.5 py-0.5 rounded-full border border-slate-200 bg-slate-50 text-slate-700 font-medium"
                            >
                              {opt}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        ) : null}
      </Modal>

      {/* ========================================================================= */}
      {/* MODAL 2: CREATE / EDIT CHECKLIST TEMPLATE & QUESTIONS                     */}
      {/* ========================================================================= */}
      <Modal
        isOpen={formModalOpen}
        onClose={() => !isSubmitting && setFormModalOpen(false)}
        title={isEditing ? `Edit Checklist: ${formData.code}` : 'Create New Checklist Template'}
        description="Configure SOP header parameters and sequenced safety checkpoints."
        maxWidth="max-w-3xl"
        footer={
          <div className="flex items-center justify-between w-full">
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setActiveFormTab(activeFormTab === 'info' ? 'questions' : 'info')}
                className="text-xs font-semibold text-emerald-600 hover:text-emerald-700 underline cursor-pointer"
              >
                Switch to {activeFormTab === 'info' ? `Questions (${questions.length})` : 'Template Details'}
              </button>
            </div>
            <div className="flex items-center gap-2">
              <Button
                variant="secondary"
                size="sm"
                onClick={() => setFormModalOpen(false)}
                disabled={isSubmitting}
              >
                Cancel
              </Button>
              <Button
                variant="primary"
                size="sm"
                onClick={handleSaveChecklist}
                loading={isSubmitting}
              >
                {isEditing ? 'Save Changes' : 'Create Template'}
              </Button>
            </div>
          </div>
        }
      >
        <form onSubmit={handleSaveChecklist} className="space-y-4">
          {modalError && (
            <Alert type="danger" title="Save Failed">
              {modalError}
            </Alert>
          )}

          {/* Form Tabs */}
          <div className="flex items-center gap-2 border-b border-slate-200 pb-2">
            <button
              type="button"
              onClick={() => setActiveFormTab('info')}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors cursor-pointer ${
                activeFormTab === 'info'
                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              1. Template Information
            </button>
            <button
              type="button"
              onClick={() => setActiveFormTab('questions')}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors cursor-pointer flex items-center gap-1.5 ${
                activeFormTab === 'questions'
                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <span>2. Checkpoints & Questions</span>
              <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-slate-200 text-slate-700 font-bold">
                {questions.length}
              </span>
            </button>
          </div>

          {/* TAB 1: TEMPLATE DETAILS */}
          {activeFormTab === 'info' && (
            <div className="space-y-4 pt-1">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Input
                  label="Checklist Code"
                  required
                  placeholder="e.g. CHK-SAN-002"
                  value={formData.code}
                  onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                  disabled={isEditing}
                  error={formErrors.code}
                  helperText={isEditing ? 'Template code is locked to preserve audit integrity' : 'Unique protocol identifier'}
                />

                <div className="flex flex-col gap-1.5 text-left">
                  <label className="text-xs font-semibold text-slate-700 flex items-center gap-1">
                    Food Safety Category <span className="text-rose-500">*</span>
                  </label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
                  >
                    {CHECKLIST_CATEGORIES.map((cat) => (
                      <option key={cat.value} value={cat.value}>
                        {cat.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <Input
                label="Checklist Title"
                required
                placeholder="e.g. Daily Pre-Operational Sanitation Verification"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                error={formErrors.title}
              />

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="flex flex-col gap-1.5 text-left">
                  <label className="text-xs font-semibold text-slate-700">
                    Assigned Department
                  </label>
                  <select
                    value={formData.department_id}
                    onChange={(e) => setFormData({ ...formData, department_id: e.target.value })}
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
                  >
                    <option value="">Unassigned (General Facility)</option>
                    {departments.map((dept) => (
                      <option key={dept.id} value={dept.id}>
                        {dept.name} ({dept.code})
                      </option>
                    ))}
                  </select>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <Input
                    label="Version"
                    type="number"
                    min="1"
                    value={formData.version}
                    onChange={(e) => setFormData({ ...formData, version: e.target.value })}
                  />
                  <Input
                    label="Est. Minutes"
                    type="number"
                    min="1"
                    value={formData.estimated_minutes}
                    onChange={(e) => setFormData({ ...formData, estimated_minutes: e.target.value })}
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Input
                  label="Execution Frequency"
                  placeholder="e.g. Daily - Pre-Operational"
                  value={formData.frequency}
                  onChange={(e) => setFormData({ ...formData, frequency: e.target.value })}
                />
              </div>

              <div className="flex flex-col gap-1.5 text-left">
                <label className="text-xs font-semibold text-slate-700">
                  Protocol Description & Scope
                </label>
                <textarea
                  rows="3"
                  className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
                  placeholder="Summarize inspection scope, SSOP reference numbers, or HACCP prerequisites..."
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                />
              </div>
            </div>
          )}

          {/* TAB 2: QUESTIONS / CHECKPOINTS */}
          {activeFormTab === 'questions' && (
            <div className="space-y-4 pt-1">
              <div className="flex items-center justify-between">
                <p className="text-xs text-slate-500">
                  Define the sequential verification steps, limits, and measurement criteria.
                </p>
                <Button
                  type="button"
                  variant="secondary"
                  size="xs"
                  icon={Plus}
                  onClick={handleAddQuestion}
                >
                  Add Question
                </Button>
              </div>

              {formErrors.questions && (
                <p className="text-xs font-semibold text-rose-600">{formErrors.questions}</p>
              )}

              {questions.length === 0 ? (
                <div className="text-center py-8 border border-dashed rounded-xl border-slate-300 text-xs text-slate-400">
                  No questions added. Click &quot;Add Question&quot; to configure your verification checkpoints.
                </div>
              ) : (
                <div className="space-y-4 max-h-[50vh] overflow-y-auto pr-1">
                  {questions.map((q, idx) => (
                    <div
                      key={idx}
                      className="rounded-xl border border-slate-200 p-4 bg-slate-50/50 space-y-3 relative group"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span className="w-5 h-5 rounded-full bg-emerald-100 text-emerald-800 font-bold text-xs flex items-center justify-center">
                            {idx + 1}
                          </span>
                          <input
                            type="text"
                            placeholder="Section Title (e.g. Chemical Sanitation)"
                            value={q.section_title || ''}
                            onChange={(e) => handleUpdateQuestion(idx, 'section_title', e.target.value)}
                            className="text-xs font-semibold text-slate-700 bg-transparent border-b border-transparent hover:border-slate-300 focus:border-emerald-500 focus:outline-none px-1"
                          />
                        </div>

                        <div className="flex items-center gap-1">
                          <button
                            type="button"
                            onClick={() => handleMoveQuestion(idx, -1)}
                            disabled={idx === 0}
                            className="p-1 rounded text-slate-400 hover:text-slate-700 disabled:opacity-30 cursor-pointer"
                            title="Move Up"
                          >
                            <ArrowUp className="w-3.5 h-3.5" />
                          </button>
                          <button
                            type="button"
                            onClick={() => handleMoveQuestion(idx, 1)}
                            disabled={idx === questions.length - 1}
                            className="p-1 rounded text-slate-400 hover:text-slate-700 disabled:opacity-30 cursor-pointer"
                            title="Move Down"
                          >
                            <ArrowDown className="w-3.5 h-3.5" />
                          </button>
                          <button
                            type="button"
                            onClick={() => handleRemoveQuestion(idx)}
                            className="p-1 rounded text-rose-400 hover:text-rose-700 cursor-pointer"
                            title="Delete Question"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>

                      {/* Question Text */}
                      <div>
                        <input
                          type="text"
                          required
                          placeholder="Inspection Question / Verification Statement *"
                          value={q.question}
                          onChange={(e) => handleUpdateQuestion(idx, 'question', e.target.value)}
                          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-1 focus:ring-emerald-500 font-medium"
                        />
                      </div>

                      {/* Instruction */}
                      <div>
                        <input
                          type="text"
                          placeholder="Standard Operating Procedure / Guidance note (optional)"
                          value={q.instruction || ''}
                          onChange={(e) => handleUpdateQuestion(idx, 'instruction', e.target.value)}
                          className="w-full rounded-lg border border-slate-200 bg-white px-3 py-1 text-xs text-slate-600 focus:border-emerald-500 focus:outline-none"
                        />
                      </div>

                      {/* Controls: Response Type & Critical Checkpoint Toggle */}
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                        <div className="flex flex-col gap-1">
                          <label className="text-[11px] font-semibold text-slate-600">Response Type</label>
                          <select
                            value={q.response_type}
                            onChange={(e) => handleUpdateQuestion(idx, 'response_type', e.target.value)}
                            className="rounded-lg border border-slate-300 bg-white px-2.5 py-1.5 text-xs text-slate-800 focus:border-emerald-500 focus:outline-none"
                          >
                            {RESPONSE_TYPES.map((rt) => (
                              <option key={rt.value} value={rt.value}>
                                {rt.label}
                              </option>
                            ))}
                          </select>
                        </div>

                        <div className="flex items-center gap-2 pt-4">
                          <input
                            type="checkbox"
                            id={`critical-${idx}`}
                            checked={Boolean(q.is_critical)}
                            onChange={(e) => handleUpdateQuestion(idx, 'is_critical', e.target.checked)}
                            className="w-4 h-4 rounded text-rose-600 border-slate-300 focus:ring-rose-500 cursor-pointer"
                          />
                          <label
                            htmlFor={`critical-${idx}`}
                            className="text-xs font-semibold text-slate-700 cursor-pointer flex items-center gap-1"
                          >
                            <ShieldAlert className="w-3.5 h-3.5 text-rose-500" />
                            Critical Safety Checkpoint (HACCP CCP)
                          </label>
                        </div>
                      </div>

                      {/* Numeric Limits Fields (if response_type === 'numeric') */}
                      {q.response_type === 'numeric' && (
                        <div className="grid grid-cols-3 gap-2 p-2.5 bg-emerald-50/60 rounded-lg border border-emerald-100">
                          <div>
                            <label className="text-[10px] font-semibold text-slate-600 block">Min Value</label>
                            <input
                              type="number"
                              step="any"
                              placeholder="e.g. 150"
                              value={q.min_value !== null ? q.min_value : ''}
                              onChange={(e) => handleUpdateQuestion(idx, 'min_value', e.target.value)}
                              className="w-full rounded border border-slate-300 bg-white px-2 py-1 text-xs"
                            />
                          </div>
                          <div>
                            <label className="text-[10px] font-semibold text-slate-600 block">Max Value</label>
                            <input
                              type="number"
                              step="any"
                              placeholder="e.g. 200"
                              value={q.max_value !== null ? q.max_value : ''}
                              onChange={(e) => handleUpdateQuestion(idx, 'max_value', e.target.value)}
                              className="w-full rounded border border-slate-300 bg-white px-2 py-1 text-xs"
                            />
                          </div>
                          <div>
                            <label className="text-[10px] font-semibold text-slate-600 block">Unit</label>
                            <input
                              type="text"
                              placeholder="e.g. ppm, °C, RLU"
                              value={q.unit || ''}
                              onChange={(e) => handleUpdateQuestion(idx, 'unit', e.target.value)}
                              className="w-full rounded border border-slate-300 bg-white px-2 py-1 text-xs"
                            />
                          </div>
                        </div>
                      )}

                      {/* Multiple Choice Options (if response_type === 'multiple_choice') */}
                      {q.response_type === 'multiple_choice' && (
                        <div className="p-2.5 bg-purple-50/60 rounded-lg border border-purple-100 space-y-1.5">
                          <label className="text-[10px] font-semibold text-slate-600 block">
                            Options (comma-separated)
                          </label>
                          <input
                            type="text"
                            placeholder="e.g. Passed, Hold & Re-clean, Discard"
                            value={Array.isArray(q.options) ? q.options.join(', ') : ''}
                            onChange={(e) =>
                              handleUpdateQuestion(
                                idx,
                                'options',
                                e.target.value.split(',').map((s) => s.trim()).filter(Boolean)
                              )
                            }
                            className="w-full rounded border border-slate-300 bg-white px-2 py-1 text-xs"
                          />
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </form>
      </Modal>

      {/* ========================================================================= */}
      {/* MODAL 3: SOFT-DEACTIVATE / REACTIVATE CONFIRMATION DIALOG                  */}
      {/* ========================================================================= */}
      <Modal
        isOpen={deactivateModalOpen}
        onClose={() => !isSubmitting && setDeactivateModalOpen(false)}
        title={templateToToggle?.is_active ? 'Deactivate Checklist Template' : 'Reactivate Checklist Template'}
        description="Preserve regulatory audit trails and inspection references."
        maxWidth="max-w-md"
        footer={
          <div className="flex items-center justify-end gap-2 w-full">
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setDeactivateModalOpen(false)}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button
              variant={templateToToggle?.is_active ? 'danger' : 'primary'}
              size="sm"
              onClick={handleConfirmToggleStatus}
              loading={isSubmitting}
            >
              {templateToToggle?.is_active ? 'Confirm Deactivation' : 'Reactivate Template'}
            </Button>
          </div>
        }
      >
        <div className="space-y-3">
          {modalError && (
            <Alert type="danger" title="Operation Failed">
              {modalError}
            </Alert>
          )}

          <div className="flex items-start gap-3 p-3 rounded-xl bg-amber-50 border border-amber-200 text-amber-900 text-xs">
            <Info className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
            <div className="space-y-1">
              <p className="font-semibold">Soft-Deactivation Pattern</p>
              <p className="opacity-90 leading-relaxed">
                {templateToToggle?.is_active
                  ? `Deactivating "${templateToToggle?.code}" will hide it from new daily audits, but will NOT delete historical inspection logs or compliance verification records.`
                  : `Reactivating "${templateToToggle?.code}" will make it immediately available for quality audits and shift checklists.`}
              </p>
            </div>
          </div>

          <p className="text-xs text-slate-600">
            Are you sure you want to {templateToToggle?.is_active ? 'deactivate' : 'reactivate'}{' '}
            <strong>{templateToToggle?.title}</strong> ({templateToToggle?.code})?
          </p>
        </div>
      </Modal>
    </div>
  )
}
