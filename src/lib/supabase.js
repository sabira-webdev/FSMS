import { createClient } from '@supabase/supabase-js'

const supabaseUrl =
  (typeof import.meta !== 'undefined' && import.meta.env?.VITE_SUPABASE_URL) ||
  (typeof process !== 'undefined' && process.env?.VITE_SUPABASE_URL)
const supabasePublishableKey =
  (typeof import.meta !== 'undefined' && import.meta.env?.VITE_SUPABASE_PUBLISHABLE_KEY) ||
  (typeof process !== 'undefined' && process.env?.VITE_SUPABASE_PUBLISHABLE_KEY)

if (!supabaseUrl || !supabasePublishableKey) {
  console.warn('[Supabase] Missing VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY in environment variables.')
}

export const supabase = createClient(supabaseUrl || '', supabasePublishableKey || '')

/**
 * Minimal, safe connection check that does not require any existing database tables or authentication.
 * Probes the Supabase PostgREST endpoint and GoTrue auth service.
 * Returns an object { success: boolean, message: string, status?: number } without exposing credentials.
 */
export async function testSupabaseConnection() {
  try {
    // Probe the PostgREST API without needing existing tables (using head request)
    const { status, error } = await supabase
      .from('_fsms_connection_probe')
      .select('*', { head: true, count: 'exact' })

    // Probe Auth service
    const { error: authError } = await supabase.auth.getSession()
    if (authError) {
      return {
        success: false,
        message: 'Supabase Auth service unreachable: ' + authError.message
      }
    }

    // HTTP 401 indicates invalid credentials (bad publishable key)
    if (status === 401) {
      return {
        success: false,
        message: 'Unauthorized: Invalid Supabase Publishable Key (HTTP 401)',
        status
      }
    }

    // Reaching the PostgREST server (e.g. 200, 404 relation not found, or 400) confirms active connectivity
    return {
      success: true,
      message: 'Successfully reached Supabase project endpoint',
      status: status || 200
    }
  } catch (err) {
    return {
      success: false,
      message: 'Connection failed: ' + (err?.message || 'Network error')
    }
  }
}
