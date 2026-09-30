const apiKey = '01f81b9b68f2858cbdd9f9b04c02c16a';
const appKey = 'ddapp_lxTRTGazMCOVNjyNGpGHugCCKToj0s0kvd';

async function listMonitors() {
  const res = await fetch('https://api.datadoghq.com/api/v1/monitor', {
    headers: {
      'DD-API-KEY': apiKey,
      'DD-APPLICATION-KEY': appKey
    }
  });
  const monitors = await res.json();
  console.log('Total monitors:', monitors.length);
  for (const m of monitors) {
    if (m.name.includes('{{') || m.name.toLowerCase().includes('location') || m.name.includes('service')) {
      console.log(`[ID: ${m.id}] "${m.name}"`);
      console.log(`   Type: ${m.type} | Query: ${m.query}`);
    }
  }
}

listMonitors().catch(console.error);
