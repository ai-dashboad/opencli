#!/usr/bin/env node
/**
 * E2E Test: Mobile WebSocket Task Submission
 * Connects to daemon on port 9876, authenticates, and submits a task.
 */

const WebSocket = require('ws');
const crypto = require('crypto');

const HOST = 'ws://localhost:9876';
const AUTH_SECRET = 'opencli-dev-secret';
const DEVICE_ID = 'e2e-test-client-001';

function generateAuthToken(deviceId, timestamp) {
  const input = `${deviceId}:${timestamp}:${AUTH_SECRET}`;
  return crypto.createHash('sha256').update(input).digest('hex');
}

async function runTest() {
  console.log('=== E2E Test: Mobile WebSocket Task Submission ===\n');

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      console.log('\n[TIMEOUT] Test timed out after 15s');
      ws.close();
      resolve({ success: false, error: 'timeout' });
    }, 15000);

    console.log(`[1] Connecting to ${HOST}...`);
    const ws = new WebSocket(HOST);

    let authenticated = false;
    let taskSubmitted = false;
    const results = {};

    ws.on('open', () => {
      console.log('[1] PASS - Connected to daemon WebSocket\n');
      results.connection = 'PASS';

      // Step 2: Authenticate
      const timestamp = Date.now();
      const token = generateAuthToken(DEVICE_ID, timestamp);

      console.log(`[2] Authenticating as device: ${DEVICE_ID}...`);
      ws.send(JSON.stringify({
        type: 'auth',
        device_id: DEVICE_ID,
        token: token,
        timestamp: timestamp,
      }));
    });

    ws.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      console.log(`    Received: ${JSON.stringify(msg)}\n`);

      if (msg.type === 'auth_success') {
        authenticated = true;
        console.log('[2] PASS - Authentication successful');
        console.log(`    Server time: ${msg.server_time}`);
        console.log(`    Device ID confirmed: ${msg.device_id}\n`);
        results.auth = 'PASS';

        // Step 3: Submit a task
        console.log('[3] Submitting test task (system_info)...');
        ws.send(JSON.stringify({
          type: 'submit_task',
          task_type: 'system_info',
          task_data: {
            action: 'get_system_info',
            detail_level: 'basic',
          },
          priority: 5,
        }));
      }

      if (msg.type === 'task_submitted') {
        taskSubmitted = true;
        console.log('[3] PASS - Task submission acknowledged by daemon');
        console.log(`    Task type: ${msg.task_type}`);
        console.log(`    Device ID: ${msg.device_id}`);
        console.log(`    Timestamp: ${msg.timestamp}\n`);
        results.taskSubmission = 'PASS';

        // Step 4: Send a heartbeat
        console.log('[4] Sending heartbeat...');
        ws.send(JSON.stringify({ type: 'heartbeat' }));
      }

      if (msg.type === 'heartbeat_ack') {
        console.log('[4] PASS - Heartbeat acknowledged\n');
        results.heartbeat = 'PASS';

        // All tests passed
        console.log('=== TEST RESULTS ===');
        console.log(`  Connection:      ${results.connection}`);
        console.log(`  Authentication:  ${results.auth}`);
        console.log(`  Task Submission: ${results.taskSubmission}`);
        console.log(`  Heartbeat:       ${results.heartbeat}`);
        console.log(`\n  Overall: ALL PASS`);

        clearTimeout(timeout);
        ws.close();
        resolve({ success: true, results });
      }

      if (msg.type === 'error') {
        console.log(`[ERROR] ${msg.message}`);
        results.error = msg.message;
        clearTimeout(timeout);
        ws.close();
        resolve({ success: false, results });
      }
    });

    ws.on('error', (err) => {
      console.log(`[ERROR] WebSocket error: ${err.message}`);
      clearTimeout(timeout);
      reject(err);
    });

    ws.on('close', () => {
      console.log('\n[INFO] WebSocket connection closed');
    });
  });
}

runTest()
  .then((result) => {
    process.exit(result.success ? 0 : 1);
  })
  .catch((err) => {
    console.error('Test failed:', err);
    process.exit(1);
  });
