import React, { useState, useRef, useEffect } from 'react'
import {
  Menu,
  Bell,
  Search,
  CheckCircle2,
  AlertTriangle,
  User,
  ShieldCheck,
  ChevronDown,
  Sparkles,
} from 'lucide-react'
import { Link } from 'react-router-dom'

/**
 * Top Header Navigation Component
 */
export function Header({ onToggleSidebar, onLogoutClick }) {
  const [notificationsOpen, setNotificationsOpen] = useState(false)
  const [profileMenuOpen, setProfileMenuOpen] = useState(false)

  const notifRef = useRef(null)
  const profileRef = useRef(null)

  // Close dropdowns when clicking outside
  useEffect(() => {
    function handleClickOutside(event) {
      if (notifRef.current && !notifRef.current.contains(event.target)) {
        setNotificationsOpen(false)
      }
      if (profileRef.current && !profileRef.current.contains(event.target)) {
        setProfileMenuOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Sample static notifications preview
  const notifications = [
    {
      id: 1,
      title: 'Daily Cold Storage Inspection Due',
      time: '15 mins ago',
      type: 'warning',
      unread: true,
    },
    {
      id: 2,
      title: 'Packaging Line B Hygiene Passed',
      time: '1 hour ago',
      type: 'success',
      unread: true,
    },
    {
      id: 3,
      title: 'HACCP Audit Report Generated',
      time: '3 hours ago',
      type: 'info',
      unread: false,
    },
  ]

  return (
    <header className="h-16 bg-white border-b border-slate-200/80 sticky top-0 z-30 px-4 sm:px-6 lg:px-8 flex items-center justify-between shadow-xs">
      {/* Left Area: Mobile Toggle & Title */}
      <div className="flex items-center gap-3 sm:gap-4">
        {/* Mobile Hamburger */}
        <button
          type="button"
          onClick={onToggleSidebar}
          className="p-2 -ml-2 rounded-lg text-slate-600 hover:text-slate-900 hover:bg-slate-100 lg:hidden cursor-pointer"
          aria-label="Toggle navigation menu"
        >
          <Menu className="w-5 h-5" />
        </button>

        {/* Title & Logo Info */}
        <div className="flex items-center gap-2.5">
          <div className="hidden sm:flex w-8 h-8 rounded-lg bg-emerald-600 items-center justify-center text-white font-bold shadow-xs">
            <ShieldCheck className="w-4 h-4" />
          </div>
          <div>
            <h2 className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
              Food Safety Management System
            </h2>
            <p className="text-[11px] text-emerald-700 font-medium hidden sm:block">
              Enterprise Quality & Compliance Portal
            </p>
          </div>
        </div>
      </div>

      {/* Right Area: System Status, Notifications & User Profile */}
      <div className="flex items-center gap-2 sm:gap-4">
        {/* Live Status Badge (Hidden on mobile) */}
        <div className="hidden md:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-50 border border-emerald-200/80 text-emerald-800 text-xs font-medium">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
          <span>System Healthy</span>
        </div>

        {/* Notification Bell Dropdown */}
        <div className="relative" ref={notifRef}>
          <button
            type="button"
            onClick={() => setNotificationsOpen(!notificationsOpen)}
            className="p-2 rounded-lg text-slate-500 hover:text-slate-800 hover:bg-slate-100 relative transition-colors cursor-pointer"
            aria-label="View notifications"
          >
            <Bell className="w-5 h-5" />
            <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-emerald-600 rounded-full ring-2 ring-white" />
          </button>

          {notificationsOpen && (
            <div className="absolute right-0 mt-2 w-80 sm:w-88 bg-white rounded-2xl border border-slate-200 shadow-xl py-2 z-50 animate-in fade-in-50 zoom-in-95">
              <div className="px-4 py-2.5 border-b border-slate-100 flex items-center justify-between">
                <div>
                  <h4 className="text-xs font-bold uppercase tracking-wider text-slate-800">Notifications</h4>
                  <p className="text-[11px] text-slate-500">2 unread compliance updates</p>
                </div>
                <span className="text-[11px] font-semibold text-emerald-700 hover:underline cursor-pointer">
                  Mark all read
                </span>
              </div>

              <div className="divide-y divide-slate-100 max-h-72 overflow-y-auto">
                {notifications.map((item) => (
                  <div
                    key={item.id}
                    className={`p-3 hover:bg-slate-50 transition-colors flex items-start gap-3 text-left ${item.unread ? 'bg-emerald-50/30' : ''
                      }`}
                  >
                    {item.type === 'warning' ? (
                      <div className="p-1.5 rounded-lg bg-amber-50 text-amber-600 shrink-0 mt-0.5">
                        <AlertTriangle className="w-3.5 h-3.5" />
                      </div>
                    ) : item.type === 'success' ? (
                      <div className="p-1.5 rounded-lg bg-emerald-50 text-emerald-600 shrink-0 mt-0.5">
                        <CheckCircle2 className="w-3.5 h-3.5" />
                      </div>
                    ) : (
                      <div className="p-1.5 rounded-lg bg-sky-50 text-sky-600 shrink-0 mt-0.5">
                        <Sparkles className="w-3.5 h-3.5" />
                      </div>
                    )}
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-medium text-slate-800 leading-snug">{item.title}</p>
                      <p className="text-[10px] text-slate-400 mt-0.5">{item.time}</p>
                    </div>
                  </div>
                ))}
              </div>

              <div className="p-2 border-t border-slate-100 text-center">
                <Link
                  to="/reports"
                  onClick={() => setNotificationsOpen(false)}
                  className="text-xs font-semibold text-emerald-700 hover:text-emerald-800"
                >
                  View all activity & audits &rarr;
                </Link>
              </div>
            </div>
          )}
        </div>

        {/* User Profile Pill & Dropdown */}
        <div className="relative" ref={profileRef}>
          <button
            type="button"
            onClick={() => setProfileMenuOpen(!profileMenuOpen)}
            className="flex items-center gap-2.5 p-1.5 sm:px-2.5 rounded-xl hover:bg-slate-100 transition-colors border border-transparent hover:border-slate-200 cursor-pointer"
            aria-label="User account menu"
          >
            {/* User Avatar */}
            <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-emerald-700 to-teal-500 text-white font-semibold text-xs flex items-center justify-center shadow-xs">
              J
            </div>

            {/* User Details (Desktop) */}
            <div className="hidden sm:block text-left">
              <p className="text-xs font-bold text-slate-800 leading-tight">Jabir P k</p>
              <p className="text-[10px] text-emerald-700 font-medium leading-none">QA & Safety Lead</p>
            </div>

            <ChevronDown className="w-3.5 h-3.5 text-slate-400 hidden sm:block" />
          </button>

          {profileMenuOpen && (
            <div className="absolute right-0 mt-2 w-56 bg-white rounded-2xl border border-slate-200 shadow-xl py-1.5 z-50 animate-in fade-in-50 zoom-in-95">
              <div className="px-4 py-3 border-b border-slate-100">
                <p className="text-xs font-bold text-slate-900">Jabir P k</p>
                <p className="text-[11px] text-slate-500 truncate">jabirapk@fsms-org</p>
                <span className="inline-block mt-1 text-[10px] font-semibold px-2 py-0.5 rounded-md bg-emerald-50 text-emerald-700 border border-emerald-200">
                  Lead Auditor (ISO 22000)
                </span>
              </div>

              <div className="py-1">
                <Link
                  to="/profile"
                  onClick={() => setProfileMenuOpen(false)}
                  className="flex items-center gap-2.5 px-4 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50"
                >
                  <User className="w-4 h-4 text-slate-400" />
                  My Profile
                </Link>
                <Link
                  to="/settings"
                  onClick={() => setProfileMenuOpen(false)}
                  className="flex items-center gap-2.5 px-4 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50"
                >
                  <ShieldCheck className="w-4 h-4 text-slate-400" />
                  System Settings
                </Link>
              </div>

              <div className="pt-1 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => {
                    setProfileMenuOpen(false)
                    onLogoutClick?.()
                  }}
                  className="w-full text-left px-4 py-2 text-xs font-semibold text-rose-600 hover:bg-rose-50 cursor-pointer"
                >
                  Sign Out
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}
