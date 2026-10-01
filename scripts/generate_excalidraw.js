const fs = require('fs');
const path = require('path');

let seedCounter = 1000;
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
  strokeColor = '#1e293b',
  backgroundColor = '#ffffff',
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
  fontFamily = 2, // 2: Helvetica / Clean Sans
  textAlign = 'left',
  strokeColor = '#0f172a',
  opacity = 100,
  lineHeight = 1.25,
  groupIds = []
}) {
  const lines = text.split('\n');
  const maxLineLen = Math.max(...lines.map(l => l.length));
  const estimatedWidth = maxLineLen * (fontSize * 0.58);
  const estimatedHeight = lines.length * (fontSize * lineHeight);

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
function addBadge({ x, y, text, strokeColor, backgroundColor, textColor, fontSize = 11 }) {
  const textWidth = text.length * 7;
  const paddingX = 14;
  const w = textWidth + paddingX * 2;
  const h = 24;
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
    y: y + 5,
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
  strokeColor = '#475569',
  strokeWidth = 2,
  strokeStyle = 'solid',
  points = null,
  label = null,
  labelColor = '#334155'
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
    const midY = y1 + dy / 2 - 12;
    addText({
      x: midX - (label.length * 3),
      y: midY,
      text: label,
      fontSize: 11,
      strokeColor: labelColor,
      fontFamily: 2
    });
  }
  return el;
}

// ==========================================
// CANVAS BUILD
// ==========================================

// 1. TOP HEADER BANNER
addRect({
  x: 60,
  y: 40,
  w: 1840,
  h: 90,
  strokeColor: '#0f172a',
  backgroundColor: '#0f172a',
  roundness: { type: 3 }
});
addText({
  x: 90,
  y: 55,
  text: 'CORE RETAIL LEDGER & MUTATION ENGINE: AZURE CLOUD ARCHITECTURE & SCALING BLUEPRINT',
  fontSize: 22,
  strokeColor: '#f8fafc',
  fontFamily: 2
});
addText({
  x: 90,
  y: 90,
  text: 'Multi-Tier Load Balancing (L7 Edge WAF + Internal Envoy), Event-Driven Autoscaling (HPA + KEDA), and Dual-Storage Resilience',
  fontSize: 14,
  strokeColor: '#94a3b8',
  fontFamily: 2
});

// ==========================================
// MAIN CONTENT LEFT COLUMN: TIERS 1 to 5 (X: 60 to 1340, Width: 1280)
// ==========================================

// ZONE 1: PUBLIC CLIENTS & USERS (Y: 150 to 240)
addRect({
  x: 60,
  y: 150,
  w: 1280,
  h: 90,
  strokeColor: '#cbd5e1',
  backgroundColor: '#f8fafc',
  strokeStyle: 'dashed',
  strokeWidth: 1.5
});
addText({
  x: 80,
  y: 158,
  text: 'PUBLIC TRAFFIC INGRESS & CLIENT ACCESS (INTERNET)',
  fontSize: 12,
  strokeColor: '#64748b'
});

// Customer Client Box
addRect({
  x: 180,
  y: 180,
  w: 420,
  h: 50,
  strokeColor: '#3b82f6',
  backgroundColor: '#eff6ff',
  strokeWidth: 1.5
});
addText({
  x: 200,
  y: 195,
  text: 'Retail Banking Customers (Web SPA / Mobile HTTPS)',
  fontSize: 14,
  strokeColor: '#1e40af'
});

// Admin Client Box
addRect({
  x: 740,
  y: 180,
  w: 420,
  h: 50,
  strokeColor: '#64748b',
  backgroundColor: '#f1f5f9',
  strokeWidth: 1.5
});
addText({
  x: 760,
  y: 195,
  text: 'Bank Operations, Audit & KYC Officers (HTTPS Portal)',
  fontSize: 14,
  strokeColor: '#334155'
});


// ZONE 2: PERIMETER SECURITY & TIER 1 LOAD BALANCER (Y: 260 to 450)
addRect({
  x: 60,
  y: 260,
  w: 1280,
  h: 190,
  strokeColor: '#f59e0b',
  backgroundColor: '#fffbeb',
  strokeWidth: 2
});
addText({
  x: 80,
  y: 270,
  text: 'ZONE 1: PERIMETER SECURITY & TIER 1 LOAD BALANCER (EDGE INGRESS)',
  fontSize: 13,
  strokeColor: '#b45309'
});

