const fs = require('fs');
const path = require('path');

let seedCounter = 8000;
function getSeed() {
  return seedCounter++;
}

let idCounter = 1;
function getId(prefix = 'elem') {
  return `${prefix}_${idCounter++}_${Math.random().toString(36).substr(2, 6)}`;
}

const elements = [];

// Helper: Add Rectangle
function addRect({
  id = getId('rect'),
  x,
  y,
  w,
  h,
  strokeColor = '#3b82f6',
  backgroundColor = '#1e293b',
  fillStyle = 'solid',
  strokeWidth = 1.5,
  strokeStyle = 'solid',
  roughness = 0,
  opacity = 100,
  roundness = { type: 3 },
  groupIds = []
}) {
  const el = {
    id,
    type: 'rectangle',
    x,
    y,
    width: w,
    height: h,
    angle: 0,
    strokeColor,
    backgroundColor,
    fillStyle,
    strokeWidth,
    strokeStyle,
    roughness,
    opacity,
    groupIds,
    frameId: null,
    roundness,
    seed: getSeed(),
    version: 1,
    versionNonce: 1,
    isDeleted: false,
    boundElements: null,
    updated: 1,
    link: null,
    locked: false
  };
  elements.push(el);
  return el;
}

// Helper: Add Text
function addText({
  id = getId('text'),
  x,
  y,
  text,
  fontSize = 14,
  fontFamily = 2,
  textAlign = 'left',
  strokeColor = '#f8fafc',
  opacity = 100,
  lineHeight = 1.35,
  groupIds = []
}) {
  const lines = text.split('\n');
  const maxLineLen = Math.max(...lines.map(l => l.length));
  const estimatedWidth = Math.ceil(maxLineLen * (fontSize * 0.58));
  const estimatedHeight = Math.ceil(lines.length * (fontSize * lineHeight));

  const el = {
    id,
    type: 'text',
    x,
    y,
    width: estimatedWidth,
    height: estimatedHeight,
    angle: 0,
    strokeColor,
    backgroundColor: 'transparent',
    fillStyle: 'solid',
    strokeWidth: 1,
    strokeStyle: 'solid',
    roughness: 0,
    opacity,
    groupIds,
    frameId: null,
    roundness: null,
    seed: getSeed(),
    version: 1,
    versionNonce: 1,
    isDeleted: false,
    text,
    fontSize,
    fontFamily,
    textAlign,
    verticalAlign: 'top',
    baseline: fontSize,
    containerId: null,
    originalText: text,
    lineHeight
  };
  elements.push(el);
  return el;
}

// Helper: Add Badge / Pill
function addBadge({ x, y, text, strokeColor, backgroundColor, textColor, fontSize = 11, h = 26 }) {
  const textWidth = text.length * (fontSize * 0.62);
  const paddingX = 14;
  const w = Math.ceil(textWidth + paddingX * 2);
  addRect({
    x,
    y,
    w,
    h,
    strokeColor,
    backgroundColor,
    strokeWidth: 1,
    roundness: { type: 3 },
    roughness: 0
  });
  addText({
    x: x + paddingX,
    y: y + Math.floor((h - fontSize) / 2) - 1,
    text,
    fontSize,
    strokeColor: textColor,
    fontFamily: 2
  });
  return { w, h };
}

// Helper: Add Arrow
function addArrow({
  x1,
  y1,
  x2,
  y2,
  strokeColor = '#60a5fa',
  strokeWidth = 2,
  strokeStyle = 'solid',
  points = null,
  label = null,
  labelColor = '#93c5fd'
}) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const arrowPoints = points || [[0, 0], [dx, dy]];
  const el = {
    id: getId('arrow'),
    type: 'arrow',
    x: x1,
    y: y1,
    width: Math.abs(dx),
    height: Math.abs(dy),
    angle: 0,
    strokeColor,
    backgroundColor: 'transparent',
    fillStyle: 'solid',
    strokeWidth,
    strokeStyle,
    roughness: 0,
    opacity: 100,
    groupIds: [],
    frameId: null,
    roundness: { type: 2 },
    seed: getSeed(),
    version: 1,
    versionNonce: 1,
    isDeleted: false,
    points: arrowPoints,
    startBinding: null,
    endBinding: null,
    lastCommittedPoint: null,
    startArrowhead: null,
    endArrowhead: 'arrow',
    updated: 1,
    link: null,
    locked: false
  };
  elements.push(el);

  if (label) {
    const midX = x1 + dx / 2;
    const midY = y1 + dy / 2 - 13;
    addText({
      x: Math.round(midX - (label.length * 3.2)),
      y: Math.round(midY),
      text: label,
      fontSize: 11,
      strokeColor: labelColor,
      fontFamily: 2
    });
  }
  return el;
}

