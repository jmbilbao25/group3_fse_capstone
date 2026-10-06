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
  AlertOctagon
} from 'lucide-react';
import apiClient, { mockState } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { formatPHP } from '../utils/currency';
import { cn } from '../ui/cn';

// Geolocation Presets for Fraud Testing
const GEO_PRESETS = [
  {
    id: 'MNL',
    name: 'Manila, Philippines',
    lat: 14.5995,
    lon: 120.9842,
    ip: '112.198.45.10',
    type: 'SAFE',
    label: 'Normal Origin',
    desc: 'Authorized home residence in Metro Manila'
  },
  {
    id: 'LON',
    name: 'London, UK',
    lat: 51.5074,
    lon: -0.1278,
    ip: '185.86.151.11',
    type: 'FRAUD',
    label: '🚨 Impossible Travel',
    desc: '10,740 km jump within 15 mins. Triggers security hold'
  },
  {
    id: 'NYC',
    name: 'New York, USA',
    lat: 40.7128,
    lon: -74.0060,
    ip: '198.51.100.42',
    type: 'FRAUD',
    label: '🚨 Impossible Travel',
    desc: '13,670 km velocity jump. Triggers security hold'
  },
  {
    id: 'CEB',
    name: 'Cebu City, Philippines',
    lat: 10.3157,
    lon: 123.8854,
    ip: '112.198.88.22',
    type: 'SAFE',
    label: 'Domestic Flight',
    desc: 'Normal domestic transit within Philippine airspace'
  }
];

// Dual-Admin Roster (Maker-Checker segregation of duties)
const ADMIN_ROSTER = [
  {
    userId: 'usr-1006-mgr-002',
    name: 'Carlos Mendoza',
    email: 'carlos.mendoza@bank.com',
    role: 'Operations Lead (Maker)',
    badge: 'Operations Lead'
  },
  {
    userId: 'usr-1004-adm-001',
    name: 'Diana Vance',
    email: 'diana.admin@bank.com',
    role: 'Compliance & Audit Lead (Checker)',
    badge: 'Compliance Lead'
  }
];

// 7 Scam Typologies from NanoJev Qwen2.5-0.5B ONNX
const SCAM_TYPOLOGIES = [
  { key: 'investment_scam', label: 'Investment / Ponzi Fraud', pct: 38, count: 46, color: '#38BDF8' },
  { key: 'romance_scam', label: 'Romance / Emergency Aid', pct: 24, count: 29, color: '#EC4899' },
  { key: 'impersonation', label: 'Fake Official / Bank Rep', pct: 18, count: 22, color: '#A855F7' },
  { key: 'prize_or_fee_scam', label: 'Prize / Advance Fee Scam', pct: 13, count: 16, color: '#F59E0B' },
  { key: 'fake_invoice_or_selling_scam', label: 'Fake COD / Selling Scam', pct: 7, count: 8, color: '#10B981' }
];