// Azure Application Gateway Box
addRect({
  x: 90,
  y: 300,
  w: 1220,
  h: 135,
  strokeColor: '#d97706',
  backgroundColor: '#ffffff',
  strokeWidth: 2
});
addText({
  x: 120,
  y: 315,
  text: 'Azure Application Gateway v2 with WAF (Public Virtual IP / Edge Ingress)',
  fontSize: 16,
  strokeColor: '#92400e'
});
addBadge({ x: 120, y: 345, text: 'TIER 1 LOAD BALANCER (L7)', strokeColor: '#b45309', backgroundColor: '#fef3c7', textColor: '#92400e' });
addBadge({ x: 340, y: 345, text: 'SSL/TLS Offloading (:443)', strokeColor: '#b45309', backgroundColor: '#fef3c7', textColor: '#92400e' });
addBadge({ x: 535, y: 345, text: 'OWASP ModSecurity Core Rule Set', strokeColor: '#b45309', backgroundColor: '#fef3c7', textColor: '#92400e' });
addBadge({ x: 795, y: 345, text: 'Zone-Redundant High Availability', strokeColor: '#b45309', backgroundColor: '#fef3c7', textColor: '#92400e' });

addText({
  x: 120,
  y: 385,
  text: '• Path-Based Routing:  /api/*  ==>  API Gateway Service Replicas\n• Static Asset Routing:  /*      ==>  React Frontend SPA Nginx Replicas\n• Traffic Distribution: Round-Robin with Actuator Health Probes (/actuator/health)',
  fontSize: 12.5,
  strokeColor: '#78350f',
  lineHeight: 1.4
});


// ZONE 3: COMPUTE & MICROSERVICES TIER (Y: 470 to 920)
addRect({
  x: 60,
  y: 470,
  w: 1280,
  h: 460,
  strokeColor: '#2563eb',
  backgroundColor: '#f8fafc',
  strokeWidth: 2
});
addText({
  x: 80,
  y: 480,
  text: 'ZONE 2: COMPUTE & ORCHESTRATION TIER (Azure Container Apps Managed Environment - Private VNet 10.0.1.0/24)',
  fontSize: 13,
  strokeColor: '#1d4ed8'
});

// TIER 2: INTERNAL ENVOY LOAD BALANCER
addRect({
  x: 90,
  y: 505,
  w: 1220,
  h: 80,
  strokeColor: '#3b82f6',
  backgroundColor: '#dbeafe',
  strokeWidth: 1.5
});
addText({
  x: 120,
  y: 518,
  text: 'Azure Container Apps Internal Envoy Proxy (TIER 2 LOAD BALANCER & SERVICE MESH)',
  fontSize: 15,
  strokeColor: '#1e3a8a'
});
addBadge({ x: 120, y: 545, text: 'TIER 2 INTERNAL L7 LOAD BALANCER', strokeColor: '#1d4ed8', backgroundColor: '#bfdbfe', textColor: '#1e3a8a' });
addBadge({ x: 395, y: 545, text: 'Private Virtual DNS Discovery (http://service-name)', strokeColor: '#1d4ed8', backgroundColor: '#bfdbfe', textColor: '#1e3a8a' });
addBadge({ x: 775, y: 545, text: 'Internal East-West Traffic Isolation', strokeColor: '#1d4ed8', backgroundColor: '#bfdbfe', textColor: '#1e3a8a' });

// MICROSERVICE 1: FRONTEND
addRect({
  x: 90,
  y: 605,
  w: 220,
  h: 150,
  strokeColor: '#0284c7',
  backgroundColor: '#ffffff',
  strokeWidth: 1.5
});
addText({ x: 105, y: 618, text: 'banking-frontend', fontSize: 15, strokeColor: '#0369a1' });
addText({ x: 105, y: 640, text: 'React 18 + Vite (Nginx :80)\nReverse proxy /api/ to Gateway', fontSize: 11.5, strokeColor: '#475569' });
addBadge({ x: 105, y: 690, text: 'HPA: 2 - 5 Replicas', strokeColor: '#0284c7', backgroundColor: '#e0f2fe', textColor: '#0369a1', fontSize: 10 });
addText({ x: 105, y: 725, text: 'Autoscale: CPU > 70%', fontSize: 10.5, strokeColor: '#64748b' });