// ==========================================
// 1. TOP HEADER BANNER
// ==========================================
addRect({
  x: 60,
  y: 40,
  w: 1880,
  h: 110,
  strokeColor: '#38bdf8',
  backgroundColor: '#0f172a',
  strokeWidth: 2,
  roundness: { type: 3 }
});
addText({
  x: 90,
  y: 58,
  text: 'RETAIL LEDGER & MUTATION ENGINE: AZURE CLOUD ARCHITECTURE & SCALING BLUEPRINT',
  fontSize: 22,
  strokeColor: '#f8fafc',
  fontFamily: 2
});
addText({
  x: 90,
  y: 92,
  text: 'Multi-Tier Load Balancing (L7 Edge WAF + Internal Envoy), Event-Driven Autoscaling (HPA + KEDA), and Dual Relational Persistence',
  fontSize: 13.5,
  strokeColor: '#94a3b8',
  fontFamily: 2
});

addBadge({ x: 1250, y: 70, text: 'TIER 1 & 2 LOAD BALANCERS', strokeColor: '#f59e0b', backgroundColor: '#451a03', textColor: '#fde68a', fontSize: 11 });
addBadge({ x: 1510, y: 70, text: 'HPA & KEDA AUTOSCALING', strokeColor: '#a855f7', backgroundColor: '#3b0764', textColor: '#f3e8ff', fontSize: 11 });
addBadge({ x: 1730, y: 70, text: 'DUAL RELATIONAL ACID', strokeColor: '#10b981', backgroundColor: '#064e3b', textColor: '#a7f3d0', fontSize: 11 });


// ==========================================
// ZONE 1: PUBLIC CLIENTS & TRAFFIC INGRESS (Y: 170 to 280)
// ==========================================
addRect({
  x: 60,
  y: 170,
  w: 1880,
  h: 115,
  strokeColor: '#334155',
  backgroundColor: '#0b1329',
  strokeWidth: 1.5,
  strokeStyle: 'dashed'
});
addText({
  x: 90,
  y: 182,
  text: 'ZONE 1: PUBLIC TRAFFIC INGRESS & CLIENT ACCESS (INTERNET)',
  fontSize: 12,
  strokeColor: '#38bdf8'
});

addRect({
  x: 180,
  y: 205,
  w: 480,
  h: 60,
  strokeColor: '#38bdf8',
  backgroundColor: '#0f172a',
  strokeWidth: 1.5
});
addText({
  x: 205,
  y: 217,
  text: 'Retail Banking Customers (Web SPA & Mobile HTTPS)',
  fontSize: 14,
  strokeColor: '#e0f2fe'
});
addText({
  x: 205,
  y: 239,
  text: 'Customer single page sessions, transfers & 2FA OTP verification',
  fontSize: 11,
  strokeColor: '#7dd3fc'
});

addRect({
  x: 740,
  y: 205,
  w: 480,
  h: 60,
  strokeColor: '#94a3b8',
  backgroundColor: '#0f172a',
  strokeWidth: 1.5
});
addText({
  x: 765,
  y: 217,
  text: 'Bank Operations, Audit & Compliance Officers',
  fontSize: 14,
  strokeColor: '#f1f5f9'
});
addText({
  x: 765,
  y: 239,
  text: 'Admin telemetry grid, KYC approvals, and immutable audit inspection',
  fontSize: 11,
  strokeColor: '#94a3b8'
});

addRect({
  x: 1300,
  y: 205,
  w: 520,
  h: 60,
  strokeColor: '#a78bfa',
  backgroundColor: '#0f172a',
  strokeWidth: 1.5
});
addText({
  x: 1325,
  y: 217,
  text: 'Azure DNS & Global Traffic Management',
  fontSize: 14,
  strokeColor: '#ede9fe'
});
addText({
  x: 1325,
  y: 239,
  text: 'Anycast DNS resolution, DDoS Protection Standard, geo-routing',
  fontSize: 11,
  strokeColor: '#c4b5fd'
});


// ==========================================
// ZONE 2: PERIMETER SECURITY & TIER 1 LOAD BALANCER (Y: 345 to 505)
// Clear 65px channel between Zone 1 and Zone 2!
// ==========================================
addRect({
  x: 60,
  y: 345,
  w: 1880,
  h: 160,
  strokeColor: '#f59e0b',
  backgroundColor: '#1c1917',
  strokeWidth: 2
});
addText({
  x: 90,
  y: 357,
  text: 'ZONE 2: PERIMETER SECURITY & TIER 1 LOAD BALANCER (EDGE INGRESS)',
  fontSize: 12,
  strokeColor: '#fbbf24'
});

