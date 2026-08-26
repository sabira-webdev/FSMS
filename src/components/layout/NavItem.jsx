import React from 'react'
import { NavLink } from 'react-router-dom'
import { cn } from '../../utils/cn'

/**
 * Sidebar Navigation Link Item
 */
export function NavItem({
  to,
  icon: Icon,
  label,
  badge,
  badgeVariant = 'neutral',
  onClick,
}) {
  return (
    <NavLink
      to={to}
      onClick={onClick}
      className={({ isActive }) =>
        cn(
          'group relative flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-sm font-medium transition-all duration-150',
          isActive
            ? 'bg-emerald-600 text-white shadow-sm font-semibold shadow-emerald-950/20'
            : 'text-slate-300 hover:text-white hover:bg-slate-800/90'
        )
      }
    >
      {({ isActive }) => (
        <>
          {isActive && (
            <span className="absolute left-0 top-1.5 bottom-1.5 w-1 bg-emerald-300 rounded-r-full" />
          )}
          {Icon && (
            <Icon
              className={cn(
                'w-5 h-5 shrink-0 transition-transform group-hover:scale-105',
                isActive ? 'text-white' : 'text-slate-400 group-hover:text-emerald-400'
              )}
            />
          )}
          <span className="truncate flex-1">{label}</span>
          {badge && (
            <span
              className={cn(
                'text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wider',
                isActive
                  ? 'bg-emerald-700/80 text-emerald-100'
                  : 'bg-slate-800 text-slate-400 group-hover:bg-slate-700 group-hover:text-slate-200'
              )}
            >
              {badge}
            </span>
          )}
        </>
      )}
    </NavLink>
  )
}
