import { createClient } from '@supabase/supabase-js'

const url = process.env.VITE_SUPABASE_URL
const key = process.env.VITE_SUPABASE_PUBLISHABLE_KEY

console.log('--- Supabase Connection Verification ---')
console.log('Environment variables present:', {
  VITE_SUPABASE_URL: Boolean(url),
  VITE_SUPABASE_PUBLISHABLE_KEY: Boolean(key)
})

if (!url || !key) {
  console.error('FAILED: One or more environment variables are missing.')
  process.exit(1)
}

const supabase = createClient(url, key)

async function runTest() {
  try {
    console.log('Pinging Supabase services...')
    
    // 1. Auth service probe
    const { data: authData, error: authError } = await supabase.auth.getSession()
    if (authError) {
      console.error('Auth check error:', authError.message)
      process.exit(1)
    }
    console.log('✓ Supabase Auth service reached successfully.')

    // 2. Data API (PostgREST) probe
    const { status, error } = await supabase
      .from('_fsms_connection_probe')
      .select('*', { head: true, count: 'exact' })

    if (status === 401) {
      console.error('FAILED: Unauthorized (HTTP 401). Please check that VITE_SUPABASE_PUBLISHABLE_KEY is correct.')
      process.exit(1)
    }

    console.log(`✓ Supabase Data API (PostgREST) reached successfully (HTTP status: ${status}).`)
    console.log('--- Verification Complete: Connection Successful ---')
  } catch (err) {
    console.error('FAILED: Network or connection error:', err.message)
    process.exit(1)
  }
}

runTest()
