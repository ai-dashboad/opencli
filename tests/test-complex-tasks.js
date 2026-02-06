#!/usr/bin/env node
// Test complex daily tasks via WebSocket
const WebSocket = require('ws');
const crypto = require('crypto');

const WS_URL = 'ws://localhost:9876';
const SECRET = 'opencli-dev-secret';
const DEVICE_ID = 'test-complex-01';

function genToken() {
  const ts = Math.floor(Date.now() / 30000) * 30000;
  return crypto.createHash('sha256').update(`${SECRET}:${ts}`).digest('hex');
}

const tasks = [
  { name: 'show_largest_files', type: 'run_command', data: { command: 'bash', args: ['-c', 'du -sh ~/Desktop ~/Downloads ~/Documents ~/Pictures 2>/dev/null | sort -rh'] } },
  { name: 'show_listening_ports', type: 'run_command', data: { command: 'bash', args: ['-c', 'lsof -i -P -n | grep LISTEN | head -15'] } },
  { name: 'monitor_cpu', type: 'run_command', data: { command: 'bash', args: ['-c', 'top -l 1 -n 5 | head -15'] } },
  { name: 'toggle_dark_mode', type: 'run_command', data: { command: 'osascript', args: ['-e', 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'] } },
  { name: 'git_log', type: 'run_command', data: { command: 'bash', args: ['-c', 'cd /Users/cw/development/opencli && git log --oneline --graph --decorate -10'] } },
  { name: 'set_volume_50', type: 'run_command', data: { command: 'osascript', args: ['-e', 'set volume output volume 50'] } },
  { name: 'blocked_rm_rf', type: 'run_command', data: { command: 'rm', args: ['-rf', '/'] } },
  { name: 'get_hostname', type: 'run_command', data: { command: 'bash', args: ['-c', 'hostname && echo "---" && whoami && echo "---" && date'] } },
  { name: 'memory_usage', type: 'run_command', data: { command: 'bash', args: ['-c', 'vm_stat | head -10 && echo "---" && sysctl hw.memsize'] } },
  { name: 'wifi_info', type: 'run_command', data: { command: 'bash', args: ['-c', 'networksetup -getairportnetwork en0 && echo "---" && ifconfig en0 | grep "inet "'] } },
];

let ws;
let taskIndex = 0;
let results = {};
let authenticated = false;

let taskTimer = null;

function submitNextTask() {
  if (taskIndex >= tasks.length) {
    printResults();
    ws.close();
    process.exit(0);
    return;
  }

  const task = tasks[taskIndex];
  const taskId = `complex-${taskIndex + 1}`;

  console.log(`\n--- Test ${taskIndex + 1}/${tasks.length}: ${task.name} ---`);

  // Per-task timeout of 30s
  if (taskTimer) clearTimeout(taskTimer);
  taskTimer = setTimeout(() => {
    console.log(`  TIMEOUT: Task ${task.name} timed out after 30s`);
    results[task.name] = { success: false, error: 'Per-task timeout (30s)' };
    taskIndex++;
    submitNextTask();
  }, 30000);

  ws.send(JSON.stringify({
    type: 'submit_task',
    task_type: task.type,
    task_data: task.data,
    task_id: taskId,
  }));
}

function printResults() {
  console.log('\n\n========================================');
  console.log('       COMPLEX TASK TEST RESULTS');
  console.log('========================================\n');

  let passed = 0, failed = 0, blocked = 0;

  for (const [name, r] of Object.entries(results)) {
    const status = r.blocked ? 'BLOCKED' : (r.success ? 'PASS' : 'FAIL');
    if (r.blocked) blocked++;
    else if (r.success) passed++;
    else failed++;

    console.log(`[${status}] ${name}`);
    if (r.command) console.log(`  Cmd: ${r.command.substring(0, 120)}`);
    if (r.stdout) console.log(`  Out: ${r.stdout.substring(0, 200).replace(/\n/g, ' | ')}`);
    if (r.stderr && r.stderr.trim()) console.log(`  Err: ${r.stderr.substring(0, 100).replace(/\n/g, ' | ')}`);
    if (r.error) console.log(`  Error: ${r.error}`);
    if (r.exit_code !== undefined && r.exit_code !== null) console.log(`  Exit: ${r.exit_code}`);
    console.log('');
  }

  console.log(`\nSummary: ${passed} PASSED, ${blocked} BLOCKED (expected), ${failed} FAILED / ${tasks.length} total`);
}

ws = new WebSocket(WS_URL);

ws.on('open', () => {
  console.log('Connected to daemon WS');
  const ts = Date.now();
  const tokenInput = `${DEVICE_ID}:${ts}:${SECRET}`;
  const authMsg = {
    type: 'auth',
    device_id: DEVICE_ID,
    token: crypto.createHash('sha256').update(tokenInput).digest('hex'),
    timestamp: ts,
    device_name: 'Complex Task Tester',
    platform: 'test',
  };
  console.log('Sending auth...');
  ws.send(JSON.stringify(authMsg));
});

ws.on('message', (data) => {
  const msg = JSON.parse(data.toString());
  console.log(`  << ${JSON.stringify(msg).substring(0, 300)}`);

  if (msg.type === 'auth_success') {
    console.log('Auth OK!');
    authenticated = true;
    submitNextTask();
    return;
  }

  if (msg.type === 'auth_required') {
    console.log('Auth required - retrying with simple token...');
    const ts2 = Math.floor(Date.now() / 30000) * 30000;
    const input2 = `${DEVICE_ID}:${ts2}:${SECRET}`;
    const simpleToken = input2.split('').reduce((a,c) => ((a << 5) - a + c.charCodeAt(0)) | 0, 0).toString(16);
    ws.send(JSON.stringify({
      type: 'auth',
      device_id: DEVICE_ID,
      token: simpleToken,
      timestamp: ts2,
      device_name: 'Complex Task Tester',
      platform: 'test',
    }));
    return;
  }

  if (msg.type === 'task_update') {
    if (taskTimer && (msg.status === 'completed' || msg.status === 'denied' || msg.status === 'error' || msg.status === 'failed')) {
      clearTimeout(taskTimer);
      taskTimer = null;
    }
    if (msg.status === 'completed') {
      const task = tasks[taskIndex];
      results[task.name] = msg.result || {};
      console.log(`  Result: ${msg.result?.success ? 'OK' : 'FAIL'}${msg.result?.blocked ? ' BLOCKED' : ''}`);
      taskIndex++;
      setTimeout(submitNextTask, 300);
    } else if (msg.status === 'denied') {
      const task = tasks[taskIndex];
      results[task.name] = { success: false, error: msg.error || 'denied' };
      console.log(`  DENIED: ${msg.error}`);
      taskIndex++;
      setTimeout(submitNextTask, 300);
    } else if (msg.status === 'error' || msg.status === 'failed') {
      const task = tasks[taskIndex];
      results[task.name] = { success: false, error: msg.error || msg.status };
      console.log(`  ${msg.status.toUpperCase()}: ${msg.error}`);
      taskIndex++;
      setTimeout(submitNextTask, 300);
    }
  }
});

ws.on('error', (err) => {
  console.error('WS Error:', err.message);
  process.exit(1);
});

ws.on('close', () => {
  console.log('WS Closed');
  if (taskIndex < tasks.length) {
    printResults();
    process.exit(1);
  }
});

setTimeout(() => {
  console.log('\nTIMEOUT after 90s');
  printResults();
  process.exit(1);
}, 90000);