addRect({
  x: 90,
  y: 380,
  w: 1820,
  h: 110,
  strokeColor: '#d97706',
  backgroundColor: '#292524',
  strokeWidth: 2
});
addText({
  x: 120,
  y: 393,
  text: 'Azure Application Gateway v2 with WAF (Public VIP / Edge Ingress)',
  fontSize: 16,
  strokeColor: '#fef3c7'
});

addBadge({ x: 120, y: 421, text: 'TIER 1 LOAD BALANCER (L7)', strokeColor: '#f59e0b', backgroundColor: '#451a03', textColor: '#fef3c7' });
addBadge({ x: 340, y: 421, text: 'SSL/TLS Offloading (:443)', strokeColor: '#f59e0b', backgroundColor: '#451a03', textColor: '#fef3c7' });
addBadge({ x: 545, y: 421, text: 'OWASP WAF Core Rule Set 3.2', strokeColor: '#f59e0b', backgroundColor: '#451a03', textColor: '#fef3c7' });
addBadge({ x: 795, y: 421, text: 'Zone-Redundant Multi-AZ', strokeColor: '#f59e0b', backgroundColor: '#451a03', textColor: '#fef3c7' });

addText({
  x: 120,
  y: 457,
  text: '• Path Routing:  /api/*  ==>  API Gateway Service Replicas     |     /* (Static)  ==>  React Frontend Nginx Replicas\n• Traffic Balancing: Round-Robin distribution with continuous health probe validation (GET /actuator/health)',
  fontSize: 12,
  strokeColor: '#fde68a',
  lineHeight: 1.4
});


// ==========================================
// ZONE 3: COMPUTE & MICROSERVICES TIER (Y: 565 to 985)
// Clear 60px channel between Zone 2 and Zone 3!
// ==========================================
addRect({
  x: 60,
  y: 565,
  w: 1880,
  h: 420,
  strokeColor: '#2563eb',
  backgroundColor: '#0c1527',
  strokeWidth: 2
});
addText({
  x: 90,
  y: 577,
  text: 'ZONE 3: COMPUTE & ORCHESTRATION TIER (Azure Container Apps Managed Environment - Private VNet 10.0.1.0/24)',
  fontSize: 12,
  strokeColor: '#60a5fa'
});

// Left Sub-Tier: Public Ingress Targets (Frontend & Gateway)
// CARD 1: FRONTEND (X: 90 to 430)
addRect({
  x: 90,
  y: 605,
  w: 340,
  h: 360,
  strokeColor: '#0284c7',
  backgroundColor: '#0f172a',
  strokeWidth: 2
});
addText({ x: 110, y: 620, text: 'banking-frontend', fontSize: 16, strokeColor: '#38bdf8' });
addText({ x: 110, y: 642, text: 'React 18 + Vite (Nginx :80)', fontSize: 12, strokeColor: '#94a3b8' });
addBadge({ x: 110, y: 668, text: '⚡ HPA: 2 - 5 Replicas', strokeColor: '#0284c7', backgroundColor: '#082f49', textColor: '#7dd3fc' });
addBadge({ x: 110, y: 700, text: 'Metric: CPU > 70%', strokeColor: '#0284c7', backgroundColor: '#082f49', textColor: '#7dd3fc' });
addText({
  x: 110,
  y: 745,
  text: '• Serves optimized SPA static assets\n• Implements Customer & Admin Portals\n• Nginx reverse-proxies /api/ to Gateway\n• Fast client-side routing & JWT storage\n• 4-Decimal mutation input validation',
  fontSize: 11.5,
  strokeColor: '#cbd5e1',
  lineHeight: 1.48
});

// CARD 2: API GATEWAY (X: 460 to 800)
addRect({
  x: 460,
  y: 605,
  w: 340,
  h: 360,
  strokeColor: '#2563eb',
  backgroundColor: '#0f172a',
  strokeWidth: 2
});
addText({ x: 480, y: 620, text: 'gateway-service', fontSize: 16, strokeColor: '#60a5fa' });
addText({ x: 480, y: 642, text: 'Spring Cloud Gateway (:8080)', fontSize: 12, strokeColor: '#94a3b8' });
addBadge({ x: 480, y: 668, text: '⚡ HPA: 2 - 10 Replicas', strokeColor: '#2563eb', backgroundColor: '#172554', textColor: '#93c5fd' });
addBadge({ x: 480, y: 700, text: 'Metric: 100 RPS / Pod', strokeColor: '#2563eb', backgroundColor: '#172554', textColor: '#93c5fd' });
addText({
  x: 480,
  y: 745,
  text: '• Perimeter JWT cryptographic verification\n• Queries Redis token blacklist in sub-5ms\n• Token-bucket rate limiting (100 req/sec)\n• Forwards internal routes through Envoy:\n  - /api/v1/auth/** -> account-service\n  - /api/v1/transfers/** -> ledger-engine',
  fontSize: 11.5,
  strokeColor: '#cbd5e1',
  lineHeight: 1.48
});

