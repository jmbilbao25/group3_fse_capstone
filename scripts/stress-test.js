/**
 * ============================================================================
 * FSE Capstone: High-Concurrency Stress & Server Saturation Test Suite
 * ============================================================================
 * Generates massive concurrent traffic against the Spring Cloud Gateway and
 * downstream microservices (Account Service, Ledger Mutation Engine, Redis, Oracle XE).
 *
 * Configurable via environment variables or CLI flags:
 *   CONCURRENCY : Number of parallel worker streams (default: 100)
 *   DURATION    : Test run duration in seconds (default: 30)
 *   BURST_COUNT : Instantaneous burst attack volume (default: 500)
 *   GATEWAY_URL : Target edge gateway URL (default: http://localhost:8080)
 *   HAMMER_AUTH : Ratio of CPU-intensive BCrypt login calls (default: 0.15)
 *
 * Examples:
 *   node scripts/stress-test.js
 *   CONCURRENCY=200 DURATION=45 node scripts/stress-test.js
 * ============================================================================
 */

const http = require('http');
const https = require('https');

// Custom agents with keepAlive and high socket pool to prevent client-side bottlenecks
const httpAgent = new http.Agent({ keepAlive: true, maxSockets: 1000 });
const httpsAgent = new https.Agent({ keepAlive: true, maxSockets: 1000 });

const GATEWAY_URL = process.env.GATEWAY_URL || 'http://localhost:8080';
const CONCURRENCY = parseInt(process.env.CONCURRENCY, 10) || 100;
const DURATION_SECONDS = parseInt(process.env.DURATION, 10) || 30;
const BURST_COUNT = parseInt(process.env.BURST_COUNT, 10) || 500;
const HAMMER_AUTH_RATIO = parseFloat(process.env.HAMMER_AUTH) || 0.15;

const TEST_USERS = [
  { email: 'juan.dc@email.com', password: 'password123' },
  { email: 'beatriz.ocampo@bank.com', password: 'password123' },
  { email: 'diana.admin@bank.com', password: 'password123' }
];

// Helper: Percentile calculation
function getPercentile(arr, p) {
  if (!arr || arr.length === 0) return '0.00';
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = Math.min(Math.floor((p / 100) * sorted.length), sorted.length - 1);
  return sorted[idx].toFixed(2);
}