// MICROSERVICE 2: API GATEWAY
addRect({
  x: 330,
  y: 605,
  w: 235,
  h: 150,
  strokeColor: '#2563eb',
  backgroundColor: '#ffffff',
  strokeWidth: 2
});
addText({ x: 345, y: 618, text: 'gateway-service', fontSize: 15, strokeColor: '#1d4ed8' });
addText({ x: 345, y: 640, text: 'Spring Cloud Gateway (:8080)\nPerimeter JWT Auth & Rate Limit', fontSize: 11.5, strokeColor: '#475569' });
addBadge({ x: 345, y: 690, text: 'HPA: 2 - 10 Replicas', strokeColor: '#2563eb', backgroundColor: '#dbeafe', textColor: '#1e40af', fontSize: 10 });
addText({ x: 345, y: 725, text: 'Autoscale: 100 RPS / pod', fontSize: 10.5, strokeColor: '#64748b' });

// MICROSERVICE 3: ACCOUNT & KYC
addRect({
  x: 585,
  y: 605,
  w: 220,
  h: 150,
  strokeColor: '#4f46e5',
  backgroundColor: '#ffffff',
  strokeWidth: 1.5
});
addText({ x: 600, y: 618, text: 'account-service', fontSize: 15, strokeColor: '#4338ca' });
addText({ x: 600, y: 640, text: 'Spring Boot 3 (:8081)\nKYC, RTR Auth, Account Master', fontSize: 11.5, strokeColor: '#475569' });
addBadge({ x: 600, y: 690, text: 'HPA: 2 - 8 Replicas', strokeColor: '#4f46e5', backgroundColor: '#e0e7ff', textColor: '#3730a3', fontSize: 10 });
addText({ x: 600, y: 725, text: 'HikariCP Pool: 25 conns', fontSize: 10.5, strokeColor: '#64748b' });

// MICROSERVICE 4: LEDGER MUTATION ENGINE
addRect({
  x: 825,
  y: 605,
  w: 235,
  h: 305,
  strokeColor: '#7c3aed',
  backgroundColor: '#ffffff',
  strokeWidth: 2
});
addText({ x: 840, y: 618, text: 'ledger-mutation-engine', fontSize: 15, strokeColor: '#6d28d9' });
addText({ x: 840, y: 640, text: 'Spring Boot 3 (:8082)\nCore Concurrency & Mutations\n• Pessimistic Row Locking\n• 4-Decimal Math (@Digits 14,4)\n• Transactional Outbox Pattern\n• Transfer Saga Consumer', fontSize: 11, strokeColor: '#334155', lineHeight: 1.3 });
addBadge({ x: 840, y: 735, text: 'KEDA AUTOSCALE: 2 - 6 Replicas', strokeColor: '#7c3aed', backgroundColor: '#ede9fe', textColor: '#5b21b6', fontSize: 10 });
addBadge({ x: 840, y: 770, text: 'Trigger: Kafka Lag > 50 msgs', strokeColor: '#7c3aed', backgroundColor: '#ede9fe', textColor: '#5b21b6', fontSize: 10 });
addBadge({ x: 840, y: 805, text: 'HikariCP Pool: 30 conns (Capped)', strokeColor: '#0284c7', backgroundColor: '#e0f2fe', textColor: '#0369a1', fontSize: 10 });
addText({ x: 840, y: 845, text: 'Partition Constraint:\n6 Partitions = Max 6 Parallel Consumers\n(Preserves per-account ordering)', fontSize: 10.5, strokeColor: '#64748b', lineHeight: 1.3 });