// Right Sub-Tier: TIER 2 ENVOY SERVICE MESH + 3 INTERNAL SERVICES
// TIER 2 ENVOY PROXY (X: 830 to 1910, W: 1080)
addRect({
  x: 830,
  y: 605,
  w: 1080,
  h: 65,
  strokeColor: '#3b82f6',
  backgroundColor: '#172554',
  strokeWidth: 2
});
addText({
  x: 850,
  y: 615,
  text: 'Azure Container Apps Internal Envoy Proxy (TIER 2 LOAD BALANCER & SERVICE MESH)',
  fontSize: 14.5,
  strokeColor: '#eff6ff'
});
addBadge({ x: 850, y: 638, text: 'TIER 2 INTERNAL L7 LOAD BALANCER', strokeColor: '#60a5fa', backgroundColor: '#1e3a8a', textColor: '#bfdbfe', fontSize: 10, h: 22 });
addBadge({ x: 1100, y: 638, text: 'Virtual DNS (http://service-name)', strokeColor: '#60a5fa', backgroundColor: '#1e3a8a', textColor: '#bfdbfe', fontSize: 10, h: 22 });
addBadge({ x: 1360, y: 638, text: 'East-West Traffic Balancing Across Pods', strokeColor: '#60a5fa', backgroundColor: '#1e3a8a', textColor: '#bfdbfe', fontSize: 10, h: 22 });
addBadge({ x: 1670, y: 638, text: 'Health Probes', strokeColor: '#60a5fa', backgroundColor: '#1e3a8a', textColor: '#bfdbfe', fontSize: 10, h: 22 });

// CARD 3: ACCOUNT & KYC (X: 830 to 1170)
addRect({
  x: 830,
  y: 690,
  w: 340,
  h: 275,
  strokeColor: '#6366f1',
  backgroundColor: '#0f172a',
  strokeWidth: 2
});
addText({ x: 850, y: 705, text: 'account-service', fontSize: 16, strokeColor: '#818cf8' });
addText({ x: 850, y: 727, text: 'Spring Boot 3 Identity (:8081)', fontSize: 12, strokeColor: '#94a3b8' });
addBadge({ x: 850, y: 752, text: '⚡ HPA: 2 - 8 Replicas', strokeColor: '#6366f1', backgroundColor: '#1e1b4b', textColor: '#c7d2fe' });
addBadge({ x: 850, y: 784, text: '🔒 HikariCP Pool: 25 conns', strokeColor: '#6366f1', backgroundColor: '#1e1b4b', textColor: '#c7d2fe' });
addText({
  x: 850,
  y: 825,
  text: '• User registration & BCrypt hashing\n• Refresh Token Rotation (RTR) logic\n• Instant session breach family purge\n• KYC verification & account provisioning\n• Balance inquiry cache (Redis 30s TTL)',
  fontSize: 11.5,
  strokeColor: '#cbd5e1',
  lineHeight: 1.45
});

// CARD 4: LEDGER MUTATION ENGINE (X: 1200 to 1540)
addRect({
  x: 1200,
  y: 690,
  w: 340,
  h: 275,
  strokeColor: '#a855f7',
  backgroundColor: '#0f172a',
  strokeWidth: 2
});
addText({ x: 1220, y: 705, text: 'ledger-mutation-engine', fontSize: 16, strokeColor: '#c084fc' });
addText({ x: 1220, y: 727, text: 'Spring Boot 3 Core Engine (:8082)', fontSize: 12, strokeColor: '#94a3b8' });
addBadge({ x: 1220, y: 752, text: '⚡ KEDA: 2 - 6 Replicas', strokeColor: '#a855f7', backgroundColor: '#3b0764', textColor: '#e9d5ff' });
addBadge({ x: 1220, y: 784, text: '🔒 HikariCP Pool: 30 conns', strokeColor: '#a855f7', backgroundColor: '#3b0764', textColor: '#e9d5ff' });
addText({
  x: 1220,
  y: 825,
  text: '• Pessimistic row locking kernel\n• 4-Decimal precision (@Digits 14,4)\n• Transactional Outbox pattern (<15ms)\n• Kafka Command Producer & Consumer\n• Customer OTP verification for >₱50k\n• Scales out when Kafka lag > 50 msgs',
  fontSize: 11.5,
  strokeColor: '#cbd5e1',
  lineHeight: 1.45
});

