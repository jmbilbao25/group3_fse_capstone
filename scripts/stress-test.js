/**
 * ============================================================================
 * FSE Capstone: High-Throughput Performance & Stress Testing Suite
 * ============================================================================
 * Generates concurrent load against the API Gateway & Microservices,
 * exercising JWT auth, Redis rate limiting, and CME concurrency locks while
 * populating live APM waterfall traces in Datadog.
 */

const GATEWAY_URL = process.env.GATEWAY_URL || 'http://localhost:8080';

// Configuration
const CONFIG = {
  loginUsers: [
    { email: 'juan.dc@email.com', password: 'password123' },
    { email: 'maria.reyes@eastwestbanker.com', password: 'password123' },
    { email: 'diana.admin@bank.com', password: 'password123' }
  ],
  warmupRequests: 10,
  stressConcurrency: 25,
  stressDurationSeconds: 15,
  burstBurstCount: 40 // Exceeds Redis burst capacity (20) to test 429 throttling
};

// Utilities
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const percentile = (arr, p) => {
  if (arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = Math.min(Math.floor((p / 100) * sorted.length), sorted.length - 1);
  return sorted[idx].toFixed(2);
};

// Main Runner
async function runSuite() {
  console.log('================================================================');
  console.log('🚀 FSE Banking Platform: Datadog APM Stress & Load Test Suite');
  console.log(`🎯 Target Edge Gateway: ${GATEWAY_URL}`);
  console.log('================================================================\n');

  // Phase 1: Authentication & Token Acquisition
  console.log('🔑 [Phase 1/4] Authenticating test clients & acquiring JWTs...');
  const tokens = [];
  for (const user of CONFIG.loginUsers) {
    const start = performance.now();
    try {
      const res = await fetch(`${GATEWAY_URL}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(user)
      });
      const duration = (performance.now() - start).toFixed(2);
      if (res.ok) {
        const body = await res.json();
        tokens.push(body.access_token);
        console.log(`   ✅ ${user.email} -> Logged in (${duration}ms) | Role: ${body.role}`);
      } else {
        console.log(`   ❌ ${user.email} -> Failed (${res.status})`);
      }
    } catch (err) {
      console.log(`   ❌ Connection error for ${user.email}: ${err.message}`);
    }
  }

  if (tokens.length === 0) {
    console.error('\n❌ No valid JWT tokens acquired. Ensure services are running.');
    process.exit(1);
  }

  const primaryToken = tokens[0];

  // Phase 2: Gateway Health & Baseline Latency Probe
  console.log('\n🩺 [Phase 2/4] Measuring baseline SLA latency (10 sequential probes)...');
  const baselineLatencies = [];
  for (let i = 0; i < 10; i++) {
    const t0 = performance.now();
    const res = await fetch(`${GATEWAY_URL}/actuator/health`);
    const lat = performance.now() - t0;
    if (res.ok) baselineLatencies.push(lat);
    await sleep(50);
  }
  console.log(`   📊 Health SLA: Min: ${percentile(baselineLatencies, 0)}ms | P50: ${percentile(baselineLatencies, 50)}ms | P95: ${percentile(baselineLatencies, 95)}ms`);

  // Phase 3: Redis Rate Limiter & Burst Attack Defense
  console.log(`\n🛡️ [Phase 3/4] Testing Redis Rate Limiter defense (${CONFIG.burstBurstCount} simultaneous burst requests)...`);
  const burstStart = performance.now();
  const burstPromises = Array.from({ length: CONFIG.burstBurstCount }, (_, i) => {
    const t0 = performance.now();
    return fetch(`${GATEWAY_URL}/api/v1/accounts`, {
      headers: { Authorization: `Bearer ${primaryToken}` }
    }).then((res) => ({
      index: i + 1,
      status: res.status,
      duration: performance.now() - t0
    })).catch((err) => ({
      index: i + 1,
      status: 0,
      error: err.message
    }));
  });

  const burstResults = await Promise.all(burstPromises);
  const statusCounts = {};
  burstResults.forEach((r) => {
    statusCounts[r.status] = (statusCounts[r.status] || 0) + 1;
  });

  console.log(`   ⏱️  Burst complete in ${(performance.now() - burstStart).toFixed(2)}ms`);
  console.log(`   📊 HTTP Status Breakdown:`);
  Object.keys(statusCounts).sort().forEach((status) => {
    const label = status === '200' ? 'OK (Allowed by Token Bucket)' : status === '429' ? 'RATE LIMITED (Redis 429 Defense Triggered!)' : 'Other';
    console.log(`      * HTTP ${status}: ${statusCounts[status]} requests -> ${label}`);
  });

  // Phase 4: Sustained Concurrency & High Throughput Stress Test
  console.log(`\n⚡ [Phase 4/4] Running sustained load (${CONFIG.stressConcurrency} concurrent workers for ${CONFIG.stressDurationSeconds}s)...`);
  const endTime = Date.now() + CONFIG.stressDurationSeconds * 1000;
  const latencies = [];
  let totalRequests = 0;
  let successRequests = 0;
  let rateLimitedRequests = 0;
  let failedRequests = 0;

  async function worker(workerId) {
    while (Date.now() < endTime) {
      const userToken = tokens[workerId % tokens.length];
      const endpoint = workerId % 2 === 0 ? `${GATEWAY_URL}/api/v1/accounts` : `${GATEWAY_URL}/actuator/health`;
      const headers = workerId % 2 === 0 ? { Authorization: `Bearer ${userToken}` } : {};

      const t0 = performance.now();
      try {
        const res = await fetch(endpoint, { headers });
        const dur = performance.now() - t0;
        latencies.push(dur);
        totalRequests++;

        if (res.status === 200) {
          successRequests++;
        } else if (res.status === 429) {
          rateLimitedRequests++;
        } else {
          failedRequests++;
        }
      } catch (err) {
        failedRequests++;
      }
      // Micro-pause to prevent socket pool exhaustion
      await sleep(10);
    }
  }

  const workers = Array.from({ length: CONFIG.stressConcurrency }, (_, i) => worker(i));
  await Promise.all(workers);

  const durationSec = CONFIG.stressDurationSeconds;
  const rps = (totalRequests / durationSec).toFixed(1);

  console.log('\n================================================================');
  console.log('📊 BENCHMARK & STRESS SUMMARY RESULTS');
  console.log('================================================================');
  console.log(`⏱️  Total Duration       : ${durationSec} seconds`);
  console.log(`📦 Total HTTP Requests   : ${totalRequests.toLocaleString()}`);
  console.log(`🚀 Throughput            : ${rps} requests/second`);
  console.log(`✅ Successful (200 OK)   : ${successRequests.toLocaleString()} (${((successRequests / totalRequests) * 100).toFixed(1)}%)`);
  console.log(`🛑 Rate Limited (429)    : ${rateLimitedRequests.toLocaleString()} (${((rateLimitedRequests / totalRequests) * 100).toFixed(1)}%)`);
  console.log(`❌ Server Errors (5xx)   : ${failedRequests.toLocaleString()}`);
  console.log('----------------------------------------------------------------');
  console.log('📈 LATENCY DISTRIBUTION (ms):');
  console.log(`   Min Latency  : ${percentile(latencies, 0)} ms`);
  console.log(`   P50 (Median) : ${percentile(latencies, 50)} ms`);
  console.log(`   P90          : ${percentile(latencies, 90)} ms`);
  console.log(`   P95          : ${percentile(latencies, 95)} ms`);
  console.log(`   P99          : ${percentile(latencies, 99)} ms`);
  console.log(`   Max Latency  : ${percentile(latencies, 100)} ms`);
  console.log('================================================================');
  console.log('📡 Datadog Telemetry:');
  console.log('   Go to: https://app.datadoghq.com/apm/traces');
  console.log('   Filter by: service:gateway-service OR service:account-service');
  console.log('   All spans, flame graphs, and rate-limiting metrics are streaming live!');
  console.log('================================================================\n');
}

runSuite().catch(console.error);
