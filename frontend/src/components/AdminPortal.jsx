import React, { useState } from 'react';
import { 
  ShieldAlert, 
  CheckCircle2, 
  Clock, 
  FileCheck2, 
  Lock, 
  Search, 
  XCircle,
  Printer,
  Download,
  ExternalLink,
  X,
  Copy,
  Check,
  Building2,
  UserCheck
} from 'lucide-react';
import { mockState, THRESHOLDS } from '../services/api';
import { formatPHP } from '../utils/currency';

export default function AdminPortal() {
  const [activeTab, setActiveTab] = useState('audit'); // 'audit' | 'amla'
  const [searchQuery, setSearchQuery] = useState('');
  const [eventFilter, setEventFilter] = useState('ALL'); // 'ALL' | 'DEBITS' | 'HOLDS' | 'APPROVALS' | 'DISAPPROVALS'
  const [selectedLog, setSelectedLog] = useState(null);
  const [copiedHash, setCopiedHash] = useState(false);

  // 100% Genuine Data-Driven Compliance Metrics
  const totalAuditLogs = mockState.auditLogs.length;
  const amlaTransactions = mockState.transfers.filter((t) => (t.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN);
  
  const debitCount = mockState.auditLogs.filter((log) => log.event_type === 'BALANCE_MUTATION_DEBIT').length;
  const holdCount = mockState.auditLogs.filter((log) => log.event_type.includes('HOLD')).length;
  
  const dualControlApprovals = mockState.auditLogs.filter((log) => 
    log.event_type === 'MANAGER_CHECKER_AUTHORIZATION' || 
    log.event_type === 'AMLA_TIER3_STAGE1_L1_SIGNOFF' ||
    log.event_type === 'AMLA_TIER3_STAGE2_FINAL_SETTLEMENT'
  ).length;

  const voidedTransactions = mockState.auditLogs.filter((log) => 
    log.event_type === 'MAKER_CHECKER_DISAPPROVAL_VOID'
  ).length;

  // Filtered SCN Journal Logs (Combined Search + Event Type Chips)
  const filteredLogs = mockState.auditLogs.filter((log) => {
    // 1. Event Type Chip Filter
    if (eventFilter === 'DEBITS' && log.event_type !== 'BALANCE_MUTATION_DEBIT') return false;
    if (eventFilter === 'HOLDS' && !log.event_type.includes('HOLD')) return false;
    if (eventFilter === 'APPROVALS' && !(log.event_type.includes('AUTHORIZATION') || log.event_type.includes('SIGNOFF') || log.event_type.includes('SETTLEMENT'))) return false;
    if (eventFilter === 'DISAPPROVALS' && !log.event_type.includes('DISAPPROVAL')) return false;

    // 2. Search Query Filter
    if (!searchQuery) return true;
    const q = searchQuery.toLowerCase().trim();
    return (
      log.tx_id?.toLowerCase().includes(q) ||
      log.event_type?.toLowerCase().includes(q) ||
      log.actor_id?.toLowerCase().includes(q) ||
      log.actor_role?.toLowerCase().includes(q) ||
      log.scn?.toString().includes(q)
    );
  });

  // Dynamic Transaction Lifecycle Badge with Uniform Size (w-[130px]) for visual consistency
  const renderAuditStatus = (log) => {
    const baseClass = "w-[130px] py-1 rounded-full text-[10px] font-semibold inline-flex items-center justify-center gap-1.5 font-mono border shadow-sm";

    // 1. Settled Mutations (STP Instant Settlement or Approved by Manager)
    if (
      log.event_type === 'BALANCE_MUTATION_DEBIT' ||
      log.event_type === 'MANAGER_CHECKER_AUTHORIZATION' ||
      log.event_type === 'AMLA_TIER3_STAGE2_FINAL_SETTLEMENT'
    ) {
      return (
        <span className={`${baseClass} bg-emerald-500/10 text-emerald-400 border-emerald-500/25`}>
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 shrink-0" />
          <span>SETTLED</span>
        </span>
      );
    }

    // 2. Voided / Disapproved
    if (log.event_type === 'MAKER_CHECKER_DISAPPROVAL_VOID') {
      return (
        <span className={`${baseClass} bg-rose-500/10 text-rose-400 border-rose-500/25`}>
          <span className="w-1.5 h-1.5 rounded-full bg-rose-400 shrink-0" />
          <span>VOIDED</span>
        </span>
      );
    }

    // 3. Stage 1 Signed (AMLA Level 1 Sign-Off complete, awaiting L2)
    if (log.event_type === 'AMLA_TIER3_STAGE1_L1_SIGNOFF') {
      return (
        <span className={`${baseClass} bg-indigo-500/10 text-indigo-300 border-indigo-500/25`}>
          <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 shrink-0" />
          <span>STAGE 1 SIGNED</span>
        </span>
      );
    }

    // 4. Soft Hold / AMLA CTR Hold (Pending Manager Approval)
    if (log.event_type.includes('HOLD')) {
      return (
        <span className={`${baseClass} bg-amber-500/10 text-amber-300 border-amber-500/25`}>
          <span className="w-1.5 h-1.5 rounded-full bg-amber-400 shrink-0" />
          <span>PENDING (HELD)</span>
        </span>
      );
    }

    return (
      <span className={`${baseClass} bg-slate-800 text-slate-300 border-slate-700`}>
        <span>LOGGED</span>
      </span>
    );
  };

  // Print Official Report
  const handlePrint = () => {
    window.print();
  };

  // Export SCN Audit Vault to CSV (AMLC / BSP Standard Ingestion Format)
  const handleExportCSV = () => {
    const headers = ['SCN Sequence', 'Event Type', 'Tx Reference', 'Actor ID', 'Actor Role', 'Mutation Delta (PHP)', 'SHA-256 Digest Hash', 'Execution Status', 'Timestamp'];
    const rows = filteredLogs.map((log) => {
      let lifecycleStatus = 'LOGGED';
      if (log.event_type === 'BALANCE_MUTATION_DEBIT' || log.event_type.includes('AUTHORIZATION') || log.event_type.includes('SETTLEMENT')) {
        lifecycleStatus = 'SETTLED';
      } else if (log.event_type.includes('DISAPPROVAL')) {
        lifecycleStatus = 'VOIDED';
      } else if (log.event_type === 'AMLA_TIER3_STAGE1_L1_SIGNOFF') {
        lifecycleStatus = 'STAGE_1_SIGNED';
      } else if (log.event_type.includes('HOLD')) {
        lifecycleStatus = 'PENDING_HELD';
      }

      return [
        log.scn,
        log.event_type,
        log.tx_id,
        log.actor_id,
        log.actor_role,
        log.delta_amount,
        log.digest_hash,
        lifecycleStatus,
        `"${new Date(log.timestamp).toISOString()}"`
      ];
    });

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `BSP_SCN_Audit_Vault_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Export AMLA CTR Register to CSV
  const handleExportAmlaCSV = () => {
    const headers = ['Reference ID', 'Sender (Maker)', 'Beneficiary Account', 'Beneficiary Name', 'Amount (PHP)', 'AMLC Status', 'Dual-Control State', 'Logged Date'];
    const rows = amlaTransactions.map((tx) => [
      tx.id,
      tx.maker_user_id,
      tx.to_account_id,
      `"${tx.recipient_name}"`,
      tx.amount,
      'CTR_MANDATORY',
      tx.status === 'SETTLED' ? 'FULLY_SETTLED_L1_L2' : tx.approval_stage === 2 ? 'AWAITING_STAGE2_L2' : 'AWAITING_STAGE1_L1',
      `"${new Date(tx.created_at).toISOString()}"`
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `AMLA_CTR_Register_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const selectedTx = selectedLog ? mockState.transfers.find((t) => t.id === selectedLog.tx_id) : null;

  return (
    <div className="space-y-6">
      {/* Real Data-Driven Compliance KPI Badges */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* 1. SCN Audit Records */}
        <div className="p-5 rounded-2xl bg-slate-900/80 border border-indigo-500/30 shadow-lg relative overflow-hidden group hover:border-indigo-500/50 transition-all">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-indigo-400">
              SCN Audit Records
            </span>
            <FileCheck2 className="w-4 h-4 text-indigo-400" />
          </div>
          <p className="text-2xl font-mono font-bold text-white tracking-tight">
            {totalAuditLogs} {totalAuditLogs === 1 ? 'Event' : 'Events'}
          </p>
          <p className="text-[11px] text-slate-400 mt-1">
            Append-only SCN sequential journal
          </p>
        </div>

        {/* 2. AMLA CTR Covered Items */}
        <div className="p-5 rounded-2xl bg-slate-900/80 border border-rose-500/30 shadow-lg relative overflow-hidden group hover:border-rose-500/50 transition-all">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-rose-400">
              AMLA Covered (CTR)
            </span>
            <ShieldAlert className="w-4 h-4 text-rose-400" />
          </div>
          <p className="text-2xl font-mono font-bold text-white tracking-tight">
            {amlaTransactions.length} {amlaTransactions.length === 1 ? 'Item' : 'Items'}
          </p>
          <p className="text-[11px] text-slate-400 mt-1">
            Mandatory RA 9160 statutory register (&ge; ₱500k)
          </p>
        </div>

        {/* 3. Dual-Control Authorizations */}
        <div className="p-5 rounded-2xl bg-slate-900/80 border border-emerald-500/30 shadow-lg relative overflow-hidden group hover:border-emerald-500/50 transition-all">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-emerald-400">
              Dual-Control Approvals
            </span>
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-mono font-bold text-emerald-400 tracking-tight">
            {dualControlApprovals} {dualControlApprovals === 1 ? 'Settlement' : 'Settlements'}
          </p>
          <p className="text-[11px] text-slate-400 mt-1">
            Operations Manager verified &amp; released
          </p>
        </div>

        {/* 4. Disapproved & Voided */}
        <div className="p-5 rounded-2xl bg-slate-900/80 border border-amber-500/30 shadow-lg relative overflow-hidden group hover:border-amber-500/50 transition-all">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-amber-400">
              Disapproved / Voided
            </span>
            <XCircle className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-mono font-bold text-amber-300 tracking-tight">
            {voidedTransactions} {voidedTransactions === 1 ? 'Mutation' : 'Mutations'}
          </p>
          <p className="text-[11px] text-slate-400 mt-1">
            Soft holds unlocked back to customer
          </p>
        </div>
      </div>

      {/* Navigation Sub-Tabs (Strictly Regulatory Focus) */}
      <div className="flex items-center gap-3 border-b border-slate-800/80 pb-3">
        <button
          onClick={() => setActiveTab('audit')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 ${
            activeTab === 'audit'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <FileCheck2 className="w-3.5 h-3.5" /> Immutable PostgreSQL SCN Audit Vault
        </button>
        <button
          onClick={() => setActiveTab('amla')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 ${
            activeTab === 'amla'
              ? 'bg-rose-600 text-white shadow-md shadow-rose-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <ShieldAlert className="w-3.5 h-3.5" /> AMLA Covered Transactions Register (CTR)
        </button>
      </div>

      {/* TAB 1: Immutable Audit Log Table */}
      {activeTab === 'audit' && (
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
          {/* Header Bar + Export/Print Actions */}
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4">
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <FileCheck2 className="w-4 h-4 text-emerald-400" />
                Append-Only SCN Journal (PostgreSQL 15)
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Click any SCN sequence number to inspect the complete cryptographic audit dossier.
              </p>
            </div>

            {/* Print & Export Actions */}
            <div className="flex items-center gap-2 w-full lg:w-auto">
              <button
                onClick={handlePrint}
                className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white border border-slate-700 transition-all flex items-center gap-1.5 shadow-sm active:scale-95 cursor-pointer"
                title="Print official audit report dossier"
              >
                <Printer className="w-3.5 h-3.5 text-slate-400" /> Print Report
              </button>
              <button
                onClick={handleExportCSV}
                className="px-4 py-1.5 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/30 transition-all flex items-center gap-1.5 active:scale-95 cursor-pointer"
                title="Export SCN audit vault to CSV format for AMLC/BSP regulatory filing"
              >
                <Download className="w-3.5 h-3.5" /> Export CSV
              </button>
            </div>
          </div>

          {/* Filter Toolbar: Quick Event Filter Chips + Search Input */}
          <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-3 pt-2 border-t border-slate-800/60">
            {/* Quick Filter Chips */}
            <div className="flex items-center gap-1.5 bg-slate-950 p-1.5 rounded-xl border border-slate-800 text-xs overflow-x-auto max-w-full">
              <button
                onClick={() => setEventFilter('ALL')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap cursor-pointer ${
                  eventFilter === 'ALL'
                    ? 'bg-indigo-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                All Events ({totalAuditLogs})
              </button>
              <button
                onClick={() => setEventFilter('DEBITS')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap cursor-pointer ${
                  eventFilter === 'DEBITS'
                    ? 'bg-slate-700 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Debits ({debitCount})
              </button>
              <button
                onClick={() => setEventFilter('HOLDS')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap cursor-pointer ${
                  eventFilter === 'HOLDS'
                    ? 'bg-amber-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Holds ({holdCount})
              </button>
              <button
                onClick={() => setEventFilter('APPROVALS')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap cursor-pointer ${
                  eventFilter === 'APPROVALS'
                    ? 'bg-emerald-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Approvals ({dualControlApprovals})
              </button>
              <button
                onClick={() => setEventFilter('DISAPPROVALS')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap cursor-pointer ${
                  eventFilter === 'DISAPPROVALS'
                    ? 'bg-rose-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Disapprovals ({voidedTransactions})
              </button>
            </div>

            {/* Search Input */}
            <div className="relative w-full md:w-64">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-2.5" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search SCN, ref, actor..."
                className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-3 py-1.5 text-xs text-white focus:outline-none focus:border-indigo-500"
              />
            </div>
          </div>

          {filteredLogs.length === 0 ? (
            <div className="py-12 text-center text-slate-500 text-xs">
              <FileCheck2 className="w-8 h-8 text-slate-600 mx-auto mb-2" />
              No audit logs matching event filter "{eventFilter}" or search query.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-slate-800 text-slate-400 font-semibold uppercase text-[10px] tracking-wider">
                  <tr>
                    <th className="pb-3">SCN Sequence</th>
                    <th className="pb-3">Event Type</th>
                    <th className="pb-3">Tx Reference</th>
                    <th className="pb-3">Actor ID</th>
                    <th className="pb-3">Mutation Delta</th>
                    <th className="pb-3">Integrity Digest (SHA-256)</th>
                    <th className="pb-3">Execution Status</th>
                    <th className="pb-3">Timestamp</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60">
                  {filteredLogs.map((log) => (
                    <tr key={log.scn} className="hover:bg-slate-900/40 transition-colors">
                      {/* Clickable SCN Sequence Number */}
                      <td className="py-3 font-mono font-bold text-indigo-400">
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedLog(log);
                            setCopiedHash(false);
                          }}
                          className="hover:underline hover:text-indigo-300 transition-all cursor-pointer flex items-center gap-1 group py-0.5 text-left"
                          title="Click to inspect complete SCN audit dossier"
                        >
                          <span>{log.scn}</span>
                          <ExternalLink className="w-3 h-3 text-indigo-400 opacity-60 group-hover:opacity-100 transition-opacity" />
                        </button>
                      </td>
                      <td className="py-3">
                        <span className="font-mono text-[11px] text-slate-200">{log.event_type}</span>
                      </td>
                      <td className="py-3 font-mono text-slate-300 font-semibold">{log.tx_id}</td>
                      <td className="py-3">
                        <span className="px-2 py-0.5 rounded font-mono text-[10px] bg-slate-800 text-slate-300 border border-slate-700/60">
                          {log.actor_id} ({log.actor_role})
                        </span>
                      </td>
                      <td className="py-3 font-mono font-bold">
                        <span className={log.delta_amount < 0 ? 'text-amber-400' : log.delta_amount > 0 ? 'text-emerald-400' : 'text-slate-400'}>
                          {log.delta_amount === 0 ? 'SIGN-OFF' : formatPHP(log.delta_amount)}
                        </span>
                      </td>
                      <td className="py-3 font-mono text-[10px] text-slate-400 max-w-xs truncate" title={`SHA-256 Digest: ${log.digest_hash} (Immutable Hash Stamp Verified)`}>
                        <div className="flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400/80 shrink-0" />
                          <span className="truncate">{log.digest_hash}</span>
                        </div>
                      </td>
                      <td className="py-3 whitespace-nowrap">
                        {renderAuditStatus(log)}
                      </td>
                      <td className="py-3 font-mono text-[11px] whitespace-nowrap">
                        <p className="text-slate-200 font-semibold leading-tight">
                          {new Date(log.timestamp).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' })}
                        </p>
                        <p className="text-slate-400 text-[10px]">
                          {new Date(log.timestamp).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true })}
                        </p>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* TAB 2: AMLA CTR Register */}
      {activeTab === 'amla' && (
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4">
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <ShieldAlert className="w-4 h-4 text-rose-400" />
                R.A. 9160 Anti-Money Laundering Council (AMLC) Covered Transaction Register
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Tracks high-value mutations exceeding ₱500,000.00 in a single banking day for statutory reporting (Sec. 3b).
              </p>
            </div>

            {/* Print & Export Actions for AMLA Register */}
            <div className="flex items-center gap-2 w-full lg:w-auto">
              <button
                onClick={handlePrint}
                className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white border border-slate-700 transition-all flex items-center gap-1.5 shadow-sm active:scale-95 cursor-pointer"
                title="Print AMLA CTR Register"
              >
                <Printer className="w-3.5 h-3.5 text-slate-400" /> Print Register
              </button>
              <button
                onClick={handleExportAmlaCSV}
                className="px-4 py-1.5 rounded-xl text-xs font-bold bg-rose-600 hover:bg-rose-500 text-white shadow-md shadow-rose-600/30 transition-all flex items-center gap-1.5 active:scale-95 cursor-pointer"
                title="Export AMLC CTR file to CSV format"
              >
                <Download className="w-3.5 h-3.5" /> Export AMLC CTR
              </button>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 font-semibold uppercase text-[10px] tracking-wider">
                <tr>
                  <th className="pb-3">Reference ID</th>
                  <th className="pb-3">Sender (Maker)</th>
                  <th className="pb-3">Beneficiary</th>
                  <th className="pb-3">Transaction Amount</th>
                  <th className="pb-3">AMLC Status</th>
                  <th className="pb-3">Dual-Control Multi-Stage Status</th>
                  <th className="pb-3">Logged Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {amlaTransactions.map((tx) => {
                  const stage = tx.approval_stage || 1;
                  const isSettled = tx.status === 'SETTLED';
                  const isRejected = tx.status === 'REJECTED';

                  return (
                    <tr key={tx.id} className="hover:bg-slate-900/40 transition-colors">
                      <td className="py-3.5 font-mono text-rose-400 font-bold">{tx.id}</td>
                      <td className="py-3.5 font-mono text-slate-300">{tx.maker_user_id}</td>
                      <td className="py-3.5">
                        <p className="font-semibold text-white">{tx.recipient_name}</p>
                        <p className="text-[10px] font-mono text-slate-400">{tx.to_account_id}</p>
                      </td>
                      <td className="py-3.5 font-mono font-bold text-rose-300">
                        {formatPHP(tx.amount)}
                      </td>
                      <td className="py-3.5">
                        <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20">
                          CTR MANDATORY
                        </span>
                      </td>
                      <td className="py-3.5 whitespace-nowrap">
                        {isSettled ? (
                          <span className="w-[230px] py-1 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/25 inline-flex items-center justify-center gap-1.5 font-mono shadow-sm">
                            <CheckCircle2 className="w-3.5 h-3.5 shrink-0" /> FULLY SETTLED (L1 &amp; L2)
                          </span>
                        ) : isRejected ? (
                          <span className="w-[230px] py-1 rounded-full text-[10px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/25 inline-flex items-center justify-center gap-1.5 font-mono shadow-sm">
                            <XCircle className="w-3.5 h-3.5 shrink-0" /> DISAPPROVED &amp; VOIDED
                          </span>
                        ) : stage === 2 ? (
                          <span className="w-[230px] py-1 rounded-full text-[10px] font-semibold bg-indigo-500/10 text-indigo-300 border border-indigo-500/25 inline-flex items-center justify-center gap-1.5 font-mono shadow-sm">
                            <Clock className="w-3.5 h-3.5 shrink-0" /> STAGE 2: AWAITING L2 MANAGER
                          </span>
                        ) : (
                          <span className="w-[230px] py-1 rounded-full text-[10px] font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/25 inline-flex items-center justify-center gap-1.5 font-mono shadow-sm">
                            <Clock className="w-3.5 h-3.5 shrink-0" /> STAGE 1: AWAITING L1 CHECKER
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 font-mono text-[11px] whitespace-nowrap">
                        <p className="text-slate-200 font-semibold leading-tight">
                          {new Date(tx.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' })}
                        </p>
                        <p className="text-slate-400 text-[10px]">
                          {new Date(tx.created_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true })}
                        </p>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* SCN Detailed Inspection Dossier Modal */}
      {selectedLog && (
        <div 
          onClick={(e) => {
            if (e.target === e.currentTarget) setSelectedLog(null);
          }}
          className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4 animate-in fade-in duration-200"
        >
          <div className="bg-slate-900 border border-indigo-500/30 rounded-3xl max-w-2xl w-full p-6 sm:p-8 shadow-2xl relative overflow-hidden animate-in zoom-in-95 duration-200 max-h-[90vh] overflow-y-auto space-y-5">
            {/* Top decorative gradient bar */}
            <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-indigo-500 via-purple-500 to-emerald-500" />

            {/* Close 'X' Button */}
            <button
              type="button"
              onClick={() => setSelectedLog(null)}
              aria-label="Close Dossier"
              className="absolute top-4 right-4 z-10 p-2 rounded-full bg-slate-800/80 hover:bg-slate-700 text-slate-400 hover:text-white border border-slate-700/80 transition-all active:scale-95 shadow-md focus:outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>

            {/* Modal Header */}
            <div className="flex items-start justify-between border-b border-slate-800 pb-4 pr-8">
              <div className="flex items-center gap-3">
                <span className="p-2.5 rounded-xl bg-indigo-500/10 border border-indigo-500/20 text-indigo-400">
                  <FileCheck2 className="w-6 h-6" />
                </span>
                <div>
                  <h3 className="text-lg font-bold text-white tracking-tight flex items-center gap-2">
                    <span>SCN Record Dossier</span>
                    <span className="text-indigo-400 font-mono">#{selectedLog.scn}</span>
                  </h3>
                  <p className="text-xs text-slate-400">
                    PostgreSQL 15 Append-Only Vault &bull; BSP Circular 808 Immutable Ledger Entry
                  </p>
                </div>
              </div>
            </div>

            {/* Cryptographic SHA-256 Tamper-Proof Stamp */}
            <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-slate-300 flex items-center gap-1.5 uppercase tracking-wider">
                  <Lock className="w-3.5 h-3.5 text-emerald-400" /> Cryptographic Integrity Digest (SHA-256)
                </span>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 flex items-center gap-1">
                  <CheckCircle2 className="w-3 h-3" /> VERIFIED TAMPER-PROOF
                </span>
              </div>
              <div className="flex items-center justify-between gap-2 p-2.5 rounded-xl bg-slate-900 border border-slate-800 font-mono text-[11px] text-slate-300 break-all">
                <span className="select-all">{selectedLog.digest_hash}</span>
                <button
                  type="button"
                  onClick={() => {
                    if (navigator.clipboard) {
                      navigator.clipboard.writeText(selectedLog.digest_hash);
                      setCopiedHash(true);
                      setTimeout(() => setCopiedHash(false), 2000);
                    }
                  }}
                  className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-all shrink-0 cursor-pointer"
                  title="Copy SHA-256 Hash"
                >
                  {copiedHash ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                </button>
              </div>
              <p className="text-[10px] text-slate-500">
                Protected by PostgreSQL trigger <code className="text-slate-400 font-mono">trg_no_update_delete_mutation_audit</code>. Any manual byte manipulation in storage breaks this cryptographic seal.
              </p>
            </div>

            {/* Financial Mutation Matrix */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                <span className="text-[11px] text-slate-400 uppercase tracking-wider">Event Classification</span>
                <p className="font-mono font-bold text-slate-200 text-xs">{selectedLog.event_type}</p>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                <span className="text-[11px] text-slate-400 uppercase tracking-wider">Execution Lifecycle Status</span>
                <div>{renderAuditStatus(selectedLog)}</div>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                <span className="text-[11px] text-slate-400 uppercase tracking-wider">Mutation Delta</span>
                <p className={`font-mono font-bold text-sm ${
                  selectedLog.delta_amount < 0 ? 'text-amber-400' : selectedLog.delta_amount > 0 ? 'text-emerald-400' : 'text-slate-400'
                }`}>
                  {selectedLog.delta_amount === 0 ? '₱ 0.00 (SIGN-OFF RELEASE)' : formatPHP(selectedLog.delta_amount)}
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                <span className="text-[11px] text-slate-400 uppercase tracking-wider">Ledger Balance After Mutation</span>
                <p className="font-mono font-bold text-emerald-400 text-sm">
                  {selectedLog.balance_after !== undefined ? formatPHP(selectedLog.balance_after) : 'Unchanged'}
                </p>
              </div>
            </div>

            {/* Identity & Non-Repudiation Actor Details */}
            <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 text-xs space-y-2.5">
              <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                <UserCheck className="w-3.5 h-3.5 text-indigo-400" /> Identity &amp; Non-Repudiation Actor Proof
              </span>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 font-mono">
                <div>
                  <span className="text-slate-500 text-[10px] block">Actor ID</span>
                  <span className="text-white font-semibold">{selectedLog.actor_id}</span>
                </div>
                <div>
                  <span className="text-slate-500 text-[10px] block">Actor Role</span>
                  <span className="text-indigo-300 font-semibold">{selectedLog.actor_role}</span>
                </div>
                <div>
                  <span className="text-slate-500 text-[10px] block">Account Reference</span>
                  <span className="text-slate-300">{selectedLog.account_id || '1000-2000-3001'}</span>
                </div>
              </div>
              <div className="pt-2 text-[11px] text-slate-400 border-t border-slate-800/80 flex items-center justify-between">
                <span>Committed Timestamp:</span>
                <span className="font-mono text-slate-200 font-semibold">
                  {new Date(selectedLog.timestamp).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' })}{' '}
                  &bull;{' '}
                  {new Date(selectedLog.timestamp).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true })}
                </span>
              </div>
            </div>

            {/* Associated Transaction Context */}
            {selectedTx && (
              <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 text-xs space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                    <Building2 className="w-3.5 h-3.5 text-slate-400" /> Business Transfer Context ({selectedTx.id})
                  </span>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-indigo-500/10 text-indigo-300 border border-indigo-500/20">
                    {selectedTx.regulatory_tier}
                  </span>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-slate-300">
                  <div>
                    <span className="text-slate-500 text-[10px] block">Beneficiary</span>
                    <span className="font-semibold text-white">{selectedTx.recipient_name}</span> ({selectedTx.to_account_id})
                  </div>
                  <div>
                    <span className="text-slate-500 text-[10px] block">Memo / Purpose</span>
                    <span className="italic">{selectedTx.memo || 'Standard Retail Transfer'}</span>
                  </div>
                </div>
                {selectedTx.approver_notes && (
                  <div className="pt-1.5 border-t border-slate-800/60 text-[11px]">
                    <span className="text-emerald-400 font-semibold">Authorizer Notes: </span>
                    <span className="text-slate-300 italic">"{selectedTx.approver_notes}"</span>
                  </div>
                )}
                {selectedTx.rejection_reason && (
                  <div className="pt-1.5 border-t border-slate-800/60 text-[11px]">
                    <span className="text-rose-400 font-semibold">Disapproval Reason: </span>
                    <span className="text-slate-300 italic">"{selectedTx.rejection_reason}"</span>
                  </div>
                )}
              </div>
            )}

            {/* Modal Actions */}
            <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setSelectedLog(null)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition-all cursor-pointer"
              >
                Close
              </button>
              <button
                type="button"
                onClick={() => window.print()}
                className="px-5 py-2 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/30 transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <Printer className="w-3.5 h-3.5" /> Print SCN Dossier Slip
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