// CARD 5: NOTIFICATION SERVICE (X: 1570 to 1910)
addRect({
  x: 1570,
  y: 690,
  w: 340,
  h: 275,
  strokeColor: '#10b981',
  backgroundColor: '#0f172a',
  strokeWidth: 2
});
addText({ x: 1590, y: 705, text: 'notification-service', fontSize: 16, strokeColor: '#34d399' });
addText({ x: 1590, y: 727, text: 'Spring Boot 3 Notifications (:8083)', fontSize: 12, strokeColor: '#94a3b8' });
addBadge({ x: 1590, y: 752, text: '⚡ KEDA: 2 - 6 Replicas', strokeColor: '#10b981', backgroundColor: '#064e3b', textColor: '#a7f3d0' });
addBadge({ x: 1590, y: 784, text: 'Trigger: Events Topic Lag', strokeColor: '#10b981', backgroundColor: '#064e3b', textColor: '#a7f3d0' });
addText({
  x: 1590,
  y: 825,
  text: '• Kafka transfers.events listener\n• Thymeleaf rich HTML template engine\n• 2FA OTP code dispatch via SMTP\n• HTML debit/credit receipt generation\n• Mandatory AMLA CTR compliance filing\n• In-memory retry spooling for outages',
  fontSize: 11.5,
  strokeColor: '#cbd5e1',
  lineHeight: 1.45
});


// ==========================================
// ZONE 4: DOWNSTREAM DATA, PERSISTENCE & STREAMING TIERS (Y: 1045 to 1575)
// Clear 60px channel between Zone 3 and Zone 4!
// 4 Symmetrical Columns:
// Col 1: Redis (X: 90, W: 430) -> Under Gateway
// Col 2: Oracle XE (X: 550, W: 440) -> Under Account
// Col 3: Event Hubs (X: 1020, W: 450) -> Under Ledger Engine
// Col 4: SendGrid Email (Top) + Postgres Audit (Bottom) (X: 1500, W: 410) -> Under Notification
// ==========================================

addRect({
  x: 60,
  y: 1045,
  w: 1880,
  h: 530,
  strokeColor: '#059669',
  backgroundColor: '#022c22',
  strokeWidth: 2
});
addText({
  x: 90,
  y: 1057,
  text: 'ZONE 4: PERSISTENCE, CACHING & EVENT STREAMING TIER (Subnets: 10.0.2.0/24 & 10.0.3.0/24)',
  fontSize: 12,
  strokeColor: '#6ee7b7'
});

// COL 1: REDIS CACHE
addRect({
  x: 90,
  y: 1080,
  w: 430,
  h: 475,
  strokeColor: '#14b8a6',
  backgroundColor: '#042f2e',
  strokeWidth: 2
});
addText({ x: 110, y: 1095, text: 'Azure Cache for Redis', fontSize: 16, strokeColor: '#2dd4bf' });
addText({ x: 110, y: 1117, text: 'Tier 3 In-Memory Fast Path (:6380 TLS)', fontSize: 12, strokeColor: '#99f6e4' });
addBadge({ x: 110, y: 1145, text: '⚡ SUB-5MS LATENCY FAST PATH', strokeColor: '#2dd4bf', backgroundColor: '#134e4a', textColor: '#ccfbf1' });
addBadge({ x: 110, y: 1177, text: 'Standard / Clustered Scale', strokeColor: '#2dd4bf', backgroundColor: '#134e4a', textColor: '#ccfbf1' });
addText({
  x: 110,
  y: 1220,
  text: '• Token Blacklist:\n  blacklist:jti:<id> (15-min TTL, blocks revoked\n  access tokens immediately in sub-5ms)\n• Session Families:\n  token_family:<id> (7-day TTL, detects token\n  theft & revokes entire family)\n• Idempotency Guard:\n  tx:<uuid> (60-sec TTL, blocks duplicate\n  double-click transfer submissions)\n• Balance Read Cache:\n  account:balance:<id> (30-sec TTL, absorbs\n  80%+ of account screen reads)\n• 2FA OTP Store:\n  2fa:otp:<userId> (300-sec TTL for > ₱50k)',
  fontSize: 11.5,
  strokeColor: '#f0fdfa',
  lineHeight: 1.48
});

// COL 2: MASTER ORACLE XE 21C DATABASE
addRect({
  x: 550,
  y: 1080,
  w: 440,
  h: 475,
  strokeColor: '#ea580c',
  backgroundColor: '#431407',
  strokeWidth: 2
});
addText({ x: 570, y: 1095, text: 'Oracle XE 21c Master DB', fontSize: 16, strokeColor: '#fb923c' });
addText({ x: 570, y: 1117, text: 'Master Operational Relational State (:1521)', fontSize: 12, strokeColor: '#fdba74' });
addBadge({ x: 570, y: 1145, text: '🔒 ACID MASTER PERSISTENCE', strokeColor: '#fb923c', backgroundColor: '#7c2d12', textColor: '#ffedd5' });
addBadge({ x: 570, y: 1177, text: 'Linux VM + 64GB Premium SSD', strokeColor: '#fb923c', backgroundColor: '#7c2d12', textColor: '#ffedd5' });
addText({
  x: 570,
  y: 1220,
  text: '• Dedicated Linux VM (Standard_D2s_v5) with\n  attached Azure Premium SSD Managed Disk\n• Kernel: Pessimistic Row Locking Kernel\n  (SELECT ... FOR UPDATE) on balance_master\n• Strict Check Constraints:\n  CHECK (balance_amount >= hold_amount >= 0)\n• Master Schema Tables:\n  users, accounts, balance_master,\n  transactions, outbox_events\n• Concurrency Protection:\n  HikariCP pool caps active connections at 30;\n  Transactional Outbox returns HTTP 202 in <15ms.',
  fontSize: 11.5,
  strokeColor: '#fff7ed',
  lineHeight: 1.48
});

