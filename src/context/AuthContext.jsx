import React, { createContext, useContext, useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'

const AuthContext = createContext(null)

/**
 * Authentication Provider managing active Supabase GoTrue session and user metadata.
 * Gracefully handles missing database profiles table without crashing or bypassing RLS.
 */
export function AuthProvider({ children }) {
  const [session, setSession] = useState(null)
  const [user, setUser] = useState(null)
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [authError, setAuthError] = useState(null)

  // Safe resolver for profile details (falls back to auth user metadata if public.profiles does not exist)
  const resolveProfile = async (currentUser) => {
    if (!currentUser) {
      setProfile(null)
      return null
    }

    const fallbackProfile = {
      id: currentUser.id,
      email: currentUser.email,
      full_name:
        currentUser.user_metadata?.full_name ||
        currentUser.user_metadata?.name ||
        currentUser.email?.split('@')[0] ||
        'Authorized User',
      role: currentUser.user_metadata?.role || 'Quality Personnel',
    }

    try {
      // Attempt query to public.profiles in case it exists in Supabase
      const { data, error: profileErr } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', currentUser.id)
        .maybeSingle()

      if (!profileErr && data) {
        const resolved = {
          ...fallbackProfile,
          ...data,
          full_name: data.full_name || fallbackProfile.full_name,
          role: data.role || fallbackProfile.role,
        }
        setProfile(resolved)
        return resolved
      }
    } catch {
      // Ignore table relation missing or RLS denial gracefully
    }

    setProfile(fallbackProfile)
    return fallbackProfile
  }

  // Restore session on mount and subscribe to auth state changes
  useEffect(() => {
    let mounted = true

    async function initSession() {
      try {
        const { data, error: sessionErr } = await supabase.auth.getSession()
        if (sessionErr) {
          console.warn('[AuthContext] Session retrieval error:', sessionErr.message)
        }
        if (mounted) {
          const currentSession = data?.session || null
          setSession(currentSession)
          setUser(currentSession?.user || null)
          if (currentSession?.user) {
            await resolveProfile(currentSession.user)
          }
        }
      } catch (err) {
        console.warn('[AuthContext] Unexpected session initialization error:', err.message)
      } finally {
        if (mounted) setLoading(false)
      }
    }

    initSession()

    // Listen to Supabase auth events (SIGNED_IN, SIGNED_OUT, TOKEN_REFRESHED)
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
      if (!mounted) return
      setSession(newSession)
      setUser(newSession?.user || null)
      if (newSession?.user) {
        await resolveProfile(newSession.user)
      } else {
        setProfile(null)
      }
      setLoading(false)
    })

    return () => {
      mounted = false
      subscription?.unsubscribe()
    }
  }, [])

  // Sign In using email and password
  const signIn = async (email, password) => {
    setAuthError(null)
    const { data, error } = await supabase.auth.signInWithPassword({
      email: email.trim().toLowerCase(),
      password,
    })

    if (error) {
      setAuthError(error.message)
      throw error
    }

    setSession(data.session)
    setUser(data.user)
    if (data.user) {
      await resolveProfile(data.user)
    }

    return data
  }

  // Sign Out
  const signOut = async () => {
    try {
      await supabase.auth.signOut()
    } catch (err) {
      console.warn('[AuthContext] Sign out error:', err.message)
    } finally {
      setSession(null)
      setUser(null)
      setProfile(null)
    }
  }

  const clearAuthError = () => setAuthError(null)

  return (
    <AuthContext.Provider
      value={{
        session,
        user,
        profile,
        role: profile?.role || 'Quality Personnel',
        loading,
        authError,
        signIn,
        signOut,
        clearAuthError,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
