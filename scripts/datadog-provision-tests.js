const apiKey = process.env.DATADOG_API_KEY || '';
const appKey = process.env.DATADOG_APP_KEY || '';
const location = process.env.DATADOG_LOCATION || 'pl:fse-local-banking-de56c164c7cb2e33ccb5d1fd190199e2';

const testsToCreate = [
  {
    name: 'Gateway Performance & SLA Latency Probe',
    type: 'api',
    subtype: 'http',
    status: 'live',
    locations: [location],
    config: {
      request: {
        method: 'GET',
        url: 'http://gateway-service:8080/actuator/health',
        timeout: 5
      },
      assertions: [
        { type: 'statusCode', operator: 'is', target: 200 },
        { type: 'responseTime', operator: 'lessThan', target: 100 } // Strict 100ms SLA
      ]
    },
    options: {
      tick_every: 60,
      min_failure_duration: 0,
      min_location_failed: 1
    },
    message: 'CRITICAL: Gateway latency exceeded 100ms SLA or is DOWN',
    tags: ['service:gateway-service', 'tier:p1', 'env:local']
  },
  {
    name: 'Ledger Mutation Engine - Concurrency & Solvency Probe',
    type: 'api',
    subtype: 'http',
    status: 'live',
    locations: [location],
    config: {
      request: {
        method: 'GET',
        url: 'http://ledger-mutation-engine:8082/actuator/health',
        timeout: 5
      },
      assertions: [
        { type: 'statusCode', operator: 'is', target: 200 },
        { type: 'responseTime', operator: 'lessThan', target: 150 }
      ]
    },
    options: {
      tick_every: 60,
      min_failure_duration: 0,
      min_location_failed: 1
    },
    message: 'CRITICAL: Core Ledger Mutation Engine is UNHEALTHY',
    tags: ['service:ledger-mutation-engine', 'tier:core', 'env:local']
  },
  {
    name: 'Account & Identity Service - KYC Probe',
    type: 'api',
    subtype: 'http',
    status: 'live',
    locations: [location],
    config: {
      request: {
        method: 'GET',
        url: 'http://account-service:8081/actuator/health',
        timeout: 5
      },
      assertions: [
        { type: 'statusCode', operator: 'is', target: 200 },
        { type: 'responseTime', operator: 'lessThan', target: 150 }
      ]
    },
    options: {
      tick_every: 60,
      min_failure_duration: 0,
      min_location_failed: 1
    },
    message: 'CRITICAL: Account & Identity Service is UNHEALTHY',
    tags: ['service:account-service', 'tier:core', 'env:local']
  },
  {
    name: 'Notification & Event Streaming Service Probe',
    type: 'api',
    subtype: 'http',
    status: 'live',
    locations: [location],
    config: {
      request: {
        method: 'GET',
        url: 'http://notification-service:8083/actuator/health',
        timeout: 5
      },
      assertions: [
        { type: 'statusCode', operator: 'is', target: 200 },
        { type: 'responseTime', operator: 'lessThan', target: 150 }
      ]
    },
    options: {
      tick_every: 60,
      min_failure_duration: 0,
      min_location_failed: 1
    },
    message: 'WARNING: Notification & Alert Service is UNHEALTHY',
    tags: ['service:notification-service', 'tier:support', 'env:local']
  }
];

async function createTests() {
  for (const test of testsToCreate) {
    try {
      const res = await fetch('https://api.datadoghq.com/api/v1/synthetics/tests/api', {
        method: 'POST',
        headers: {
          'DD-API-KEY': apiKey,
          'DD-APPLICATION-KEY': appKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(test)
      });
      const data = await res.json();
      if (res.ok) {
        console.log(`[CREATED] ${test.name} -> ID: ${data.public_id}`);
      } else {
        console.error(`[FAILED] ${test.name}:`, data);
      }
    } catch (err) {
      console.error(`[ERROR] ${test.name}:`, err.message);
    }
  }
}

createTests();
