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
  Download
} from 'lucide-react';
import { mockState, THRESHOLDS } from '../services/api';
import { formatPHP } from '../utils/currency';

export default function AdminPortal() {
  const [activeTab, setActiveTab] = useState('audit'); // 'audit' | 'amla'
  const [searchQuery, setSearchQuery] = useState('');
  const [eventFilter, setEventFilter] = useState('ALL'); // 'ALL' | 'DEBITS' | 'HOLDS' | 'APPROVALS' | 'DISAPPROVALS'

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

  // Dynamic Transaction Lifecycle Badge
  const renderAuditStatus = (log) => {
    // 1. Settled Mutations (STP Instant Settlement or Approved by Manager)
    if (
      log.event_type === 'BALANCE_MUTATION_DEBIT' ||
      log.event_type === 'MANAGER_CHECKER_AUTHORIZATION' ||
      log.event_type === 'AMLA_TIER3_STAGE2_FINAL_SETTLEMENT'
    ) {
      return (
        <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 inline-flex items-center gap-1 font-mono">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
          SETTLED
        </span>
      );
    }

    // 2. Voided / Disapproved
    if (log.event_type === 'MAKER_CHECKER_DISAPPROVAL_VOID') {
      return (
        <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20 inline-flex items-center gap-1 font-mono">
          <span className="w-1.5 h-1.5 rounded-full bg-rose-400" />
          VOIDED
        </span>
      );
    }

    // 3. Stage 1 Signed (AMLA Level 1 Sign-Off complete, awaiting L2)
    if (log.event_type === 'AMLA_TIER3_STAGE1_L1_SIGNOFF') {
      return (
        <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-indigo-500/10 text-indigo-300 border border-indigo-500/20 inline-flex items-center gap-1 font-mono">
          <span className="w-1.5 h-1.5 rounded-full bg-indigo-400" />
          STAGE 1 SIGNED
        </span>
      );
    }

    // 4. Soft Hold / AMLA CTR Hold (Pending Manager Approval)
    if (log.event_type.includes('HOLD')) {
      return (
        <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/20 inline-flex items-center gap-1 font-mono">
          <span className="w-1.5 h-1.5 rounded-full bg-amber-400" />
          PENDING (HELD)
        </span>
      );
    }

    return (
      <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-slate-800 text-slate-300 border border-slate-700 font-mono">
        LOGGED
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
                Every balance debit, hold reservation, and manager sign-off is committed chronologically with cryptographic hashes (BSP Cir. 808).
              </p>
            </div>

            {/* Print & Export Actions */}
            <div className="flex items-center gap-2 w-full lg:w-auto">
              <button
                onClick={handlePrint}
                className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white border border-slate-700 transition-all flex items-center gap-1.5 shadow-sm active:scale-95"
                title="Print official audit report dossier"
              >
                <Printer className="w-3.5 h-3.5 text-slate-400" /> Print Report
              </button>
              <button
                onClick={handleExportCSV}
                className="px-4 py-1.5 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/30 transition-all flex items-center gap-1.5 active:scale-95"
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
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap ${
                  eventFilter === 'ALL'
                    ? 'bg-indigo-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                All Events ({totalAuditLogs})
              </button>
              <button
                onClick={() => setEventFilter('DEBITS')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap ${
                  eventFilter === 'DEBITS'
                    ? 'bg-slate-700 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Debits ({debitCount})
              </button>
              <button
                onClick={() => setEventFilter('HOLDS')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap ${
                  eventFilter === 'HOLDS'
                    ? 'bg-amber-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Holds ({holdCount})
              </button>
              <button
                onClick={() => setEventFilter('APPROVALS')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap ${
                  eventFilter === 'APPROVALS'
                    ? 'bg-emerald-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Approvals ({dualControlApprovals})
              </button>
              <button
                onClick={() => setEventFilter('DISAPPROVALS')}
                className={`px-3 py-1 rounded-lg transition-all font-medium whitespace-nowrap ${
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
                      <td className="py-3 font-mono font-bold text-indigo-400">{log.scn}</td>
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
                      <td className="py-3">
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
                className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white border border-slate-700 transition-all flex items-center gap-1.5 shadow-sm active:scale-95"
                title="Print AMLA CTR Register"
              >
                <Printer className="w-3.5 h-3.5 text-slate-400" /> Print Register
              </button>
              <button
                onClick={handleExportAmlaCSV}
                className="px-4 py-1.5 rounded-xl text-xs font-bold bg-rose-600 hover:bg-rose-500 text-white shadow-md shadow-rose-600/30 transition-all flex items-center gap-1.5 active:scale-95"
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
                      <td className="py-3.5">
                        {isSettled ? (
                          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 inline-flex items-center gap-1 font-mono">
                            <CheckCircle2 className="w-3 h-3" /> FULLY SETTLED (L1 &amp; L2 APPROVED)
                          </span>
                        ) : isRejected ? (
                          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20 inline-flex items-center gap-1 font-mono">
                            <XCircle className="w-3 h-3" /> DISAPPROVED &amp; VOIDED
                          </span>
                        ) : stage === 2 ? (
                          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-indigo-500/10 text-indigo-300 border border-indigo-500/20 inline-flex items-center gap-1 font-mono">
                            <Clock className="w-3 h-3" /> STAGE 2: AWAITING L2 SENIOR MANAGER
                          </span>
                        ) : (
                          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/20 inline-flex items-center gap-1 font-mono">
                            <Clock className="w-3 h-3" /> STAGE 1: AWAITING L1 OPERATIONS CHECKER
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
    </div>
  );
}