// MICROSERVICE 5: NOTIFICATION SERVICE
addRect({
  x: 1080,
  y: 605,
  w: 230,
  h: 150,
  strokeColor: '#059669',
  backgroundColor: '#ffffff',
  strokeWidth: 1.5
});
addText({ x: 1095, y: 618, text: 'notification-service', fontSize: 15, strokeColor: '#047857' });
addText({ x: 1095, y: 640, text: 'Spring Boot 3 (:8083)\nAlerts, 2FA OTP & Receipts\n• Thymeleaf Template Engine\n• AMLA Compliance CTR Filing', fontSize: 11, strokeColor: '#475569', lineHeight: 1.3 });
addBadge({ x: 1095, y: 700, text: 'KEDA: 2 - 6 Replicas', strokeColor: '#059669', backgroundColor: '#d1fae5', textColor: '#065f46', fontSize: 10 });

// Worker queue badge below Notification & Account
addRect({
  x: 90,
  y: 775,
  w: 715,
  h: 135,
  strokeColor: '#cbd5e1',
  backgroundColor: '#ffffff',
  strokeWidth: 1.5
});
addText({ x: 110, y: 790, text: 'MICROSERVICE INTERACTION & ASYNCHRONOUS SCALING WORKFLOW', fontSize: 12.5, strokeColor: '#0f172a' });
addText({
  x: 110,
  y: 815,
  text: '1. Fast Ingestion (HTTP < 15ms): Gateway routes transfer to Ledger Engine -> Oracle records INITIATED + Outbox Event.\n2. Asynchronous Command Stream: Outbox worker polls events and produces to Kafka commands topic.\n3. Mutation Execution: Worker acquires SELECT FOR UPDATE on balance_master, computes balance, and updates state.\n4. Event Fan-out: State change published to Kafka events topic -> Audit Vault & Notification workers consume concurrently.',
  fontSize: 11,
  strokeColor: '#475569',
  lineHeight: 1.45
});


// ZONE 4: CACHING & EVENT STREAMING BACKBONE (Y: 950 to 1180)
addRect({
  x: 60,
  y: 950,
  w: 1280,
  h: 240,
  strokeColor: '#0f766e',
  backgroundColor: '#f0fdfa',
  strokeWidth: 2
});
addText({
  x: 80,
  y: 960,
  text: 'ZONE 3: IN-MEMORY CACHE & DISTRIBUTED EVENT STREAMING (Subnet: 10.0.2.0/24)',
  fontSize: 13,
  strokeColor: '#0f766e'
});

// Redis Cache Box
addRect({
  x: 90,
  y: 985,
  w: 520,
  h: 185,
  strokeColor: '#0d9488',
  backgroundColor: '#ffffff',
  strokeWidth: 2
});
addText({ x: 110, y: 1000, text: 'Azure Cache for Redis (In-Memory Fast Path :6380 TLS)', fontSize: 15, strokeColor: '#0f766e' });
addBadge({ x: 110, y: 1025, text: 'SUB-5MS LATENCY FAST PATH', strokeColor: '#0d9488', backgroundColor: '#ccfbf1', textColor: '#115e59' });
addBadge({ x: 335, y: 1025, text: 'Standard / Clustered Scale', strokeColor: '#0d9488', backgroundColor: '#ccfbf1', textColor: '#115e59' });
addText({
  x: 110,
  y: 1060,
  text: '• Token Blacklist: blacklist:jti:<id> (15-min TTL, instant logout check)\n• Token Rotation Families: token_family:<id> (7-day TTL, breach purge)\n• Idempotency Guard: tx:<uuid> (60-sec TTL, blocks duplicate clicks)\n• Read Cache: account:balance:<id> (30-sec TTL, absorbs 80% read volume)\n• 2FA OTP Store: 2fa:otp:<userId> (300-sec TTL for transfers > ₱50,000)',
  fontSize: 11,
  strokeColor: '#134e4a',
  lineHeight: 1.4
});

