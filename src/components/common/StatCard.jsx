import React from 'react'
import { TrendingUp, TrendingDown, Minus } from 'lucide-react'
import { Card } from './Card'
import { cn } from '../../utils/cn'

/**
 * Reusable Metric / KPI Card Component
 */
export function StatCard({
  title,
  value,
  change,
  changeType = 'increase', // 'increase', 'decrease', 'neutral'
  changeLabel = 'vs last month',
  icon: Icon,
  iconBg = 'bg-emerald-50 text-emerald-600 border-emerald-100',
  className = '',
}) {
  return (
    <Card hover className={cn('p-5 flex flex-col justify-between relative overflow-hidden', className)}>
      <div className="flex items-start justify-between">
        <div className="space-y-1">
          <p className="text-xs font-medium text-slate-500 uppercase tracking-wider">{title}</p>
          <p className="text-2xl font-bold text-slate-900 tracking-tight">{value}</p>
        </div>
        {Icon && (
          <div className={cn('p-2.5 rounded-xl border flex items-center justify-center shrink-0 shadow-xs', iconBg)}>
            <Icon className="w-5 h-5" />
          </div>
        )}
      </div>

      {change !== undefined && (
        <div className="mt-4 pt-3 border-t border-slate-100 flex items-center gap-2 text-xs">
          <span
            className={cn(
              'inline-flex items-center gap-0.5 font-semibold px-1.5 py-0.5 rounded-md',
              changeType === 'increase' && 'text-emerald-700 bg-emerald-50',
              changeType === 'decrease' && 'text-rose-700 bg-rose-50',
              changeType === 'neutral' && 'text-slate-600 bg-slate-100'
            )}
          >
            {changeType === 'increase' && <TrendingUp className="w-3.5 h-3.5" />}
            {changeType === 'decrease' && <TrendingDown className="w-3.5 h-3.5" />}
            {changeType === 'neutral' && <Minus className="w-3.5 h-3.5" />}
            {change}
          </span>
          <span className="text-slate-500">{changeLabel}</span>
        </div>
      )}
    </Card>
  )
}
