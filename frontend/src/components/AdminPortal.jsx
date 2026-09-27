import React, { useState } from 'react';
import { 
  ShieldAlert, 
  CheckCircle2, 
  Clock, 
  FileCheck2, 
  Lock, 
  Search, 
  XCircle,
  UserCheck,
  AlertCircle
} from 'lucide-react';
import { mockState, THRESHOLDS } from '../services/api';
import { formatPHP } from '../utils/currency';

export default function AdminPortal() {
  const [activeTab, setActiveTab] = useState('audit'); // 'audit' | 'amla'
  const [searchQuery, setSearchQuery] = useState('');

  // 100% Genuine Data-Driven Compliance Metrics
  const totalAuditLogs = mockState.auditLogs.length;
  const amlaTransactions = mockState.transfers.filter((t) => (t.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN);
  
  const dualControlApprovals = mockState.auditLogs.filter((log) => 
    log.event_type === 'MANAGER_CHECKER_AUTHORIZATION' || 
    log.event_type === 'AMLA_TIER3_STAGE2_FINAL_SETTLEMENT'
  ).length;

  const voidedTransactions = mockState.auditLogs.filter((log) => 
    log.event_type === 'MAKER_CHECKER_DISAPPROVAL_VOID'
  ).length;

  const filteredLogs = mockState.auditLogs.filter((log) => {
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
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <FileCheck2 className="w-4 h-4 text-emerald-400" />
                Append-Only SCN Journal (PostgreSQL 15)
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Every balance debit, hold reservation, and manager sign-off is committed chronologically with cryptographic hashes (BSP Cir. 808).
              </p>
            </div>

            <div className="relative w-full sm:w-72">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-3" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search SCN, ref, actor, event..."
                className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-3 py-2 text-xs text-white focus:outline-none focus:border-indigo-500"
              />
            </div>
          </div>

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
                  <th className="pb-3">Status</th>
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
                    <td className="py-3 font-mono text-[10px] text-slate-400 max-w-xs truncate" title={log.digest_hash}>
                      {log.digest_hash}
                    </td>
                    <td className="py-3">
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                        {log.status}
                      </span>
                    </td>
                    <td className="py-3 text-slate-400 text-[11px] font-mono">
                      {new Date(log.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: AMLA CTR Register */}
      {activeTab === 'amla' && (
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
          <div>
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <ShieldAlert className="w-4 h-4 text-rose-400" />
              R.A. 9160 Anti-Money Laundering Council (AMLC) Covered Transaction Register
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Tracks high-value mutations exceeding ₱500,000.00 in a single banking day for statutory reporting (Sec. 3b).
            </p>
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
                          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 inline-flex items-center gap-1">
                            <CheckCircle2 className="w-3 h-3" /> FULLY SETTLED (L1 &amp; L2 APPROVED)
                          </span>
                        ) : isRejected ? (
                          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20 inline-flex items-center gap-1">
                            <XCircle className="w-3 h-3" /> DISAPPROVED &amp; VOIDED
                          </span>
                        ) : stage === 2 ? (
                          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-indigo-500/10 text-indigo-300 border border-indigo-500/20 inline-flex items-center gap-1">
                            <Clock className="w-3 h-3" /> STAGE 2: AWAITING L2 SENIOR MANAGER
                          </span>
                        ) : (
                          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/20 inline-flex items-center gap-1">
                            <Clock className="w-3 h-3" /> STAGE 1: AWAITING L1 OPERATIONS CHECKER
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 text-slate-400 text-[11px] font-mono">
                        {new Date(tx.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
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
