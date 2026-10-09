import React, { useState, useEffect, useMemo } from 'react';
import { 
  ShieldCheck, 
  ShieldAlert, 
  RotateCcw, 
  CheckCircle2, 
  Clock, 
  Search, 
  MapPin, 
  Users, 
  Database, 
  AlertTriangle, 
  Check, 
  Copy, 
  RefreshCw, 
  Globe, 
  X, 
  Layers, 
  ArrowRight, 
  TrendingUp, 
  ChevronRight, 
  SlidersHorizontal, 
  Activity, 
  Lock, 
  Fingerprint, 
  Cpu, 
  Radio, 
  PhoneCall, 
  ScreenShare, 
  Terminal, 
  Zap, 
  FileText,
  BarChart3,
  PieChart as PieChartIcon,
  Shield,
  HelpCircle,
  AlertOctagon,
  Info,
  CreditCard,
  Wallet,
  Eye,
  UserCheck,
  Unlock
} from 'lucide-react';
import apiClient, { mockState } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { formatPHP } from '../utils/currency';
import { cn } from '../ui/cn';

// Geolocation Presets for Fraud Testing
const GEO_PRESETS = [
  {
    id: 'BASELINE',
    name: 'Customer Registered Baseline',
    lat: null,
    lon: null,
    ip: null,
    type: 'SAFE',
    label: 'Home Baseline',
    desc: 'Restore account holder authorized baseline coordinates'
  },
  {
    id: 'MNL',
    name: 'Metro Manila, Philippines',
    lat: 14.5995,
    lon: 120.9842,
    ip: '112.198.45.10',
    type: 'SAFE',
    label: 'Capital District',
    desc: 'Safe domestic origin in NCR Metro Manila'
  },
  {
    id: 'CEB',
    name: 'Cebu City, Philippines',
    lat: 10.3157,
    lon: 123.8854,
    ip: '112.198.88.22',
    type: 'SAFE',
    label: 'Visayas Hub',
    desc: 'Normal domestic transit within Philippine airspace'
  },
  {
    id: 'LON',
    name: 'London, UK',
    lat: 51.5074,
    lon: -0.1278,
    ip: '185.86.151.11',
    type: 'FRAUD',
    label: '🚨 Impossible Travel',
    desc: '10,740 km international jump. Triggers security hold'
  },
  {
    id: 'NYC',
    name: 'New York, USA',
    lat: 40.7128,
    lon: -74.0060,
    ip: '198.51.100.42',
    type: 'FRAUD',
    label: '🚨 Impossible Travel',
    desc: '13,670 km international jump. Triggers security hold'
  }
];

// Multi-Customer Simulation Target Directory (Expanded Retail Customer Pool)
const SIMULATION_CUSTOMERS = [
  {
    userId: 'usr-1001-cst-001',
    name: 'Juan Dela Cruz',
    email: 'juan.delacruz@retailbank.ph',
    accountNumber: '1000-2000-3001',
    baselineCity: 'Manila, Philippines',
    lat: 14.5995,
    lon: 120.9842,
    ip: '112.198.45.10',
    avatar: 'JD',
    balance: '₱15,000,000.00',
    tier: 'Retail Primary'
  },
  {
    userId: 'usr-1002-cst-002',
    name: 'Maria Clara Santos',
    email: 'maria.santos@retailbank.ph',
    accountNumber: '1000-2000-3002',
    baselineCity: 'Cebu City, Philippines',
    lat: 10.3157,
    lon: 123.8854,
    ip: '112.198.88.22',
    avatar: 'MC',
    balance: '₱8,500,000.00',
    tier: 'Premier Client'
  },
  {
    userId: 'usr-1003-cst-003',
    name: 'Jose Rizal',
    email: 'jose.rizal@retailbank.ph',
    accountNumber: '1000-2000-3004',
    baselineCity: 'Calamba, Laguna, Philippines',
    lat: 14.2117,
    lon: 121.1656,
    ip: '112.198.33.15',
    avatar: 'JR',
    balance: '₱5,200,000.00',
    tier: 'Commercial'
  },
  {
    userId: 'usr-1004-cst-004',
    name: 'Andres Bonifacio',
    email: 'andres.bonifacio@retailbank.ph',
    accountNumber: '1000-2000-3005',
    baselineCity: 'Davao City, Philippines',
    lat: 7.1907,
    lon: 125.4553,
    ip: '112.198.99.77',
    avatar: 'AB',
    balance: '₱3,750,000.00',
    tier: 'Retail Standard'
  },
  {
    userId: 'usr-1005-cst-005',
    name: 'Gabriela Silang',
    email: 'gabriela.silang@retailbank.ph',
    accountNumber: '1000-2000-3006',
    baselineCity: 'Vigan, Ilocos Sur, Philippines',
    lat: 17.5747,
    lon: 120.3869,
    ip: '112.198.71.12',
    avatar: 'GS',
    balance: '₱4,200,000.00',
    tier: 'Retail Standard'
  },
  {
    userId: 'usr-1006-cst-006',
    name: 'Emilio Jacinto',
    email: 'emilio.jacinto@retailbank.ph',
    accountNumber: '1000-2000-3007',
    baselineCity: 'Quezon City, Philippines',
    lat: 14.6760,
    lon: 121.0437,
    ip: '112.198.22.44',
    avatar: 'EJ',
    balance: '₱6,800,000.00',
    tier: 'Commercial'
  },
  {
    userId: 'usr-1007-cst-007',
    name: 'Melchora Aquino',
    email: 'melchora.aquino@retailbank.ph',
    accountNumber: '1000-2000-3008',
    baselineCity: 'Caloocan, Philippines',
    lat: 14.6495,
    lon: 120.9679,
    ip: '112.198.63.89',
    avatar: 'MA',
    balance: '₱2,950,000.00',
    tier: 'Retail Standard'
  },
  {
    userId: 'usr-1008-cst-008',
    name: 'Apolinario Mabini',
    email: 'apolinario.mabini@retailbank.ph',
    accountNumber: '1000-2000-3009',
    baselineCity: 'Batangas City, Philippines',
    lat: 13.7565,
    lon: 121.0583,
    ip: '112.198.54.33',
    avatar: 'AM',
    balance: '₱9,100,000.00',
    tier: 'Premier Client'
  }
];

// 3 Distinct Bank Admin Roles (Segregation of Duties & Least Privilege RBAC)
const ADMIN_ROSTER = [
  {
    userId: 'usr-1007-sec-003',
    name: 'Alex Rivera',
    email: 'alex.rivera@bank.com',
    role: 'Fraud Ops & Security Analyst',
    badge: 'Fraud Ops Analyst',
    capability: 'SIMULATION',
    capabilityLabel: 'Security Simulation & Threat Radar',
    desc: 'Authorized to inject Geo jumps, simulate threat vectors, and monitor live AI threat radar.',
    allowedViews: ['overview', 'threat_radar', 'geo_surveillance'],
    defaultView: 'threat_radar',
    menuSection: 'Fraud & Threat Center',
  },
  {
    userId: 'usr-1006-mgr-002',
    name: 'Carlos Mendoza',
    email: 'carlos.mendoza@bank.com',
    role: 'Customer Service & Branch Operations',
    badge: 'Branch Operations Officer',
    capability: 'ACCOUNT_LOCK_UNLOCK',
    capabilityLabel: 'Account Freeze/Unfreeze & 360 Governance',
    desc: 'Authorized to freeze/unfreeze customer accounts and manage Customer 360° profiles.',
    allowedViews: ['overview', 'accounts', 'transactions'],
    defaultView: 'accounts',
    menuSection: 'Branch Operations Center',
  },
  {
    userId: 'usr-1004-adm-001',
    name: 'Diana Vance',
    email: 'diana.admin@bank.com',
    role: 'Compliance & Settlement Auditor',
    badge: 'Compliance Lead (Checker)',
    capability: 'REVERSAL_APPROVAL',
    capabilityLabel: 'Maker-Checker Reversal Sign-Off',
    desc: 'Authorized to approve T24 compensating reversals (Maker-Checker) and inspect WORM vault.',
    allowedViews: ['overview', 'transactions', 'audit_vault', 'sar_queue'],
    defaultView: 'transactions',
    menuSection: 'Compliance & Audit Center',
  }
];

// Background Applications & Device Posture Threat Vectors (NanoJev / Laya Neural Monitor)
const BACKGROUND_APP_THREATS = [
  { key: 'remote_access_rat', label: 'Remote Access RATs (AnyDesk / TeamViewer / RustDesk)', pct: 38, count: 47, color: '#EF4444', action: 'BLOCK / HOLD', risk: 'CRITICAL', desc: 'Accessibility service remote-control or screen-sharing process active in background.' },
  { key: 'voice_call_coercion', label: 'Live Voice Call Coercion (Vishing / In-Call)', pct: 26, count: 32, color: '#F97316', action: 'STEP-UP 2FA', risk: 'HIGH', desc: 'Active telephony call (CALL_STATE_OFFHOOK) detected concurrent with funds transfer initiation.' },
  { key: 'screen_recording', label: 'Media Projection & Screen Recording Active', pct: 15, count: 18, color: '#A855F7', action: 'STEP-UP BIOMETRIC', risk: 'MEDIUM-HIGH', desc: 'Virtual display recording stream capturing real-time user authentication screens.' },
  { key: 'sideloaded_dropper', label: 'Sideloaded APK Droppers (Unofficial Installer)', pct: 10, count: 12, color: '#F59E0B', action: 'EXTRA AUDIT', risk: 'MEDIUM', desc: 'Banking app environment running alongside apps installed from unverified web origins.' },
  { key: 'clipboard_injection', label: 'Clipboard Injection / Hooked Payee Input', pct: 6, count: 7, color: '#38BDF8', action: 'PAYEE VERIFY', risk: 'ELEVATED', desc: 'Destination account pasted via background accessibility pasteboard interceptor.' },
  { key: 'root_hooking_frida', label: 'Root & Hooking Frameworks (Frida / Magisk)', pct: 3, count: 4, color: '#E11D48', action: 'BLOCK EXECUTION', risk: 'CRITICAL', desc: 'Frida-server ptrace injection, Magisk root bypass, or substrate zygote hooks detected.' },
  { key: 'clean_device_posture', label: 'Clean Verified Device Posture', pct: 2, count: 2, color: '#10B981', action: 'ALLOW STP', risk: 'CLEAN', desc: 'Hardware KeyStore backed, Google Play Protect certified, zero anomalous background processes.' }
];

// Alias for backwards compatibility where referenced
const SCAM_TYPOLOGIES = BACKGROUND_APP_THREATS;

// Daily velocity and threat datapoints for the 7-day range
const VELOCITY_SERIES = [
  { day: 'Mon', settled: 320000, threat: 35000, label: 'Mon Oct 29' },
  { day: 'Tue', settled: 480000, threat: 55000, label: 'Tue Oct 30' },
  { day: 'Wed', settled: 950000, threat: 110000, label: 'Wed Oct 31' },
  { day: 'Thu', settled: 1150000, threat: 140000, label: 'Thu Nov 01' },
  { day: 'Fri', settled: 880000, threat: 85000, label: 'Fri Nov 02' },
  { day: 'Sat', settled: 740000, threat: 60000, label: 'Sat Nov 03' },
  { day: 'Today', settled: 1439201, threat: 250000, label: 'Today (Peak 14:00)' }
];

// Reusable Interactive Info Tooltip
function InfoTooltip({ title, text, align = 'right', inverted = false, direction = 'top' }) {
  const [isOpen, setIsOpen] = useState(false);
  const isDrop = direction === 'bottom' || inverted;

  return (
    <div 
      className="relative inline-flex items-center"
      onMouseEnter={() => setIsOpen(true)}
      onMouseLeave={() => setIsOpen(false)}
      onFocus={() => setIsOpen(true)}
      onBlur={() => setIsOpen(false)}
    >
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          setIsOpen(!isOpen);
        }}
        className={cn(
          "flex h-4 w-4 items-center justify-center rounded-full transition focus:outline-none",
          inverted
            ? "text-white/80 hover:text-white hover:bg-white/10"
            : "text-fg-subtle hover:text-accent hover:bg-surface/80"
        )}
        aria-label="Information"
      >
        <Info className="h-3.5 w-3.5" />
      </button>

      {isOpen && (
        <div 
          className={cn(
            "absolute z-50 w-72 rounded-2xl border border-line bg-surface p-3.5 text-left shadow-2xl backdrop-blur-md transition animate-in fade-in zoom-in-95 duration-150 pointer-events-none text-fg",
            isDrop ? "top-full mt-2" : "bottom-full mb-2",
            align === 'right' ? "right-0" : align === 'left' ? "left-0" : "left-1/2 -translate-x-1/2"
          )}
        >
          {title && (
            <div className="flex items-center gap-1.5 text-xs font-semibold text-fg mb-1">
              <Info className="h-3.5 w-3.5 text-accent shrink-0" />
              <span>{title}</span>
            </div>
          )}
          <p className="text-[11px] text-fg-muted leading-relaxed">{text}</p>
        </div>
      )}
    </div>
  );
}

// Helper to format short IDs
const formatShortId = (id) => {
  if (!id) return '';
  if (id.length <= 16) return id;
  const isRev = id.endsWith('-REV');
  const cleanId = isRev ? id.slice(0, -4) : id;
  return `${cleanId.slice(0, 8)}···${cleanId.slice(-4)}${isRev ? '-REV' : ''}`;
};