// Helper: Micro-sleep
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function runStressSuite() {
  console.log('================================================================');
  console.log('[SUITE] FSE Banking Platform High-Throughput Stress Test');
  console.log(`[TARGET] Gateway Endpoint : ${GATEWAY_URL}`);
  console.log(`[CONFIG] Concurrency      : ${CONCURRENCY} parallel workers`);
  console.log(`[CONFIG] Duration         : ${DURATION_SECONDS} seconds`);
  console.log(`[CONFIG] Burst Attack     : ${BURST_COUNT} instant requests`);
  console.log(`[CONFIG] Auth Hammer Rate : ${(HAMMER_AUTH_RATIO * 100).toFixed(0)}% (CPU BCrypt load)`);
  console.log('================================================================\n');

  // --------------------------------------------------------------------------
  // Phase 1: Authentication & Token Acquisition
  // --------------------------------------------------------------------------
  console.log('[PHASE 1/3] Authenticating seed personas to obtain Bearer tokens...');
  const tokens = [];
  for (const user of TEST_USERS) {
    const t0 = performance.now();
    try {
      const res = await fetch(`${GATEWAY_URL}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(user)
      });
      const dur = (performance.now() - t0).toFixed(2);
      if (res.ok) {
        const body = await res.json();
        tokens.push(body.access_token);
        console.log(`  [AUTH_OK] ${user.email} -> JWT acquired (${dur}ms, Role: ${body.role || 'N/A'})`);
      } else {
        console.log(`  [AUTH_FAIL] ${user.email} -> HTTP ${res.status}`);
      }
    } catch (err) {
      console.log(`  [AUTH_ERR] ${user.email} -> ${err.message}`);
    }
  }

  if (tokens.length === 0) {
    console.error('\n[FATAL] No JWT tokens acquired. Verify services are running on port 8080.');
    process.exit(1);
  }

  const primaryToken = tokens[0];

  // --------------------------------------------------------------------------
  // Phase 2: Instantaneous Burst Flood (Stress Redis Rate Limiter & Concurrency)
  // --------------------------------------------------------------------------
  console.log(`\n[PHASE 2/3] Firing burst flood of ${BURST_COUNT} simultaneous requests...`);
  const burstStart = performance.now();
  const burstPromises = Array.from({ length: BURST_COUNT }, (_, idx) => {
    const t0 = performance.now();
    return fetch(`${GATEWAY_URL}/api/v1/accounts`, {
      headers: { Authorization: `Bearer ${primaryToken}` }
    })
      .then((res) => ({
        index: idx + 1,
        status: res.status,
        latency: performance.now() - t0
      }))
      .catch((err) => ({
        index: idx + 1,
        status: 0,
        error: err.code || err.message,
        latency: performance.now() - t0
      }));
  });

  const burstResults = await Promise.all(burstPromises);
  const burstDuration = (performance.now() - burstStart).toFixed(2);
  const burstStatusMap = {};
  burstResults.forEach((r) => {
    const key = r.status === 0 ? `ERR (${r.error})` : `HTTP ${r.status}`;
    burstStatusMap[key] = (burstStatusMap[key] || 0) + 1;
  });

  console.log(`  [BURST_COMPLETE] ${BURST_COUNT} requests sent in ${burstDuration}ms`);
  console.log('  [BURST_STATUS_BREAKDOWN]');
  Object.keys(burstStatusMap).sort().forEach((k) => {
    console.log(`    - ${k}: ${burstStatusMap[k]} requests`);
  });

  // --------------------------------------------------------------------------
  // Phase 3: Massive Sustained Saturation & Server Stress Flood
  // --------------------------------------------------------------------------
  console.log(`\n[PHASE 3/3] Launching sustained saturation flood (${CONCURRENCY} workers, ${DURATION_SECONDS}s)...`);
  console.log('  [INFO] Targets: /actuator/health, /api/v1/accounts, /api/v1/accounts/1000-2000-3001, /api/v1/ledger/audit, /api/v1/auth/login');

  const startTime = Date.now();
  const endTime = startTime + DURATION_SECONDS * 1000;

  const latencies = [];
  const statusCounts = {};
  let totalRequests = 0;
  let connectionErrors = 0;

  // Real-time progress logger
  let lastReportTime = startTime;
  let lastReportRequests = 0;

  const progressInterval = setInterval(() => {
    const now = Date.now();
    const elapsedSec = ((now - startTime) / 1000).toFixed(1);
    const windowSec = (now - lastReportTime) / 1000;
    const windowRequests = totalRequests - lastReportRequests;
    const currentRps = (windowRequests / (windowSec || 1)).toFixed(0);

    const okCount = statusCounts['200'] || 0;
    const rateLimitCount = statusCounts['429'] || 0;
    const errCount = (statusCounts['500'] || 0) + (statusCounts['502'] || 0) + (statusCounts['503'] || 0) + (statusCounts['504'] || 0) + connectionErrors;

    process.stdout.write(
      `  [PROGRESS] Elapsed: ${elapsedSec}s / ${DURATION_SECONDS}s | Total Req: ${totalRequests.toLocaleString()} | Speed: ${currentRps} req/s | 200: ${okCount} | 429: ${rateLimitCount} | Err/5xx: ${errCount}\r`
    );

    lastReportTime = now;
    lastReportRequests = totalRequests;
  }, 2000);

  // Worker task: fires unthrottled requests back-to-back
  async function worker(workerId) {
    let reqCounter = 0;
    while (Date.now() < endTime) {
      reqCounter++;
      const userToken = tokens[workerId % tokens.length];

      // Distribute request types across diverse microservice operations
      const rand = Math.random();
      let url = `${GATEWAY_URL}/api/v1/accounts`;
      let method = 'GET';
      let headers = { Authorization: `Bearer ${userToken}` };
      let body = undefined;

      if (rand < HAMMER_AUTH_RATIO) {
        // CPU-intensive BCrypt authentication hammer
        url = `${GATEWAY_URL}/api/v1/auth/login`;
        method = 'POST';
        headers = { 'Content-Type': 'application/json' };
        body = JSON.stringify(TEST_USERS[workerId % TEST_USERS.length]);
      } else if (rand < 0.40) {
        // Deep account entity lookup
        url = `${GATEWAY_URL}/api/v1/accounts/1000-2000-3001`;
      } else if (rand < 0.65) {
        // PostgreSQL audit ledger query
        url = `${GATEWAY_URL}/api/v1/ledger/audit`;
      } else if (rand < 0.85) {
        // Fast Gateway health probe
        url = `${GATEWAY_URL}/actuator/health`;
        headers = {};
      }

      const t0 = performance.now();
      try {
        const res = await fetch(url, {
          method,
          headers,
          body
        });
        const duration = performance.now() - t0;
        latencies.push(duration);
        totalRequests++;

        const code = String(res.status);
        statusCounts[code] = (statusCounts[code] || 0) + 1;
      } catch (err) {
        totalRequests++;
        connectionErrors++;
        const errKey = `ERR_${err.code || 'UNKNOWN'}`;
        statusCounts[errKey] = (statusCounts[errKey] || 0) + 1;
      }
    }
  }

  // Launch all workers in parallel
  const workerPromises = Array.from({ length: CONCURRENCY }, (_, i) => worker(i));
  await Promise.all(workerPromises);

  clearInterval(progressInterval);
  process.stdout.write('\n'); // Clear carriage return

  const totalTimeSec = ((Date.now() - startTime) / 1000).toFixed(2);
  const overallRps = (totalRequests / (parseFloat(totalTimeSec) || 1)).toFixed(1);

  // --------------------------------------------------------------------------
  // Summary & Breakdown
  // --------------------------------------------------------------------------
  console.log('\n================================================================');
  console.log('[RESULTS] HIGH-CONCURRENCY STRESS TEST SUMMARY');
  console.log('================================================================');
  console.log(`Execution Duration       : ${totalTimeSec} seconds`);
  console.log(`Active Parallel Streams  : ${CONCURRENCY} workers`);
  console.log(`Total Requests Processed : ${totalRequests.toLocaleString()}`);
  console.log(`Sustained Throughput     : ${overallRps} requests/second`);
  console.log('----------------------------------------------------------------');
  console.log('HTTP STATUS & OUTCOME DISTRIBUTION:');

  const sortedStatuses = Object.keys(statusCounts).sort();
  for (const status of sortedStatuses) {
    const count = statusCounts[status];
    const pct = ((count / totalRequests) * 100).toFixed(2);
    let description = '';
    if (status === '200') description = '[SUCCESS] Allowed & Processed';
    else if (status === '429') description = '[DEFENSE] Throttled by Redis Token-Bucket Limiter';
    else if (status === '401') description = '[AUTH] Unauthorized / Token Expired';
    else if (status === '500') description = '[SERVER_ERROR] Internal Service Exception';
    else if (status === '502') description = '[BAD_GATEWAY] Downstream Microservice Offline / Unreachable';
    else if (status === '503') description = '[UNAVAILABLE] Server Overloaded / Thread Pool Saturated';
    else if (status === '504') description = '[GATEWAY_TIMEOUT] Downstream Service Exceeded SLA Timeout';
    else if (status.startsWith('ERR_')) description = '[SOCKET_FAILURE] Connection Dropped or Refused';
    else description = '[OTHER]';

    console.log(`  - ${status.padEnd(16)} : ${String(count).padStart(8)} (${pct.padStart(6)}%) -> ${description}`);
  }

  console.log('----------------------------------------------------------------');
  console.log('LATENCY PERCENTILE DISTRIBUTION (Milliseconds):');
  console.log(`  Min Latency            : ${getPercentile(latencies, 0).padStart(8)} ms`);
  console.log(`  P50 (Median)           : ${getPercentile(latencies, 50).padStart(8)} ms`);
  console.log(`  P90                    : ${getPercentile(latencies, 90).padStart(8)} ms`);
  console.log(`  P95                    : ${getPercentile(latencies, 95).padStart(8)} ms`);
  console.log(`  P99                    : ${getPercentile(latencies, 99).padStart(8)} ms`);
  console.log(`  Max Latency            : ${getPercentile(latencies, 100).padStart(8)} ms`);
  console.log('================================================================');
  console.log('[TELEMETRY] Datadog APM & Service Map:');
  console.log('  Live traces: https://app.datadoghq.com/apm/traces');
  console.log('  Check services: gateway-service, account-service, ledger-mutation-engine');
  console.log('================================================================\n');
}

runStressSuite().catch((err) => {
  console.error('[FATAL_ERROR]', err);
  process.exit(1);
});
