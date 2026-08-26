import React from 'react'
import {
  LayoutDashboard,
  Users,
  Building2,
  ClipboardCheck,
  ShieldCheck,
  AlertTriangle,
  BarChart3,
  UserCog,
  Settings,
  User,
  LogOut,
  Shield,
  X,
} from 'lucide-react'
import { NavItem } from './NavItem'
import { cn } from '../../utils/cn'

/**
 * Enterprise Sidebar Navigation Component
 */
export function Sidebar({ isOpen, onClose, onLogoutClick }) {
  const navSections = [
    {
      title: 'OVERVIEW',
      items: [
        { to: '/', label: 'Dashboard', icon: LayoutDashboard },
      ],
    },
    {
      title: 'OPERATIONS & QUALITY',
      items: [
        { to: '/employees', label: 'Employees', icon: Users },
        { to: '/departments', label: 'Departments', icon: Building2 },
        { to: '/checklists', label: 'Checklists', icon: ClipboardCheck },
        { to: '/inspections', label: 'Inspections', icon: ShieldCheck, badge: 'Live' },
        { to: '/capa', label: 'CAPA', icon: AlertTriangle, badge: '3 Open' },
        { to: '/reports', label: 'Reports', icon: BarChart3 },
      ],
    },
    {
      title: 'ADMINISTRATION',
      items: [
        { to: '/users', label: 'Users', icon: UserCog },
        { to: '/settings', label: 'Settings', icon: Settings },
      ],
    },
    {
      title: 'ACCOUNT',
      items: [
        { to: '/profile', label: 'My Profile', icon: User },
      ],
    },
  ]

  return (
    <>
      {/* Mobile Backdrop */}
      {isOpen && (
        <div
          className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs z-40 lg:hidden transition-opacity"
          onClick={onClose}
          aria-hidden="true"
        />
      )}

      {/* Sidebar Container */}
      <aside
        className={cn(
          'fixed top-0 bottom-0 left-0 z-50 w-64 bg-slate-900 border-r border-slate-800 text-slate-200 flex flex-col transition-transform duration-300 ease-in-out lg:static lg:translate-x-0',
          isOpen ? 'translate-x-0 shadow-2xl' : '-translate-x-full'
        )}
      >
        {/* Brand Header */}
        <div className="h-16 px-5 flex items-center justify-between border-b border-slate-800 shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-emerald-600 to-emerald-400 flex items-center justify-center text-white shadow-md shadow-emerald-900/40">
              <Shield className="w-5 h-5 fill-white/20" />
            </div>
            <div>
              <div className="text-base font-bold tracking-tight text-white flex items-center gap-1.5">
                FSMS <span className="text-[10px] uppercase font-semibold text-emerald-400 bg-emerald-950/80 px-1.5 py-0.5 rounded border border-emerald-800">Pro</span>
              </div>
              <p className="text-[11px] text-slate-400 font-medium">Food Safety System</p>
            </div>
          </div>

          {/* Close button for mobile */}
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 lg:hidden cursor-pointer"
            aria-label="Close sidebar"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Navigation Items (Scrollable) */}
        <div className="flex-1 overflow-y-auto px-3.5 py-4 space-y-6">
          {navSections.map((section, idx) => (
            <div key={idx} className="space-y-1">
              <div className="px-3 text-[10px] font-bold text-slate-500 uppercase tracking-wider">
                {section.title}
              </div>
              <div className="space-y-1 pt-1">
                {section.items.map((item) => (
                  <NavItem
                    key={item.to}
                    to={item.to}
                    label={item.label}
                    icon={item.icon}
                    badge={item.badge}
                    onClick={() => {
                      if (window.innerWidth < 1024) onClose()
                    }}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Bottom Section - Status & Logout */}
        <div className="p-3.5 border-t border-slate-800 bg-slate-950/40 shrink-0 space-y-2">
          {/* Compliance Status Pill */}
          <div className="p-2.5 rounded-xl bg-slate-800/60 border border-slate-700/60 flex items-center gap-3">
            <div className="relative">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 block" />
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-500/50 animate-ping absolute inset-0" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-xs font-semibold text-slate-200 truncate">HACCP & ISO 22000</p>
              <p className="text-[10px] text-emerald-400">All Nodes Compliant</p>
            </div>
          </div>

          {/* Logout Button */}
          <button
            type="button"
            onClick={onLogoutClick}
            className="w-full flex items-center gap-3 px-3.5 py-2 rounded-xl text-sm font-medium text-slate-400 hover:text-rose-300 hover:bg-rose-950/30 transition-colors cursor-pointer"
          >
            <LogOut className="w-4 h-4 text-slate-400" />
            <span>Logout</span>
          </button>
        </div>
      </aside>
    </>
  )
}
