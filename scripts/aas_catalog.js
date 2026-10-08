#!/usr/bin/env node

/**
 * Agentic Awesome Skills (AAS) Catalog Helper
 *
 * Usage:
 *   node scripts/aas_catalog.js search <keyword>
 *   node scripts/aas_catalog.js info <skill-name>
 */

const https = require('https');

const API_ROOT = 'https://api.github.com';
const REPO = 'sickn33/agentic-awesome-skills';

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'User-Agent': 'AAS-Catalog-Helper-Agent/1.0',
        'Accept': 'application/vnd.github.v3+json'
      }
    };
    https.get(url, options, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse response: ${e.message}`));
        }
      });
    }).on('error', reject);
  });
}

async function searchSkills(keyword) {
  console.log(`Searching AAS catalog for: "${keyword}"...`);
  try {
    const url = `${API_ROOT}/search/code?q=${encodeURIComponent(keyword)}+repo:${REPO}+filename:SKILL.md`;
    const res = await fetchJson(url);
    if (!res.items || res.items.length === 0) {
      console.log(`No skills found matching "${keyword}".`);
      return;
    }
    console.log(`Found ${res.total_count} matching skill(s):\n`);
    res.items.slice(0, 15).forEach((item, idx) => {
      console.log(`${idx + 1}. ${item.path}`);
      console.log(`   URL: ${item.html_url}`);
    });
  } catch (err) {
    console.error(`Search error: ${err.message}`);
    console.log(`Fallback: Visit https://github.com/${REPO} or run: npx -y agentic-awesome-skills`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'help';
  const query = args.slice(1).join(' ');

  if (command === 'search' && query) {
    await searchSkills(query);
  } else {
    console.log('Agentic Awesome Skills (AAS) Catalog Helper');
    console.log('Usage:');
    console.log('  node scripts/aas_catalog.js search <keyword>');
    console.log('  npx -y agentic-awesome-skills');
  }
}

main();
