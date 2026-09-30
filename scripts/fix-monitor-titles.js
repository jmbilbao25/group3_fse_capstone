const apiKey = '01f81b9b68f2858cbdd9f9b04c02c16a';
const appKey = 'ddapp_lxTRTGazMCOVNjyNGpGHugCCKToj0s0kvd';

const monitorRenames = {
  // Synthetic Private Location Monitors
  326178556: '[Synthetic Private Location] fse-local-banking: Worker stopped reporting',
  326178557: '[Synthetic Private Location] fse-local-banking: Worker image version outdated',
  326178559: '[Synthetic Private Location] fse-local-banking: Worker is underprovisioned',
  326178560: '[Synthetic Private Location] fse-local-banking: Polling queue latency high (> 10s)',

  // APM Monitors
  325579906: 'Watchdog APM Automated Anomaly Detection',
  325583224: '[APM: Core Services] High Error Rate on Servlet HTTP Requests',
  325583226: '[APM: Core Services] High Error Rate on Spring Handlers',
  325583231: '[APM: API Gateway] High Error Rate on Netty Edge Requests',
  325583232: '[APM: API Gateway] High Error Rate on ReadOperationHandler',
  325586287: '[APM: API Gateway] High Error Rate on FilteringWebHandler',
  325590037: '[APM: API Gateway] High Error Rate on ResourceWebHandler',

  // Host Monitors
  325576603: '[Host Infrastructure] High CPU usage (> 90%)',
  325576604: '[Host Infrastructure] High Disk I/O latency (> 500ms)',
  325576607: '[Host Infrastructure] High Disk storage utilization (>= 99%)',
  325576608: '[Host Infrastructure] High System load',
  325576609: '[Host Infrastructure] High Inbound network traffic',
  325576610: '[Host Infrastructure] High Outbound network traffic',
  325576612: '[Host Infrastructure] Low Memory space (< 10% usable)'
};

async function fixMonitors() {
  for (const [id, newName] of Object.entries(monitorRenames)) {
    try {
      const res = await fetch(`https://api.datadoghq.com/api/v1/monitor/${id}`, {
        method: 'PUT',
        headers: {
          'DD-API-KEY': apiKey,
          'DD-APPLICATION-KEY': appKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name: newName })
      });
      const data = await res.json();
      if (res.ok) {
        console.log(`✅ [${id}] -> "${data.name}"`);
      } else {
        console.error(`❌ [${id}] Failed:`, data);
      }
    } catch (err) {
      console.error(`❌ [${id}] Error:`, err.message);
    }
  }
}

fixMonitors().catch(console.error);