// COL 3: AZURE EVENT HUBS (KAFKA STREAMING BUS)
addRect({
  x: 1020,
  y: 1080,
  w: 450,
  h: 475,
  strokeColor: '#8b5cf6',
  backgroundColor: '#2e1065',
  strokeWidth: 2
});
addText({ x: 1040, y: 1095, text: 'Azure Event Hubs (Kafka Bus)', fontSize: 16, strokeColor: '#c084fc' });
addText({ x: 1040, y: 1117, text: 'Apache Kafka 1.0+ Protocol Surface (:9093)', fontSize: 12, strokeColor: '#ddd6fe' });
addBadge({ x: 1040, y: 1145, text: '⚡ MANAGED EVENT BROKER', strokeColor: '#a78bfa', backgroundColor: '#4c1d95', textColor: '#f5f3ff' });
addBadge({ x: 1040, y: 1177, text: 'Auto-Inflate Throughput Units', strokeColor: '#a78bfa', backgroundColor: '#4c1d95', textColor: '#f5f3ff' });
addText({
  x: 1040,
  y: 1220,
  text: '• banking.transfers.commands\n  - 6 Partitions (Key: source_account_id)\n  - Guarantees strict per-account chronological\n    serialization without distributed locks\n  - Up to 6 active parallel worker consumers\n• banking.transfers.events\n  - 6 Partitions (Key: transfer_id)\n  - Fan-out to Audit and Notification groups\n• banking.transfers.retry\n  - 3 Partitions with exponential backoff\n• banking.transfers.dlt\n  - 1 Partition dead-letter poison pill isolation',
  fontSize: 11.5,
  strokeColor: '#f5f3ff',
  lineHeight: 1.48
});

// COL 4A: CLOUD EMAIL SERVICE (TOP OF COL 4 - DIRECTLY UNDER NOTIFICATION!)
addRect({
  x: 1500,
  y: 1080,
  w: 410,
  h: 225,
  strokeColor: '#0284c7',
  backgroundColor: '#082f49',
  strokeWidth: 2
});
addText({ x: 1520, y: 1095, text: 'Cloud Email: SendGrid / ACS', fontSize: 15, strokeColor: '#38bdf8' });
addBadge({ x: 1520, y: 1120, text: 'REPLACES LOCAL MAILHOG', strokeColor: '#38bdf8', backgroundColor: '#0c4a6e', textColor: '#e0f2fe' });
addText({
  x: 1520,
  y: 1155,
  text: '• Production replacement for local MailHog\n• Delivers real 6-digit OTP codes via SMTP\n  (:587 TLS) for transfers > ₱50,000.00\n• Dispatches rich HTML debit/credit receipts\n  with masked accounts & SHA-256 hash\n• In-memory retry spooling for network blips',
  fontSize: 11,
  strokeColor: '#f0f9ff',
  lineHeight: 1.42
});

// COL 4B: POSTGRESQL AUDIT VAULT (BOTTOM OF COL 4 - CONNECTED FROM EVENT HUBS!)
addRect({
  x: 1500,
  y: 1330,
  w: 410,
  h: 225,
  strokeColor: '#10b981',
  backgroundColor: '#064e3b',
  strokeWidth: 2
});
addText({ x: 1520, y: 1345, text: 'PostgreSQL Audit Vault (:5432)', fontSize: 15, strokeColor: '#34d399' });
addBadge({ x: 1520, y: 1370, text: 'IMMUTABLE AUDIT VAULT', strokeColor: '#34d399', backgroundColor: '#022c22', textColor: '#a7f3d0' });
addText({
  x: 1520,
  y: 1405,
  text: '• Azure Database for PostgreSQL Flexible Svc\n• Trigger trg_no_update_delete blocks\n  all UPDATE/DELETE statements\n• 100% Append-only immutable compliance\n• Built-in PgBouncer connection multiplexing\n• Async projection from transfers.events',
  fontSize: 11,
  strokeColor: '#ecfdf5',
  lineHeight: 1.42
});


