import React, { useState } from 'react';
import { 
  Database, 
  Activity, 
  ShieldAlert, 
  Server, 
  Cpu, 
  CheckCircle2, 
  Clock,
  Layers,
  FileCheck2,
  Mail,
  Lock,
  Search,
  ExternalLink
} from 'lucide-react';
import { mockState, THRESHOLDS } from '../services/api';
import { formatPHP } from '../utils/currency';

export default function AdminPortal() {
  const [activeTab, setActiveTab] = useState('audit'); // 'audit' | 'amla' | 'telemetry'
  const [searchQuery, setSearchQuery] = useState('');

  const amlaTransactions = mockState.transfers.filter((t) => (t.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN);

  const filteredLogs = mockState.auditLogs.filter((log) => {
    if (!searchQuery) return true;
    const q = searchQuery.toLowerCase();
    return (
      log.tx_id.toLowerCase().includes(q) ||
      log.event_type.toLowerCase().includes(q) ||
      log.actor_id.toLowerCase().includes(q) ||
      log.scn.toString().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* SLA & Telemetry Badges */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
              Throughput Performance
            </span>
            <Activity className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-xl font-mono font-bold text-emerald-400">248 TPS</p>
          <p className="text-[11px] text-slate-400 mt-1">SLA Benchmark target &gt; 200 TPS</p>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
              p99 Settlement Latency
            </span>
            <Clock className="w-4 h-4 text-indigo-400" />
          </div>
          <p className="text-xl font-mono font-bold text-indigo-400">42 ms</p>
          <p className="text-[11px] text-slate-400 mt-1">Row-lock SLA guarantee &lt; 150 ms</p>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
              PostgreSQL SCN Integrity
            </span>
            <Lock className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-xl font-mono font-bold text-emerald-400">100% Immutable</p>
          <p className="text-[11px] text-slate-400 mt-1">No update/delete trigger active</p>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
              Notification Engine
            </span>
            <Mail className="w-4 h-4 text-cyan-400" />
          </div>
          <p className="text-xl font-mono font-bold text-cyan-400">Online (:8083)</p>
          <p className="text-[11px] text-slate-400 mt-1">Dual-template HTML advice active</p>
        </div>
      </div>

      {/* Navigation Sub-Tabs */}
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
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <ShieldAlert className="w-3.5 h-3.5" /> AMLA Covered Transactions (CTR)
        </button>
        <button
          onClick={() => setActiveTab('telemetry')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 ${
            activeTab === 'telemetry'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <Server className="w-3.5 h-3.5" /> Infrastructure Health &amp; Topology
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
                Every balance debit, hold reservation, and manager sign-off is committed chronologically with cryptographic hashes.
              </p>
            </div>

            <div className="relative w-full sm:w-64">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-3" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search SCN, ref, actor..."
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
                      <span className="px-2 py-0.5 rounded font-mono text-[10px] bg-slate-800 text-slate-300">
                        {log.actor_id} ({log.actor_role})
                      </span>
                    </td>
                    <td className="py-3 font-mono font-bold">
                      <span className={log.delta_amount < 0 ? 'text-amber-400' : 'text-slate-400'}>
                        {log.delta_amount === 0 ? 'SIGN-OFF' : formatPHP(log.delta_amount)}
                      </span>
                    </td>
                    <td className="py-3 font-mono text-[10px] text-slate-500 max-w-xs truncate" title={log.digest_hash}>
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
              Tracks high-value mutations exceeding ₱500,000.00 in a single banking day for statutory reporting.
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
                  <th className="pb-3">Dual-Control State</th>
                  <th className="pb-3">Logged Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {amlaTransactions.map((tx) => (
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
                        AMLA CTR FLAGGED
                      </span>
                    </td>
                    <td className="py-3.5">
                      <span
                        className={`px-2 py-0.5 rounded-full text-[10px] font-semibold border ${
                          tx.status === 'SETTLED'
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                            : 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                        }`}
                      >
                        {tx.status === 'SETTLED' ? 'AUTHORIZED BY MANAGER' : 'AWAITING CHECKER'}
                      </span>
                    </td>
                    <td className="py-3.5 text-slate-400 text-[11px] font-mono">
                      {new Date(tx.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: Infrastructure Telemetry */}
      {activeTab === 'telemetry' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <Database className="w-4 h-4 text-indigo-400" />
                Oracle XE 21c (Pessimistic Row-Lock Master)
              </h3>
              <span className="px-2 py-0.5 rounded text-[10px] font-mono bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                Port 1521 &bull; Master ACID
              </span>
            </div>
            <p className="text-xs text-slate-400 leading-relaxed">
              Enforces table constraints (<code className="text-indigo-300">chk_available_balance &gt;= 0</code>) and pessimistic row-level locking via <code className="text-indigo-300">SELECT FOR UPDATE</code> to ensure zero double-spend mutations under high concurrency.
            </p>
            <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs font-mono space-y-1.5 text-slate-300">
              <div className="flex justify-between">
                <span>HikariCP Pool Connections:</span>
                <span className="text-emerald-400 font-bold">4 Active / 30 Max</span>
              </div>
              <div className="flex justify-between">
                <span>Check Constraint:</span>
                <span className="text-emerald-400 font-bold">ACTIVE (chk_available_balance &gt;= 0)</span>
              </div>
              <div className="flex justify-between">
                <span>Outbox Event Poller:</span>
                <span className="text-indigo-400 font-bold">Online (0 ms lag)</span>
              </div>
            </div>
          </div>

          <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <Server className="w-4 h-4 text-emerald-400" />
                PostgreSQL 15 (Immutable Audit Sink)
              </h3>
              <span className="px-2 py-0.5 rounded text-[10px] font-mono bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                Port 5432 &bull; Append-Only
              </span>
            </div>
            <p className="text-xs text-slate-400 leading-relaxed">
              Stores all historical balance mutations and dual-control sign-offs. Strictly protected by database trigger <code className="text-emerald-300">trg_no_update_delete_mutation_audit</code>, blocking all modifications.
            </p>
            <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs font-mono space-y-1.5 text-slate-300">
              <div className="flex justify-between">
                <span>Trigger Status:</span>
                <span className="text-emerald-400 font-bold">ENFORCED (trg_no_update_delete)</span>
              </div>
              <div className="flex justify-between">
                <span>Tampered Rows Detected:</span>
                <span className="text-emerald-400 font-bold">0 (100% Integrity)</span>
              </div>
              <div className="flex justify-between">
                <span>Audit SCN Head:</span>
                <span className="text-indigo-400 font-bold">
                  {mockState.auditLogs.length > 0 ? mockState.auditLogs[mockState.auditLogs.length - 1].scn : '18492044'}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