export default function AdminExecutivePortal() {
  const { user: activeAuthUser } = useAuth();

  // Sidebar Views: 'overview' | 'transactions' | 'threat_radar' | 'geo_surveillance' | 'audit_vault' | 'sar_queue'
  const [activeView, setActiveView] = useState('overview');

  // Search & Filter State
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Active Admin Operator
  const [activeAdminId, setActiveAdminId] = useState(
    activeAuthUser?.user_id === 'usr-1006-mgr-002' ? 'usr-1006-mgr-002' : 'usr-1004-adm-001'
  );

  // Core Data States
  const [transactions, setTransactions] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [copiedId, setCopiedId] = useState(null);

  // Selected Transaction for Slide-over Detail Drawer
  const [selectedTx, setSelectedTx] = useState(null);

  // Reversal / Rollback Modal State
  const [rollbackTarget, setRollbackTarget] = useState(null);
  const [rollbackApproverId, setRollbackApproverId] = useState('usr-1004-adm-001');
  const [reversalReason, setReversalReason] = useState('CUSTOMER_DISPUTE_WRONG_ACCOUNT');
  const [reversalMemo, setReversalMemo] = useState('Customer mistakenly transferred funds to incorrect account. CSR requested reversal.');
  const [isSubmittingRollback, setIsSubmittingRollback] = useState(false);
  const [notification, setNotification] = useState(null);

  // Customer Geolocation Simulation State
  const [userLocation, setUserLocation] = useState({
    latitude: 14.5995,
    longitude: 120.9842,
    locationName: 'Manila, Philippines',
    ipAddress: '112.198.45.10'
  });
  const [isUpdatingLocation, setIsUpdatingLocation] = useState(false);

  // Active admin helper
  const currentAdmin = useMemo(() => {
    return ADMIN_ROSTER.find(a => a.userId === activeAdminId) || ADMIN_ROSTER[0];
  }, [activeAdminId]);

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
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    const timer = setInterval(loadData, 15000);
    return () => clearInterval(timer);
  }, []);

  // Set Location Preset
  const handleApplyLocation = async (preset) => {
    setIsUpdatingLocation(true);
    try {
      const payload = {
        latitude: preset.lat,
        longitude: preset.lon,
        location_name: preset.name,
        ip_address: preset.ip
      };
      await apiClient.patch('/ledger/users/usr-1001-cst-001/location', payload);
      setUserLocation({
        latitude: preset.lat,
        longitude: preset.lon,
        locationName: preset.name,
        ipAddress: preset.ip
      });
      setNotification({
        type: preset.type === 'FRAUD' ? 'alert' : 'success',
        title: preset.type === 'FRAUD' ? '🚨 Impossible Travel Simulated' : 'Location Updated',
        message: preset.type === 'FRAUD'
          ? `Customer relocated to ${preset.name}. Subsequent transfer attempts will trigger an instant security hold.`
          : `Customer baseline location restored to ${preset.name}.`
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

  // Execute Reversal / Rollback
  const handleExecuteRollback = async () => {
    if (!rollbackTarget) return;
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

  // Aggregated Stats
  const stats = useMemo(() => {
    const totalVolume = transactions.reduce((acc, t) => acc + (t.status !== 'FAILED' ? t.amount : 0), 0);
    const reversedCount = transactions.filter(t => t.status === 'REVERSED').length;
    const reversedVolume = transactions.filter(t => t.status === 'REVERSED').reduce((acc, t) => acc + t.amount, 0);
    const isAnomaly = userLocation.locationName.includes('London') || userLocation.locationName.includes('New York');

    return {
      totalVolume,
      totalCount: transactions.length,
      reversedCount,
      reversedVolume,
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
            <span className="px-3 text-[10px] font-bold uppercase tracking-wider text-fg-subtle">
              Operations Center
            </span>
            <nav className="mt-2 space-y-1">
              {[
                { id: 'overview', label: 'Overview & Telemetry', icon: BarChart3 },
                { id: 'transactions', label: 'Transactions & Reversals', icon: Layers, count: transactions.length },
                { id: 'threat_radar', label: 'Two-Stage Threat Radar', icon: Zap },
                { id: 'geo_surveillance', label: 'Geo & Device Signals', icon: Globe, alert: stats.isAnomaly },
                { id: 'audit_vault', label: 'Immutable Audit Vault', icon: Database, count: auditLogs.length },
                { id: 'sar_queue', label: 'AMLC SAR Reports', icon: FileText }
              ].map((item) => {
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
          </div>

          {/* Section: System Status */}
          <div className="rounded-2xl border border-line bg-sunken/40 p-3.5 space-y-2.5">
            <span className="text-[10px] font-bold uppercase tracking-wider text-fg-subtle block">
              Engine Health
            </span>
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
        </div>

        {/* Operator Badge at Bottom */}
        <div className="rounded-2xl border border-line bg-sunken/60 p-3">
          <div className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-accent/20 text-accent font-bold text-xs">
              {currentAdmin.name.split(' ').map(n => n[0]).join('')}
            </div>
            <div className="min-w-0 flex-1">
              <span className="truncate block text-xs font-semibold text-fg">
                {currentAdmin.name}
              </span>
              <span className="block text-[10px] text-fg-subtle">
                {currentAdmin.badge}
              </span>
            </div>
          </div>
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
            {/* Operator Switcher */}
            <div className="flex items-center gap-2 rounded-2xl border border-line bg-surface px-3 py-1.5 shadow-xs">
              <Users className="h-3.5 w-3.5 text-accent" />
              <select
                value={activeAdminId}
                onChange={(e) => {
                  setActiveAdminId(e.target.value);
                  setRollbackApproverId(ADMIN_ROSTER.find(a => a.userId !== e.target.value)?.userId || 'usr-1004-adm-001');
                }}
                className="bg-transparent text-xs font-medium text-fg focus:outline-none cursor-pointer"
              >
                {ADMIN_ROSTER.map(admin => (
                  <option key={admin.userId} value={admin.userId} className="bg-surface text-fg">
                    {admin.name} ({admin.badge})
                  </option>
                ))}
              </select>
            </div>

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
            VIEW 1: OVERVIEW & TELEMETRY (INSPIRED BY DOLAB DASHBOARD REFERENCE)
            ========================================================================= */}
        {activeView === 'overview' && (
          <div className="space-y-6 animate-fade-in">
            {/* Top Row: Hero Graph Card + Stat Cards */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Hero Wave Card (Glowing Cyan & Magenta Curves from Reference Image) */}
              <div className="lg:col-span-2 rounded-3xl border border-line bg-surface p-6 shadow-xs relative overflow-hidden flex flex-col justify-between">
                {/* Background Glow */}
                <div className="absolute top-0 right-0 -mt-10 -mr-10 h-64 w-64 rounded-full bg-accent/10 blur-3xl pointer-events-none" />

                <div>
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="text-xs font-medium text-fg-muted">Total Settled Volume & Velocity</span>
                      <div className="mt-1 text-2xl font-bold tracking-tight text-fg">
                        {formatPHP(stats.totalVolume)}
                      </div>
                    </div>

                    <div className="flex items-center gap-3">
                      <div className="flex items-center gap-1.5 text-xs text-accent">
                        <span className="h-2 w-2 rounded-full bg-accent" />
                        <span>Settled Transfers</span>
                      </div>
                      <div className="flex items-center gap-1.5 text-xs text-rose-400">
                        <span className="h-2 w-2 rounded-full bg-rose-400" />
                        <span>Threat Outflow</span>
                      </div>
                    </div>
                  </div>

                  {/* SVG Wave Visualization (Dolab Style Curved Lines) */}
                  <div className="relative mt-6 h-40 w-full flex items-end">
                    <svg viewBox="0 0 500 150" className="w-full h-full overflow-visible">
                      <defs>
                        <linearGradient id="cyanGrad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#38BDF8" stopOpacity="0.4" />
                          <stop offset="100%" stopColor="#38BDF8" stopOpacity="0.0" />
                        </linearGradient>
                        <linearGradient id="pinkGrad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#EC4899" stopOpacity="0.3" />
                          <stop offset="100%" stopColor="#EC4899" stopOpacity="0.0" />
                        </linearGradient>
                      </defs>

                      {/* Cyan Wave Path */}
                      <path
                        d="M 0,110 Q 70,120 125,75 T 250,50 T 375,90 T 500,30 L 500,150 L 0,150 Z"
                        fill="url(#cyanGrad)"
                      />
                      <path
                        d="M 0,110 Q 70,120 125,75 T 250,50 T 375,90 T 500,30"
                        fill="none"
                        stroke="#38BDF8"
                        strokeWidth="3"
                      />

                      {/* Magenta Threat Wave Path */}
                      <path
                        d="M 0,130 Q 70,135 125,110 T 250,90 T 375,120 T 500,80 L 500,150 L 0,150 Z"
                        fill="url(#pinkGrad)"
                      />
                      <path
                        d="M 0,130 Q 70,135 125,110 T 250,90 T 375,120 T 500,80"
                        fill="none"
                        stroke="#EC4899"
                        strokeWidth="2.5"
                      />
                    </svg>
                  </div>
                </div>

                <div className="flex items-center justify-between border-t border-line/60 pt-4 text-xs text-fg-subtle">
                  <span>Mon</span>
                  <span>Tue</span>
                  <span>Wed</span>
                  <span>Thu</span>
                  <span>Fri</span>
                  <span>Sat</span>
                  <span>Today (Peak 14:00)</span>
                </div>
              </div>

              {/* Right Side Stat Cards (Dolab Inspired Mini-Cards) */}
              <div className="space-y-4 flex flex-col justify-between">
                {/* Card 1: Reversals Restored */}
                <div className="rounded-3xl border border-line bg-surface p-5 shadow-xs">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-medium text-fg-muted">Rollbacks Executed</span>
                    <span className="rounded-xl bg-amber-500/10 p-2 text-amber-500">
                      <RotateCcw className="h-4 w-4" />
                    </span>
                  </div>
                  <div className="mt-2 text-2xl font-bold tracking-tight text-fg">
                    {stats.reversedCount}
                  </div>
                  <span className="mt-1 block text-xs text-fg-subtle">
                    {formatPHP(stats.reversedVolume)} restored to source accounts
                  </span>
                </div>

                {/* Card 2: Scam Typology Pressure Gauge */}
                <div className="rounded-3xl border border-line bg-surface p-5 shadow-xs">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-medium text-fg-muted">Typology Friction</span>
                    <div className="flex h-9 w-9 items-center justify-center rounded-full bg-accent/10 text-xs font-bold text-accent">
                      38%
                    </div>
                  </div>
                  <div className="mt-1 text-base font-bold text-fg">
                    Medium Friction Tier
                  </div>
                  <span className="mt-1 block text-xs text-fg-subtle">
                    Threshold: $\theta_{'{'}med{'}'} = 0.35$ (NanoJev calibrated)
                  </span>
                </div>

                {/* Card 3: Latin Biometric Zero-OTP Compliance */}
                <div className="rounded-3xl border border-line bg-surface p-5 shadow-xs">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-medium text-fg-muted">BSP Cir. 1213 Auth</span>
                    <span className="rounded-xl bg-emerald-500/10 p-2 text-emerald-400">
                      <Fingerprint className="h-4 w-4" />
                    </span>
                  </div>
                  <div className="mt-1 text-base font-bold text-emerald-400">
                    100% Zero SMS OTP
                  </div>
                  <span className="mt-1 block text-xs text-fg-subtle">
                    Primary device hardware biometrics only
                  </span>
                </div>
              </div>
            </div>

            {/* Middle Row: Scam Typology Distribution + Two-Stage Telemetry + Device Surveillance */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Donut Chart: 7 Scam Typologies */}
              <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs">
                <div className="flex items-center justify-between border-b border-line pb-3">
                  <div className="flex items-center gap-2">
                    <PieChartIcon className="h-4 w-4 text-accent" />
                    <h3 className="text-sm font-semibold text-fg">Scam Typology Mix</h3>
                  </div>
                  <span className="text-[11px] text-fg-subtle font-mono">NanoJev ONNX</span>
                </div>

                {/* Circular Donut Display */}
                <div className="mt-6 flex items-center justify-center">
                  <div className="relative flex h-36 w-36 items-center justify-center">
                    <svg viewBox="0 0 36 36" className="h-full w-full rotate-[-90deg]">
                      {/* Circle slices */}
                      <circle cx="18" cy="18" r="14" fill="none" stroke="#1E293B" strokeWidth="4" />
                      <circle cx="18" cy="18" r="14" fill="none" stroke="#38BDF8" strokeWidth="4" strokeDasharray="38 100" strokeDashoffset="0" />
                      <circle cx="18" cy="18" r="14" fill="none" stroke="#EC4899" strokeWidth="4" strokeDasharray="24 100" strokeDashoffset="-38" />
                      <circle cx="18" cy="18" r="14" fill="none" stroke="#A855F7" strokeWidth="4" strokeDasharray="18 100" strokeDashoffset="-62" />
                      <circle cx="18" cy="18" r="14" fill="none" stroke="#F59E0B" strokeWidth="4" strokeDasharray="13 100" strokeDashoffset="-80" />
                    </svg>
                    <div className="absolute text-center">
                      <span className="text-lg font-bold text-fg">121</span>
                      <span className="block text-[10px] text-fg-subtle">Threat Memos</span>
                    </div>
                  </div>
                </div>

                {/* Legend */}
                <div className="mt-4 space-y-2 text-xs">
                  {SCAM_TYPOLOGIES.slice(0, 4).map((item) => (
                    <div key={item.key} className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="h-2 w-2 rounded-full" style={{ backgroundColor: item.color }} />
                        <span className="text-fg-muted truncate max-w-[150px]">{item.label}</span>
                      </div>
                      <span className="font-mono font-semibold text-fg">{item.pct}%</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Two-Stage Architecture Latency & Gate 0 */}
              <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between border-b border-line pb-3">
                    <div className="flex items-center gap-2">
                      <Cpu className="h-4 w-4 text-accent" />
                      <h3 className="text-sm font-semibold text-fg">Two-Stage Latency Budget</h3>
                    </div>
                    <span className="text-[11px] text-emerald-400 font-semibold font-mono">P99 Clear</span>
                  </div>

                  <div className="mt-4 space-y-4">
                    {/* Stage A */}
                    <div>
                      <div className="flex justify-between text-xs mb-1">
                        <span className="font-semibold text-fg">Stage A: Sync S2 XGBoost</span>
                        <span className="font-mono text-emerald-400">28 ms / 200 ms max</span>
                      </div>
                      <div className="h-2 w-full rounded-full bg-sunken overflow-hidden">
                        <div className="h-full bg-emerald-400 rounded-full" style={{ width: '14%' }} />
                      </div>
                      <span className="text-[10px] text-fg-subtle mt-0.5 block">
                        Gate 0 velocity + tabular balance drain inference
                      </span>
                    </div>

                    {/* Stage B */}
                    <div>
                      <div className="flex justify-between text-xs mb-1">
                        <span className="font-semibold text-fg">Stage B: Bounded NanoJev</span>
                        <span className="font-mono text-accent">220 ms / 1,500 ms max</span>
                      </div>
                      <div className="h-2 w-full rounded-full bg-sunken overflow-hidden">
                        <div className="h-full bg-accent rounded-full" style={{ width: '15%' }} />
                      </div>
                      <span className="text-[10px] text-fg-subtle mt-0.5 block">
                        Unstructured memo & device coercion threat synthesis
                      </span>
                    </div>

                    {/* Escalate Invariant */}
                    <div className="rounded-2xl border border-line bg-sunken/40 p-3 text-xs">
                      <div className="flex items-center gap-1.5 font-semibold text-fg">
                        <ShieldCheck className="h-3.5 w-3.5 text-accent" />
                        <span>Escalate-Only Safety Invariant</span>
                      </div>
                      <p className="mt-1 text-[11px] text-fg-muted">
                        $RiskTier(final) \ge RiskTier(a_0)$. NanoJev can never downgrade a Block decision.
                      </p>
                    </div>
                  </div>
                </div>

                <div className="pt-3 border-t border-line text-[11px] text-fg-subtle flex justify-between">
                  <span>Adversarial Injection Invariance:</span>
                  <strong className="text-emerald-400 font-mono">100% (60/60 attacks)</strong>
                </div>
              </div>

              {/* Device Threat Telemetry Surveillance */}
              <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between border-b border-line pb-3">
                    <div className="flex items-center gap-2">
                      <Radio className="h-4 w-4 text-accent" />
                      <h3 className="text-sm font-semibold text-fg">Device Coercion Signals</h3>
                    </div>
                    <span className="text-[11px] text-fg-subtle">Real-Time Telemetry</span>
                  </div>

                  <div className="mt-4 space-y-3">
                    <div className="flex items-center justify-between rounded-2xl border border-line bg-sunken/40 p-3">
                      <div className="flex items-center gap-2.5">
                        <ScreenShare className="h-4 w-4 text-rose-400" />
                        <div>
                          <strong className="text-xs font-semibold text-fg block">Remote Access (RAT)</strong>
                          <span className="text-[10px] text-fg-subtle">AnyDesk / TeamViewer Active</span>
                        </div>
                      </div>
                      <span className="rounded-full bg-rose-500/10 px-2 py-0.5 text-[10px] font-semibold text-rose-400">
                        High Threat
                      </span>
                    </div>

                    <div className="flex items-center justify-between rounded-2xl border border-line bg-sunken/40 p-3">
                      <div className="flex items-center gap-2.5">
                        <PhoneCall className="h-4 w-4 text-amber-400" />
                        <div>
                          <strong className="text-xs font-semibold text-fg block">Active Call (Vishing)</strong>
                          <span className="text-[10px] text-fg-subtle">Coercion during transfer</span>
                        </div>
                      </div>
                      <span className="rounded-full bg-amber-500/10 px-2 py-0.5 text-[10px] font-semibold text-amber-400">
                        Cooldown 10m
                      </span>
                    </div>

                    <div className="flex items-center justify-between rounded-2xl border border-line bg-sunken/40 p-3">
                      <div className="flex items-center gap-2.5">
                        <AlertOctagon className="h-4 w-4 text-emerald-400" />
                        <div>
                          <strong className="text-xs font-semibold text-fg block">Root / Hooking Shield</strong>
                          <span className="text-[10px] text-fg-subtle">Frida / Xposed / Tamper</span>
                        </div>
                      </div>
                      <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                        Blocked (Gate 0)
                      </span>
                    </div>
                  </div>
                </div>

                <div className="pt-3 border-t border-line text-[11px] text-fg-subtle">
                  Telemetry hooked directly into Transfer Orchestrator state.
                </div>
              </div>
            </div>

            {/* Bottom Row: Recent Transaction Journal Preview */}
            <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-semibold text-fg">Live Transaction Ledger</h3>
                  <p className="text-xs text-fg-muted">Recent transfers with dual-admin rollback and audit inspection</p>
                </div>
                <button
                  onClick={() => setActiveView('transactions')}
                  className="text-xs font-semibold text-accent hover:underline flex items-center gap-1"
                >
                  <span>View all {transactions.length} transfers</span>
                  <ChevronRight className="h-3 w-3" />
                </button>
              </div>

              {/* Mini Table */}
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead>
                    <tr className="border-b border-line text-[11px] text-fg-subtle font-semibold uppercase">
                      <th className="py-2.5 px-3">Reference</th>
                      <th className="py-2.5 px-3">Route</th>
                      <th className="py-2.5 px-3 text-right">Amount</th>
                      <th className="py-2.5 px-3 text-center">Status</th>
                      <th className="py-2.5 px-3">Audit / Sign-off</th>
                      <th className="py-2.5 px-3 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line/60">
                    {transactions.slice(0, 5).map((tx) => (
                      <tr 
                        key={tx.id}
                        onClick={() => setSelectedTx(tx)}
                        className="cursor-pointer hover:bg-sunken/40 transition"
                      >
                        <td className="py-3 px-3 font-mono font-medium text-fg">
                          {formatShortId(tx.id)}
                        </td>
                        <td className="py-3 px-3 text-fg">
                          Juan Dela Cruz ➔ Maria Reyes
                        </td>
                        <td className="py-3 px-3 text-right font-semibold text-fg">
                          {formatPHP(tx.amount)}
                        </td>
                        <td className="py-3 px-3 text-center">
                          <span className={cn(
                            "rounded-full px-2.5 py-0.5 text-[10px] font-semibold",
                            tx.status === 'REVERSED' && "bg-rose-500/10 text-rose-400",
                            (tx.status === 'COMMITTED' || tx.status === 'POSTED') && "bg-emerald-500/10 text-emerald-400",
                            tx.status === 'PENDING_APPROVAL' && "bg-amber-500/10 text-amber-400"
                          )}>
                            {tx.status}
                          </span>
                        </td>
                        <td className="py-3 px-3 text-fg-muted">
                          {tx.status === 'REVERSED' ? (
                            <span className="text-rose-400 font-medium">Reversed by {tx.reversedBy === 'usr-1006-mgr-002' ? 'Carlos M.' : 'Diana V.'}</span>
                          ) : (
                            <span>{tx.approvedBy ? `Approved: ${tx.approvedBy === 'usr-1004-adm-001' ? 'Diana V.' : 'Carlos M.'}` : 'Auto-Settled'}</span>
                          )}
                        </td>
                        <td className="py-3 px-3 text-right">
                          {(tx.status === 'COMMITTED' || tx.status === 'POSTED') && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setRollbackTarget(tx);
                              }}
                              className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-2 py-0.5 text-[11px] font-medium text-amber-400 hover:bg-amber-500/20"
                            >
                              Rollback
                            </button>
                          )}
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
            VIEW 2: TRANSACTIONS & REVERSALS (FULL DETAILED JOURNAL)
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
                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    setRollbackTarget(tx);
                                  }}
                                  className="rounded-xl border border-amber-500/30 bg-amber-500/10 px-3 py-1 text-xs font-semibold text-amber-400 hover:bg-amber-500/20 transition shadow-xs"
                                >
                                  Rollback
                                </button>
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
              <div className="flex items-center gap-2">
                <Zap className="h-5 w-5 text-accent" />
                <h2 className="text-base font-semibold text-fg">
                  Two-Stage Threat Radar: NanoJev Scam Typology & Invariants
                </h2>
              </div>
              <p className="mt-1 text-xs text-fg-muted max-w-3xl">
                The risk engine splits evaluation into <strong>Stage A</strong> (Deterministic Gate 0 rules + XGBoost S2 tabular scoring in &lt; 30ms) 
                and <strong>Stage B</strong> (NanoJev Qwen2.5-0.5B ONNX bounded to 1500ms). When a memo contains social engineering coercion, NanoJev categorizes the threat into 7 calibrated typologies.
              </p>
            </div>

            {/* 7 Typology Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {SCAM_TYPOLOGIES.map((typology) => (
                <div key={typology.key} className="rounded-3xl border border-line bg-surface p-5 shadow-xs space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-fg">{typology.label}</span>
                    <span className="font-mono text-xs font-bold" style={{ color: typology.color }}>
                      {typology.pct}%
                    </span>
                  </div>
                  <div className="h-2 w-full rounded-full bg-sunken overflow-hidden">
                    <div className="h-full rounded-full" style={{ width: `${typology.pct}%`, backgroundColor: typology.color }} />
                  </div>
                  <div className="flex items-center justify-between text-[11px] text-fg-subtle pt-1">
                    <span>{typology.count} simulated incidents</span>
                    <span className="text-accent font-semibold">Friction: {typology.pct > 20 ? 'HIGH (Hold)' : 'MEDIUM'}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* =========================================================================
            VIEW 4: CUSTOMER GEOLOCATION SURVEILLANCE
            ========================================================================= */}
        {activeView === 'geo_surveillance' && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 animate-fade-in">
            {/* Left Card: Customer Location Control */}
            <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs space-y-6">
              <div>
                <div className="flex items-center gap-2">
                  <Globe className="h-4 w-4 text-accent" />
                  <h2 className="text-base font-semibold text-fg">
                    Customer Geolocation Control
                  </h2>
                </div>
                <p className="mt-1 text-xs text-fg-muted">
                  Simulate geographic jumps for <strong>Juan Dela Cruz</strong>. Relocating to London or New York triggers the Impossible Travel velocity rule and places transactions on security hold.
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
                <span className="text-xs font-semibold text-fg-subtle block">
                  Select Simulation Vector
                </span>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {GEO_PRESETS.map((preset) => (
                    <button
                      key={preset.id}
                      onClick={() => handleApplyLocation(preset)}
                      disabled={isUpdatingLocation}
                      className={cn(
                        "flex flex-col text-left rounded-2xl border p-3.5 transition shadow-xs",
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

            {/* Right Card: Radar & Customer Notice Preview */}
            <div className="space-y-6">
              <div className="rounded-3xl border border-line bg-surface p-6 shadow-xs">
                <div className="flex items-center justify-between border-b border-line pb-3">
                  <div className="flex items-center gap-2">
                    <MapPin className="h-4 w-4 text-accent" />
                    <h3 className="text-sm font-semibold text-fg">Geodetic Velocity Radar</h3>
                  </div>
                  <span className="text-xs text-fg-subtle font-mono">Haversine Metric</span>
                </div>

                {/* Map Canvas Graphic */}
                <div className="relative mt-4 h-48 rounded-2xl border border-line bg-sunken/40 flex items-center justify-center overflow-hidden">
                  <div className="absolute inset-0 bg-[linear-gradient(to_right,#8080800f_1px,transparent_1px),linear-gradient(to_bottom,#8080800f_1px,transparent_1px)] bg-[size:20px_20px]" />

                  {/* Point 1: Manila */}
                  <div className="absolute left-[65%] top-[55%] flex flex-col items-center">
                    <span className="h-6 w-6 rounded-full bg-emerald-500 text-black flex items-center justify-center text-xs font-bold shadow-md">
                      1
                    </span>
                    <span className="mt-1 text-[10px] font-semibold text-fg bg-surface px-1.5 py-0.5 rounded-lg border border-line shadow-xs">
                      Manila
                    </span>
                  </div>

                  {/* Point 2: Anomaly Point */}
                  {stats.isAnomaly && (
                    <>
                      <div className="absolute left-[25%] top-[25%] flex flex-col items-center animate-bounce">
                        <span className="h-7 w-7 rounded-full bg-rose-500 text-white flex items-center justify-center text-xs font-bold shadow-lg ring-4 ring-rose-500/30">
                          2
                        </span>
                        <span className="mt-1 text-[10px] font-bold text-rose-400 bg-surface px-2 py-0.5 rounded-lg border border-rose-500/30 shadow-xs">
                          {userLocation.locationName.split(',')[0]}
                        </span>
                      </div>

                      <svg className="absolute inset-0 h-full w-full pointer-events-none">
                        <line x1="65%" y1="55%" x2="25%" y2="25%" stroke="#f43f5e" strokeWidth="2" strokeDasharray="4 4" />
                      </svg>
                    </>
                  )}

                  {!stats.isAnomaly && (
                    <div className="text-xs text-fg-muted flex items-center gap-1.5">
                      <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                      <span>User origin matches Manila. No velocity anomalies.</span>
                    </div>
                  )}
                </div>
              </div>

              {/* Customer Notice Preview */}
              <div className="rounded-3xl border border-amber-500/30 bg-amber-500/5 p-5 shadow-xs">
                <div className="flex items-center gap-2 text-xs font-semibold text-amber-300">
                  <ShieldAlert className="h-4 w-4" />
                  <span>Customer Warning Notice (Shown on held transfers)</span>
                </div>
                <p className="mt-2 text-xs text-fg-muted leading-relaxed">
                  <strong>"Security Notice: Transaction Temporarily Held"</strong><br />
                  We detected unusual activity from a new location. To protect your funds, this transfer was stopped and your account has been placed on a temporary security hold. If this was you, please verify your identity via Face/2FA or contact Customer Support.
                </p>
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
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 sm:p-6 animate-in fade-in duration-200">
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
                {(selectedTx.status === 'COMMITTED' || selectedTx.status === 'POSTED' || selectedTx.status === 'SETTLED') && (
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
          ROLLBACK / REVERSAL MODAL (MAKER-CHECKER WORKFLOW)
          ========================================================================= */}
      {rollbackTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-xs p-4 animate-in fade-in duration-200">
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