// Event Hubs Kafka Box
addRect({
  x: 640,
  y: 985,
  w: 670,
  h: 185,
  strokeColor: '#7c3aed',
  backgroundColor: '#ffffff',
  strokeWidth: 2
});
addText({ x: 660, y: 1000, text: 'Azure Event Hubs (Apache Kafka 1.0+ Surface :9093 SASL/SSL)', fontSize: 15, strokeColor: '#6d28d9' });
addBadge({ x: 660, y: 1025, text: 'FULLY MANAGED EVENT BROKER', strokeColor: '#7c3aed', backgroundColor: '#ede9fe', textColor: '#5b21b6' });
addBadge({ x: 915, y: 1025, text: 'Auto-Inflate Throughput Units (TUs)', strokeColor: '#7c3aed', backgroundColor: '#ede9fe', textColor: '#5b21b6' });
addText({
  x: 660,
  y: 1060,
  text: '• banking.transfers.commands (6 Partitions, Key: source_account_id)\n  -> Guarantees strict per-account chronological serialization without locks\n• banking.transfers.events (6 Partitions, Key: transfer_id)\n  -> Fan-out to Audit Vault and Notification consumer groups\n• banking.transfers.retry (3 Partitions, exponential backoff)\n• banking.transfers.dlt (1 Partition, dead-letter quarantine)',
  fontSize: 11,
  strokeColor: '#4c1d95',
  lineHeight: 1.4
});


// ZONE 5: DUAL-STORAGE RELATIONAL PERSISTENCE (Y: 1210 to 1530)
addRect({
  x: 60,
  y: 1210,
  w: 1280,
  h: 310,
  strokeColor: '#166534',
  backgroundColor: '#f0fdf4',
  strokeWidth: 2
});
addText({
  x: 80,
  y: 1220,
  text: 'ZONE 4: PERSISTENCE TIER - DUAL-STORAGE ARCHITECTURE (Subnet: 10.0.3.0/24)',
  fontSize: 13,
  strokeColor: '#166534'
});

// Master DB: Oracle XE
addRect({
  x: 90,
  y: 1245,
  w: 570,
  h: 255,
  strokeColor: '#ea580c',
  backgroundColor: '#ffffff',
  strokeWidth: 2
});
addText({ x: 110, y: 1260, text: 'Master Operational State: Oracle XE 21c (:1521 XEPDB1)', fontSize: 15, strokeColor: '#c2410c' });
addBadge({ x: 110, y: 1285, text: 'ACID MASTER PERSISTENCE', strokeColor: '#ea580c', backgroundColor: '#ffedd5', textColor: '#9a3412' });
addBadge({ x: 330, y: 1285, text: 'Azure VM + Premium SSD Disk', strokeColor: '#ea580c', backgroundColor: '#ffedd5', textColor: '#9a3412' });
addText({
  x: 110,
  y: 1320,
  text: '• Host: Linux VM (Standard_D2s_v5) + Attached 64GB Premium SSD Disk\n• Kernel: Pessimistic Row Locking Kernel (SELECT ... FOR UPDATE)\n• Strict Constraints: CHECK (balance_amount >= hold_amount >= 0)\n• Tables: users, accounts, balance_master, transactions, outbox_events\n• Concurrency Protection:\n  - Spring Boot HikariCP pool caps active connections at 30\n  - Transactional Outbox decouples HTTP bursts from disk write throughput\n  - Read queries offloaded to Redis 30s cache',
  fontSize: 11,
  strokeColor: '#7c2d12',
  lineHeight: 1.42
});

// Audit Vault DB: PostgreSQL Flexible Server
addRect({
  x: 690,
  y: 1245,
  w: 620,
  h: 255,
  strokeColor: '#059669',
  backgroundColor: '#ffffff',
  strokeWidth: 2
});
addText({ x: 710, y: 1260, text: 'Immutable Audit Vault: Azure PostgreSQL Flexible Server (:5432)', fontSize: 15, strokeColor: '#047857' });
addBadge({ x: 710, y: 1285, text: 'IMMUTABLE AUDIT VAULT', strokeColor: '#059669', backgroundColor: '#d1fae5', textColor: '#065f46' });
addBadge({ x: 915, y: 1285, text: 'Built-in PgBouncer Connection Pool', strokeColor: '#059669', backgroundColor: '#d1fae5', textColor: '#065f46' });
addText({
  x: 710,
  y: 1320,
  text: '• Architecture: Managed PaaS with Auto-Grow Storage & Automated Backups\n• Immutability Enforcement:\n  - Native Trigger: trg_no_update_delete_mutation_audit strictly blocks all\n    UPDATE and DELETE SQL statements. Records are 100% append-only.\n• Event Projection: Independent consumer group audit-vault-workers pulls from\n  banking.transfers.events and inserts audit entries asynchronously.\n• Read Scaling:\n  - Read-Replica can be spun up for regulatory audits with 0% impact on writes\n  - Indexed on (account_id, created_at) for sub-5ms query response',
  fontSize: 11,
  strokeColor: '#064e3b',
  lineHeight: 1.42
});


