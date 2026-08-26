import React from 'react'
import { AlertCircle, CheckCircle2, Info, AlertTriangle, X } from 'lucide-react'
import { cn } from '../../utils/cn'

/**
 * Reusable Alert Component for warnings, compliance alerts, and statuses
 */
export function Alert({
  type = 'info', // 'info', 'success', 'warning', 'danger'
  title,
  children,
  onDismiss,
  className = '',
}) {
  const configs = {
    info: {
      icon: Info,
      container: 'bg-sky-50/80 border-sky-200 text-sky-900',
      iconClass: 'text-sky-600',
      btnHover: 'hover:bg-sky-100 text-sky-700',
    },
    success: {
      icon: CheckCircle2,
      container: 'bg-emerald-50/80 border-emerald-200 text-emerald-900',
      iconClass: 'text-emerald-600',
      btnHover: 'hover:bg-emerald-100 text-emerald-700',
    },
    warning: {
      icon: AlertTriangle,
      container: 'bg-amber-50/80 border-amber-200 text-amber-900',
      iconClass: 'text-amber-600',
      btnHover: 'hover:bg-amber-100 text-amber-700',
    },
    danger: {
      icon: AlertCircle,
      container: 'bg-rose-50/80 border-rose-200 text-rose-900',
      iconClass: 'text-rose-600',
      btnHover: 'hover:bg-rose-100 text-rose-700',
    },
  }

  const config = configs[type] || configs.info
  const Icon = config.icon

  return (
    <div
      className={cn(
        'p-4 rounded-xl border flex items-start gap-3 transition-all text-left shadow-xs',
        config.container,
        className
      )}
      role="alert"
    >
      <Icon className={cn('w-5 h-5 shrink-0 mt-0.5', config.iconClass)} />
      <div className="flex-1 space-y-0.5">
        {title && <h5 className="text-sm font-semibold leading-none">{title}</h5>}
        <div className="text-xs opacity-90 leading-relaxed">{children}</div>
      </div>
      {onDismiss && (
        <button
          onClick={onDismiss}
          className={cn('p-1 rounded-md shrink-0 transition-colors cursor-pointer', config.btnHover)}
          aria-label="Dismiss alert"
        >
          <X className="w-4 h-4" />
        </button>
      )}
    </div>
  )
}
