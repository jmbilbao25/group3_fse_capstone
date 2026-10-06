import React, { useState, useEffect, useMemo } from 'react';
import { 
  ShieldCheck, 
  ShieldAlert, 
  RotateCcw, 
  CheckCircle2, 
  Clock, 
  Search, 
  Filter, 
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
  ExternalLink,
  Shield,
  ArrowUpRight
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
    desc: '10,740 km jump within minutes. Triggers security hold'
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
    badge: 'Operations'
  },
  {
    userId: 'usr-1004-adm-001',
    name: 'Diana Vance',
    email: 'diana.admin@bank.com',
    role: 'Compliance & Audit Lead (Checker)',
    badge: 'Compliance'
  }
];

export default function AdminExecutivePortal() {
  const { user: activeAuthUser } = useAuth();

  // Active Navigation Tab: 'transactions' | 'georadar' | 'auditvault'
  const [activeTab, setActiveTab] = useState('transactions');

  // Search & Filter State
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Active Admin Operator State
  const [activeAdminId, setActiveAdminId] = useState(
    activeAuthUser?.user_id === 'usr-1006-mgr-002' ? 'usr-1006-mgr-002' : 'usr-1004-adm-001'
  );

  // Core Data States
  const [transactions, setTransactions] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [lastRefreshed, setLastRefreshed] = useState(new Date());
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

      setLastRefreshed(new Date());
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
    <div className="space-y-8 animate-fade-in pb-12">
      {/* =========================================================================
          1. CLEAN RELAXED HEADER WITH OPERATOR & METRICS STRIP
          ========================================================================= */}
      <div className="flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-full bg-emerald-500 ring-4 ring-emerald-500/20" />
            <span className="text-xs font-medium tracking-wide uppercase text-fg-subtle">
              Operations & Governance
            </span>
          </div>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-fg">
            Ledger & Fraud Console
          </h1>
        </div>

        {/* Action Controls & Active Admin */}
        <div className="flex items-center gap-3">
          {/* Admin Switcher */}
          <div className="flex items-center gap-2.5 rounded-xl border border-line bg-surface px-3 py-1.5 shadow-xs">
            <Users className="h-4 w-4 text-accent" />
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

          {/* Sync Button */}
          <button
            onClick={loadData}
            disabled={isLoading}
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-line bg-surface text-fg-muted hover:text-fg hover:bg-sunken transition shadow-xs"
            title="Refresh Ledger Data"
          >
            <RefreshCw className={cn("h-4 w-4", isLoading && "animate-spin text-accent")} />
          </button>
        </div>
      </div>

      {/* =========================================================================
          2. MINIMALIST METRIC STRIP (LIGHT, SPACIOUS, ZERO CLUTTER)
          ========================================================================= */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {/* Metric 1 */}
        <div className="rounded-2xl border border-line bg-surface p-5 shadow-xs transition hover:border-line-strong">
          <span className="text-xs font-medium text-fg-muted">Settled Volume</span>
          <div className="mt-2 text-xl font-bold tracking-tight text-fg">
            {formatPHP(stats.totalVolume)}
          </div>
          <span className="mt-1 block text-xs text-fg-subtle">
            {stats.totalCount} transactions logged
          </span>
        </div>

        {/* Metric 2 */}
        <div className="rounded-2xl border border-line bg-surface p-5 shadow-xs transition hover:border-line-strong">
          <span className="text-xs font-medium text-fg-muted">Rollbacks Executed</span>
          <div className="mt-2 text-xl font-bold tracking-tight text-fg">
            {stats.reversedCount}
          </div>
          <span className="mt-1 block text-xs text-fg-subtle">
            {formatPHP(stats.reversedVolume)} restored
          </span>
        </div>

        {/* Metric 3 */}
        <div className="rounded-2xl border border-line bg-surface p-5 shadow-xs transition hover:border-line-strong">
          <span className="text-xs font-medium text-fg-muted">Customer Origin</span>
          <div className="mt-2 flex items-center gap-2">
            <span className="truncate text-base font-semibold text-fg">
              {userLocation.locationName.split(',')[0]}
            </span>
            {stats.isAnomaly && (
              <span className="rounded-full bg-rose-500/10 px-2 py-0.5 text-[10px] font-semibold text-rose-400">
                Flagged
              </span>
            )}
          </div>
          <span className="mt-1 block text-xs text-fg-subtle truncate">
            Juan Dela Cruz
          </span>
        </div>

        {/* Metric 4 */}
        <div className="rounded-2xl border border-line bg-surface p-5 shadow-xs transition hover:border-line-strong">
          <span className="text-xs font-medium text-fg-muted">Audit Vault</span>
          <div className="mt-2 flex items-center gap-1.5 text-xl font-bold text-emerald-400">
            <ShieldCheck className="h-5 w-5" />
            <span>Immutable</span>
          </div>
          <span className="mt-1 block text-xs text-fg-subtle">
            WORM trigger active
          </span>
        </div>
      </div>

      {/* =========================================================================
          NOTIFICATION BANNER (SUBTLE & DISMISSIBLE)
          ========================================================================= */}
      {notification && (
        <div className={cn(
          "flex items-center justify-between rounded-xl border p-4 text-xs shadow-xs animate-fade-in",
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
              <span className="opacity-90">{notification.message}</span>
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
          3. CLEAN TAB NAVIGATION (CONCISE, NO WALL OF TEXT)
          ========================================================================= */}
      <div className="flex items-center gap-2 border-b border-line pb-px">
        <button
          onClick={() => setActiveTab('transactions')}
          className={cn(
            "flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-medium transition",
            activeTab === 'transactions'
              ? "border-accent text-accent font-semibold"
              : "border-transparent text-fg-muted hover:text-fg"
          )}
        >
          <span>Transactions</span>
          <span className="rounded-full bg-sunken px-2 py-0.5 text-xs text-fg-subtle">
            {transactions.length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('georadar')}
          className={cn(
            "flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-medium transition",
            activeTab === 'georadar'
              ? "border-accent text-accent font-semibold"
              : "border-transparent text-fg-muted hover:text-fg"
          )}
        >
          <span>Geolocation & Fraud</span>
          {stats.isAnomaly && (
            <span className="h-2 w-2 rounded-full bg-rose-500 animate-pulse" />
          )}
        </button>

        <button
          onClick={() => setActiveTab('auditvault')}
          className={cn(
            "flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-medium transition",
            activeTab === 'auditvault'
              ? "border-accent text-accent font-semibold"
              : "border-transparent text-fg-muted hover:text-fg"
          )}
        >
          <span>Audit Vault</span>
          <span className="rounded-full bg-sunken px-2 py-0.5 text-xs text-fg-subtle">
            {auditLogs.length}
          </span>
        </button>
      </div>

      {/* =========================================================================
          TAB 1: TRANSACTIONS & REVERSAL JOURNAL
          ========================================================================= */}
      {activeTab === 'transactions' && (
        <div className="space-y-4">
          {/* Search & Filter Bar */}
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <div className="relative flex-1 max-w-sm">
              <Search className="pointer-events-none absolute left-3.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-fg-subtle" />
              <input
                type="text"
                placeholder="Search reference, account, or amount..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="h-10 w-full rounded-xl border border-line bg-surface pl-9 pr-4 text-xs text-fg placeholder:text-fg-subtle focus:border-accent focus:outline-none transition shadow-xs"
              />
            </div>

            <div className="flex items-center gap-1.5 self-start sm:self-auto">
              {['ALL', 'SETTLED', 'REVERSED', 'REVIEW'].map((status) => (
                <button
                  key={status}
                  onClick={() => setStatusFilter(status)}
                  className={cn(
                    "rounded-lg px-3 py-1.5 text-xs font-medium transition",
                    statusFilter === status
                      ? "bg-sunken text-fg font-semibold shadow-xs border border-line"
                      : "text-fg-muted hover:text-fg"
                  )}
                >
                  {status === 'ALL' ? 'All' : status === 'SETTLED' ? 'Settled' : status === 'REVERSED' ? 'Reversed' : 'Review'}
                </button>
              ))}
            </div>
          </div>

          {/* Spacious Table */}
          <div className="overflow-hidden rounded-2xl border border-line bg-surface shadow-xs">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-line bg-sunken/40 text-[11px] font-semibold uppercase tracking-wider text-fg-subtle">
                    <th className="py-3.5 px-6">Reference</th>
                    <th className="py-3.5 px-6">Transfer Route</th>
                    <th className="py-3.5 px-6 text-right">Amount</th>
                    <th className="py-3.5 px-6 text-center">Status</th>
                    <th className="py-3.5 px-6">Sign-off</th>
                    <th className="py-3.5 px-6 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line text-xs">
                  {filteredTransactions.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="py-16 text-center text-fg-muted">
                        No transactions found matching criteria.
                      </td>
                    </tr>
                  ) : (
                    filteredTransactions.map((tx) => {
                      const isReversed = tx.status === 'REVERSED';
                      const isCommitted = tx.status === 'COMMITTED' || tx.status === 'POSTED' || tx.status === 'SETTLED';

                      return (
                        <tr 
                          key={tx.id}
                          onClick={() => setSelectedTx(tx)}
                          className="group cursor-pointer transition hover:bg-sunken/50"
                        >
                          {/* Reference & Time */}
                          <td className="py-4 px-6 font-mono">
                            <div className="flex items-center gap-1.5">
                              <span className="font-semibold text-fg">
                                {formatShortId(tx.id)}
                              </span>
                              <button
                                onClick={(e) => handleCopy(tx.id, tx.id, e)}
                                className="opacity-0 group-hover:opacity-100 text-fg-subtle hover:text-fg transition p-0.5"
                                title="Copy full ID"
                              >
                                {copiedId === tx.id ? (
                                  <Check className="h-3 w-3 text-emerald-400" />
                                ) : (
                                  <Copy className="h-3 w-3" />
                                )}
                              </button>
                            </div>
                            <span className="block text-[11px] font-sans text-fg-subtle mt-0.5">
                              {new Date(tx.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </span>
                          </td>

                          {/* Route */}
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

                          {/* Amount */}
                          <td className="py-4 px-6 text-right font-medium text-fg">
                            <span className="text-sm font-semibold">{formatPHP(tx.amount)}</span>
                          </td>

                          {/* Status Badge */}
                          <td className="py-4 px-6 text-center">
                            {isReversed && (
                              <span className="inline-flex items-center gap-1 rounded-full bg-rose-500/10 px-2.5 py-0.5 text-[11px] font-medium text-rose-400">
                                <RotateCcw className="h-3 w-3" />
                                Reversed
                              </span>
                            )}
                            {isCommitted && (
                              <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/10 px-2.5 py-0.5 text-[11px] font-medium text-emerald-400">
                                <CheckCircle2 className="h-3 w-3" />
                                Settled
                              </span>
                            )}
                            {tx.status === 'PENDING_APPROVAL' && (
                              <span className="inline-flex items-center gap-1 rounded-full bg-amber-500/10 px-2.5 py-0.5 text-[11px] font-medium text-amber-400">
                                <Clock className="h-3 w-3" />
                                Review
                              </span>
                            )}
                            {tx.status === 'HELD_FRAUD' && (
                              <span className="inline-flex items-center gap-1 rounded-full bg-rose-500/10 px-2.5 py-0.5 text-[11px] font-medium text-rose-400">
                                <ShieldAlert className="h-3 w-3" />
                                Held
                              </span>
                            )}
                          </td>

                          {/* Audit Info */}
                          <td className="py-4 px-6 text-fg-muted">
                            {isReversed ? (
                              <span className="text-rose-400 text-xs font-medium">
                                Reversed ({tx.reversedBy === 'usr-1006-mgr-002' ? 'Carlos M.' : 'Diana V.'})
                              </span>
                            ) : tx.approvedBy ? (
                              <span className="text-xs text-fg">
                                {tx.approvedBy === 'usr-1004-adm-001' ? 'Diana V.' : 'Carlos M.'}
                              </span>
                            ) : (
                              <span className="text-xs text-fg-subtle">
                                Auto-settled
                              </span>
                            )}
                          </td>

                          {/* Actions */}
                          <td className="py-4 px-6 text-right">
                            <div className="flex items-center justify-end gap-2">
                              {isCommitted && (
                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    setRollbackTarget(tx);
                                  }}
                                  className="rounded-lg border border-line bg-surface px-2.5 py-1 text-xs font-medium text-amber-400 hover:bg-amber-500/10 hover:border-amber-500/30 transition shadow-xs"
                                >
                                  Rollback
                                </button>
                              )}
                              <ChevronRight className="h-4 w-4 text-fg-subtle group-hover:text-fg group-hover:translate-x-0.5 transition" />
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          TAB 2: CUSTOMER GEOLOCATION & FRAUD RADAR
          ========================================================================= */}
      {activeTab === 'georadar' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left Card: Customer Location Control */}
          <div className="rounded-2xl border border-line bg-surface p-6 shadow-xs space-y-6">
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
            <div className="rounded-xl border border-line bg-sunken/40 p-4">
              <span className="text-[10px] font-semibold uppercase tracking-wider text-fg-subtle block">
                Active Database Coordinates
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
                      "flex flex-col text-left rounded-xl border p-3.5 transition shadow-xs",
                      preset.type === 'FRAUD' 
                        ? "border-rose-500/30 bg-rose-500/5 hover:bg-rose-500/10" 
                        : "border-line bg-surface hover:bg-sunken",
                      userLocation.locationName.includes(preset.name.split(',')[0]) && "ring-2 ring-accent"
                    )}
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-fg">{preset.name}</span>
                      <span className={cn(
                        "text-[10px] font-semibold px-1.5 py-0.5 rounded",
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
            <div className="rounded-2xl border border-line bg-surface p-6 shadow-xs">
              <div className="flex items-center justify-between border-b border-line pb-3">
                <div className="flex items-center gap-2">
                  <MapPin className="h-4 w-4 text-accent" />
                  <h3 className="text-sm font-semibold text-fg">Geodetic Velocity Radar</h3>
                </div>
                <span className="text-xs text-fg-subtle font-mono">Haversine Metric</span>
              </div>

              {/* Map Canvas Graphic */}
              <div className="relative mt-4 h-48 rounded-xl border border-line bg-sunken/40 flex items-center justify-center overflow-hidden">
                <div className="absolute inset-0 bg-[linear-gradient(to_right,#8080800f_1px,transparent_1px),linear-gradient(to_bottom,#8080800f_1px,transparent_1px)] bg-[size:20px_20px]" />

                {/* Point 1: Manila */}
                <div className="absolute left-[65%] top-[55%] flex flex-col items-center">
                  <span className="h-6 w-6 rounded-full bg-emerald-500 text-black flex items-center justify-center text-xs font-bold shadow-md">
                    1
                  </span>
                  <span className="mt-1 text-[10px] font-semibold text-fg bg-surface px-1.5 py-0.5 rounded border border-line shadow-xs">
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
                      <span className="mt-1 text-[10px] font-bold text-rose-400 bg-surface px-2 py-0.5 rounded border border-rose-500/30 shadow-xs">
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
            <div className="rounded-2xl border border-amber-500/30 bg-amber-500/5 p-5 shadow-xs">
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
          TAB 3: IMMUTABLE AUDIT VAULT
          ========================================================================= */}
      {activeTab === 'auditvault' && (
        <div className="overflow-hidden rounded-2xl border border-line bg-surface shadow-xs">
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
                {auditLogs.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="py-16 text-center text-fg-muted font-sans">
                      No audit records available in vault.
                    </td>
                  </tr>
                ) : (
                  auditLogs.map((log) => {
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
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* =========================================================================
          SLIDE-OVER TRANSACTION AUDIT DRAWER (CLEAN, SPACIOUS, 11-STAGE PIPELINE)
          ========================================================================= */}
      {selectedTx && (
        <div className="fixed inset-0 z-50 flex justify-end bg-black/50 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="w-full max-w-md h-full bg-surface border-l border-line p-6 shadow-2xl overflow-y-auto flex flex-col justify-between">
            <div className="space-y-6">
              {/* Drawer Header */}
              <div className="flex items-start justify-between border-b border-line pb-4">
                <div>
                  <span className="text-[10px] uppercase font-bold text-fg-subtle">
                    Transaction Audit Inspector
                  </span>
                  <div className="mt-1 flex items-center gap-2">
                    <span className="font-mono text-base font-bold text-fg">
                      {formatShortId(selectedTx.id)}
                    </span>
                    <button
                      onClick={(e) => handleCopy(selectedTx.id, selectedTx.id, e)}
                      className="text-fg-subtle hover:text-fg p-0.5 transition"
                    >
                      {copiedId === selectedTx.id ? (
                        <Check className="h-3.5 w-3.5 text-emerald-400" />
                      ) : (
                        <Copy className="h-3.5 w-3.5" />
                      )}
                    </button>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedTx(null)}
                  className="rounded-lg p-1 text-fg-subtle hover:text-fg hover:bg-sunken transition"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>

              {/* Amount & Status Card */}
              <div className="rounded-xl border border-line bg-sunken/40 p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs text-fg-muted">Settlement Amount</span>
                  <span className="text-xl font-bold text-fg">{formatPHP(selectedTx.amount)}</span>
                </div>
                <div className="flex items-center justify-between border-t border-line/60 pt-2 text-xs">
                  <span className="text-fg-subtle">Status</span>
                  <span className="font-semibold text-emerald-400">{selectedTx.status}</span>
                </div>
              </div>

              {/* 11-Stage Visual Timeline */}
              <div className="space-y-3">
                <span className="text-xs font-semibold uppercase tracking-wider text-fg-subtle block">
                  Processing Lifecycle Stepper
                </span>

                <div className="relative pl-6 space-y-4 before:absolute before:left-2 before:top-2 before:bottom-2 before:w-0.5 before:bg-line">
                  {[
                    { step: 1, name: 'Initiated', desc: 'Received via API Gateway' },
                    { step: 2, name: 'Validated', desc: 'Account format & currency verified' },
                    { step: 3, name: 'Authenticated', desc: 'Active JWT session verified' },
                    { step: 4, name: 'Fraud Check', desc: 'NanoJev velocity & geo score cleared' },
                    { step: 5, name: 'Limit Check', desc: 'BSP Cir. 1033 daily thresholds verified' },
                    { step: 6, name: 'Funds Check', desc: 'Pessimistic row lock & balance sufficient' },
                    { step: 7, name: 'Authorized', desc: 'Maker-checker dual rules passed' },
                    { step: 8, name: 'Posted', desc: 'Committed to Oracle XE Master' },
                    { step: 9, name: 'Ledger Update', desc: 'Atomic double-entry mutation complete' },
                    { step: 10, name: 'Notification', desc: 'Kafka outbox event published' },
                    { step: 11, name: 'Reconciliation', desc: 'Immutable seal written to PostgreSQL' },
                  ].map((stage) => (
                    <div key={stage.step} className="relative">
                      <span className="absolute -left-6 top-1 h-3.5 w-3.5 rounded-full bg-emerald-500 ring-4 ring-surface" />
                      <div>
                        <strong className="text-xs font-semibold text-fg">{stage.name}</strong>
                        <p className="text-[11px] text-fg-muted">{stage.desc}</p>
                      </div>
                    </div>
                  ))}

                  {selectedTx.status === 'REVERSED' && (
                    <div className="relative">
                      <span className="absolute -left-6 top-1 h-3.5 w-3.5 rounded-full bg-rose-500 ring-4 ring-surface" />
                      <div>
                        <strong className="text-xs font-semibold text-rose-400">Reversed (Contra-Entry)</strong>
                        <p className="text-[11px] text-fg-muted">
                          Rolled back by {selectedTx.reversedBy || 'Carlos Mendoza'}. Reason: {selectedTx.reversalReason || 'Customer dispute'}
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Bottom Actions inside Drawer */}
            <div className="pt-6 border-t border-line">
              {(selectedTx.status === 'COMMITTED' || selectedTx.status === 'POSTED') && (
                <button
                  onClick={() => setRollbackTarget(selectedTx)}
                  className="w-full rounded-xl bg-amber-500 px-4 py-2.5 text-xs font-semibold text-black hover:bg-amber-400 transition shadow-xs flex items-center justify-center gap-1.5"
                >
                  <RotateCcw className="h-3.5 w-3.5" />
                  <span>Initiate Rollback for this Transaction</span>
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          ROLLBACK / REVERSAL MODAL (MAKER-CHECKER WORKFLOW)
          ========================================================================= */}
      {rollbackTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 animate-in fade-in duration-200">
          <div className="w-full max-w-md rounded-2xl border border-line bg-surface p-6 shadow-2xl space-y-5">
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
            <div className="rounded-xl border border-line bg-sunken/40 p-3 space-y-1.5 text-xs">
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
                <div className="rounded-lg border border-line bg-sunken px-3 py-2 text-fg font-semibold">
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
                  className="w-full rounded-lg border border-line bg-surface px-3 py-2 text-fg font-medium focus:outline-none"
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
                  className="w-full rounded-lg border border-line bg-surface px-3 py-2 text-fg font-medium focus:outline-none"
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
                  className="w-full rounded-lg border border-line bg-surface p-2.5 text-fg focus:outline-none"
                />
              </div>
            </div>

            {/* Modal Actions */}
            <div className="flex items-center justify-end gap-2.5 pt-3 border-t border-line">
              <button
                type="button"
                onClick={() => setRollbackTarget(null)}
                className="rounded-lg border border-line bg-surface px-3.5 py-2 text-xs font-medium text-fg hover:bg-sunken"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleExecuteRollback}
                disabled={isSubmittingRollback}
                className="rounded-lg bg-amber-500 px-4 py-2 text-xs font-semibold text-black hover:bg-amber-400 transition"
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