// ==========================================
// RIGHT COLUMN: SUPPORTING GOVERNANCE, OBSERVABILITY & LEGEND (X: 1370 to 1900, Width: 530)
// ==========================================

addRect({
  x: 1370,
  y: 150,
  w: 530,
  h: 1370,
  strokeColor: '#475569',
  backgroundColor: '#f8fafc',
  strokeWidth: 2
});
addText({
  x: 1390,
  y: 165,
  text: 'PLATFORM GOVERNANCE, OBSERVABILITY & EXTERNAL INTEGRATIONS',
  fontSize: 13,
  strokeColor: '#0f172a'
});

// BOX 1: AZURE KEY VAULT
addRect({
  x: 1390,
  y: 195,
  w: 490,
  h: 140,
  strokeColor: '#e11d48',
  backgroundColor: '#ffffff',
  strokeWidth: 1.5
});
addText({ x: 1410, y: 210, text: 'Azure Key Vault & Managed Identities', fontSize: 15, strokeColor: '#be123c' });
addBadge({ x: 1410, y: 235, text: 'ZERO-SECRET ARCHITECTURE', strokeColor: '#e11d48', backgroundColor: '#ffe4e6', textColor: '#9f1239' });
addText({
  x: 1410,
  y: 268,
  text: '• Replaces plaintext passwords in .env / git files.\n• Microservices use Azure System-Assigned Managed Identity to pull:\n  - Database credentials (Oracle & Postgres passwords)\n  - Cryptographic HMAC-SHA256 JWT signing secret\n  - SendGrid SMTP API keys & Datadog API Key',
  fontSize: 11,
  strokeColor: '#475569',
  lineHeight: 1.4
});

// BOX 2: AZURE CONTAINER REGISTRY
addRect({
  x: 1390,
  y: 350,
  w: 490,
  h: 120,
  strokeColor: '#2563eb',
  backgroundColor: '#ffffff',
  strokeWidth: 1.5
});
addText({ x: 1410, y: 365, text: 'Azure Container Registry (ACR)', fontSize: 15, strokeColor: '#1d4ed8' });
addBadge({ x: 1410, y: 390, text: 'SECURE OCI IMAGE REGISTRY', strokeColor: '#2563eb', backgroundColor: '#dbeafe', textColor: '#1e40af' });
addText({
  x: 1410,
  y: 422,
  text: '• Houses versioned Docker images for all 5 services\n• Pull-authenticated via Managed Identity (zero token rotation)\n• Automated vulnerability scanning on image push',
  fontSize: 11,
  strokeColor: '#475569',
  lineHeight: 1.35
});

// BOX 3: CLOUD OBSERVABILITY (DATADOG + AZURE MONITOR)
addRect({
  x: 1390,
  y: 485,
  w: 490,
  h: 210,
  strokeColor: '#7c3aed',
  backgroundColor: '#ffffff',
  strokeWidth: 1.5
});
addText({ x: 1410, y: 500, text: 'Datadog Enterprise APM & Telemetry', fontSize: 15, strokeColor: '#6d28d9' });
addBadge({ x: 1410, y: 525, text: 'DISTRIBUTED TRACING & TPS SLA', strokeColor: '#7c3aed', backgroundColor: '#ede9fe', textColor: '#5b21b6' });
addText({
  x: 1410,
  y: 560,
  text: '• dd-java-agent bytecode instrumentation across all Spring Boot apps\n• APM Trace Ingestion (:8126) + OpenTelemetry spans (:4317/:4318)\n• DogStatsD UDP (:8125): Custom transaction metrics (TPS counter against\n  200 TPS benchmark, p50/p95/p99 latency against 150ms SLA)\n• HikariCP pool saturation & Kafka consumer lag monitors\n• Synthetic Check Runner (datadog-synthetics-worker) validating\n  internal banking-net APIs',
  fontSize: 11,
  strokeColor: '#475569',
  lineHeight: 1.4
});

