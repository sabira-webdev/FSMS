import React from 'react'
import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { Shield } from 'lucide-react'

/**
 * Route Guard that requires a valid active Supabase session.
 * Displays a branded loading state while verifying credentials.
 */
export function ProtectedRoute() {
  const { session, loading } = useAuth()
  const location = useLocation()

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-900 flex flex-col items-center justify-center p-4">
        <div className="flex flex-col items-center text-center space-y-4 max-w-sm">
          <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-emerald-600 to-emerald-400 flex items-center justify-center text-white shadow-lg shadow-emerald-950/50 animate-pulse">
            <Shield className="w-6 h-6 fill-white/20" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-white tracking-tight">Food Safety Management System</h3>
            <p className="text-xs text-slate-400 mt-1">Verifying facility access credentials...</p>
          </div>
          <div className="flex items-center gap-1.5 pt-2">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: '0ms' }} />
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: '150ms' }} />
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: '300ms' }} />
          </div>
        </div>
      </div>
    )
  }

  if (!session) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  return <Outlet />
}
