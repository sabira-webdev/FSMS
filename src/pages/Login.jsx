import React, { useState, useEffect } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { Shield, Mail, Lock, Eye, EyeOff, LogIn } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { Button, Input, Alert } from '../components/common'

export function Login() {
  const navigate = useNavigate()
  const location = useLocation()
  const { session, signIn, authError, clearAuthError } = useAuth()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState(null)

  // Target destination after successful login
  const from = location.state?.from?.pathname || '/'

  // If already authenticated, redirect to destination
  useEffect(() => {
    if (session) {
      navigate(from, { replace: true })
    }
  }, [session, navigate, from])

  const handleSubmit = async (e) => {
    e.preventDefault()
    setErrorMessage(null)
    clearAuthError()

    if (!email.trim()) {
      setErrorMessage('Please enter your facility email address.')
      return
    }
    if (!password) {
      setErrorMessage('Please enter your account password.')
      return
    }

    setIsSubmitting(true)
    try {
      await signIn(email, password)
      navigate(from, { replace: true })
    } catch (err) {
      setErrorMessage(err?.message || 'Authentication failed. Please verify your credentials.')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center p-4 sm:p-6 lg:p-8">
      {/* Background Decorative Gradients */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-96 h-96 rounded-full bg-emerald-600/10 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-96 h-96 rounded-full bg-teal-600/10 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md mx-auto space-y-6">
        {/* Brand Header */}
        <div className="text-center space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-emerald-600 to-emerald-400 flex items-center justify-center text-white shadow-xl shadow-emerald-950/60 mx-auto">
            <Shield className="w-7 h-7 fill-white/20" />
          </div>
          <div>
            <div className="text-2xl font-bold tracking-tight text-white flex items-center justify-center gap-2">
              FSMS <span className="text-xs uppercase font-semibold text-emerald-400 bg-emerald-950/80 px-2 py-0.5 rounded border border-emerald-800">Pro</span>
            </div>
            <p className="text-xs text-slate-400 mt-1 font-medium">Food Safety & Compliance Management System</p>
          </div>
        </div>

        {/* Login Card */}
        <div className="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl p-6 sm:p-8 space-y-6">
          <div className="border-b border-slate-800 pb-4">
            <h2 className="text-lg font-bold text-white tracking-tight">Personnel Sign In</h2>
            <p className="text-xs text-slate-400 mt-0.5">
              Authenticate to access audits, compliance rosters, and HACCP logs.
            </p>
          </div>

          {/* Error Notice */}
          {(errorMessage || authError) && (
            <Alert
              type="danger"
              title="Authentication Error"
              onDismiss={() => {
                setErrorMessage(null)
                clearAuthError()
              }}
            >
              {errorMessage || authError}
            </Alert>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email Field */}
            <div className="space-y-1 text-left">
              <label className="text-xs font-semibold text-slate-300 flex items-center gap-1">
                Facility Email Address <span className="text-rose-400">*</span>
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
                  <Mail className="w-4 h-4" />
                </div>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value)
                    if (errorMessage) setErrorMessage(null)
                  }}
                  placeholder="e.g. auditor@fsms-facility.org"
                  required
                  autoComplete="email"
                  className="w-full rounded-lg border border-slate-700 bg-slate-800/80 pl-9 pr-3 py-2 text-sm text-white placeholder:text-slate-500 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-1 text-left">
              <label className="text-xs font-semibold text-slate-300 flex items-center gap-1">
                Password <span className="text-rose-400">*</span>
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
                  <Lock className="w-4 h-4" />
                </div>
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value)
                    if (errorMessage) setErrorMessage(null)
                  }}
                  placeholder="Enter your password"
                  required
                  autoComplete="current-password"
                  className="w-full rounded-lg border border-slate-700 bg-slate-800/80 pl-9 pr-10 py-2 text-sm text-white placeholder:text-slate-500 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-colors"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((prev) => !prev)}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-slate-400 hover:text-slate-200 cursor-pointer"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Sign In Button */}
            <div className="pt-2">
              <Button
                type="submit"
                variant="primary"
                size="md"
                loading={isSubmitting}
                icon={LogIn}
                className="w-full py-2.5 text-sm font-semibold justify-center"
              >
                Sign In to FSMS
              </Button>
            </div>
          </form>

          {/* Security Compliance Note */}
          <div className="pt-4 border-t border-slate-800/80 text-center">
            <p className="text-[11px] text-slate-500 leading-relaxed">
              Authorized access only. All activities, modifications, and CCP logs are cryptographically timestamped and audited in compliance with ISO 22000.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