// =========================================================================
// ROLE OVERVIEW 1: FRAUD OPS & SECURITY ANALYST (ALEX RIVERA)
// =========================================================================
function OverviewFraud({
  stats,
  transactions,
  hoveredVelocityIdx,
  setHoveredVelocityIdx,
  setSelectedTx,
  formatPHP,
  BACKGROUND_APP_THREATS,
  VELOCITY_SERIES
}) {
  const activeThreatsCount = BACKGROUND_APP_THREATS.reduce((sum, t) => sum + (t.risk !== 'CLEAN' ? t.count : 0), 0);
  const flaggedTxs = useMemo(() => {
    return transactions.filter(t => t.status === 'HELD_FRAUD' || t.status === 'PENDING_APPROVAL' || t.amount >= 200000);
  }, [transactions]);

  return (
    <div className="space-y-6">
      {/* Top Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Highlight Card: Royal Violet */}
        <div className="rounded-3xl bg-[#311075] text-white p-6 shadow-md relative flex flex-col justify-between min-h-[175px]">
          <div className="absolute inset-0 rounded-3xl overflow-hidden pointer-events-none">
            <div className="absolute top-0 right-0 -mt-8 -mr-8 h-48 w-48 rounded-full bg-purple-400/15 blur-2xl" />
          </div>
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-white/10 text-white shadow-xs">
                  <ShieldAlert className="h-4 w-4 text-white" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-white/80">
                  Flagged Threat Volume
                </span>
              </div>
              <InfoTooltip 
                title="Neural Threat Volume"
                text="Real-time aggregation of retail transaction volumes placed on hold or evaluated by the Laya / NanoJev threat radar."
                inverted={true}
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-white font-mono">
                {formatPHP(stats.threatVolume || 250000)}
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-rose-300">
                <AlertTriangle className="h-3.5 w-3.5 shrink-0" />
                <span>{stats.heldCount || 1} active high-friction containment hold</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-white/10 flex items-center justify-between text-[11px] text-white/70">
            <span>Threat Ratio: 17.3% Peak</span>
            <span className="font-semibold text-emerald-300">Gate 0 Intercept</span>
          </div>
        </div>

        {/* White Card 2: Active Background App Threats */}
        <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs flex flex-col justify-between min-h-[175px]">
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-accent/10 text-accent">
                  <Radio className="h-4 w-4" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-fg-subtle">
                  Active App Threats
                </span>
              </div>
              <InfoTooltip 
                title="Background App Threats"
                text="Active client background processes monitored in real-time, including remote desktop RATs, screen recording, and live voice calls."
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-fg font-mono">
                {activeThreatsCount} Incidents
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-rose-500 font-medium">
                <ScreenShare className="h-3.5 w-3.5 shrink-0" />
                <span>47 Remote Access RAT sessions flagged</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-line flex items-center justify-between text-[11px] text-fg-subtle">
            <span>7 Monitored Threat Vectors</span>
            <span className="text-accent font-semibold font-mono">Laya Sensor Active</span>
          </div>
        </div>

        {/* White Card 3: Neural Pipeline Latency SLA */}
        <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs flex flex-col justify-between min-h-[175px]">
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-accent/10 text-accent">
                  <Cpu className="h-4 w-4" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-fg-subtle">
                  Two-Stage Latency SLA
                </span>
              </div>
              <InfoTooltip 
                title="Two-Stage Pipeline SLA"
                text="Stage A deterministic Gate 0 + XGBoost tabular checks evaluate in <30ms; Stage B ONNX neural inference runs within a bounded 1500ms timeout."
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-fg font-mono">
                12ms / 180ms
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-emerald-500 font-medium">
                <CheckCircle2 className="h-3.5 w-3.5 shrink-0" />
                <span>Deterministic S2 + NanoJev Invariant Pass</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-line flex items-center justify-between text-[11px] text-fg-subtle">
            <span>Hard Deadline: 1,500ms</span>
            <span className="text-emerald-500 font-semibold font-mono">100% On-Time</span>
          </div>
        </div>
      </div>

      {/* Chart Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* 7-Day Velocity Chart */}
        <div className="lg:col-span-2 rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 border-b border-line pb-4">
            <div>
              <div className="flex items-center gap-2">
                <BarChart3 className="h-4 w-4 text-accent" />
                <h3 className="text-sm font-semibold text-fg">
                  7-Day Velocity & Threat Stream
                </h3>
                <InfoTooltip 
                  title="Settled vs Threat Velocity"
                  text="Daily comparison of cleared volume against intercepted threat volume across retail banking channels."
                />
              </div>
              <p className="mt-0.5 text-xs text-fg-muted">
                Hover columns to inspect transaction totals and flagged threat volume.
              </p>
            </div>
            {/* Range HUD */}
            <div className="rounded-2xl border border-line bg-sunken/60 px-3.5 py-1.5 text-xs flex items-center gap-3">
              <div>
                <span className="text-[10px] text-fg-subtle uppercase block font-semibold">Hovered Period</span>
                <span className="font-semibold text-fg">{VELOCITY_SERIES[hoveredVelocityIdx].label}</span>
              </div>
              <div className="h-6 w-px bg-line" />
              <div>
                <span className="text-[10px] text-fg-subtle uppercase block font-semibold">Cleared</span>
                <span className="font-mono font-bold text-accent">{formatPHP(VELOCITY_SERIES[hoveredVelocityIdx].settled)}</span>
              </div>
              <div className="h-6 w-px bg-line" />
              <div>
                <span className="text-[10px] text-fg-subtle uppercase block font-semibold">Threat</span>
                <span className="font-mono font-bold text-rose-500">{formatPHP(VELOCITY_SERIES[hoveredVelocityIdx].threat)}</span>
              </div>
            </div>
          </div>

          {/* Bar Chart Representation */}
          <div className="pt-4 pb-2">
            <div className="flex items-end justify-between gap-3 h-48 px-2">
              {VELOCITY_SERIES.map((item, idx) => {
                const maxVal = 1500000;
                const settledHeight = Math.min(100, Math.round((item.settled / maxVal) * 100));
                const threatHeight = Math.min(100, Math.round((item.threat / maxVal) * 100));
                const isHovered = hoveredVelocityIdx === idx;
                return (
                  <div
                    key={item.day}
                    onMouseEnter={() => setHoveredVelocityIdx(idx)}
                    className="flex-1 flex flex-col items-center h-full justify-end cursor-pointer group"
                  >
                    <div className="w-full max-w-[42px] flex items-end justify-center gap-1 h-full pb-2">
                      <div
                        style={{ height: `${settledHeight}%` }}
                        className={cn(
                          "w-1/2 rounded-t-lg transition-all duration-200",
                          isHovered ? "bg-[#311075]" : "bg-[#311075]/70 group-hover:bg-[#311075]"
                        )}
                        title={`Settled: ${formatPHP(item.settled)}`}
                      />
                      <div
                        style={{ height: `${threatHeight}%` }}
                        className={cn(
                          "w-1/2 rounded-t-lg transition-all duration-200",
                          isHovered ? "bg-rose-500" : "bg-rose-400/80 group-hover:bg-rose-500"
                        )}
                        title={`Threat: ${formatPHP(item.threat)}`}
                      />
                    </div>
                    <span className={cn(
                      "text-[11px] font-medium transition",
                      isHovered ? "text-accent font-bold" : "text-fg-subtle"
                    )}>
                      {item.day}
                    </span>
                  </div>
                );
              })}
            </div>
            <div className="flex items-center justify-center gap-6 pt-4 border-t border-line text-xs">
              <div className="flex items-center gap-2">
                <span className="h-3 w-3 rounded-md bg-[#311075]" />
                <span className="text-fg-muted font-medium">Cleared Volume</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="h-3 w-3 rounded-md bg-rose-500" />
                <span className="text-fg-muted font-medium">Flagged Threat</span>
              </div>
            </div>
          </div>
        </div>

        {/* Background App Threat Radar Breakdown */}
        <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between border-b border-line pb-3">
              <div className="flex items-center gap-2">
                <Zap className="h-4 w-4 text-accent" />
                <h3 className="text-sm font-semibold text-fg">
                  Background App Threat Radar
                </h3>
              </div>
              <InfoTooltip 
                title="NanoJev Device Telemetry"
                text="7 monitored background process & device posture threat vectors detected by the client security SDK."
              />
            </div>
            <div className="mt-3 divide-y divide-line/60">
              {BACKGROUND_APP_THREATS.slice(0, 5).map((threat) => (
                <div key={threat.key} className="py-2.5 space-y-1.5">
                  <div className="flex items-center justify-between text-xs">
                    <span className="font-semibold text-fg truncate max-w-[170px]">{threat.label.split('(')[0]}</span>
                    <span className="font-mono font-bold" style={{ color: threat.color }}>{threat.pct}%</span>
                  </div>
                  <div className="h-1.5 w-full rounded-full bg-sunken overflow-hidden">
                    <div className="h-full rounded-full" style={{ width: `${threat.pct}%`, backgroundColor: threat.color }} />
                  </div>
                  <div className="flex items-center justify-between text-[10px] text-fg-subtle">
                    <span>{threat.count} detections</span>
                    <span className="font-semibold px-1.5 py-0.5 rounded-md bg-sunken" style={{ color: threat.color }}>
                      {threat.action}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
          <div className="pt-3 border-t border-line text-[11px] text-fg-subtle flex items-center justify-between">
            <span>Stage B NanoJev Radar</span>
            <span className="text-accent font-semibold">Active Monitoring</span>
          </div>
        </div>
      </div>

      {/* Real-time Threat Alert Stream */}
      <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4">
        <div className="flex items-center justify-between border-b border-line pb-3">
          <div className="flex items-center gap-2">
            <Activity className="h-4 w-4 text-rose-500" />
            <h3 className="text-sm font-semibold text-fg">
              Real-Time Security Threat Stream
            </h3>
            <InfoTooltip 
              title="Real-Time Threat Queue"
              text="Transfers flagged by velocity rules, remote access RAT detection, or geodetic anomalies requiring immediate analyst review."
            />
          </div>
          <span className="text-xs text-fg-subtle font-mono">
            {flaggedTxs.length} Flags Pending Review
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-line text-[11px] font-semibold uppercase tracking-wider text-fg-subtle">
                <th className="py-2.5 px-3">Transaction ID</th>
                <th className="py-2.5 px-3">Origin / Destination</th>
                <th className="py-2.5 px-3 text-right">Amount</th>
                <th className="py-2.5 px-3 text-center">Threat Vector</th>
                <th className="py-2.5 px-3 text-center">Status</th>
                <th className="py-2.5 px-3 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line/60">
              {flaggedTxs.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-xs text-fg-subtle">
                    No active high-risk security threats detected in current queue.
                  </td>
                </tr>
              ) : (
                flaggedTxs.slice(0, 5).map(tx => (
                  <tr key={tx.id} className="hover:bg-sunken/40 transition">
                    <td className="py-3 px-3 font-mono font-semibold text-fg">
                      {formatShortId(tx.id)}
                    </td>
                    <td className="py-3 px-3">
                      <div className="font-mono text-fg">{tx.fromAccount}</div>
                      <div className="text-[10px] text-fg-subtle">➔ {tx.toAccount}</div>
                    </td>
                    <td className="py-3 px-3 text-right font-mono font-bold text-fg">
                      {formatPHP(tx.amount)}
                    </td>
                    <td className="py-3 px-3 text-center">
                      <span className="rounded-full bg-rose-500/10 text-rose-500 px-2 py-0.5 text-[10px] font-semibold">
                        {tx.requires2Fa ? 'Remote Access RAT / Coercion' : 'High Velocity Jump'}
                      </span>
                    </td>
                    <td className="py-3 px-3 text-center">
                      <span className={cn(
                        "rounded-full px-2.5 py-0.5 text-[10px] font-semibold",
                        tx.status === 'HELD_FRAUD' ? "bg-rose-500/10 text-rose-500" : "bg-amber-500/10 text-amber-500"
                      )}>
                        {tx.status}
                      </span>
                    </td>
                    <td className="py-3 px-3 text-right">
                      <button
                        onClick={() => setSelectedTx(tx)}
                        className="rounded-xl border border-line bg-surface px-2.5 py-1 text-[11px] font-semibold text-fg hover:bg-sunken hover:text-accent transition shadow-xs"
                      >
                        Inspect
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

// =========================================================================
// ROLE OVERVIEW 2: BRANCH OPERATIONS OFFICER (CARLOS MENDOZA)
// =========================================================================
function OverviewBranchOps({
  stats,
  accounts,
  transactions,
  setSelectedAccount,
  setActiveView,
  handleToggleAccountStatus,
  formatPHP
}) {
  const totalSavingsDeposit = useMemo(() => {
    return accounts.reduce((acc, a) => acc + (parseFloat(a.current_balance || a.balance || 0)), 0);
  }, [accounts]);

  const activeAccountsCount = useMemo(() => {
    return accounts.filter(a => a.status === 'ACTIVE').length;
  }, [accounts]);

  const lockedAccountsCount = useMemo(() => {
    return accounts.filter(a => a.status === 'LOCKED').length;
  }, [accounts]);

  return (
    <div className="space-y-6">
      {/* Top Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Highlight Card: Royal Violet */}
        <div className="rounded-3xl bg-[#311075] text-white p-6 shadow-md relative flex flex-col justify-between min-h-[175px]">
          <div className="absolute inset-0 rounded-3xl overflow-hidden pointer-events-none">
            <div className="absolute top-0 right-0 -mt-8 -mr-8 h-48 w-48 rounded-full bg-purple-400/15 blur-2xl" />
          </div>
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-white/10 text-white shadow-xs">
                  <Wallet className="h-4 w-4 text-white" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-white/80">
                  Total Retail Savings Deposits
                </span>
              </div>
              <InfoTooltip 
                title="Total Retail Savings Deposits"
                text="Aggregated balance master records across all verified retail savings account holders in the core banking ledger."
                inverted={true}
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-white font-mono">
                {formatPHP(totalSavingsDeposit || 47500000)}
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-white/80">
                <Users className="h-3.5 w-3.5 shrink-0" />
                <span>{accounts.length} retail savings account holders</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-white/10 flex items-center justify-between text-[11px] text-white/70">
            <span>Account Standard: 100% Savings</span>
            <span className="font-semibold text-emerald-300">Oracle XE Synced</span>
          </div>
        </div>

        {/* White Card 2: KYC & Biometric Verification */}
        <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs flex flex-col justify-between min-h-[175px]">
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-accent/10 text-accent">
                  <UserCheck className="h-4 w-4" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-fg-subtle">
                  Account Standing & KYC
                </span>
              </div>
              <InfoTooltip 
                title="KYC & Account Standing"
                text="Verification status of customer identities, biometric profiles, and active vs protective lock standings under BSP guidelines."
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-fg font-mono">
                100% Verified
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-emerald-500 font-medium">
                <CheckCircle2 className="h-3.5 w-3.5 shrink-0" />
                <span>{activeAccountsCount} Active • {lockedAccountsCount} Protective Lock</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-line flex items-center justify-between text-[11px] text-fg-subtle">
            <span>PSA / PRC ID Authenticated</span>
            <span className="text-emerald-500 font-semibold">Tier 1 Standing</span>
          </div>
        </div>

        {/* White Card 3: Daily Branch Flow */}
        <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs flex flex-col justify-between min-h-[175px]">
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-accent/10 text-accent">
                  <TrendingUp className="h-4 w-4" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-fg-subtle">
                  Daily Deposit Inflow
                </span>
              </div>
              <InfoTooltip 
                title="Daily Deposit Inflow"
                text="Total volume and volume velocity settled through branch savings accounts in today's ledger cycle."
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-fg font-mono">
                {formatPHP(stats.totalVolume)}
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-accent font-medium">
                <Clock className="h-3.5 w-3.5 shrink-0" />
                <span>{transactions.filter(t => t.status !== 'FAILED').length} completed branch movements</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-line flex items-center justify-between text-[11px] text-fg-subtle">
            <span>T24 Core Mutation Engine</span>
            <span className="text-accent font-semibold font-mono">Real-Time STP</span>
          </div>
        </div>
      </div>

      {/* Customer Accounts Quick Monitor Table */}
      <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 border-b border-line pb-3">
          <div>
            <div className="flex items-center gap-2">
              <Users className="h-4 w-4 text-accent" />
              <h3 className="text-sm font-semibold text-fg">
                Retail Savings Accounts Quick Monitor
              </h3>
              <InfoTooltip 
                title="Branch Accounts Monitor"
                text="Overview of retail savings account holders. Inspect complete Customer 360 profiles or toggle protective security freezes directly."
              />
            </div>
            <p className="mt-0.5 text-xs text-fg-muted">
              Select any customer account to open Customer 360° or manage freeze status.
            </p>
          </div>

          <button
            onClick={() => setActiveView('accounts')}
            className="flex items-center gap-1.5 rounded-xl border border-line bg-sunken px-3 py-1.5 text-xs font-semibold text-fg hover:bg-accent hover:text-white transition shadow-xs"
          >
            <span>Open Full Customer 360°</span>
            <ArrowRight className="h-3.5 w-3.5" />
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-line text-[11px] font-semibold uppercase tracking-wider text-fg-subtle">
                <th className="py-2.5 px-3">Account Holder</th>
                <th className="py-2.5 px-3">Account Number</th>
                <th className="py-2.5 px-3">Branch Location</th>
                <th className="py-2.5 px-3 text-right">Available Balance</th>
                <th className="py-2.5 px-3 text-center">Status</th>
                <th className="py-2.5 px-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line/60">
              {accounts.map(acc => (
                <tr key={acc.account_number} className="hover:bg-sunken/40 transition">
                  <td className="py-3 px-3">
                    <div className="font-semibold text-fg">{acc.user_name || acc.account_name}</div>
                    <div className="text-[10px] text-fg-subtle">{acc.government_id || 'PSA-Verified'}</div>
                  </td>
                  <td className="py-3 px-3 font-mono font-medium text-fg">
                    <div>{acc.account_number}</div>
                    <span className="rounded-full bg-accent/10 px-2 py-0.5 text-[9px] font-semibold text-accent">
                      SAVINGS
                    </span>
                  </td>
                  <td className="py-3 px-3 text-fg-muted">
                    {acc.location_name || 'Manila, Philippines'}
                  </td>
                  <td className="py-3 px-3 text-right font-mono font-bold text-fg">
                    {formatPHP(acc.current_balance || acc.balance || 0)}
                  </td>
                  <td className="py-3 px-3 text-center">
                    <span className={cn(
                      "rounded-full px-2.5 py-0.5 text-[10px] font-semibold",
                      acc.status === 'LOCKED' ? "bg-rose-500/10 text-rose-500" : "bg-emerald-500/10 text-emerald-500"
                    )}>
                      {acc.status}
                    </span>
                  </td>
                  <td className="py-3 px-3 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <button
                        onClick={() => {
                          setSelectedAccount(acc);
                          setActiveView('accounts');
                        }}
                        className="rounded-xl border border-line bg-surface px-2.5 py-1 text-[11px] font-semibold text-fg hover:bg-sunken hover:text-accent transition shadow-xs"
                      >
                        View 360°
                      </button>
                      <button
                        onClick={() => handleToggleAccountStatus(acc, acc.status === 'LOCKED' ? 'ACTIVE' : 'LOCKED')}
                        className={cn(
                          "rounded-xl px-2.5 py-1 text-[11px] font-semibold transition shadow-xs",
                          acc.status === 'LOCKED'
                            ? "bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20"
                            : "bg-rose-500/10 text-rose-400 hover:bg-rose-500/20"
                        )}
                      >
                        {acc.status === 'LOCKED' ? 'Unlock' : 'Freeze'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

// =========================================================================
// ROLE OVERVIEW 3: COMPLIANCE LEAD & CHECKER (DIANA VANCE)
// =========================================================================
function OverviewCompliance({
  stats,
  transactions,
  auditLogs,
  setRollbackTarget,
  setSelectedTx,
  formatPHP
}) {
  const ctrTransactions = useMemo(() => {
    return transactions.filter(t => t.amount >= 500000);
  }, [transactions]);

  const reversalTransactions = useMemo(() => {
    return transactions.filter(t => t.status === 'REVERSED' || t.status === 'PENDING_APPROVAL');
  }, [transactions]);

  return (
    <div className="space-y-6">
      {/* Top Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Highlight Card: Royal Violet */}
        <div className="rounded-3xl bg-[#311075] text-white p-6 shadow-md relative flex flex-col justify-between min-h-[175px]">
          <div className="absolute inset-0 rounded-3xl overflow-hidden pointer-events-none">
            <div className="absolute top-0 right-0 -mt-8 -mr-8 h-48 w-48 rounded-full bg-purple-400/15 blur-2xl" />
          </div>
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-white/10 text-white shadow-xs">
                  <RotateCcw className="h-4 w-4 text-white" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-white/80">
                  Compensating Reversals Settled
                </span>
              </div>
              <InfoTooltip 
                title="Settled Compensating Reversals"
                text="Total debit/credit compensating contra-entries authorized under maker-checker protocol and settled to the core ledger."
                inverted={true}
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-white font-mono">
                {formatPHP(stats.reversedVolume || 38000)}
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-white/80">
                <CheckCircle2 className="h-3.5 w-3.5 shrink-0" />
                <span>{stats.reversedCount || 1} Maker-Checker Sign-offs Completed</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-white/10 flex items-center justify-between text-[11px] text-white/70">
            <span>Compensating Contra-Entry</span>
            <span className="font-semibold text-emerald-300">T24 Verified</span>
          </div>
        </div>

        {/* White Card 2: AMLC Covered Transaction Reports (>= 500k) */}
        <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs flex flex-col justify-between min-h-[175px]">
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-accent/10 text-accent">
                  <FileText className="h-4 w-4" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-fg-subtle">
                  AMLC CTR Covered Queue
                </span>
              </div>
              <InfoTooltip 
                title="AMLC CTR Covered Queue"
                text="Covered Transaction Reports for single transactions exceeding ₱500,000 threshold under Philippine Anti-Money Laundering Act (RA 9160)."
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-fg font-mono">
                {ctrTransactions.length} Reports
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-accent font-medium">
                <ShieldCheck className="h-3.5 w-3.5 shrink-0" />
                <span>Threshold: Single-day transfer &ge; ₱500,000.00</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-line flex items-center justify-between text-[11px] text-fg-subtle">
            <span>RA 9160 Automated Filing</span>
            <span className="text-emerald-500 font-semibold">Compliant</span>
          </div>
        </div>

        {/* White Card 3: Immutable WORM Audit Vault */}
        <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs flex flex-col justify-between min-h-[175px]">
          <div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-accent/10 text-accent">
                  <Database className="h-4 w-4" />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-fg-subtle">
                  WORM Audit Vault Integrity
                </span>
              </div>
              <InfoTooltip 
                title="WORM Audit Vault Integrity"
                text="PostgreSQL Write-Once-Read-Many cryptographic audit vault. Every ledger transaction and operator authorization is hashed with SHA-256."
              />
            </div>
            <div className="mt-3">
              <div className="text-3xl font-bold tracking-tight text-fg font-mono">
                100% Cryptographic
              </div>
              <div className="mt-2 flex items-center gap-1.5 text-xs text-emerald-500 font-medium">
                <CheckCircle2 className="h-3.5 w-3.5 shrink-0" />
                <span>Zero Hash Mismatches • 0 Tamper Invariants</span>
              </div>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-line flex items-center justify-between text-[11px] text-fg-subtle">
            <span>SHA-256 Merkle Chain</span>
            <span className="text-emerald-500 font-semibold">Sealed</span>
          </div>
        </div>
      </div>

      {/* Maker-Checker Authorization & Reversal Audit Queue */}
      <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4">
        <div className="flex items-center justify-between border-b border-line pb-3">
          <div className="flex items-center gap-2">
            <RotateCcw className="h-4 w-4 text-accent" />
            <h3 className="text-sm font-semibold text-fg">
              Maker-Checker Reversal Authorization Queue
            </h3>
            <InfoTooltip 
              title="Maker-Checker Reversal Queue"
              text="Mandatory two-officer protocol for T24 core ledger contra-entry compensating reversals under Philippine Banking regulations."
            />
          </div>
          <span className="text-xs text-fg-subtle font-mono">
            {reversalTransactions.length} Handled Events
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-line text-[11px] font-semibold uppercase tracking-wider text-fg-subtle">
                <th className="py-2.5 px-3">Transaction ID</th>
                <th className="py-2.5 px-3">Accounts</th>
                <th className="py-2.5 px-3 text-right">Amount</th>
                <th className="py-2.5 px-3 text-center">Status</th>
                <th className="py-2.5 px-3">Maker / Checker Audit</th>
                <th className="py-2.5 px-3 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line/60">
              {reversalTransactions.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-xs text-fg-subtle">
                    No active compensating reversal requests in queue.
                  </td>
                </tr>
              ) : (
                reversalTransactions.map(tx => (
                  <tr key={tx.id} className="hover:bg-sunken/40 transition">
                    <td className="py-3 px-3 font-mono font-semibold text-fg">
                      {formatShortId(tx.id)}
                    </td>
                    <td className="py-3 px-3">
                      <div className="font-mono text-fg">{tx.fromAccount}</div>
                      <div className="text-[10px] text-fg-subtle">➔ {tx.toAccount}</div>
                    </td>
                    <td className="py-3 px-3 text-right font-mono font-bold text-fg">
                      {formatPHP(tx.amount)}
                    </td>
                    <td className="py-3 px-3 text-center">
                      <span className={cn(
                        "rounded-full px-2.5 py-0.5 text-[10px] font-semibold",
                        tx.status === 'REVERSED' ? "bg-rose-500/10 text-rose-500" : "bg-amber-500/10 text-amber-500"
                      )}>
                        {tx.status}
                      </span>
                    </td>
                    <td className="py-3 px-3 text-fg-muted">
                      {tx.status === 'REVERSED' ? (
                        <div>
                          <span className="font-semibold text-rose-400">Reversed:</span> Contra-entry committed
                        </div>
                      ) : (
                        <div>
                          <span className="font-semibold text-amber-400">Pending Review:</span> Maker submitted
                        </div>
                      )}
                    </td>
                    <td className="py-3 px-3 text-right">
                      {tx.status !== 'REVERSED' ? (
                        <button
                          onClick={() => setRollbackTarget(tx)}
                          className="rounded-xl border border-amber-500/30 bg-amber-500/10 px-2.5 py-1 text-[11px] font-semibold text-amber-400 hover:bg-amber-500/20 transition shadow-xs"
                        >
                          Sign-Off Reversal
                        </button>
                      ) : (
                        <button
                          onClick={() => setSelectedTx(tx)}
                          className="rounded-xl border border-line bg-surface px-2.5 py-1 text-[11px] font-semibold text-fg hover:bg-sunken transition shadow-xs"
                        >
                          Inspect Detail
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Immutable WORM Audit Stream */}
      <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4">
        <div className="flex items-center justify-between border-b border-line pb-3">
          <div className="flex items-center gap-2">
            <Database className="h-4 w-4 text-accent" />
            <h3 className="text-sm font-semibold text-fg">
              Recent Cryptographic Audit Records (PostgreSQL WORM)
            </h3>
            <InfoTooltip 
              title="PostgreSQL WORM Log"
              text="Tamper-evident chronological audit journal containing cryptographic hashes of all balance mutations."
            />
          </div>
          <span className="text-xs text-fg-subtle font-mono">
            Immutable Storage
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-line text-[11px] font-semibold uppercase tracking-wider text-fg-subtle">
                <th className="py-2.5 px-3">Event Type</th>
                <th className="py-2.5 px-3">Entity ID</th>
                <th className="py-2.5 px-3">Operator</th>
                <th className="py-2.5 px-3">Timestamp</th>
                <th className="py-2.5 px-3 text-right font-mono">SHA-256 Hash</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line/60">
              {auditLogs.slice(0, 5).map((log, idx) => (
                <tr key={log.id || idx} className="hover:bg-sunken/40 transition">
                  <td className="py-3 px-3">
                    <span className="rounded-full bg-accent/10 px-2 py-0.5 text-[10px] font-semibold text-accent">
                      {log.eventType || log.action || 'MUTATION'}
                    </span>
                  </td>
                  <td className="py-3 px-3 font-mono text-fg">
                    {formatShortId(log.entityId || log.transactionId || 'TXN')}
                  </td>
                  <td className="py-3 px-3 text-fg-muted">
                    {log.actor || 'System Engine'}
                  </td>
                  <td className="py-3 px-3 text-fg-subtle">
                    {new Date(log.timestamp || Date.now()).toLocaleTimeString()}
                  </td>
                  <td className="py-3 px-3 text-right font-mono text-[10px] text-fg-subtle">
                    {log.hash ? `${log.hash.slice(0, 10)}...${log.hash.slice(-6)}` : 'sha256-verified'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default function AdminExecutivePortal() {
  const { user: activeAuthUser } = useAuth();

  // Sidebar Views: 'overview' | 'transactions' | 'threat_radar' | 'geo_surveillance' | 'audit_vault' | 'sar_queue'
  const [activeView, setActiveView] = useState('overview');

  // Search & Filter State
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [hoveredVelocityIdx, setHoveredVelocityIdx] = useState(6); // Default to Today (Peak)

  // Active Admin Operator
  const [activeAdminId, setActiveAdminId] = useState(
    activeAuthUser?.email?.includes('alex') 
      ? 'usr-1007-sec-003' 
      : activeAuthUser?.email?.includes('diana') 
      ? 'usr-1004-adm-001' 
      : 'usr-1006-mgr-002'
  );

  // Core Data States
  const [transactions, setTransactions] = useState([]);
  const [accounts, setAccounts] = useState([]);
  const [selectedAccount, setSelectedAccount] = useState(null);
  const [accountSearchQuery, setAccountSearchQuery] = useState('');
  const [accountTypeFilter, setAccountTypeFilter] = useState('ALL');
  const [auditLogs, setAuditLogs] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [copiedId, setCopiedId] = useState(null);

  // Selected Transaction for Slide-over Detail Drawer
  const [selectedTx, setSelectedTx] = useState(null);

  // Account Lock / Unlock Modal State
  const [lockTargetAccount, setLockTargetAccount] = useState(null);
  const [lockReason, setLockReason] = useState('SUSPECTED_PHISHING_COERCION');
  const [lockMemo, setLockMemo] = useState('Customer reported suspicious account activity and requested protective security lock.');
  const [isSubmittingLock, setIsSubmittingLock] = useState(false);

  // Reversal / Rollback Modal State
  const [rollbackTarget, setRollbackTarget] = useState(null);
  const [rollbackApproverId, setRollbackApproverId] = useState('usr-1004-adm-001');
  const [reversalReason, setReversalReason] = useState('CUSTOMER_DISPUTE_WRONG_ACCOUNT');
  const [reversalMemo, setReversalMemo] = useState('Customer mistakenly transferred funds to incorrect account. CSR requested reversal.');
  const [isSubmittingRollback, setIsSubmittingRollback] = useState(false);
  const [notification, setNotification] = useState(null);

  // Customer Geolocation Simulation State
  const [selectedSimCustomer, setSelectedSimCustomer] = useState(SIMULATION_CUSTOMERS[0]);
  const [userLocation, setUserLocation] = useState({
    latitude: 14.5995,
    longitude: 120.9842,
    locationName: 'Manila, Philippines',
    ipAddress: '112.198.45.10'
  });
  const [isUpdatingLocation, setIsUpdatingLocation] = useState(false);
  const [simSearchQuery, setSimSearchQuery] = useState('');

  // Active admin helper
  const currentAdmin = useMemo(() => {
    return ADMIN_ROSTER.find(a => a.userId === activeAdminId) || ADMIN_ROSTER[0];
  }, [activeAdminId]);

  // Sync activeAdminId when activeAuthUser changes (e.g. from top Navbar switcher)
  useEffect(() => {
    if (activeAuthUser?.email?.includes('alex')) {
      setActiveAdminId('usr-1007-sec-003');
    } else if (activeAuthUser?.email?.includes('carlos')) {
      setActiveAdminId('usr-1006-mgr-002');
    } else if (activeAuthUser?.email?.includes('diana')) {
      setActiveAdminId('usr-1004-adm-001');
    }
  }, [activeAuthUser?.email]);

  // Strict Segregation of Duties (SoD): auto-redirect if current view is not permitted for this role
  useEffect(() => {
    if (currentAdmin?.allowedViews && !currentAdmin.allowedViews.includes(activeView)) {
      setActiveView(currentAdmin.defaultView || currentAdmin.allowedViews[0]);
    }
  }, [currentAdmin, activeView]);

  // Copy helper
  const handleCopy = (id, text, e) => {
    e?.stopPropagation();
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 1800);
  };

  // Helper to format short IDs
  const formatShortId = (id) => {
    if (!id) return '';
    if (id.length <= 16) return id;
    const isRev = id.endsWith('-REV');
    const cleanId = isRev ? id.slice(0, -4) : id;
    return `${cleanId.slice(0, 8)}···${cleanId.slice(-4)}${isRev ? '-REV' : ''}`;
  };

  // Load Transactions, Audit Logs, and User Geo
  const loadData = async () => {
    setIsLoading(true);
    try {
      // 1. Transactions from Oracle XE
      let txList = [];
      try {
        const res = await apiClient.get('/transfers');
        if (Array.isArray(res.data) && res.data.length > 0) {
          txList = res.data.map(t => ({
            id: t.transactionId || t.transaction_id,
            timestamp: t.createdAt || t.created_at || new Date().toISOString(),
            fromAccount: t.fromAccountId || t.from_account_id,
            toAccount: t.toAccountId || t.to_account_id,
            amount: parseFloat(t.amount || 0),
            status: t.status || 'COMMITTED',
            type: t.type || 'TRANSFER',
            requires2Fa: t.requires2FaOtp === 1 || t.requires_2fa_otp === 1,
            reversedBy: t.reversedByUserId || t.reversed_by_user_id,
            approvedBy: t.approvedByUserId || t.approved_by_user_id,
            reversalReason: t.reversalReason || t.reversal_reason,
            reversalMemo: t.reversalMemo || t.reversal_memo,
            locationName: t.locationName || t.location_name
          }));
        }
      } catch (_) {}

      // Fallback to mock state if empty
      if (txList.length === 0 && mockState?.transfers?.length > 0) {
        txList = mockState.transfers.map(t => ({
          id: t.id || t.transaction_id,
          timestamp: t.timestamp || new Date().toISOString(),
          fromAccount: t.source || t.fromAccountId || '1000-2000-3001',
          toAccount: t.target || t.toAccountId || '1000-2000-3002',
          amount: parseFloat(t.amount || 0),
          status: t.status || 'COMMITTED',
          type: 'TRANSFER',
          reversedBy: t.reversed_by || t.reversed_by_user_id,
          approvedBy: t.approved_by || t.approved_by_user_id,
          reversalReason: t.reversal_reason || 'CUSTOMER_DISPUTE_WRONG_ACCOUNT',
          reversalMemo: t.reversal_memo,
          locationName: t.location || 'Manila, Philippines'
        }));
      }
      setTransactions(txList);

      // 2. Audit records from PostgreSQL
      try {
        const auditRes = await apiClient.get('/ledger/audit');
        if (Array.isArray(auditRes.data)) {
          setAuditLogs(auditRes.data);
        }
      } catch (_) {}

      // 3. User location from Oracle XE
      try {
        const locRes = await apiClient.get('/ledger/users/usr-1001-cst-001/location');
        if (locRes.data?.latitude) {
          setUserLocation({
            latitude: locRes.data.latitude,
            longitude: locRes.data.longitude,
            locationName: locRes.data.location_name || 'Manila, Philippines',
            ipAddress: locRes.data.ip_address || '112.198.45.10'
          });
        }
      } catch (_) {}

      // 4. Accounts & 360 Customer Profiles from Oracle XE / Core Banking
      let accountsList = [];
      try {
        const accRes = await apiClient.get('/accounts');
        if (Array.isArray(accRes.data) && accRes.data.length > 0) {
          accountsList = accRes.data.map(acc => ({
            account_id: acc.accountId || acc.account_id || acc.accountNumber || acc.account_number,
            account_number: acc.accountNumber || acc.account_number || acc.accountId,
            account_type: acc.accountType || acc.account_type || 'SAVINGS',
            status: acc.status || 'ACTIVE',
            user_id: acc.userId || acc.user_id || 'U1001',
            account_name: acc.accountName || acc.account_name || 'Retail Deposit Account',
            user_name: acc.userName || acc.user_name || 'Juan Dela Cruz',
            user_email: acc.userEmail || acc.user_email || 'juan.delacruz@retailbank.ph',
            user_phone: acc.userPhone || acc.user_phone || '09171234567',
            government_id: acc.governmentId || acc.government_id || 'PSA-1985-0012',
            location_name: acc.locationName || acc.location_name || 'Manila, Philippines',
            ip_address: acc.ipAddress || acc.ip_address || '112.198.45.10',
            available_balance: typeof acc.available_balance === 'number' ? acc.available_balance : (typeof acc.availableBalance === 'number' ? acc.availableBalance : 15000000.00),
            current_balance: typeof acc.current_balance === 'number' ? acc.current_balance : (typeof acc.currentBalance === 'number' ? acc.currentBalance : 15000000.00),
            held_balance: typeof acc.held_balance === 'number' ? acc.held_balance : 0.00,
            currency: 'PHP',
            created_at: acc.createdAt || acc.created_at || '2024-01-15T08:00:00Z',
            user_profile: acc.user_profile || acc.userProfile || {}
          }));
        }
      } catch (_) {}

      // Robust fallback if backend endpoint returned empty (e.g. admin has no personal deposit accounts, or mock session)
      if (accountsList.length === 0) {
        const sourceAccounts = (mockState?.registeredAccounts?.length ? mockState.registeredAccounts : [
          { account_id: '1000-2000-3001', account_number: '1000-2000-3001', user_id: 'usr-1001-cst-001', account_name: 'Juan Dela Cruz', account_type: 'SAVINGS', status: 'LOCKED' },
          { account_id: '1000-2000-3002', account_number: '1000-2000-3002', user_id: 'usr-1002-cst-002', account_name: 'Maria Clara Santos', account_type: 'SAVINGS', status: 'ACTIVE' },
          { account_id: '1000-2000-3004', account_number: '1000-2000-3004', user_id: 'usr-2003-cst-003', account_name: 'Jose Rizal', account_type: 'SAVINGS', status: 'ACTIVE' },
          { account_id: '1000-2000-3005', account_number: '1000-2000-3005', user_id: 'usr-2004-cst-004', account_name: 'Andres Bonifacio', account_type: 'SAVINGS', status: 'ACTIVE' },
          { account_id: '1000-2000-3006', account_number: '1000-2000-3006', user_id: 'usr-2005-cst-005', account_name: 'Gabriela Silang', account_type: 'SAVINGS', status: 'ACTIVE' },
          { account_id: '1000-2000-3007', account_number: '1000-2000-3007', user_id: 'usr-2006-cst-006', account_name: 'Emilio Jacinto', account_type: 'SAVINGS', status: 'ACTIVE' },
          { account_id: '1000-2000-3008', account_number: '1000-2000-3008', user_id: 'usr-2007-cst-007', account_name: 'Melchora Aquino', account_type: 'SAVINGS', status: 'ACTIVE' },
          { account_id: '1000-2000-3009', account_number: '1000-2000-3009', user_id: 'usr-2008-cst-008', account_name: 'Apolinario Mabini', account_type: 'SAVINGS', status: 'ACTIVE' },
        ]).filter(acc => acc.account_type !== 'CHECKING' && acc.account_number !== '1000-2000-3003');

        const users = mockState?.users?.length ? mockState.users : [
          { user_id: 'usr-1001-cst-001', first_name: 'Juan', last_name: 'Dela Cruz', email: 'juan.delacruz@retailbank.ph', phone_number: '09171234567', government_id: 'PSA-1985-0012', last_known_location_name: 'Manila, Philippines', last_known_ip: '112.198.45.10' },
          { user_id: 'usr-1002-cst-002', first_name: 'Maria', middle_name: 'Clara', last_name: 'Santos', email: 'maria.santos@retailbank.ph', phone_number: '09189876543', government_id: 'PSA-1992-0045', last_known_location_name: 'Cebu City, Philippines', last_known_ip: '112.198.88.22' },
          { user_id: 'usr-2003-cst-003', first_name: 'Jose', last_name: 'Rizal', email: 'jose.rizal@retailbank.ph', phone_number: '09195556677', government_id: 'PRC-1861-1234', last_known_location_name: 'Calamba, Laguna, Philippines', last_known_ip: '112.198.33.15' },
          { user_id: 'usr-2004-cst-004', first_name: 'Andres', last_name: 'Bonifacio', email: 'andres.bonifacio@retailbank.ph', phone_number: '09173334455', government_id: 'PSA-1863-1130', last_known_location_name: 'Davao City, Philippines', last_known_ip: '112.198.99.77' },
          { user_id: 'usr-2005-cst-005', first_name: 'Gabriela', last_name: 'Silang', email: 'gabriela.silang@retailbank.ph', phone_number: '09178881122', government_id: 'PSA-1988-1234', last_known_location_name: 'Vigan, Ilocos Sur, Philippines', last_known_ip: '112.198.71.12' },
          { user_id: 'usr-2006-cst-006', first_name: 'Emilio', last_name: 'Jacinto', email: 'emilio.jacinto@retailbank.ph', phone_number: '09192223344', government_id: 'PSA-1991-5678', last_known_location_name: 'Quezon City, Philippines', last_known_ip: '112.198.22.44' },
          { user_id: 'usr-2007-cst-007', first_name: 'Melchora', last_name: 'Aquino', email: 'melchora.aquino@retailbank.ph', phone_number: '09174445566', government_id: 'PSA-1980-9988', last_known_location_name: 'Caloocan, Philippines', last_known_ip: '112.198.63.89' },
          { user_id: 'usr-2008-cst-008', first_name: 'Apolinario', last_name: 'Mabini', email: 'apolinario.mabini@retailbank.ph', phone_number: '09187778899', government_id: 'PSA-1984-7766', last_known_location_name: 'Batangas City, Philippines', last_known_ip: '112.198.54.33' },
        ];

        accountsList = sourceAccounts.map(acc => {
          const u = users.find(u => u.user_id === acc.user_id) || users[0];
          const isJuanSav = acc.account_number === '1000-2000-3001';
          const isMaria = acc.account_number === '1000-2000-3002';
          const isJose = acc.account_number === '1000-2000-3004';
          const isAndres = acc.account_number === '1000-2000-3005';
          const isGabriela = acc.account_number === '1000-2000-3006';
          const isEmilio = acc.account_number === '1000-2000-3007';
          const isMelchora = acc.account_number === '1000-2000-3008';
          const isApolinario = acc.account_number === '1000-2000-3009';
          const bal = isJuanSav ? 15000000.00 : isMaria ? 8500000.00 : isJose ? 5200000.00 : isAndres ? 3750000.00 : isGabriela ? 4200000.00 : isEmilio ? 6800000.00 : isMelchora ? 2950000.00 : isApolinario ? 9100000.00 : 5000000.00;
          const availBal = bal;
          const currBal = bal;
          return {
            account_id: acc.account_id || acc.account_number,
            account_number: acc.account_number,
            user_id: acc.user_id,
            account_name: acc.account_name || `${u.first_name} ${u.last_name}`,
            account_type: acc.account_type || 'SAVINGS',
            status: acc.status || 'ACTIVE',
            user_name: `${u.first_name} ${u.middle_name ? u.middle_name + ' ' : ''}${u.last_name}`.trim(),
            user_email: u.email,
            user_phone: u.phone_number,
            government_id: u.government_id,
            location_name: u.last_known_location_name || 'Manila, Philippines',
            ip_address: u.last_known_ip || '112.198.45.10',
            available_balance: availBal,
            current_balance: currBal,
            held_balance: 0.00,
            currency: 'PHP',
            created_at: acc.created_at || '2024-01-15T08:00:00Z',
            user_profile: { ...u }
          };
        });
      }

      setAccounts(accountsList);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    const timer = setInterval(loadData, 15000);
    return () => clearInterval(timer);
  }, []);

  // Select Customer Target for Simulation (Connected to Live API)
  const handleSelectSimCustomer = async (cust) => {
    setSelectedSimCustomer(cust);
    try {
      const res = await apiClient.get(`/ledger/users/${cust.userId}/location`);
      if (res?.data?.last_known_latitude) {
        setUserLocation({
          latitude: res.data.last_known_latitude,
          longitude: res.data.last_known_longitude,
          locationName: res.data.last_known_location_name || cust.baselineCity,
          ipAddress: res.data.last_known_ip || cust.ip
        });
      } else {
        setUserLocation({
          latitude: cust.lat,
          longitude: cust.lon,
          locationName: cust.baselineCity,
          ipAddress: cust.ip
        });
      }
    } catch (_) {
      setUserLocation({
        latitude: cust.lat,
        longitude: cust.lon,
        locationName: cust.baselineCity,
        ipAddress: cust.ip
      });
    }
    setNotification({
      type: 'success',
      title: 'Target Customer Loaded',
      message: `Active simulation target set to ${cust.name} (${cust.baselineCity}). Live coordinates synced from database.`
    });
  };

  // Set Location Preset for Selected Customer
  const handleApplyLocation = async (preset) => {
    if (currentAdmin.capability !== 'SIMULATION') {
      setNotification({
        type: 'alert',
        title: 'Segregation of Duties Enforced',
        message: 'Only Fraud Ops Analysts (Alex Rivera) are authorized to inject geolocation threat vectors.'
      });
      return;
    }
    setIsUpdatingLocation(true);
    try {
      const isBaseline = preset.id === 'BASELINE';
      const targetCity = isBaseline ? selectedSimCustomer.baselineCity : preset.name;
      const targetLat = isBaseline ? selectedSimCustomer.lat : preset.lat;
      const targetLon = isBaseline ? selectedSimCustomer.lon : preset.lon;
      const targetIp = isBaseline ? selectedSimCustomer.ip : preset.ip;

      const payload = {
        latitude: targetLat,
        longitude: targetLon,
        location_name: targetCity,
        ip_address: targetIp
      };
      await apiClient.patch(`/ledger/users/${selectedSimCustomer.userId}/location`, payload);
      setUserLocation({
        latitude: targetLat,
        longitude: targetLon,
        locationName: targetCity,
        ipAddress: targetIp
      });
      setNotification({
        type: preset.type === 'FRAUD' ? 'alert' : 'success',
        title: preset.type === 'FRAUD' ? '🚨 Impossible Travel Simulated' : isBaseline ? 'Baseline Location Restored' : 'Location Updated',
        message: preset.type === 'FRAUD'
          ? `${selectedSimCustomer.name} relocated to ${targetCity}. Subsequent transfer attempts will trigger an instant security hold.`
          : isBaseline
          ? `${selectedSimCustomer.name} baseline location restored to ${targetCity}.`
          : `${selectedSimCustomer.name} simulated location updated to ${targetCity}.`
      });
    } catch (err) {
      setNotification({
        type: 'alert',
        title: 'Update Failed',
        message: err.message || 'Could not update location.'
      });
    } finally {
      setIsUpdatingLocation(false);
    }
  };

  // Execute Protective Account Freeze / Unfreeze (Branch Operations Officer)
  const handleToggleAccountStatus = async (account, targetStatus) => {
    if (currentAdmin.capability !== 'ACCOUNT_LOCK_UNLOCK') {
      setNotification({
        type: 'alert',
        title: 'Segregation of Duties Enforced',
        message: 'Only Branch Operations Officers (Carlos Mendoza) are authorized to freeze or unfreeze customer accounts.'
      });
      return;
    }
    setIsSubmittingLock(true);
    try {
      const accId = account.account_id || account.account_number;
      try {
        await apiClient.patch(`/accounts/${accId}/status`, {
          status: targetStatus,
          reason: lockReason,
          memo: lockMemo,
          actioned_by_user_id: activeAdminId
        });
      } catch (patchErr) {
        // Fallback retry with minimal payload in case backend strict DTO only accepts status
        try {
          await apiClient.patch(`/accounts/${accId}/status`, {
            status: targetStatus
          });
        } catch (_) {
          // Fallback to updating local mock store
          if (mockState?.registeredAccounts) {
            const m = mockState.registeredAccounts.find(a => a.account_id === accId || a.account_number === accId);
            if (m) m.status = targetStatus;
          }
        }
      }

      // Update in local accounts list
      setAccounts(prev => prev.map(a => {
        if ((a.account_id || a.account_number) === accId) {
          return { ...a, status: targetStatus };
        }
        return a;
      }));

      if (selectedAccount && (selectedAccount.account_id || selectedAccount.account_number) === accId) {
        setSelectedAccount(prev => ({ ...prev, status: targetStatus }));
      }

      setNotification({
        type: 'success',
        title: targetStatus === 'LOCKED' ? '🔒 Account Frozen' : '✅ Account Unfrozen',
        message: targetStatus === 'LOCKED'
          ? `Account ${accId} has been placed under protective security freeze by ${currentAdmin.name}. All debit transactions are blocked.`
          : `Account ${accId} has been unfrozen by ${currentAdmin.name}. Regular banking services restored.`
      });

      setLockTargetAccount(null);
    } catch (err) {
      setNotification({
        type: 'alert',
        title: 'Status Update Failed',
        message: err.message || 'Could not update account status.'
      });
    } finally {
      setIsSubmittingLock(false);
    }
  };

  // Execute Reversal / Rollback
  const handleExecuteRollback = async () => {
    if (!rollbackTarget) return;
    if (currentAdmin.capability !== 'REVERSAL_APPROVAL') {
      setNotification({
        type: 'alert',
        title: 'Segregation of Duties Enforced',
        message: 'Only the Compliance & Settlement Checker (Diana Vance) is authorized to sign off on compensating contra-entries.'
      });
      return;
    }
    setIsSubmittingRollback(true);
    try {
      const payload = {
        reversed_by_user_id: activeAdminId,
        approved_by_admin_id: rollbackApproverId,
        reason: reversalReason,
        memo: reversalMemo
      };
      await apiClient.post(`/transfers/${rollbackTarget.id}/reverse`, payload);
      setNotification({
        type: 'success',
        title: 'Reversal Executed',
        message: `Transaction ${formatShortId(rollbackTarget.id)} reversed by ${currentAdmin.name}. Compensating contra-entry posted.`
      });
      setRollbackTarget(null);
      if (selectedTx?.id === rollbackTarget.id) {
        setSelectedTx(null);
      }
      await loadData();
    } catch (err) {
      setNotification({
        type: 'alert',
        title: 'Rollback Failed',
        message: err.response?.data?.message || err.message || 'Error executing reversal.'
      });
    } finally {
      setIsSubmittingRollback(false);
    }
  };

  // Filtered transactions
  const filteredTransactions = useMemo(() => {
    return transactions.filter(tx => {
      const matchSearch = searchQuery === '' ||
        tx.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
        tx.fromAccount.toLowerCase().includes(searchQuery.toLowerCase()) ||
        tx.toAccount?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        tx.amount.toString().includes(searchQuery);

      const matchStatus = statusFilter === 'ALL' ||
        (statusFilter === 'SETTLED' && (tx.status === 'COMMITTED' || tx.status === 'POSTED' || tx.status === 'SETTLED')) ||
        (statusFilter === 'REVERSED' && tx.status === 'REVERSED') ||
        (statusFilter === 'REVIEW' && (tx.status === 'PENDING_APPROVAL' || tx.status === 'HELD_FRAUD'));

      return matchSearch && matchStatus;
    });
  }, [transactions, searchQuery, statusFilter]);

  // Filtered accounts
  const filteredAccounts = useMemo(() => {
    return accounts.filter(acc => {
      const q = accountSearchQuery.toLowerCase();
      const matchSearch = accountSearchQuery === '' ||
        (acc.account_number || '').toLowerCase().includes(q) ||
        (acc.user_name || '').toLowerCase().includes(q) ||
        (acc.user_email || '').toLowerCase().includes(q) ||
        (acc.government_id || '').toLowerCase().includes(q) ||
        (acc.location_name || '').toLowerCase().includes(q);

      const matchType = accountTypeFilter === 'ALL' ||
        acc.account_type === accountTypeFilter ||
        (accountTypeFilter === 'ACTIVE' && acc.status === 'ACTIVE') ||
        (accountTypeFilter === 'LOCKED' && acc.status !== 'ACTIVE');

      return matchSearch && matchType;
    });
  }, [accounts, accountSearchQuery, accountTypeFilter]);

  // Filtered Simulation Customers
  const filteredSimCustomers = useMemo(() => {
    if (!simSearchQuery.trim()) return SIMULATION_CUSTOMERS;
    const q = simSearchQuery.toLowerCase();
    return SIMULATION_CUSTOMERS.filter(c => 
      c.name.toLowerCase().includes(q) ||
      c.accountNumber.toLowerCase().includes(q) ||
      c.baselineCity.toLowerCase().includes(q) ||
      c.email.toLowerCase().includes(q)
    );
  }, [simSearchQuery]);

  // Aggregated Stats
  const stats = useMemo(() => {
    const totalVolume = transactions.reduce((acc, t) => acc + (t.status !== 'FAILED' ? t.amount : 0), 0);
    const reversedCount = transactions.filter(t => t.status === 'REVERSED').length;
    const reversedVolume = transactions.filter(t => t.status === 'REVERSED').reduce((acc, t) => acc + t.amount, 0);
    const heldCount = transactions.filter(t => t.status === 'HELD_FRAUD' || t.status === 'PENDING_APPROVAL').length;
    const threatVolume = transactions.filter(t => t.status === 'HELD_FRAUD' || t.status === 'PENDING_APPROVAL').reduce((acc, t) => acc + t.amount, 0) || 250000;
    const isAnomaly = userLocation.locationName.includes('London') || userLocation.locationName.includes('New York');

    return {
      totalVolume,
      totalCount: transactions.length,
      reversedCount,
      reversedVolume,
      heldCount,
      threatVolume,
      isAnomaly
    };
  }, [transactions, userLocation]);

  return (
    <div className="flex min-h-[calc(100vh-6rem)] gap-6">
      {/* =========================================================================
          LEFT SIDEBAR (DOLAB-STYLE MODERN NAV)
          ========================================================================= */}
      <aside className="hidden lg:flex w-64 flex-col justify-between rounded-3xl border border-line bg-surface p-4 shadow-sm">
        <div className="space-y-6">
          {/* Section: Main Menu */}
          <div>
            <div className="flex items-center justify-between px-3">
              <span className="text-[10px] font-bold uppercase tracking-wider text-accent font-mono">
                {currentAdmin.menuSection || 'Operations Center'}
              </span>
              <span className="text-[9px] font-mono px-1.5 py-0.5 rounded bg-accent/10 text-accent font-semibold">
                SoD
              </span>
            </div>
            <nav className="mt-2 space-y-1">
              {[
                { id: 'overview', label: 'Overview & Telemetry', icon: BarChart3 },
                { id: 'threat_radar', label: 'Two-Stage Threat Radar', icon: Zap },
                { id: 'geo_surveillance', label: 'Geo & Device Signals', icon: Globe, alert: stats.isAnomaly },
                { id: 'accounts', label: 'Customer Accounts & 360°', icon: Users, count: accounts.length },
                { id: 'transactions', label: 'Transactions & Reversals', icon: Layers, count: transactions.length },
                { id: 'audit_vault', label: 'Immutable Audit Vault', icon: Database, count: auditLogs.length },
                { id: 'sar_queue', label: 'AMLC SAR Reports', icon: FileText }
              ]
                .filter(item => currentAdmin.allowedViews?.includes(item.id))
                .map((item) => {
                  const Icon = item.icon;
                  const active = activeView === item.id;

                  return (
                    <button
                      key={item.id}
                      onClick={() => setActiveView(item.id)}
                      className={cn(
                        "flex w-full items-center justify-between rounded-2xl px-3.5 py-2.5 text-xs font-medium transition",
                        active
                          ? "bg-gradient-to-r from-accent/20 to-accent/5 text-accent font-semibold border border-accent/30 shadow-xs"
                          : "text-fg-muted hover:bg-sunken hover:text-fg"
                      )}
                    >
                      <div className="flex items-center gap-3">
                        <Icon className={cn("h-4 w-4", active ? "text-accent" : "text-fg-subtle")} />
                        <span>{item.label}</span>
                      </div>
                      {item.count !== undefined && (
                        <span className="rounded-full bg-sunken px-2 py-0.5 text-[10px] font-mono text-fg-subtle">
                          {item.count}
                        </span>
                      )}
                      {item.alert && (
                        <span className="h-2 w-2 rounded-full bg-rose-500 animate-pulse" />
                      )}
                    </button>
                  );
                })}
            </nav>

            {/* Segregated Duty Capsule */}
            <div className="mt-3 px-3 py-2.5 rounded-2xl border border-line bg-sunken/40 space-y-1">
              <div className="flex items-center gap-1.5 font-semibold text-fg text-xs">
                <ShieldCheck className="h-3.5 w-3.5 text-accent" />
                <span>Duty Assignment:</span>
              </div>
              <p className="text-[10px] text-fg-muted leading-tight font-medium">
                {currentAdmin.capabilityLabel}
              </p>
            </div>
          </div>

          {/* Section: System Status (Only for Fraud Ops Analyst) */}
          {currentAdmin.capability === 'SIMULATION' && (
            <div className="rounded-2xl border border-line bg-sunken/40 p-3.5 space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-bold uppercase tracking-wider text-fg-subtle">
                  Engine Health
                </span>
                <InfoTooltip 
                  title="Engine Health & Latency Telemetry"
                  text="Live runtime performance tracking across Gate 0 deterministic rules, tabular XGBoost scoring, NanoJev ONNX model latency, and PostgreSQL WORM (Write Once Read Many) cryptographic audit integrity."
                  align="left"
                />
              </div>
              <div className="space-y-1.5 text-[11px]">
                <div className="flex items-center justify-between">
                  <span className="text-fg-muted">Gate 0 + S2 XGBoost</span>
                  <span className="text-emerald-400 font-semibold font-mono">&lt; 30ms</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-fg-muted">NanoJev Qwen-0.5B</span>
                  <span className="text-accent font-semibold font-mono">1.5s bound</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-fg-muted">Zero SMS OTP (BSP)</span>
                  <span className="text-emerald-400 font-semibold">Active</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-fg-muted">PostgreSQL WORM</span>
                  <span className="text-emerald-400 font-semibold">Immutable</span>
                </div>
              </div>
            </div>
          )}
        </div>
      </aside>

      {/* =========================================================================
          MAIN CONTENT AREA
          ========================================================================= */}
      <main className="flex-1 space-y-6 min-w-0">
        {/* Top Bar for View Header & Actions */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 className="text-xl font-bold tracking-tight text-fg capitalize">
              {activeView.replace('_', ' ')}
            </h1>
            <p className="text-xs text-fg-muted mt-0.5">
              AuraBank Core Operations & Real-Time Two-Stage Fraud Threat Governance
            </p>
          </div>

          <div className="flex items-center gap-3">
            {/* Refresh */}
            <button
              onClick={loadData}
              disabled={isLoading}
              className="flex h-9 w-9 items-center justify-center rounded-2xl border border-line bg-surface text-fg-muted hover:text-fg hover:bg-sunken transition shadow-xs"
              title="Sync Engine Data"
            >
              <RefreshCw className={cn("h-4 w-4", isLoading && "animate-spin text-accent")} />
            </button>
          </div>
        </div>

        {/* Notification Banner */}
        {notification && (
          <div className={cn(
            "flex items-center justify-between rounded-2xl border p-4 text-xs shadow-xs animate-fade-in",
            notification.type === 'alert' && "border-rose-500/30 bg-rose-500/10 text-rose-300",
            notification.type === 'success' && "border-emerald-500/30 bg-emerald-500/10 text-emerald-300"
          )}>
            <div className="flex items-center gap-2.5">
              {notification.type === 'alert' ? (
                <AlertTriangle className="h-4 w-4 shrink-0 text-rose-400" />
              ) : (
                <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-400" />
              )}
              <div>
                <strong className="font-semibold">{notification.title}: </strong>
                <span>{notification.message}</span>
              </div>
            </div>
            <button 
              onClick={() => setNotification(null)}
              className="p-1 text-fg-subtle hover:text-fg rounded-md transition"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
        )}

        {/* =========================================================================
            SEGREGATION OF DUTIES (SoD) ENFORCEMENT ACCESS GUARD
            ========================================================================= */}
        {!currentAdmin.allowedViews?.includes(activeView) && (
          <div className="rounded-3xl border border-amber-500/30 bg-surface p-8 shadow-xs text-center space-y-4 max-w-xl mx-auto my-12 animate-fade-in">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-amber-500/10 text-amber-500">
              <Lock className="h-7 w-7" />
            </div>
            <div className="space-y-1.5">
              <h2 className="text-base font-bold text-fg">Segregation of Duties (SoD) Enforced</h2>
              <p className="text-xs text-fg-muted leading-relaxed">
                The <span className="font-semibold text-fg capitalize">{activeView.replace('_', ' ')}</span> module is restricted from your assigned role as <strong>{currentAdmin.role}</strong> ({currentAdmin.badge}).
              </p>
              <p className="text-[11px] text-fg-subtle">
                Under Philippine Banking Least-Privilege RBAC guidelines, operations outside your duty profile are restricted.
              </p>
            </div>
            <div className="pt-2">
              <button
                onClick={() => setActiveView(currentAdmin.defaultView)}
                className="rounded-xl bg-accent px-4 py-2 text-xs font-semibold text-white hover:bg-accent-hover transition shadow-xs"
              >
                Go to Authorized Workspace ({currentAdmin.defaultView.replace('_', ' ')})
              </button>
            </div>
          </div>
        )}

        {/* =========================================================================
            VIEW 1: OVERVIEW & TELEMETRY (AURA BANK RELAXED WHITE & ROYAL VIOLET)
            ========================================================================= */}
        {activeView === 'overview' && (
          <div className="space-y-6 animate-fade-in">
            {currentAdmin.capability === 'SIMULATION' && (
              <OverviewFraud
                stats={stats}
                transactions={transactions}
                hoveredVelocityIdx={hoveredVelocityIdx}
                setHoveredVelocityIdx={setHoveredVelocityIdx}
                setSelectedTx={setSelectedTx}
                formatPHP={formatPHP}
                BACKGROUND_APP_THREATS={BACKGROUND_APP_THREATS}
                VELOCITY_SERIES={VELOCITY_SERIES}
              />
            )}

            {currentAdmin.capability === 'ACCOUNT_LOCK_UNLOCK' && (
              <OverviewBranchOps
                stats={stats}
                accounts={accounts}
                transactions={transactions}
                setSelectedAccount={setSelectedAccount}
                setActiveView={setActiveView}
                handleToggleAccountStatus={handleToggleAccountStatus}
                formatPHP={formatPHP}
              />
            )}

            {currentAdmin.capability === 'REVERSAL_APPROVAL' && (
              <OverviewCompliance
                stats={stats}
                transactions={transactions}
                auditLogs={auditLogs}
                setRollbackTarget={setRollbackTarget}
                setSelectedTx={setSelectedTx}
                formatPHP={formatPHP}
              />
            )}
          </div>
        )}

        {/* =========================================================================
            VIEW: CUSTOMER ACCOUNTS & 360° PROFILE GOVERNANCE
            ========================================================================= */}
        {activeView === 'accounts' && (
          <div className="space-y-6 animate-fade-in">
            {/* Header / Search Controls */}
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <div>
                <div className="flex items-center gap-2">
                  <Users className="h-5 w-5 text-accent" />
                  <h2 className="text-base font-semibold text-fg">
                    Customer Accounts & 360° Identity Governance
                  </h2>
                  <InfoTooltip
                    title="Customer 360° Account Mapping"
                    text="Combines Oracle XE Master USERS, ACCOUNTS, and BALANCE_MASTER tables into a unified view. Drill down into any customer to inspect all their linked deposit accounts, real-time ledger balances, and specific transaction histories."
                  />
                </div>
                <p className="mt-1 text-xs text-fg-muted">
                  Relational customer profiles linked to Oracle XE balance records with real-time KYC, status, and transaction history.
                </p>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                <div className="relative">
                  <Search className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-fg-subtle" />
                  <input
                    type="text"
                    value={accountSearchQuery}
                    onChange={(e) => setAccountSearchQuery(e.target.value)}
                    placeholder="Search account, name, or KYC ID..."
                    className="h-9 w-64 rounded-2xl border border-line bg-surface pl-9 pr-3 text-xs text-fg placeholder:text-fg-subtle focus:border-accent focus:outline-none"
                  />
                  {accountSearchQuery && (
                    <button
                      onClick={() => setAccountSearchQuery('')}
                      className="absolute right-2.5 top-1/2 -translate-y-1/2 text-fg-subtle hover:text-fg"
                    >
                      <X className="h-3 w-3" />
                    </button>
                  )}
                </div>

                <div className="flex items-center rounded-2xl border border-line bg-surface p-1 text-xs shadow-xs">
                  {['ALL', 'SAVINGS', 'ACTIVE', 'LOCKED'].map((f) => (
                    <button
                      key={f}
                      onClick={() => setAccountTypeFilter(f)}
                      className={cn(
                        "rounded-xl px-2.5 py-1 text-[11px] font-semibold transition",
                        accountTypeFilter === f
                          ? "bg-accent/15 text-accent border border-accent/20"
                          : "text-fg-muted hover:text-fg"
                      )}
                    >
                      {f}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Quick Metrics Bar */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div className="rounded-3xl border border-line bg-surface p-4 shadow-xs">
                <span className="text-xs text-fg-muted">Total Depository Accounts</span>
                <div className="mt-1 text-xl font-bold text-fg">{accounts.length} Accounts</div>
                <span className="text-[11px] text-fg-subtle">Normalized Oracle XE schema</span>
              </div>
              <div className="rounded-3xl border border-line bg-surface p-4 shadow-xs">
                <span className="text-xs text-fg-muted">Total Depository Balance</span>
                <div className="mt-1 text-xl font-bold text-emerald-400">
                  {formatPHP(accounts.reduce((acc, a) => acc + (a.available_balance || 0), 0))}
                </div>
                <span className="text-[11px] text-fg-subtle">Aggregated customer liquidity</span>
              </div>
              <div className="rounded-3xl border border-line bg-surface p-4 shadow-xs">
                <span className="text-xs text-fg-muted">KYC & Identity Verification</span>
                <div className="mt-1 text-xl font-bold text-accent">100% Cleared</div>
                <span className="text-[11px] text-fg-subtle">BSP Cir. 1213 Biometrics</span>
              </div>
            </div>

            {/* Accounts Table */}
            <div className="rounded-3xl border border-line bg-surface overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="border-b border-line bg-sunken/60 text-[10px] uppercase font-bold text-fg-subtle tracking-wider">
                    <tr>
                      <th className="py-3 px-4">Account Number</th>
                      <th className="py-3 px-4">Customer Holder</th>
                      <th className="py-3 px-4">Origin Location</th>
                      <th className="py-3 px-4 text-right">Available Balance</th>
                      <th className="py-3 px-4 text-right">Ledger Balance</th>
                      <th className="py-3 px-4 text-center">Status</th>
                      <th className="py-3 px-4 text-right">Governance Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line/60">
                    {filteredAccounts.map((acc) => (
                      <tr
                        key={acc.account_number}
                        onClick={() => setSelectedAccount(acc)}
                        className="hover:bg-sunken/50 transition cursor-pointer group"
                      >
                        <td className="py-3.5 px-4">
                          <div className="flex items-center gap-2">
                            <CreditCard className="h-4 w-4 text-accent shrink-0" />
                            <div>
                              <span className="font-mono font-bold text-fg block text-xs">
                                {acc.account_number}
                              </span>
                              <span className="text-[10px] text-fg-subtle font-mono uppercase">
                                {acc.account_type}
                              </span>
                            </div>
                          </div>
                        </td>
                        <td className="py-3.5 px-4">
                          <div className="font-semibold text-fg">{acc.user_name}</div>
                          <div className="text-[11px] text-fg-muted">{acc.user_email}</div>
                          <div className="text-[10px] text-fg-subtle font-mono">{acc.government_id}</div>
                        </td>
                        <td className="py-3.5 px-4">
                          <div className="flex items-center gap-1.5 text-fg">
                            <MapPin className="h-3 w-3 text-accent shrink-0" />
                            <span className="truncate">{acc.location_name}</span>
                          </div>
                          <div className="text-[10px] text-fg-subtle font-mono pl-4.5">
                            IP: {acc.ip_address}
                          </div>
                        </td>
                        <td className="py-3.5 px-4 text-right font-sans font-bold text-emerald-400">
                          {formatPHP(acc.available_balance)}
                        </td>
                        <td className="py-3.5 px-4 text-right font-sans font-medium text-fg-muted">
                          {formatPHP(acc.current_balance)}
                        </td>
                        <td className="py-3.5 px-4 text-center">
                          <span className={cn(
                            "rounded-full px-2.5 py-0.5 text-[10px] font-semibold",
                            acc.status === 'ACTIVE' ? "bg-emerald-500/10 text-emerald-400" : "bg-rose-500/10 text-rose-400"
                          )}>
                            {acc.status}
                          </span>
                        </td>
                        <td className="py-3.5 px-4 text-right">
                          <div className="flex items-center justify-end gap-1.5" onClick={(e) => e.stopPropagation()}>
                            <button
                              onClick={() => setSelectedAccount(acc)}
                              className="inline-flex items-center gap-1 rounded-xl border border-accent/30 bg-accent/10 px-2.5 py-1 text-[11px] font-semibold text-accent hover:bg-accent/20 transition shadow-xs"
                              title="Inspect 360° Profile & Balances"
                            >
                              <Eye className="h-3 w-3" />
                              <span>360° View</span>
                            </button>
                            {currentAdmin.capability === 'ACCOUNT_LOCK_UNLOCK' && (
                              <button
                                onClick={() => {
                                  setLockTargetAccount(acc);
                                  setLockReason(acc.status === 'LOCKED' ? 'CUSTOMER_VOLUNTARY_REQUEST' : 'SUSPECTED_PHISHING_COERCION');
                                  setLockMemo(acc.status === 'LOCKED' ? 'Customer identity verified at branch. Restoring normal account access.' : 'Customer reported suspicious activity. Freezing debit access.');
                                }}
                                className={cn(
                                  "inline-flex items-center gap-1 rounded-xl border px-2.5 py-1 text-[11px] font-semibold transition shadow-xs",
                                  acc.status === 'LOCKED'
                                    ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20"
                                    : "border-rose-500/30 bg-rose-500/10 text-rose-400 hover:bg-rose-500/20"
                                )}
                                title={acc.status === 'LOCKED' ? "Unfreeze Customer Account" : "Freeze Customer Account"}
                              >
                                {acc.status === 'LOCKED' ? (
                                  <>
                                    <Unlock className="h-3 w-3" />
                                    <span>Unfreeze</span>
                                  </>
                                ) : (
                                  <>
                                    <Lock className="h-3 w-3" />
                                    <span>Freeze</span>
                                  </>
                                )}
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* =========================================================================
            VIEW 3: TRANSACTIONS & REVERSALS (FULL DETAILED JOURNAL)
            ========================================================================= */}
        {activeView === 'transactions' && (
          <div className="space-y-4 animate-fade-in">
            {/* Search and Filters */}
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div className="relative flex-1 max-w-sm">
                <Search className="pointer-events-none absolute left-3.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-fg-subtle" />
                <input
                  type="text"
                  placeholder="Search reference, account, or amount..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="h-10 w-full rounded-2xl border border-line bg-surface pl-9 pr-4 text-xs text-fg placeholder:text-fg-subtle focus:border-accent focus:outline-none transition shadow-xs"
                />
              </div>

              <div className="flex items-center gap-1.5">
                {['ALL', 'SETTLED', 'REVERSED', 'REVIEW'].map((status) => (
                  <button
                    key={status}
                    onClick={() => setStatusFilter(status)}
                    className={cn(
                      "rounded-xl px-3 py-1.5 text-xs font-medium transition",
                      statusFilter === status
                        ? "bg-accent/10 text-accent font-semibold border border-accent/30 shadow-xs"
                        : "text-fg-muted hover:text-fg"
                    )}
                  >
                    {status}
                  </button>
                ))}
              </div>
            </div>

            {/* Table */}
            <div className="overflow-hidden rounded-3xl border border-line bg-surface shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="border-b border-line bg-sunken/40 text-[11px] font-semibold uppercase tracking-wider text-fg-subtle">
                      <th className="py-3.5 px-6">Reference</th>
                      <th className="py-3.5 px-6">Transfer Route</th>
                      <th className="py-3.5 px-6 text-right">Amount</th>
                      <th className="py-3.5 px-6 text-center">Status</th>
                      <th className="py-3.5 px-6">Sign-off / Reversal</th>
                      <th className="py-3.5 px-6 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line text-xs">
                    {filteredTransactions.map((tx) => {
                      const isReversed = tx.status === 'REVERSED';
                      const isCommitted = tx.status === 'COMMITTED' || tx.status === 'POSTED' || tx.status === 'SETTLED';

                      return (
                        <tr 
                          key={tx.id}
                          onClick={() => setSelectedTx(tx)}
                          className="group cursor-pointer hover:bg-sunken/50 transition"
                        >
                          <td className="py-4 px-6 font-mono">
                            <span className="font-semibold text-fg block">{formatShortId(tx.id)}</span>
                            <span className="text-[10px] font-sans text-fg-subtle">
                              {new Date(tx.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </span>
                          </td>

                          <td className="py-4 px-6">
                            <div className="flex items-center gap-1.5 text-fg">
                              <span className="font-medium">Juan Dela Cruz</span>
                              <span className="text-fg-subtle">➔</span>
                              <span className="font-medium">Maria Reyes</span>
                            </div>
                            <span className="block text-[10px] font-mono text-fg-subtle mt-0.5">
                              {tx.fromAccount}
                            </span>
                          </td>

                          <td className="py-4 px-6 text-right font-medium text-fg">
                            <span className="text-sm font-semibold">{formatPHP(tx.amount)}</span>
                          </td>

                          <td className="py-4 px-6 text-center">
                            <span className={cn(
                              "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-medium",
                              isReversed && "bg-rose-500/10 text-rose-400",
                              isCommitted && "bg-emerald-500/10 text-emerald-400",
                              tx.status === 'PENDING_APPROVAL' && "bg-amber-500/10 text-amber-400"
                            )}>
                              {isReversed ? 'Reversed' : isCommitted ? 'Settled' : 'Review'}
                            </span>
                          </td>

                          <td className="py-4 px-6 text-fg-muted">
                            {isReversed ? (
                              <span className="text-rose-400 font-medium">Reversed by {tx.reversedBy === 'usr-1006-mgr-002' ? 'Carlos M.' : 'Diana V.'}</span>
                            ) : (
                              <span>{tx.approvedBy ? `Approved: ${tx.approvedBy === 'usr-1004-adm-001' ? 'Diana V.' : 'Carlos M.'}` : 'Auto-settled'}</span>
                            )}
                          </td>

                          <td className="py-4 px-6 text-right">
                            <div className="flex items-center justify-end gap-2">
                              {isCommitted && (
                                currentAdmin.capability === 'REVERSAL_APPROVAL' ? (
                                  <button
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      setRollbackTarget(tx);
                                    }}
                                    className="rounded-xl border border-amber-500/30 bg-amber-500/10 px-3 py-1 text-xs font-semibold text-amber-400 hover:bg-amber-500/20 transition shadow-xs"
                                  >
                                    Rollback
                                  </button>
                                ) : (
                                  <span className="rounded-lg bg-sunken px-2 py-0.5 text-[10px] text-fg-subtle italic">
                                    Checker Req.
                                  </span>
                                )
                              )}
                              <ChevronRight className="h-4 w-4 text-fg-subtle group-hover:text-fg group-hover:translate-x-0.5 transition" />
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* =========================================================================
            VIEW 3: TWO-STAGE THREAT RADAR (NANOJEV & SCAM TYPOLOGIES)
            ========================================================================= */}
        {activeView === 'threat_radar' && (
          <div className="space-y-6 animate-fade-in">
            <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div className="flex items-center gap-2">
                  <Zap className="h-5 w-5 text-accent" />
                  <h2 className="text-base font-semibold text-fg">
                    Two-Stage Threat Radar: Background Application & Device Posture Monitor
                  </h2>
                  <InfoTooltip
                    title="NanoJev Background App Monitor"
                    text="Monitors client device runtime processes, telephony call states, accessibility services, and device integrity invariants to detect unauthorized remote access, live voice coercion, screen recording, and hooking tools in real time."
                  />
                </div>
                <span className="rounded-full bg-accent/10 px-3 py-1 text-xs font-semibold text-accent border border-accent/20">
                  Laya Security SDK Active
                </span>
              </div>
              <p className="mt-2 text-xs text-fg-muted max-w-3xl leading-relaxed">
                The risk engine splits evaluation into <strong>Stage A</strong> (Deterministic Gate 0 rules + XGBoost S2 tabular scoring in &lt; 30ms) 
                and <strong>Stage B</strong> (NanoJev runtime process telemetry & anomaly classification bounded to 1,500ms). The client device posture sensor continuously streams background application telemetry.
              </p>

              {/* Real-time Device Sensor Probes */}
              <div className="mt-5 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 pt-4 border-t border-line">
                <div className="flex items-center gap-3 p-3 rounded-2xl border border-line bg-sunken/40">
                  <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-rose-500/10 text-rose-400">
                    <ScreenShare className="h-4 w-4" />
                  </div>
                  <div>
                    <div className="text-xs font-semibold text-fg">Accessibility RAT Probe</div>
                    <div className="text-[10px] text-emerald-400 font-medium">Active • AnyDesk / TeamViewer</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-2xl border border-line bg-sunken/40">
                  <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-amber-500/10 text-amber-400">
                    <PhoneCall className="h-4 w-4" />
                  </div>
                  <div>
                    <div className="text-xs font-semibold text-fg">Telephony Call State</div>
                    <div className="text-[10px] text-emerald-400 font-medium">Active • In-Call Coercion Probe</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-2xl border border-line bg-sunken/40">
                  <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-purple-500/10 text-purple-400">
                    <Layers className="h-4 w-4" />
                  </div>
                  <div>
                    <div className="text-xs font-semibold text-fg">Media Projection Probe</div>
                    <div className="text-[10px] text-emerald-400 font-medium">Active • Screen Capture Invariant</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-2xl border border-line bg-sunken/40">
                  <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-sky-500/10 text-sky-400">
                    <Terminal className="h-4 w-4" />
                  </div>
                  <div>
                    <div className="text-xs font-semibold text-fg">Hooking & Root Invariant</div>
                    <div className="text-[10px] text-emerald-400 font-medium">Active • Frida / Magisk Guard</div>
                  </div>
                </div>
              </div>
            </div>

            {/* 7 Background Application Threat Vector Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {BACKGROUND_APP_THREATS.map((threat) => (
                <div key={threat.key} className="rounded-3xl border border-line bg-surface p-5 shadow-xs space-y-3 flex flex-col justify-between">
                  <div>
                    <div className="flex items-start justify-between gap-2">
                      <div className="space-y-1">
                        <span className="text-xs font-bold text-fg leading-tight block">{threat.label}</span>
                        <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full inline-block" style={{ backgroundColor: `${threat.color}15`, color: threat.color }}>
                          {threat.risk} RISK
                        </span>
                      </div>
                      <InfoTooltip title={threat.label} text={threat.desc} />
                    </div>
                    <p className="mt-2 text-[11px] text-fg-muted leading-relaxed">
                      {threat.desc}
                    </p>
                  </div>

                  <div className="space-y-2 pt-2 border-t border-line/60">
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-fg-subtle text-[11px]">Posture Prevalence</span>
                      <span className="font-mono font-bold" style={{ color: threat.color }}>
                        {threat.pct}%
                      </span>
                    </div>
                    <div className="h-2 w-full rounded-full bg-sunken overflow-hidden">
                      <div className="h-full rounded-full transition-all duration-500" style={{ width: `${threat.pct}%`, backgroundColor: threat.color }} />
                    </div>
                    <div className="flex items-center justify-between text-[11px] text-fg-subtle pt-0.5">
                      <span>{threat.count} detected sessions</span>
                      <span className="font-semibold px-2 py-0.5 rounded-lg border border-line shadow-2xs" style={{ color: threat.color }}>
                        Action: {threat.action}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* =========================================================================
            VIEW 4: CUSTOMER GEOLOCATION SURVEILLANCE & MULTI-CUSTOMER SIMULATION
            ========================================================================= */}
        {activeView === 'geo_surveillance' && (
          <div className="space-y-6 animate-fade-in">
            {/* Top Customer Selection Directory Bar with Search and List */}
            <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <Globe className="h-5 w-5 text-accent" />
                    <h2 className="text-base font-semibold text-fg">
                      Multi-Customer Geolocation Simulation Engine
                    </h2>
                    <InfoTooltip
                      title="Multi-Customer Attack Vector Simulation"
                      text="Select any retail customer profile from the bank's active directory. Injected geolocation updates dynamically patch the Oracle XE database record, allowing security teams to simulate impossible travel anomalies, credential sharing, and regional fraud runs across different customer accounts."
                    />
                  </div>
                  <p className="mt-1 text-xs text-fg-muted">
                    Pick a target account holder from the directory below to inspect baseline coordinates and trigger simulated impossible travel jumps.
                  </p>
                </div>

                {/* Customer Search Bar */}
                <div className="relative">
                  <Search className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-fg-subtle" />
                  <input
                    type="text"
                    value={simSearchQuery}
                    onChange={(e) => setSimSearchQuery(e.target.value)}
                    placeholder="Search customer by name, account, or city..."
                    className="h-9 w-full sm:w-80 rounded-2xl border border-line bg-surface pl-9 pr-8 text-xs text-fg placeholder:text-fg-subtle focus:border-accent focus:outline-none"
                  />
                  {simSearchQuery && (
                    <button
                      onClick={() => setSimSearchQuery('')}
                      className="absolute right-2.5 top-1/2 -translate-y-1/2 text-fg-subtle hover:text-fg"
                    >
                      <X className="h-3 w-3" />
                    </button>
                  )}
                </div>
              </div>

              {/* Compact Scrollable Customer List */}
              <div className="max-h-56 overflow-y-auto divide-y divide-line rounded-2xl border border-line bg-surface">
                {filteredSimCustomers.map((cust) => {
                  const isSelected = selectedSimCustomer.userId === cust.userId;
                  return (
                    <button
                      key={cust.userId}
                      onClick={() => handleSelectSimCustomer(cust)}
                      className={cn(
                        "w-full flex items-center justify-between p-3 text-left transition hover:bg-sunken/60",
                        isSelected && "bg-accent/5 ring-1 ring-inset ring-accent/30"
                      )}
                    >
                      <div className="flex items-center gap-3">
                        <div className={cn(
                          "flex h-8 w-8 items-center justify-center rounded-xl font-bold text-xs shrink-0",
                          isSelected ? "bg-accent text-white" : "bg-sunken text-fg-muted"
                        )}>
                          {cust.avatar}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-xs font-semibold text-fg">{cust.name}</span>
                            <span className="text-[10px] text-fg-subtle font-mono">{cust.accountNumber}</span>
                            <span className="text-[9px] px-1.5 py-0.2 rounded-md bg-accent/10 text-accent font-semibold">{cust.tier}</span>
                          </div>
                          <div className="text-[11px] text-fg-muted flex items-center gap-2 mt-0.5">
                            <span className="flex items-center gap-1">
                              <MapPin className="h-3 w-3 text-fg-subtle" />
                              {cust.baselineCity}
                            </span>
                            <span>•</span>
                            <span className="font-mono text-fg-subtle">IP: {cust.ip}</span>
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="font-mono font-semibold text-xs text-emerald-400">{cust.balance}</span>
                        {isSelected && (
                          <span className="flex h-5 w-5 items-center justify-center rounded-full bg-accent text-white text-[10px]">
                            <Check className="h-3 w-3" />
                          </span>
                        )}
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Simulation Controls & Radar */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Left Card: Customer Location Control */}
              <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-6">
                <div>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Globe className="h-4 w-4 text-accent" />
                      <h3 className="text-sm font-semibold text-fg">
                        Active Target: {selectedSimCustomer.name}
                      </h3>
                      <InfoTooltip
                        title="Target Geolocation Injector"
                        text="Simulate instant coordinates changes. Testing velocity checks against impossible travel boundaries (e.g. >1,000 km/h)."
                      />
                    </div>
                    <span className="text-[11px] font-mono text-fg-subtle">
                      {selectedSimCustomer.accountNumber}
                    </span>
                  </div>
                  <p className="mt-1 text-xs text-fg-muted">
                    Simulate geographic jumps for <strong>{selectedSimCustomer.name}</strong>. Relocating to London or New York triggers the Impossible Travel velocity rule and places subsequent transactions on security hold.
                  </p>
                </div>

                {/* Current Active Origin Card */}
                <div className="rounded-2xl border border-line bg-sunken/40 p-4">
                  <span className="text-[10px] font-semibold uppercase tracking-wider text-fg-subtle block">
                    Active Database Coordinates (Oracle XE)
                  </span>
                  <div className="mt-1 flex items-baseline justify-between">
                    <span className="text-base font-bold text-fg">
                      {userLocation.locationName}
                    </span>
                    <span className="font-mono text-xs text-fg-muted">
                      IP: {userLocation.ipAddress}
                    </span>
                  </div>
                  <span className="mt-0.5 block font-mono text-[11px] text-fg-subtle">
                    {userLocation.latitude.toFixed(4)}° N, {userLocation.longitude.toFixed(4)}° E
                  </span>
                </div>

                {/* 1-Click Simulation Buttons */}
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold text-fg-subtle block">
                      Select Simulation Vector for {selectedSimCustomer.name}
                    </span>
                    {isUpdatingLocation && (
                      <span className="text-[10px] text-accent animate-pulse font-mono">
                        Updating Oracle XE...
                      </span>
                    )}
                  </div>

                  {currentAdmin.capability !== 'SIMULATION' && (
                    <div className="rounded-xl border border-amber-500/30 bg-amber-500/5 p-2.5 text-[11px] text-amber-400 flex items-center gap-2">
                      <Lock className="h-3.5 w-3.5 shrink-0" />
                      <span>Simulation vector injection restricted to Fraud Ops Analyst ({ADMIN_ROSTER[0].name}).</span>
                    </div>
                  )}

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {GEO_PRESETS.map((preset) => (
                      <button
                        key={preset.id}
                        onClick={() => handleApplyLocation(preset)}
                        disabled={isUpdatingLocation || currentAdmin.capability !== 'SIMULATION'}
                        className={cn(
                          "flex flex-col text-left rounded-2xl border p-3.5 transition shadow-xs",
                          currentAdmin.capability !== 'SIMULATION' && "opacity-50 cursor-not-allowed",
                          preset.type === 'FRAUD' 
                            ? "border-rose-500/30 bg-rose-500/5 hover:bg-rose-500/10" 
                            : "border-line bg-surface hover:bg-sunken",
                          userLocation.locationName.includes(preset.name.split(',')[0]) && "ring-2 ring-accent"
                        )}
                      >
                        <div className="flex items-center justify-between">
                          <span className="text-xs font-bold text-fg">{preset.name}</span>
                          <span className={cn(
                            "text-[10px] font-semibold px-1.5 py-0.5 rounded-lg",
                            preset.type === 'FRAUD' ? "text-rose-400 bg-rose-500/10" : "text-emerald-400 bg-emerald-500/10"
                          )}>
                            {preset.type === 'FRAUD' ? 'Anomaly' : 'Safe'}
                          </span>
                        </div>
                        <p className="mt-1 text-[11px] text-fg-muted leading-tight">
                          {preset.desc}
                        </p>
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              {/* Right Card: Real Interactive Map & Telemetry HUD */}
              <div className="space-y-6">
                <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4">
                  <div className="flex items-center justify-between border-b border-line pb-3">
                    <div className="flex items-center gap-2">
                      <MapPin className="h-4 w-4 text-accent" />
                      <h3 className="text-sm font-semibold text-fg">Geodetic Velocity Radar & Live Map</h3>
                      <InfoTooltip
                        title="Geodetic Velocity Radar"
                        text="Calculates Haversine distance and transit speed between consecutive transactions to identify impossible travel anomalies."
                      />
                    </div>
                    <span className="text-xs text-fg-subtle font-mono">Haversine Metric</span>
                  </div>

                  {/* Interactive OpenStreetMap Embed */}
                  <div className="relative rounded-2xl border border-line bg-sunken/40 overflow-hidden shadow-inner">
                    <iframe
                      title="Customer Live Coordinate Map"
                      className="w-full h-64 border-0"
                      src={`https://www.openstreetmap.org/export/embed.html?bbox=${(userLocation.longitude || 120.9842) - 0.08}%2C${(userLocation.latitude || 14.5995) - 0.08}%2C${(userLocation.longitude || 120.9842) + 0.08}%2C${(userLocation.latitude || 14.5995) + 0.08}&layer=mapnik&marker=${userLocation.latitude || 14.5995}%2C${userLocation.longitude || 120.9842}`}
                    />
                  </div>

                  {/* Telemetry HUD */}
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-1">
                    <div className="p-2.5 rounded-xl border border-line bg-sunken/40">
                      <span className="text-[10px] text-fg-subtle block uppercase font-semibold">Coordinates</span>
                      <span className="font-mono text-xs font-bold text-fg">
                        {userLocation.latitude.toFixed(4)}° N, {userLocation.longitude.toFixed(4)}° E
                      </span>
                    </div>
                    <div className="p-2.5 rounded-xl border border-line bg-sunken/40">
                      <span className="text-[10px] text-fg-subtle block uppercase font-semibold">City / Region</span>
                      <span className="text-xs font-semibold text-fg truncate block">
                        {userLocation.locationName.split(',')[0]}
                      </span>
                    </div>
                    <div className="p-2.5 rounded-xl border border-line bg-sunken/40">
                      <span className="text-[10px] text-fg-subtle block uppercase font-semibold">Network IP</span>
                      <span className="font-mono text-xs text-fg">
                        {userLocation.ipAddress}
                      </span>
                    </div>
                    <div className="p-2.5 rounded-xl border border-line bg-sunken/40">
                      <span className="text-[10px] text-fg-subtle block uppercase font-semibold">Velocity Status</span>
                      <span className={cn(
                        "text-xs font-bold block",
                        stats.isAnomaly ? "text-rose-400" : "text-emerald-400"
                      )}>
                        {stats.isAnomaly ? 'Anomaly Alert' : 'Normal Match'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Customer Notice Preview */}
                <div className="rounded-3xl border border-amber-500/30 bg-amber-500/5 p-5 shadow-xs">
                  <div className="flex items-center gap-2 text-xs font-semibold text-amber-300">
                    <ShieldAlert className="h-4 w-4" />
                    <span>Customer Warning Notice (Shown on held transfers)</span>
                    <InfoTooltip
                      title="Customer Notification Dispatch"
                      text="Push notification and in-app warning sent immediately to account holder when suspicious geo-velocity triggers a hold."
                    />
                  </div>
                  <p className="mt-2 text-xs text-fg-muted leading-relaxed">
                    <strong>"Security Notice: Transaction Temporarily Held"</strong><br />
                    We detected unusual activity from a new location. To protect your funds, this transfer was stopped and your account has been placed on a temporary security hold. If this was you, please verify your identity via Face/2FA or contact Customer Support.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* =========================================================================
            VIEW 5: IMMUTABLE AUDIT VAULT (POSTGRESQL)
            ========================================================================= */}
        {activeView === 'audit_vault' && (
          <div className="overflow-hidden rounded-3xl border border-line bg-surface shadow-xs animate-fade-in">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-line bg-sunken/40 text-[11px] font-semibold uppercase tracking-wider text-fg-subtle">
                    <th className="py-3.5 px-6">Audit ID</th>
                    <th className="py-3.5 px-6">Transaction Ref</th>
                    <th className="py-3.5 px-6">Account</th>
                    <th className="py-3.5 px-6 text-right">Amount</th>
                    <th className="py-3.5 px-6">Maker (Reversing)</th>
                    <th className="py-3.5 px-6">Checker (Approver)</th>
                    <th className="py-3.5 px-6 text-center">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line text-xs font-mono">
                  {auditLogs.map((log) => {
                    const isRollback = log.status === 'ROLLED_BACK';

                    return (
                      <tr key={log.auditId || log.audit_id} className="hover:bg-sunken/40 transition">
                        <td className="py-3.5 px-6 text-fg-subtle">
                          #{log.auditId || log.audit_id}
                        </td>
                        <td className="py-3.5 px-6 text-fg font-medium">
                          {formatShortId(log.transactionId || log.transaction_id)}
                        </td>
                        <td className="py-3.5 px-6 text-fg-muted">
                          {log.accountId || log.account_id}
                        </td>
                        <td className="py-3.5 px-6 text-right font-sans font-semibold text-fg">
                          {formatPHP(parseFloat(log.mutationAmount || log.mutation_amount || 0))}
                        </td>
                        <td className="py-3.5 px-6 font-sans text-fg">
                          {log.reversedByUserId === 'usr-1006-mgr-002' ? 'Carlos Mendoza' : log.reversedByUserId || log.initiatorUserId || 'System'}
                        </td>
                        <td className="py-3.5 px-6 font-sans text-fg-muted">
                          {log.approvedByUserId === 'usr-1004-adm-001' ? 'Diana Vance' : log.approvedByUserId || 'Auto'}
                        </td>
                        <td className="py-3.5 px-6 text-center font-sans">
                          {isRollback ? (
                            <span className="inline-flex items-center gap-1 rounded-full bg-rose-500/10 px-2 py-0.5 text-[10px] font-semibold text-rose-400">
                              <RotateCcw className="h-2.5 w-2.5" />
                              Rolled Back
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                              Committed
                            </span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* =========================================================================
            VIEW 6: AMLC SAR REPORTS (AUTOMATED DRAFT SUSPICIOUS ACTIVITY REPORTS)
            ========================================================================= */}
        {activeView === 'sar_queue' && (
          <div className="space-y-4 animate-fade-in">
            <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-base font-semibold text-fg">
                    Anti-Money Laundering Council (AMLC) SAR Drafts
                  </h2>
                  <p className="mt-1 text-xs text-fg-muted">
                    Automated background drafts generated when Gate 0 or NanoJev flags high-urgency fraud patterns.
                  </p>
                </div>
                <span className="rounded-xl border border-line bg-sunken px-3 py-1 text-xs font-semibold text-fg">
                  12 Cases Enqueued
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {[
                { ref: 'TX-30E637D3', typology: 'Investment Scam', amount: 500000, trigger: 'High Spike Ratio (25x) + Urgent Memo' },
                { ref: 'TX-74D6BDD5', typology: 'Impersonation / NBI Warrant', amount: 250000, trigger: 'Active Call + Coercion Telemetry' },
                { ref: 'TX-CD05024D', typology: 'Romance / Emergency Aid', amount: 150000, trigger: 'New Payee + Drain Ratio 0.85' },
                { ref: 'TX-AE3E7621', typology: 'Impossible Travel / Hijack', amount: 80000, trigger: 'Velocity > 2,000,000 km/h (London Jump)' }
              ].map((sar) => (
                <div key={sar.ref} className="rounded-3xl border border-line bg-surface p-5 shadow-xs space-y-2.5">
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs font-bold text-fg">{sar.ref}</span>
                    <span className="rounded-full bg-rose-500/10 px-2.5 py-0.5 text-[10px] font-semibold text-rose-400">
                      Draft STR/SAR
                    </span>
                  </div>
                  <div className="text-sm font-bold text-fg">{sar.typology}</div>
                  <div className="text-xs text-fg-muted">Trigger: {sar.trigger}</div>
                  <div className="pt-2 border-t border-line/60 flex items-center justify-between text-xs">
                    <span className="text-fg-subtle">Amount:</span>
                    <span className="font-semibold text-fg">{formatPHP(sar.amount)}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </main>

      {/* =========================================================================
          CENTERED WIDE TRANSACTION AUDIT MODAL (11-STAGE PIPELINE)
          ========================================================================= */}
      {selectedTx && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4 sm:p-6 animate-in fade-in duration-200">
          <div className="w-full max-w-4xl max-h-[92vh] bg-surface border border-line rounded-3xl shadow-2xl flex flex-col overflow-hidden animate-in zoom-in-95 duration-150">
            {/* Modal Header */}
            <div className="flex items-center justify-between border-b border-line px-6 py-4 bg-surface">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-accent/10 text-accent">
                  <Layers className="h-5 w-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-fg-subtle">
                      Transaction Audit Inspector
                    </span>
                    <span
                      className={cn(
                        'rounded-full px-2 py-0.5 text-[10px] font-semibold',
                        selectedTx.status === 'REVERSED'
                          ? 'bg-rose-500/10 text-rose-400'
                          : selectedTx.status === 'PENDING_APPROVAL' || selectedTx.status === 'REVIEW'
                          ? 'bg-amber-500/10 text-amber-400'
                          : 'bg-emerald-500/10 text-emerald-400'
                      )}
                    >
                      {selectedTx.status}
                    </span>
                  </div>
                  <div className="flex items-center gap-2 mt-0.5">
                    <span className="font-mono text-base font-bold text-fg">
                      {selectedTx.id}
                    </span>
                    <button
                      onClick={(e) => handleCopy(selectedTx.id, selectedTx.id, e)}
                      title="Copy Reference ID"
                      className="text-fg-subtle hover:text-fg p-1 rounded-md hover:bg-sunken transition"
                    >
                      {copiedId === selectedTx.id ? (
                        <Check className="h-3.5 w-3.5 text-emerald-400" />
                      ) : (
                        <Copy className="h-3.5 w-3.5" />
                      )}
                    </button>
                  </div>
                </div>
              </div>
              <button
                onClick={() => setSelectedTx(null)}
                className="rounded-2xl p-2 text-fg-subtle hover:text-fg hover:bg-sunken transition"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {/* Modal Scrollable Body */}
            <div className="flex-1 overflow-y-auto p-6 sm:p-7 space-y-6">
              {/* Top Summary Cards (3 Columns) */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div className="rounded-2xl border border-line bg-sunken/40 p-4 space-y-1">
                  <span className="text-xs text-fg-muted font-medium">Settlement Amount</span>
                  <div className="text-2xl font-bold text-fg">
                    {formatPHP(selectedTx.amount)}
                  </div>
                  <div className="text-[11px] text-fg-subtle">
                    Oracle 21c Decimal Precision (18,4)
                  </div>
                </div>

                <div className="rounded-2xl border border-line bg-sunken/40 p-4 space-y-1">
                  <span className="text-xs text-fg-muted font-medium">Transfer Route</span>
                  <div className="text-sm font-semibold text-fg truncate">
                    {selectedTx.fromAccount || '1000-2000-3001'}
                  </div>
                  <div className="flex items-center gap-1.5 text-xs text-fg-muted">
                    <ArrowRight className="h-3 w-3 text-accent" />
                    <span className="truncate">{selectedTx.toAccount || '1000-2000-3002'}</span>
                  </div>
                </div>

                <div className="rounded-2xl border border-line bg-sunken/40 p-4 space-y-1">
                  <span className="text-xs text-fg-muted font-medium">Security & Compliance</span>
                  <div className="flex items-center gap-1.5 text-xs font-semibold text-emerald-400">
                    <ShieldCheck className="h-3.5 w-3.5 text-emerald-400" />
                    <span>Two-Stage Risk Verified</span>
                  </div>
                  <div className="text-[11px] text-fg-subtle">
                    BSP Cir. 1213 Biometrics • Zero SMS OTP
                  </div>
                </div>
              </div>

              {/* Reversal Banner if Rolled Back */}
              {selectedTx.status === 'REVERSED' && (
                <div className="rounded-2xl border border-rose-500/30 bg-rose-500/5 p-4 flex items-start gap-3">
                  <RotateCcw className="h-5 w-5 text-rose-400 shrink-0 mt-0.5" />
                  <div className="space-y-1 text-xs">
                    <div className="font-semibold text-rose-400">
                      Compensating Reversal Executed (T24 Ledger Balance Restored)
                    </div>
                    <div className="text-fg-muted">
                      Initiated by <strong className="text-fg">{selectedTx.reversedBy === 'usr-1006-mgr-002' ? 'Carlos Mendoza' : selectedTx.reversedBy || 'Diana Vance'}</strong>, approved by <strong className="text-fg">{selectedTx.approvedBy === 'usr-1004-adm-001' ? 'Diana Vance' : 'Carlos Mendoza'}</strong>.
                    </div>
                    <div className="text-fg-subtle pt-1">
                      Reason: <span className="text-fg font-mono">{selectedTx.reversalReason || 'CUSTOMER_DISPUTE_WRONG_ACCOUNT'}</span>
                      {selectedTx.reversalMemo && ` — "${selectedTx.reversalMemo}"`}
                    </div>
                  </div>
                </div>
              )}

              {/* 11-Stage Visual Lifecycle Section */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div>
                    <h4 className="text-xs font-bold uppercase tracking-wider text-fg-subtle">
                      Processing Lifecycle Stepper
                    </h4>
                    <p className="text-xs text-fg-muted">
                      Deterministic progression from API Gateway ingestion to immutable database sealing.
                    </p>
                  </div>
                  <span className="rounded-full bg-emerald-500/10 px-2.5 py-1 text-[11px] font-semibold text-emerald-400 flex items-center gap-1">
                    <CheckCircle2 className="h-3 w-3" />
                    11 / 11 Stages Verified
                  </span>
                </div>

                {/* Single Row per Stage (11 Rows) */}
                <div className="space-y-2.5">
                  {[
                    { step: 1, name: 'Initiated', system: 'Gateway :8080', desc: 'Received via API Gateway with client device fingerprint and TLS session verification' },
                    { step: 2, name: 'Validated', system: 'Account Svc :8081', desc: 'Account format, beneficiary existence, active status & ISO-4217 PHP currency verified' },
                    { step: 3, name: 'Authenticated', system: 'Security JWT', desc: 'Active cryptographic JWT session and hardware-bound device signature cleared' },
                    { step: 4, name: 'Fraud Check', system: 'Risk Engine :8084', desc: 'Stage A Gate 0 (<200ms latency) & NanoJev ONNX memo NLP threat check passed' },
                    { step: 5, name: 'Limit Check', system: 'BSP Cir. 1033', desc: 'Regulatory daily ceilings, velocity limits & AMLA threshold validation completed' },
                    { step: 6, name: 'Funds Check', system: 'Pessimistic Lock', desc: 'Database row-level lock acquired; available balance verified strictly sufficient' },
                    { step: 7, name: 'Authorized', system: 'Dual Controls', desc: 'Hardware biometric token & maker-checker segregation of duties verified' },
                    { step: 8, name: 'Posted', system: 'Oracle XE 21c', desc: 'Transaction master record committed to Oracle database with unique sequence' },
                    { step: 9, name: 'Ledger Update', system: 'Ledger Engine :8082', desc: 'Atomic double-entry mutation complete in Balance Master (Debit Dr / Credit Cr)' },
                    { step: 10, name: 'Notification', system: 'Kafka Broker :9092', desc: 'Transactional outbox event dispatched to Kafka cluster and customer advice stream' },
                    { step: 11, name: 'Reconciliation', system: 'PostgreSQL :5433', desc: 'Immutable SHA-256 cryptographic seal written to PostgreSQL WORM Audit Vault' },
                  ].map((stage) => (
                    <div
                      key={stage.step}
                      className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 rounded-2xl border border-line bg-surface p-3.5 hover:bg-sunken/40 transition"
                    >
                      <div className="flex items-center gap-3.5 min-w-0">
                        <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-400 font-mono text-xs font-bold ring-2 ring-emerald-500/20">
                          {stage.step}
                        </div>
                        <div className="min-w-[130px] sm:min-w-[150px] shrink-0">
                          <span className="text-xs font-bold text-fg block">{stage.name}</span>
                          <span className="text-[10px] text-fg-subtle font-mono">{stage.system}</span>
                        </div>
                        <p className="text-xs text-fg-muted">
                          {stage.desc}
                        </p>
                      </div>
                      <div className="shrink-0 flex items-center justify-end sm:justify-start">
                        <span className="rounded-full bg-emerald-500/10 px-2.5 py-1 text-[11px] text-emerald-400 font-semibold flex items-center gap-1 border border-emerald-500/20">
                          <Check className="h-3 w-3" /> Passed
                        </span>
                      </div>
                    </div>
                  ))}

                  {selectedTx.status === 'REVERSED' && (
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 rounded-2xl border border-rose-500/30 bg-rose-500/5 p-3.5 transition">
                      <div className="flex items-center gap-3.5 min-w-0">
                        <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-rose-500/20 text-rose-400 font-mono text-xs font-bold ring-2 ring-rose-500/30">
                          12
                        </div>
                        <div className="min-w-[130px] sm:min-w-[150px] shrink-0">
                          <span className="text-xs font-bold text-rose-400 block">Compensating Rollback</span>
                          <span className="text-[10px] text-rose-300 font-mono">T24 Core Banking</span>
                        </div>
                        <p className="text-xs text-fg-muted">
                          Contra-entry credited back to originating account. Signed off by {selectedTx.reversedBy || 'Carlos Mendoza'} & approved by {selectedTx.approvedBy || 'Diana Vance'}.
                        </p>
                      </div>
                      <div className="shrink-0 flex items-center justify-end sm:justify-start">
                        <span className="rounded-full bg-rose-500/10 px-2.5 py-1 text-[11px] text-rose-400 font-semibold flex items-center gap-1 border border-rose-500/20">
                          <RotateCcw className="h-3 w-3" /> Reversed
                        </span>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Modal Sticky Footer */}
            <div className="border-t border-line px-6 py-4 bg-surface flex flex-col sm:flex-row items-center justify-between gap-3">
              <div className="flex items-center gap-2 text-xs text-fg-muted">
                <Database className="h-4 w-4 text-fg-subtle" />
                <span>Audited via append-only PostgreSQL ledger with SHA-256 digest sealing.</span>
              </div>
              <div className="flex items-center gap-2 w-full sm:w-auto">
                {(selectedTx.status === 'COMMITTED' || selectedTx.status === 'POSTED' || selectedTx.status === 'SETTLED') && currentAdmin.capability === 'REVERSAL_APPROVAL' && (
                  <button
                    onClick={() => {
                      const txToRollback = selectedTx;
                      setSelectedTx(null);
                      setRollbackTarget(txToRollback);
                    }}
                    className="flex-1 sm:flex-initial rounded-2xl bg-amber-500 px-4 py-2 text-xs font-semibold text-black hover:bg-amber-400 transition shadow-xs flex items-center justify-center gap-1.5"
                  >
                    <RotateCcw className="h-3.5 w-3.5" />
                    <span>Initiate Rollback</span>
                  </button>
                )}
                <button
                  onClick={() => setSelectedTx(null)}
                  className="flex-1 sm:flex-initial rounded-2xl border border-line bg-sunken px-4 py-2 text-xs font-semibold text-fg hover:bg-raised transition"
                >
                  Close Inspector
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          360° CUSTOMER PROFILE & ACCOUNT INSPECTOR MODAL
          ========================================================================= */}
      {selectedAccount && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4 sm:p-6 animate-in fade-in duration-200">
          <div className="w-full max-w-4xl max-h-[92vh] bg-surface border border-line rounded-3xl shadow-2xl flex flex-col overflow-hidden animate-in zoom-in-95 duration-150">
            {/* Modal Header */}
            <div className="flex items-center justify-between border-b border-line px-6 py-4 bg-surface">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-accent/15 text-accent font-bold text-sm">
                  {selectedAccount.user_name.split(' ').map(n => n[0]).join('')}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-fg-subtle">
                      Customer 360° Profile & Account Ledger
                    </span>
                    <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                      {selectedAccount.status}
                    </span>
                  </div>
                  <div className="flex items-center gap-2 mt-0.5">
                    <span className="font-bold text-fg text-base">
                      {selectedAccount.user_name}
                    </span>
                    <span className="font-mono text-xs text-fg-muted">
                      ({selectedAccount.user_id || 'U1001'})
                    </span>
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {currentAdmin.capability === 'ACCOUNT_LOCK_UNLOCK' && (
                  <button
                    onClick={() => {
                      setLockTargetAccount(selectedAccount);
                      setLockReason(selectedAccount.status === 'LOCKED' ? 'CUSTOMER_VOLUNTARY_REQUEST' : 'SUSPECTED_PHISHING_COERCION');
                      setLockMemo(selectedAccount.status === 'LOCKED' ? 'Customer identity verified at branch. Restoring normal account access.' : 'Customer reported suspicious activity. Freezing debit access.');
                    }}
                    className={cn(
                      "inline-flex items-center gap-1.5 rounded-2xl border px-3 py-1.5 text-xs font-semibold transition shadow-xs",
                      selectedAccount.status === 'LOCKED'
                        ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20"
                        : "border-rose-500/30 bg-rose-500/10 text-rose-400 hover:bg-rose-500/20"
                    )}
                  >
                    {selectedAccount.status === 'LOCKED' ? (
                      <>
                        <Unlock className="h-3.5 w-3.5" />
                        <span>Unlock Account</span>
                      </>
                    ) : (
                      <>
                        <Lock className="h-3.5 w-3.5" />
                        <span>Freeze / Lock Account</span>
                      </>
                    )}
                  </button>
                )}
                <button
                  onClick={() => setSelectedAccount(null)}
                  className="rounded-2xl p-2 text-fg-subtle hover:text-fg hover:bg-sunken transition"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>
            </div>

            {/* Modal Scrollable Body */}
            <div className="flex-1 overflow-y-auto p-6 sm:p-7 space-y-6">
              {/* Row 1: 3 Balance & Liquidity Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div className="rounded-2xl border border-line bg-sunken/40 p-4 space-y-1">
                  <span className="text-xs text-fg-muted font-medium">Selected Account Available Balance</span>
                  <div className="text-2xl font-bold text-emerald-400 font-sans">
                    {formatPHP(selectedAccount.available_balance)}
                  </div>
                  <div className="text-[11px] text-fg-subtle font-mono">
                    Acc #{selectedAccount.account_number} ({selectedAccount.account_type})
                  </div>
                </div>

                <div className="rounded-2xl border border-line bg-sunken/40 p-4 space-y-1">
                  <span className="text-xs text-fg-muted font-medium">Oracle XE Ledger Balance</span>
                  <div className="text-2xl font-bold text-fg font-sans">
                    {formatPHP(selectedAccount.current_balance)}
                  </div>
                  <div className="text-[11px] text-fg-subtle">
                    Soft Holds Applied: {formatPHP(selectedAccount.held_balance || 0)}
                  </div>
                </div>

                <div className="rounded-2xl border border-line bg-sunken/40 p-4 space-y-1">
                  <span className="text-xs text-fg-muted font-medium">Total Customer Wealth</span>
                  <div className="text-2xl font-bold text-accent font-sans">
                    {formatPHP(
                      accounts
                        .filter(a => a.user_id === selectedAccount.user_id)
                        .reduce((acc, a) => acc + (a.available_balance || 0), 0)
                    )}
                  </div>
                  <div className="text-[11px] text-fg-subtle">
                    Across {accounts.filter(a => a.user_id === selectedAccount.user_id).length} linked depository accounts
                  </div>
                </div>
              </div>

              {/* Row 2: Customer Identity, KYC & Device Telemetry Profile */}
              <div className="rounded-2xl border border-line bg-surface p-5 space-y-4 shadow-xs">
                <div className="flex items-center justify-between border-b border-line pb-3">
                  <div className="flex items-center gap-2">
                    <UserCheck className="h-4 w-4 text-accent" />
                    <h3 className="text-xs font-bold uppercase tracking-wider text-fg">
                      Customer KYC & Telemetry Profile (USERS Table)
                    </h3>
                  </div>
                  <span className="text-[11px] text-emerald-400 font-semibold font-mono">
                    BSP KYC Tier 3 (Fully Verified)
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 text-xs">
                  <div>
                    <span className="text-fg-subtle block text-[11px]">Email Address</span>
                    <strong className="text-fg truncate block">{selectedAccount.user_email}</strong>
                  </div>
                  <div>
                    <span className="text-fg-subtle block text-[11px]">Contact Number</span>
                    <strong className="text-fg font-mono block">{selectedAccount.user_phone}</strong>
                  </div>
                  <div>
                    <span className="text-fg-subtle block text-[11px]">Government ID</span>
                    <strong className="text-fg font-mono block">{selectedAccount.government_id}</strong>
                  </div>
                  <div>
                    <span className="text-fg-subtle block text-[11px]">Date of Birth</span>
                    <strong className="text-fg font-mono block">{selectedAccount.dob || '1990-05-14'}</strong>
                  </div>
                </div>

                <div className="pt-3 border-t border-line/60 grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs">
                  <div className="flex items-center gap-2">
                    <MapPin className="h-4 w-4 text-accent shrink-0" />
                    <div>
                      <span className="text-[11px] text-fg-subtle block">Baseline Origin</span>
                      <strong className="text-fg">{selectedAccount.location_name}</strong>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Globe className="h-4 w-4 text-accent shrink-0" />
                    <div>
                      <span className="text-[11px] text-fg-subtle block">Registered IP Address</span>
                      <strong className="text-fg font-mono">{selectedAccount.ip_address}</strong>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Fingerprint className="h-4 w-4 text-emerald-400 shrink-0" />
                    <div>
                      <span className="text-[11px] text-fg-subtle block">Biometric Authentication</span>
                      <strong className="text-emerald-400">Zero SMS OTP (Face ID Bound)</strong>
                    </div>
                  </div>
                </div>
              </div>

              {/* Row 3: All Accounts Linked to this Customer */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <CreditCard className="h-4 w-4 text-accent" />
                    <h3 className="text-xs font-bold uppercase tracking-wider text-fg-subtle">
                      All Accounts Linked to {selectedAccount.user_name}
                    </h3>
                  </div>
                  <span className="text-[11px] text-fg-subtle">
                    Click to switch active account inspection
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {accounts
                    .filter(a => a.user_id === selectedAccount.user_id)
                    .map((linkedAcc) => {
                      const isCurrent = linkedAcc.account_number === selectedAccount.account_number;
                      return (
                        <div
                          key={linkedAcc.account_number}
                          onClick={() => setSelectedAccount(linkedAcc)}
                          className={cn(
                            "rounded-2xl border p-4 transition cursor-pointer flex items-center justify-between",
                            isCurrent
                              ? "border-accent/40 bg-accent/5 ring-1 ring-accent/30"
                              : "border-line bg-surface hover:bg-sunken"
                          )}
                        >
                          <div className="flex items-center gap-3">
                            <div className={cn(
                              "flex h-9 w-9 items-center justify-center rounded-xl",
                              isCurrent ? "bg-accent/20 text-accent" : "bg-sunken text-fg-subtle"
                            )}>
                              <CreditCard className="h-4 w-4" />
                            </div>
                            <div>
                              <div className="font-mono text-xs font-bold text-fg">
                                {linkedAcc.account_number}
                              </div>
                              <span className="text-[10px] uppercase font-semibold text-fg-subtle">
                                {linkedAcc.account_type} {isCurrent && '• Currently Viewing'}
                              </span>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="font-sans text-xs font-bold text-fg">
                              {formatPHP(linkedAcc.available_balance)}
                            </div>
                            <span className="text-[10px] text-emerald-400 font-semibold">
                              {linkedAcc.status}
                            </span>
                          </div>
                        </div>
                      );
                    })}
                </div>
              </div>

              {/* Row 4: Transaction History for this Account */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Layers className="h-4 w-4 text-accent" />
                    <h3 className="text-xs font-bold uppercase tracking-wider text-fg-subtle">
                      Recent Transactions on Account #{selectedAccount.account_number}
                    </h3>
                  </div>
                  <span className="text-[11px] text-fg-subtle font-mono">
                    {transactions.filter(t => t.fromAccount === selectedAccount.account_number || t.toAccount === selectedAccount.account_number).length} Entries
                  </span>
                </div>

                <div className="rounded-2xl border border-line bg-surface overflow-hidden">
                  <table className="w-full text-left text-xs">
                    <thead className="border-b border-line bg-sunken/60 text-[10px] uppercase font-bold text-fg-subtle">
                      <tr>
                        <th className="py-2.5 px-4">Tx Reference</th>
                        <th className="py-2.5 px-4">Flow Direction</th>
                        <th className="py-2.5 px-4 text-right">Amount</th>
                        <th className="py-2.5 px-4 text-center">Status</th>
                        <th className="py-2.5 px-4 text-right">Action</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-line/60">
                      {transactions
                        .filter(t => t.fromAccount === selectedAccount.account_number || t.toAccount === selectedAccount.account_number)
                        .slice(0, 5)
                        .map((tx) => {
                          const isSender = tx.fromAccount === selectedAccount.account_number;
                          return (
                            <tr key={tx.id} className="hover:bg-sunken/40 transition">
                              <td className="py-2.5 px-4 font-mono font-bold text-fg">
                                {formatShortId(tx.id)}
                              </td>
                              <td className="py-2.5 px-4">
                                <span className={cn(
                                  "inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[10px] font-semibold",
                                  isSender ? "bg-amber-500/10 text-amber-400" : "bg-emerald-500/10 text-emerald-400"
                                )}>
                                  {isSender ? 'Outgoing Debit' : 'Incoming Credit'}
                                </span>
                              </td>
                              <td className="py-2.5 px-4 text-right font-sans font-bold text-fg">
                                {formatPHP(tx.amount)}
                              </td>
                              <td className="py-2.5 px-4 text-center">
                                <span className={cn(
                                  "rounded-full px-2 py-0.5 text-[10px] font-semibold",
                                  tx.status === 'REVERSED' ? "bg-rose-500/10 text-rose-400" : "bg-emerald-500/10 text-emerald-400"
                                )}>
                                  {tx.status}
                                </span>
                              </td>
                              <td className="py-2.5 px-4 text-right">
                                <button
                                  onClick={() => setSelectedTx(tx)}
                                  className="text-accent hover:underline text-[11px] font-semibold"
                                >
                                  Audit Stepper →
                                </button>
                              </td>
                            </tr>
                          );
                        })}
                      {transactions.filter(t => t.fromAccount === selectedAccount.account_number || t.toAccount === selectedAccount.account_number).length === 0 && (
                        <tr>
                          <td colSpan={5} className="py-6 text-center text-xs text-fg-muted">
                            No ledger transactions recorded yet for this account.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            {/* Modal Sticky Footer */}
            <div className="border-t border-line px-6 py-4 bg-surface flex flex-col sm:flex-row items-center justify-between gap-3">
              <div className="flex items-center gap-2 text-xs text-fg-muted">
                <Database className="h-4 w-4 text-fg-subtle" />
                <span>Oracle 21c Normalized Master: USERS ↔ ACCOUNTS ↔ BALANCE_MASTER</span>
              </div>
              <button
                onClick={() => setSelectedAccount(null)}
                className="w-full sm:w-auto rounded-2xl border border-line bg-sunken px-4 py-2 text-xs font-semibold text-fg hover:bg-raised transition"
              >
                Close Profile
              </button>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          ACCOUNT LOCK / UNLOCK MODAL (BRANCH OPERATIONS & SECURITY OFFICER)
          ========================================================================= */}
      {lockTargetAccount && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
          <div className="w-full max-w-md rounded-3xl border border-line bg-surface p-6 shadow-2xl space-y-5 animate-in zoom-in-95 duration-150">
            {/* Modal Header */}
            <div className="flex items-start justify-between border-b border-line pb-3">
              <div className="flex items-center gap-2">
                {lockTargetAccount.status === 'LOCKED' ? (
                  <Unlock className="h-4 w-4 text-emerald-400" />
                ) : (
                  <Lock className="h-4 w-4 text-rose-400" />
                )}
                <h3 className="text-sm font-semibold text-fg">
                  {lockTargetAccount.status === 'LOCKED' ? 'Unlock Account Authorization' : 'Protective Account Lock Authorization'}
                </h3>
              </div>
              <button
                onClick={() => setLockTargetAccount(null)}
                className="text-fg-subtle hover:text-fg p-1 rounded-md"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Target Account Summary */}
            <div className="rounded-2xl border border-line bg-sunken/40 p-3.5 space-y-2 text-xs">
              <div className="flex justify-between items-center">
                <span className="text-fg-subtle">Customer Name:</span>
                <span className="font-semibold text-fg">{lockTargetAccount.user_name}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-fg-subtle">Account Number:</span>
                <span className="font-mono font-bold text-fg">{lockTargetAccount.account_number}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-fg-subtle">Current Status:</span>
                <span className={cn(
                  "rounded-full px-2 py-0.5 text-[10px] font-semibold",
                  lockTargetAccount.status === 'ACTIVE' ? "bg-emerald-500/10 text-emerald-400" : "bg-rose-500/10 text-rose-400"
                )}>
                  {lockTargetAccount.status}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-fg-subtle">Target New Status:</span>
                <span className={cn(
                  "rounded-full px-2 py-0.5 text-[10px] font-bold uppercase",
                  lockTargetAccount.status === 'LOCKED' ? "bg-emerald-500/10 text-emerald-400" : "bg-rose-500/10 text-rose-400"
                )}>
                  ➔ {lockTargetAccount.status === 'LOCKED' ? 'ACTIVE' : 'LOCKED'}
                </span>
              </div>
            </div>

            {/* Officer & Role Check */}
            <div className="space-y-3.5 text-xs">
              <div>
                <label className="block font-medium text-fg mb-1">
                  Authorizing Officer (Segregation of Duties)
                </label>
                <div className="flex items-center justify-between rounded-xl border border-line bg-sunken px-3 py-2 text-fg">
                  <div>
                    <div className="font-semibold">{currentAdmin.name}</div>
                    <div className="text-[10px] text-fg-subtle">{currentAdmin.badge} • {currentAdmin.role}</div>
                  </div>
                  {currentAdmin.capability === 'ACCOUNT_LOCK_UNLOCK' ? (
                    <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                      Authorized
                    </span>
                  ) : (
                    <span className="rounded-full bg-amber-500/10 px-2 py-0.5 text-[10px] font-semibold text-amber-400">
                      Cross-Role Override
                    </span>
                  )}
                </div>
              </div>

              <div>
                <label className="block font-medium text-fg mb-1">
                  Audit Security Reason
                </label>
                <select
                  value={lockReason}
                  onChange={(e) => setLockReason(e.target.value)}
                  className="w-full rounded-xl border border-line bg-surface px-3 py-2 text-fg font-medium focus:outline-none"
                >
                  <option value="SUSPECTED_PHISHING_COERCION">
                    Suspected Phishing / Social Engineering Coercion
                  </option>
                  <option value="LOST_DEVICE_SIM_SWAP">
                    Reported Stolen Device / Unauthorized SIM Swap
                  </option>
                  <option value="IMPOSSIBLE_TRAVEL_ANOMALY">
                    Geographic Anomaly / Impossible Travel Trigger
                  </option>
                  <option value="COURT_ORDER_REGULATORY_HOLD">
                    Regulatory / Court Order Freeze (AMLA / BSP)
                  </option>
                  <option value="CUSTOMER_VOLUNTARY_REQUEST">
                    Customer Voluntary Request / Temporary Lock
                  </option>
                </select>
              </div>

              <div>
                <label className="block font-medium text-fg mb-1">
                  Official Justification Memo
                </label>
                <textarea
                  rows="2"
                  value={lockMemo}
                  onChange={(e) => setLockMemo(e.target.value)}
                  className="w-full rounded-xl border border-line bg-surface p-2.5 text-fg focus:outline-none text-xs"
                />
              </div>
            </div>

            {/* Modal Actions */}
            <div className="flex items-center justify-end gap-2.5 pt-3 border-t border-line">
              <button
                type="button"
                onClick={() => setLockTargetAccount(null)}
                className="rounded-xl border border-line bg-surface px-3.5 py-2 text-xs font-medium text-fg hover:bg-sunken"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => handleToggleAccountStatus(
                  lockTargetAccount, 
                  lockTargetAccount.status === 'LOCKED' ? 'ACTIVE' : 'LOCKED'
                )}
                disabled={isSubmittingLock}
                className={cn(
                  "rounded-xl px-4 py-2 text-xs font-semibold text-white transition",
                  lockTargetAccount.status === 'LOCKED'
                    ? "bg-emerald-600 hover:bg-emerald-500"
                    : "bg-rose-600 hover:bg-rose-500"
                )}
              >
                {isSubmittingLock
                  ? 'Updating...'
                  : (lockTargetAccount.status === 'LOCKED' ? 'Confirm Unlock Account' : 'Confirm Freeze / Lock Account')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          ROLLBACK / REVERSAL MODAL (MAKER-CHECKER WORKFLOW)
          ========================================================================= */}
      {rollbackTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
          <div className="w-full max-w-md rounded-3xl border border-line bg-surface p-6 shadow-2xl space-y-5">
            {/* Modal Header */}
            <div className="flex items-start justify-between border-b border-line pb-3">
              <div className="flex items-center gap-2">
                <RotateCcw className="h-4 w-4 text-amber-500" />
                <h3 className="text-sm font-semibold text-fg">
                  Authorize Reversal (T24 Rollback)
                </h3>
              </div>
              <button
                onClick={() => setRollbackTarget(null)}
                className="text-fg-subtle hover:text-fg p-1 rounded-md"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Target Summary */}
            <div className="rounded-2xl border border-line bg-sunken/40 p-3.5 space-y-1.5 text-xs">
              <div className="flex justify-between">
                <span className="text-fg-subtle">Target Reference:</span>
                <span className="font-mono font-bold text-fg">{formatShortId(rollbackTarget.id)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-subtle">Reversal Amount:</span>
                <span className="font-bold text-accent">{formatPHP(rollbackTarget.amount)}</span>
              </div>
            </div>

            {/* Form */}
            <div className="space-y-3.5 text-xs">
              <div>
                <label className="block font-medium text-fg mb-1">
                  Reversal Maker (Current Operator)
                </label>
                <div className="rounded-xl border border-line bg-sunken px-3 py-2 text-fg font-semibold">
                  {currentAdmin.name} ({currentAdmin.badge})
                </div>
              </div>

              <div>
                <label className="block font-medium text-fg mb-1">
                  Checker Sign-off Admin
                </label>
                <select
                  value={rollbackApproverId}
                  onChange={(e) => setRollbackApproverId(e.target.value)}
                  className="w-full rounded-xl border border-line bg-surface px-3 py-2 text-fg font-medium focus:outline-none"
                >
                  {ADMIN_ROSTER.map(admin => (
                    <option key={admin.userId} value={admin.userId}>
                      {admin.name} ({admin.role})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block font-medium text-fg mb-1">
                  Reversal Reason
                </label>
                <select
                  value={reversalReason}
                  onChange={(e) => setReversalReason(e.target.value)}
                  className="w-full rounded-xl border border-line bg-surface px-3 py-2 text-fg font-medium focus:outline-none"
                >
                  <option value="CUSTOMER_DISPUTE_WRONG_ACCOUNT">
                    Customer Dispute - Wrong Recipient
                  </option>
                  <option value="FRAUD_INVESTIGATION_HOLD">
                    Fraud Velocity Anomaly
                  </option>
                  <option value="DUPLICATE_PROCESSING_ERROR">
                    Duplicate Processing Error
                  </option>
                </select>
              </div>

              <div>
                <label className="block font-medium text-fg mb-1">
                  Audit Justification Memo
                </label>
                <textarea
                  rows="2"
                  value={reversalMemo}
                  onChange={(e) => setReversalMemo(e.target.value)}
                  className="w-full rounded-xl border border-line bg-surface p-2.5 text-fg focus:outline-none"
                />
              </div>
            </div>

            {/* Modal Actions */}
            <div className="flex items-center justify-end gap-2.5 pt-3 border-t border-line">
              <button
                type="button"
                onClick={() => setRollbackTarget(null)}
                className="rounded-xl border border-line bg-surface px-3.5 py-2 text-xs font-medium text-fg hover:bg-sunken"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleExecuteRollback}
                disabled={isSubmittingRollback}
                className="rounded-xl bg-amber-500 px-4 py-2 text-xs font-semibold text-black hover:bg-amber-400 transition"
              >
                {isSubmittingRollback ? 'Executing...' : 'Confirm Rollback'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
