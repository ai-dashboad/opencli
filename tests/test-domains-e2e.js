#!/usr/bin/env node
/**
 * E2E Domain Test Script v2 — handles async out-of-order responses
 *
 * Tests all 34 domain task types via WebSocket connection to the daemon.
 * Submits ALL tasks, then waits for ALL responses (handles out-of-order).
 */

const WebSocket = require('ws');
const crypto = require('crypto');

const DAEMON_WS = 'ws://localhost:9876';
const AUTH_SECRET = 'opencli-dev-secret';
const DEVICE_ID = 'e2e-test-device';

function generateToken(timestamp) {
  return crypto.createHash('sha256')
    .update(`${DEVICE_ID}:${timestamp}:${AUTH_SECRET}`)
    .digest('hex');
}

// All 34 domain task types to test
const DOMAIN_TESTS = [
  // Timer domain (4)
  { taskType: 'timer_set', data: { minutes: 1, label: 'E2E Test' }, domain: 'timer' },
  { taskType: 'timer_status', data: {}, domain: 'timer' },
  { taskType: 'timer_cancel', data: {}, domain: 'timer' },
  { taskType: 'timer_pomodoro', data: { minutes: 1 }, domain: 'timer' },

  // Calculator domain (4)
  { taskType: 'calculator_eval', data: { expression: '15 * 7 + 3' }, domain: 'calculator' },
  { taskType: 'calculator_convert', data: { value: 100, from: 'km', to: 'miles' }, domain: 'calculator' },
  { taskType: 'calculator_timezone', data: { location: 'Tokyo' }, domain: 'calculator' },
  { taskType: 'calculator_date_math', data: { days: 30, operation: 'days_from_now' }, domain: 'calculator' },

  // Music domain (6)
  { taskType: 'music_now_playing', data: {}, domain: 'music' },
  { taskType: 'music_play', data: {}, domain: 'music' },
  { taskType: 'music_pause', data: {}, domain: 'music' },
  { taskType: 'music_next', data: {}, domain: 'music' },
  { taskType: 'music_previous', data: {}, domain: 'music' },
  { taskType: 'music_playlist', data: { playlist: 'Test' }, domain: 'music' },

  // Reminders domain (3)
  { taskType: 'reminders_list', data: {}, domain: 'reminders' },
  { taskType: 'reminders_add', data: { title: 'E2E Test Reminder' }, domain: 'reminders' },
  { taskType: 'reminders_complete', data: { title: 'E2E Test Reminder' }, domain: 'reminders' },

  // Calendar domain (3)
  { taskType: 'calendar_list_events', data: { date_raw: 'today' }, domain: 'calendar' },
  { taskType: 'calendar_add_event', data: { title: 'E2E Test Event', datetime_raw: 'tomorrow at 3pm' }, domain: 'calendar' },
  { taskType: 'calendar_delete_event', data: { title: 'E2E Test Event' }, domain: 'calendar' },

  // Notes domain (3)
  { taskType: 'notes_create', data: { title: 'E2E Test Note', body: 'Testing domain system' }, domain: 'notes' },
  { taskType: 'notes_list', data: {}, domain: 'notes' },
  { taskType: 'notes_search', data: { query: 'E2E Test' }, domain: 'notes' },

  // Weather domain (2)
  { taskType: 'weather_current', data: { location: '' }, domain: 'weather' },
  { taskType: 'weather_forecast', data: { location: '' }, domain: 'weather' },

  // Email domain (2)
  { taskType: 'email_check', data: {}, domain: 'email' },
  { taskType: 'email_compose', data: { to: 'test@example.com', subject: 'E2E Test' }, domain: 'email' },

  // Contacts domain (2)
  { taskType: 'contacts_find', data: { name: 'John' }, domain: 'contacts' },
  { taskType: 'contacts_call', data: { name: 'John' }, domain: 'contacts' },

  // Messages domain (1)
  { taskType: 'messages_send', data: { recipient: 'test', message: 'E2E test' }, domain: 'messages' },

  // Translation domain (1)
  { taskType: 'translation_translate', data: { text: 'hello', target_language: 'Spanish' }, domain: 'translation' },

  // Files/Media domain (3)
  { taskType: 'files_compress', data: { path: '/tmp/opencli-e2e-test' }, domain: 'files_media' },
  { taskType: 'files_convert', data: { from_format: 'png', to_format: 'jpg', path: '/tmp' }, domain: 'files_media' },
  { taskType: 'files_organize', data: { path: '/tmp/opencli-e2e-test' }, domain: 'files_media' },
];

// Track pending tasks by task_id
const pendingTasks = new Map(); // task_id -> { taskType, resolve, reject }
const testResults = new Map();  // taskType -> { success, result, error, duration }