// ==========================================
// ZONE 5: GOVERNANCE, OBSERVABILITY & SCALING MATRIX (Y: 1605 to 2000)
// ==========================================
addRect({
  x: 60,
  y: 1605,
  w: 1880,
  h: 390,
  strokeColor: '#475569',
  backgroundColor: '#0f172a',
  strokeWidth: 2
});
addText({
  x: 90,
  y: 1620,
  text: 'ZONE 5: PLATFORM GOVERNANCE, ENTERPRISE OBSERVABILITY & ARCHITECTURE SCALING MATRIX',
  fontSize: 12,
  strokeColor: '#cbd5e1'
});

addRect({
  x: 90,
  y: 1645,
  w: 430,
  h: 330,
  strokeColor: '#e11d48',
  backgroundColor: '#1e293b',
  strokeWidth: 1.5
});
addText({ x: 110, y: 1660, text: 'Azure Key Vault & Managed Identity', fontSize: 15, strokeColor: '#fda4af' });
addBadge({ x: 110, y: 1687, text: 'ZERO-SECRET ARCHITECTURE', strokeColor: '#f43f5e', backgroundColor: '#4c0519', textColor: '#ffe4e6' });
addText({
  x: 110,
  y: 1725,
  text: '• Eliminates plaintext credentials in files and git\n• Microservices authenticate via System-Assigned\n  Managed Identity with zero static tokens\n• Centralized Secrets:\n  - Oracle DB & PostgreSQL audit passwords\n  - Cryptographic HMAC-SHA256 JWT secret\n  - SendGrid SMTP credentials & Datadog API keys\n• Automatic certificate renewal & audit logging',
  fontSize: 11.5,
  strokeColor: '#f1f5f9',
  lineHeight: 1.48
});

addRect({
  x: 550,
  y: 1645,
  w: 440,
  h: 330,
  strokeColor: '#2563eb',
  backgroundColor: '#1e293b',
  strokeWidth: 1.5
});
addText({ x: 570, y: 1660, text: 'Azure Container Registry (ACR)', fontSize: 15, strokeColor: '#93c5fd' });
addBadge({ x: 570, y: 1687, text: 'SECURE OCI IMAGE REGISTRY', strokeColor: '#3b82f6', backgroundColor: '#172554', textColor: '#dbeafe' });
addText({
  x: 570,
  y: 1725,
  text: '• Private, geo-replicated container repository\n• Houses versioned production container images:\n  - banking-frontend (Nginx Alpine)\n  - gateway-service (Spring Cloud Gateway)\n  - account-service (Spring Boot 3)\n  - ledger-mutation-engine (Spring Boot 3)\n  - notification-service (Spring Boot 3)\n• Microsoft Defender image vulnerability scans',
  fontSize: 11.5,
  strokeColor: '#f1f5f9',
  lineHeight: 1.48
});

addRect({
  x: 1020,
  y: 1645,
  w: 450,
  h: 330,
  strokeColor: '#7c3aed',
  backgroundColor: '#1e293b',
  strokeWidth: 1.5
});
addText({ x: 1040, y: 1660, text: 'Datadog Enterprise APM & Telemetry', fontSize: 15, strokeColor: '#d8b4fe' });
addBadge({ x: 1040, y: 1687, text: 'APM TRACES & 200 TPS BENCHMARK', strokeColor: '#8b5cf6', backgroundColor: '#2e1065', textColor: '#f3e8ff' });
addText({
  x: 1040,
  y: 1725,
  text: '• dd-java-agent bytecode instrumentation\n• APM Trace ingestion (:8126) + OTLP spans (:4317)\n• DogStatsD UDP (:8125): Custom business metrics\n  - TPS throughput against 200 TPS benchmark\n  - p50, p95, p99 latencies against 150ms SLA\n• HikariCP pool saturation & Kafka consumer lag alerts\n• Synthetic Check Runner (datadog-synthetics-worker)\n  running end-to-end API tests inside the private VNet',
  fontSize: 11.5,
  strokeColor: '#f1f5f9',
  lineHeight: 1.48
});

addRect({
  x: 1500,
  y: 1645,
  w: 410,
  h: 330,
  strokeColor: '#059669',
  backgroundColor: '#1e293b',
  strokeWidth: 1.5
});
addText({ x: 1520, y: 1660, text: 'Scaling & Load Balancing Matrix', fontSize: 15, strokeColor: '#6ee7b7' });
addBadge({ x: 1520, y: 1687, text: 'ARCHITECTURE REFERENCE', strokeColor: '#10b981', backgroundColor: '#064e3b', textColor: '#d1fae5' });
addText({
  x: 1520,
  y: 1725,
  text: '• Tier 1 LB: Azure App Gateway v2 (L7 Edge WAF)\n• Tier 2 LB: ACA Internal Envoy Proxy (Virtual DNS)\n• Tier 3 LB: Built-in PgBouncer & HikariCP caps\n• HPA Scaling: Frontend (2-5), Gateway (2-10),\n  Account (2-8) scale on CPU > 70% and RPS\n• KEDA Scaling: Ledger & Notification (2-6)\n  scale on Kafka consumer topic lag\n• Partition Limit: 6 Partitions = Max 6 active\n  parallel consumers per account stream',
  fontSize: 11.5,
  strokeColor: '#f1f5f9',
  lineHeight: 1.48
});