// BOX 4: TRANSACTIONAL EMAIL SERVICE
addRect({
  x: 1390,
  y: 710,
  w: 490,
  h: 145,
  strokeColor: '#0284c7',
  backgroundColor: '#ffffff',
  strokeWidth: 1.5
});
addText({ x: 1410, y: 725, text: 'Cloud SMTP: SendGrid / Azure Comm Services', fontSize: 15, strokeColor: '#0369a1' });
addBadge({ x: 1410, y: 750, text: 'REPLACES LOCAL MAILHOG', strokeColor: '#0284c7', backgroundColor: '#e0f2fe', textColor: '#0369a1' });
addText({
  x: 1410,
  y: 785,
  text: '• Production replacement for MailHog mock inbox\n• Dispatches real 6-digit OTP codes via SMTP (:587 TLS) for transfers\n  exceeding ₱50,000.00 directly to customer mobile email inboxes\n• Dispatches HTML debit/credit transfer receipts with SHA-256 verification',
  fontSize: 11,
  strokeColor: '#475569',
  lineHeight: 1.4
});

// BOX 5: ARCHITECTURE SCALING LEGEND & SUMMARY
addRect({
  x: 1390,
  y: 870,
  w: 490,
  h: 630,
  strokeColor: '#334155',
  backgroundColor: '#ffffff',
  strokeWidth: 2
});
addText({ x: 1410, y: 885, text: 'SCALING MECHANISM REFERENCE MATRIX', fontSize: 15, strokeColor: '#0f172a' });

const legendItems = [
  {
    badge: 'TIER 1 LOAD BALANCER',
    desc: 'Azure Application Gateway v2 (L7) terminates SSL at the edge, enforces WAF security rules, and distributes requests via round-robin to healthy container replicas.',
    color: '#d97706', bg: '#fef3c7'
  },
  {
    badge: 'TIER 2 LOAD BALANCER',
    desc: 'Azure Container Apps internal Envoy proxy automatically routes east-west microservice calls (e.g. gateway -> ledger) across dynamic container replicas using virtual DNS.',
    color: '#2563eb', bg: '#dbeafe'
  },
  {
    badge: 'HPA AUTOSCALE',
    desc: 'Horizontal Pod Autoscaling: Scales stateless containers (Frontend, Gateway, Account) from 2 up to 10 instances based on CPU utilization (>70%) and concurrent HTTP request rate.',
    color: '#0284c7', bg: '#e0f2fe'
  },
  {
    badge: 'KEDA AUTOSCALE',
    desc: 'Kubernetes Event-driven Autoscaling: Scales worker replicas (Ledger Engine, Notification) based on message lag in Kafka/Event Hubs topics. When queue grows, workers scale out.',
    color: '#7c3aed', bg: '#ede9fe'
  },
  {
    badge: 'PARTITION SCALING BOUND',
    desc: 'Topics partitioned by source_account_id (6 partitions). Maximum effective consumer count is 6, guaranteeing chronological transaction order per bank account without race conditions.',
    color: '#4c1d95', bg: '#f3e8ff'
  },
  {
    badge: 'HIKARICP CONCURRENCY CAP',
    desc: 'Connection pool caps (30 conns) protect Oracle XE from connection exhaustion during traffic bursts. Transactional Outbox pattern offloads heavy processing to Kafka asynchronously.',
    color: '#ea580c', bg: '#ffedd5'
  },
  {
    badge: 'PGBOUNCER POOLING',
    desc: 'Built-in connection pooler on PostgreSQL Flexible Server multiplexes thousands of incoming audit stream connections into a compact set of database workers.',
    color: '#059669', bg: '#d1fae5'
  }
];

let legendY = 920;
for (const item of legendItems) {
  addBadge({ x: 1410, y: legendY, text: item.badge, strokeColor: item.color, backgroundColor: item.bg, textColor: item.color, fontSize: 10 });
  addText({ x: 1410, y: legendY + 30, text: item.desc, fontSize: 10.5, strokeColor: '#475569', lineHeight: 1.35 });
  legendY += 76;
}


// ==========================================
// CONNECTORS & FLOW ARROWS (Orthogonal & Clean)
// ==========================================