async function runTests() {
  console.log('╔══════════════════════════════════════════════════════╗');
  console.log('║   OpenCLI Domain E2E Tests v2 - 34 Task Types       ║');
  console.log('╚══════════════════════════════════════════════════════╝\n');

  // Create test directory for files_media tests
  const { execSync } = require('child_process');
  try {
    execSync('mkdir -p /tmp/opencli-e2e-test && echo "test" > /tmp/opencli-e2e-test/test.txt');
  } catch(e) {}

  return new Promise((resolve, reject) => {
    const ws = new WebSocket(DAEMON_WS);
    let authenticated = false;
    const taskIdMap = new Map(); // task_id -> taskType

    ws.on('open', () => {
      console.log('Connected to daemon');
      const timestamp = Date.now();
      ws.send(JSON.stringify({
        type: 'auth',
        device_id: DEVICE_ID,
        token: generateToken(timestamp),
        timestamp: timestamp,
        device_name: 'E2E Test Runner v2',
        platform: 'test',
      }));
    });

    ws.on('message', (raw) => {
      const msg = JSON.parse(raw.toString());

      if (msg.type === 'auth_success') {
        authenticated = true;
        console.log('Authenticated\n');
        // Submit ALL tasks sequentially with small delay
        submitAllTasks(ws, taskIdMap);
        return;
      }

      if (msg.type === 'task_submitted') {
        const taskId = msg.task_id || `${DEVICE_ID}_${msg.timestamp}`;
        const taskType = msg.task_type;
        taskIdMap.set(taskId, taskType);
        return;
      }

      if (msg.type === 'task_update') {
        if (msg.status === 'running') return; // Skip running status

        const taskId = msg.task_id;
        // Find which taskType this belongs to
        let taskType = taskIdMap.get(taskId);
        if (!taskType) {
          // Try to infer from result
          taskType = msg.result?.domain ? `${msg.result.domain}_unknown` : 'unknown';
        }

        if (msg.status === 'completed' || msg.status === 'failed' || msg.status === 'denied') {
          const result = msg.result || {};
          const success = result.success === true;
          const error = msg.error || result.error;

          if (!testResults.has(taskType)) {
            testResults.set(taskType, {
              success,
              result: JSON.stringify(result).substring(0, 200),
              error: error || null,
              status: msg.status,
            });

            const icon = success ? '✅' : '❌';
            const detail = success
              ? JSON.stringify(result).substring(0, 100)
              : (error || 'failed');
            console.log(`  ${icon} ${taskType}: ${detail}`);
          }

          // Check if all done
          if (testResults.size >= DOMAIN_TESTS.length) {
            setTimeout(() => {
              printSummary();
              ws.close();
              resolve();
            }, 1000);
          }
        }
      }
    });

    ws.on('error', (err) => {
      console.error('WebSocket error:', err.message);
      reject(err);
    });

    // Global timeout — 120s should be enough for all AppleScript tasks
    setTimeout(() => {
      console.log('\n⏱ Global timeout reached (120s)');
      printSummary();
      ws.close();
      resolve();
    }, 120000);
  });
}

async function submitAllTasks(ws, taskIdMap) {
  console.log(`Submitting ${DOMAIN_TESTS.length} tasks...\n`);

  for (let i = 0; i < DOMAIN_TESTS.length; i++) {
    const test = DOMAIN_TESTS[i];
    const timestamp = Date.now();
    const taskId = `${DEVICE_ID}_${timestamp}`;

    taskIdMap.set(taskId, test.taskType);

    ws.send(JSON.stringify({
      type: 'submit_task',
      task_type: test.taskType,
      task_data: test.data,
    }));

    // Small delay between submissions to avoid overwhelming
    await new Promise(r => setTimeout(r, 200));
  }

  console.log(`All ${DOMAIN_TESTS.length} tasks submitted. Waiting for results...\n`);
}

function printSummary() {
  let passed = 0, failed = 0, missing = 0;

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('                  DETAILED RESULTS');
  console.log('═══════════════════════════════════════════════════════\n');

  // Group by domain
  const domains = {};
  for (const test of DOMAIN_TESTS) {
    if (!domains[test.domain]) domains[test.domain] = [];
    const result = testResults.get(test.taskType);
    domains[test.domain].push({ ...test, result });
  }

  for (const [domain, tests] of Object.entries(domains)) {
    console.log(`  ${domain.toUpperCase()}`);
    for (const t of tests) {
      if (t.result) {
        const icon = t.result.success ? '✅' : '❌';
        if (t.result.success) passed++;
        else failed++;
        const detail = t.result.success
          ? t.result.result.substring(0, 80)
          : (t.result.error || 'failed');
        console.log(`    ${icon} ${t.taskType}: ${detail}`);
      } else {
        missing++;
        console.log(`    ⏱ ${t.taskType}: No response (AppleScript timeout)`);
      }
    }
    console.log();
  }

  console.log('═══════════════════════════════════════════════════════');
  console.log('                    TEST SUMMARY');
  console.log('═══════════════════════════════════════════════════════');
  console.log(`  Total:      ${DOMAIN_TESTS.length}`);
  console.log(`  ✅ PASS:     ${passed}`);
  console.log(`  ❌ FAIL:     ${failed}`);
  console.log(`  ⏱ TIMEOUT:  ${missing}`);
  console.log(`  Pass Rate:  ${Math.round(passed / DOMAIN_TESTS.length * 100)}%`);
  console.log(`  Exec Rate:  ${Math.round((passed + failed) / DOMAIN_TESTS.length * 100)}%`);
  console.log('═══════════════════════════════════════════════════════\n');

  // Write JSON report
  const fs = require('fs');
  const allResults = {};
  for (const test of DOMAIN_TESTS) {
    allResults[test.taskType] = testResults.get(test.taskType) || { status: 'timeout' };
  }
  const report = {
    timestamp: new Date().toISOString(),
    summary: { total: DOMAIN_TESTS.length, passed, failed, timeout: missing },
    results: allResults,
  };
  fs.writeFileSync('/Users/cw/development/opencli/test-results/domain_e2e_results.json', JSON.stringify(report, null, 2));
  console.log('Results: test-results/domain_e2e_results.json');
}

runTests().catch(console.error);