// ==========================================
// CONNECTORS & ARROWS (100% NON-CROSSING, ORTHOGONAL & SPACIOUS)
// ==========================================

// 1. Client Ingress -> App Gateway (Clean straight down in 65px channel)
addArrow({
  x1: 420, y1: 265, x2: 420, y2: 380,
  strokeColor: '#38bdf8', strokeWidth: 2.5,
  label: 'HTTPS :443'
});
addArrow({
  x1: 980, y1: 265, x2: 980, y2: 380,
  strokeColor: '#94a3b8', strokeWidth: 2,
  label: 'HTTPS :443'
});

// 2. App Gateway -> Frontend & Gateway Service (Clean straight down in 60px channel)
addArrow({
  x1: 260, y1: 490, x2: 260, y2: 605,
  strokeColor: '#38bdf8', strokeWidth: 2.5,
  label: 'Path /* (Static SPA)'
});
addArrow({
  x1: 630, y1: 490, x2: 630, y2: 605,
  strokeColor: '#60a5fa', strokeWidth: 2.5,
  label: 'Path /api/* (API REST)'
});

// 3. Gateway Service -> Envoy Proxy (Clean rightward link to Envoy)
addArrow({
  x1: 800, y1: 638, x2: 830, y2: 638,
  strokeColor: '#60a5fa', strokeWidth: 2.5,
  label: 'Forward to Envoy'
});

// 4. Envoy Proxy -> 3 Internal Microservices (Clean downward branches from Envoy into top of cards)
addArrow({
  x1: 1000, y1: 670, x2: 1000, y2: 690,
  strokeColor: '#818cf8', strokeWidth: 2,
  label: 'HTTP :8081'
});
addArrow({
  x1: 1370, y1: 670, x2: 1370, y2: 690,
  strokeColor: '#c084fc', strokeWidth: 2,
  label: 'HTTP :8082'
});
addArrow({
  x1: 1740, y1: 670, x2: 1740, y2: 690,
  strokeColor: '#34d399', strokeWidth: 2,
  label: 'HTTP :8083'
});

// 5. Microservices -> Downstream Data Stores (100% Vertical & Straight Down in 60px channel!)
// Gateway -> Redis (Straight Down)
addArrow({
  x1: 300, y1: 965, x2: 300, y2: 1080,
  strokeColor: '#2dd4bf', strokeWidth: 2.5,
  label: 'Token Blacklist & Rate Limit (:6380 TLS)'
});

// Account -> Oracle Master DB (Straight Down)
addArrow({
  x1: 770, y1: 965, x2: 770, y2: 1080,
  strokeColor: '#fb923c', strokeWidth: 2.5,
  label: 'Oracle TNS :1521 (Users & Accounts)'
});

// Ledger Engine -> Event Hubs (Straight Down)
addArrow({
  x1: 1250, y1: 965, x2: 1250, y2: 1080,
  strokeColor: '#c084fc', strokeWidth: 2.5,
  label: 'Produce Commands & Events (:9093)'
});

// Notification Service -> SendGrid Email (Straight Down directly into SendGrid!)
addArrow({
  x1: 1705, y1: 965, x2: 1705, y2: 1080,
  strokeColor: '#38bdf8', strokeWidth: 2.5,
  label: 'SMTP :587 (OTP & Receipts)'
});

// 6. Cross-Tier Event & Audit Connectors
// Event Hubs -> PostgreSQL Audit Vault (Clean horizontal link from bottom-right of Event Hubs into Audit Vault!)
addArrow({
  x1: 1470, y1: 1440, x2: 1500, y2: 1440,
  strokeColor: '#34d399', strokeWidth: 2.5,
  label: 'Audit Stream (:5432)'
});


// Write to file
const excalidrawFile = {
  type: 'excalidraw',
  version: 2,
  source: 'https://excalidraw.com',
  elements,
  appState: {
    gridSize: 20,
    viewBackgroundColor: '#0b0f19'
  },
  files: {}
};

const outputPath = path.resolve(__dirname, '../azure_scaling_architecture.excalidraw');
fs.writeFileSync(outputPath, JSON.stringify(excalidrawFile, null, 2), 'utf-8');
console.log(`Successfully generated clean Excalidraw diagram at: ${outputPath}`);
console.log(`Total elements: ${elements.length}`);
