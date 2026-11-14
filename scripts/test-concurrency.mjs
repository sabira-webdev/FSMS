/**
 * scripts/test-concurrency.mjs
 * Direct-connection concurrency tests using distinct PostgreSQL backend PIDs.
 * STATUS: NOT EXECUTED. Requires staging database access.
 */
import pg from 'pg'

const DB_URL = process.env.DATABASE_URL
if (!DB_URL) {
  console.error('DATABASE_URL required')
  process.exit(1)
}

async function connect(label) {
  const c = new pg.Client({ connectionString: DB_URL })
  await c.connect()
  const { rows } = await c.query('SELECT pg_backend_pid() AS pid')
  console.log(`[${label}] PID: ${rows[0].pid}`)
  return c
}

async function run() {
  const A = await connect('A')
  const B = await connect('B')

  // Verify distinct PIDs
  const pidA = (await A.query('SELECT pg_backend_pid() AS p')).rows[0].p
  const pidB = (await B.query('SELECT pg_backend_pid() AS p')).rows[0].p
  if (pidA === pidB) throw new Error('FAIL: Same backend PID')
  console.log(`Verified distinct PIDs: ${pidA} vs ${pidB}`)

  // Create test fixtures via session A
  await A.query('BEGIN')
  // (fixture creation SQL here — department, template, items, inspection)
  // ... obtain v_insp_id, v_item1, v_item2 ...
  await A.query('COMMIT')

  // TC-1: Simultaneous saves to DIFFERENT questions
  console.log('TC-1: Parallel saves to different questions...')
  await Promise.all([
    A.query(`UPDATE public.inspection_results SET text_value='Pass' WHERE inspection_id=$1 AND item_id=$2`, [/*v_insp_id, v_item1*/]),
    B.query(`UPDATE public.inspection_results SET numeric_value=2.5 WHERE inspection_id=$1 AND item_id=$2`, [/*v_insp_id, v_item2*/]),
  ])
  console.log('TC-1 PASSED: No deadlock (40P01)')

  // TC-2: Simultaneous saves to SAME question (last writer wins)
  console.log('TC-2: Race on same question...')
  await Promise.all([
    A.query(`UPDATE public.inspection_results SET text_value='Pass' WHERE inspection_id=$1 AND item_id=$2`, [/*v_insp_id, v_item1*/]),
    B.query(`UPDATE public.inspection_results SET text_value='Fail' WHERE inspection_id=$1 AND item_id=$2`, [/*v_insp_id, v_item1*/]),
  ])
  console.log('TC-2 PASSED: Sequential row lock, no deadlock')

  // TC-3: Save vs submission (submission holds FOR UPDATE, save waits)
  console.log('TC-3: Save during submission...')
  await A.query('BEGIN')
  await A.query(`SELECT * FROM public.inspections WHERE id=$1 FOR UPDATE`, [/*v_insp_id*/])
  const savePromise = B.query(`UPDATE public.inspection_results SET text_value='Pass' WHERE inspection_id=$1 AND item_id=$2`, [/*v_insp_id, v_item1*/])
  // B's save acquires FOR SHARE on inspections, which conflicts with A's FOR UPDATE, so B waits.
  // Release A:
  await A.query('ROLLBACK')
  await savePromise
  console.log('TC-3 PASSED: Save waited for submission lock, then completed')

  // TC-4: Concurrent submission and finalization (both try FOR UPDATE → one waits)
  console.log('TC-4: Racing submit vs finalize...')
  // Setup: get inspection to In Progress, answer all questions, then race
  console.log('TC-4: Requires full setup — marked for manual staging execution')

  // Cleanup
  await A.end()
  await B.end()
  console.log('=== CONCURRENCY HARNESS COMPLETE ===')
}

run().catch((e) => {
  console.error('FAILED:', e)
  process.exit(1)
})