// Client -> App Gateway
addArrow({
  x1: 390, y1: 230, x2: 390, y2: 300,
  strokeColor: '#3b82f6', strokeWidth: 2,
  label: 'HTTPS :443'
});
addArrow({
  x1: 950, y1: 230, x2: 950, y2: 300,
  strokeColor: '#64748b', strokeWidth: 2,
  label: 'HTTPS :443'
});

// App Gateway -> Frontend & Gateway
addArrow({
  x1: 200, y1: 435, x2: 200, y2: 605,
  strokeColor: '#0284c7', strokeWidth: 2,
  label: 'Path: /* (SPA Static)'
});
addArrow({
  x1: 445, y1: 435, x2: 445, y2: 605,
  strokeColor: '#2563eb', strokeWidth: 2.5,
  label: 'Path: /api/* (API Traffic)'
});

// Gateway -> Envoy Proxy / Internal services
addArrow({
  x1: 565, y1: 670, x2: 585, y2: 670,
  strokeColor: '#4f46e5', strokeWidth: 2,
  label: 'HTTP :8081'
});
addArrow({
  x1: 565, y1: 710, x2: 825, y2: 710,
  strokeColor: '#7c3aed', strokeWidth: 2,
  label: 'HTTP :8082'
});

// Services -> Redis Cache
addArrow({
  x1: 445, y1: 755, x2: 350, y2: 985,
  strokeColor: '#0d9488', strokeWidth: 2,
  label: 'Token Blacklist & Rate Limit'
});
addArrow({
  x1: 695, y1: 755, x2: 450, y2: 985,
  strokeColor: '#0d9488', strokeWidth: 2,
  label: 'RTR Token Family'
});
addArrow({
  x1: 890, y1: 910, x2: 550, y2: 985,
  strokeColor: '#0d9488', strokeWidth: 2,
  label: 'Idempotency Lock & Balance Cache'
});

// Ledger Engine -> Event Hubs / Kafka
addArrow({
  x1: 950, y1: 910, x2: 950, y2: 985,
  strokeColor: '#7c3aed', strokeWidth: 2.5,
  label: 'Produce Commands & Events (:9093)'
});

// Event Hubs -> Consumers
addArrow({
  x1: 1000, y1: 985, x2: 1000, y2: 910,
  strokeColor: '#7c3aed', strokeWidth: 2, strokeStyle: 'dashed',
  label: 'Consume Commands'
});
addArrow({
  x1: 1195, y1: 985, x2: 1195, y2: 755,
  strokeColor: '#059669', strokeWidth: 2, strokeStyle: 'dashed',
  label: 'Consume Events (:9093)'
});

// Notification Service -> SendGrid
addArrow({
  x1: 1310, y1: 680, x2: 1390, y2: 760,
  strokeColor: '#0284c7', strokeWidth: 2,
  label: 'SMTP :587 (OTP & Receipts)'
});

// Databases:
// Account Svc & Ledger Engine -> Oracle Master DB
addArrow({
  x1: 650, y1: 755, x2: 350, y2: 1245,
  strokeColor: '#ea580c', strokeWidth: 2,
  label: 'Oracle TNS :1521 (Users & KYC)'
});
addArrow({
  x1: 850, y1: 910, x2: 480, y2: 1245,
  strokeColor: '#ea580c', strokeWidth: 2.5,
  label: 'SELECT FOR UPDATE & Outbox INSERT'
});

// Event Hubs -> PostgreSQL Audit Vault
addArrow({
  x1: 950, y1: 1170, x2: 950, y2: 1245,
  strokeColor: '#059669', strokeWidth: 2.5,
  label: 'Audit Consumer Insert (:5432)'
});

// Write to file
const excalidrawFile = {
  type: 'excalidraw',
  version: 2,
  source: 'https://excalidraw.com',
  elements,
  appState: {
    gridSize: 20,
    viewBackgroundColor: '#ffffff'
  },
  files: {}
};

const outputPath = path.resolve(__dirname, '../azure_scaling_architecture.excalidraw');
fs.writeFileSync(outputPath, JSON.stringify(excalidrawFile, null, 2), 'utf-8');
console.log(`Successfully generated Excalidraw diagram at: ${outputPath}`);
console.log(`Total elements: ${elements.length}`);
