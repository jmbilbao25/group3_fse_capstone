import React, { useState } from 'react';
import { 
  Building2, 
  ArrowLeftRight, 
  ShieldCheck, 
  Wallet, 
  UserCheck, 
  History, 
  AlertCircle, 
  TrendingUp,
  CreditCard
} from 'lucide-react';

export default function App() {
  const [activeRole, setActiveRole] = useState('CUSTOMER');

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 flex flex-col font-sans">
      {/* Top Navigation */}
      <header className="border-b border-slate-800 bg-slate-950/70 backdrop-blur px-6 py-4 flex items-center justify-between sticky top-0 z-50">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-indigo-600 rounded-xl shadow-lg shadow-indigo-600/30">
            <Building2 className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="font-bold text-lg text-white leading-tight">EastWest Retail Core Ledger</h1>
            <p className="text-xs text-slate-400">High-Throughput Mutation &amp; Dual-Write Engine</p>
          </div>
        </div>

        {/* Role Switcher */}
        <div className="flex items-center gap-2 bg-slate-900 border border-slate-800 p-1 rounded-xl text-xs font-semibold">
          {['CUSTOMER', 'TELLER', 'ADMIN'].map((role) => (
            <button
              key={role}
              onClick={() => setActiveRole(role)}
              className={`px-3 py-1.5 rounded-lg transition-all ${
                activeRole === role
                  ? 'bg-indigo-600 text-white shadow-md'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              {role}
            </button>
          ))}
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-6 md:p-8 space-y-8">
        {/* Banner */}
        <div className="p-6 rounded-2xl bg-gradient-to-r from-indigo-900/40 via-slate-900 to-slate-900 border border-indigo-500/20 shadow-xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
          <div>
            <span className="px-2.5 py-1 rounded-full text-[11px] font-semibold bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
              Active Mode: {activeRole}
            </span>
            <h2 className="text-2xl font-bold text-white mt-2">
              {activeRole === 'CUSTOMER' && 'Welcome back, Juan Dela Cruz'}
              {activeRole === 'TELLER' && 'Branch Teller Terminal (Workstation #1)'}
              {activeRole === 'ADMIN' && 'Maker-Checker Approval & System Administration'}
            </h2>
            <p className="text-sm text-slate-400 mt-1">
              Dual-write storage connected to Oracle XE (Master State) &amp; PostgreSQL (Immutable Audit Trail).
            </p>
          </div>
          <div className="flex items-center gap-4 bg-slate-950/60 border border-slate-800 p-4 rounded-xl">
            <div>
              <p className="text-xs text-slate-400">Available Balance (A2001)</p>
              <p className="text-2xl font-mono font-bold text-emerald-400">₱ 298,000.0000</p>
            </div>
            <div className="w-px h-8 bg-slate-800" />
            <div>
              <p className="text-xs text-slate-400">Hold Amount</p>
              <p className="text-sm font-mono text-amber-400 font-semibold">₱ 0.0000</p>
            </div>
          </div>
        </div>

        {/* Action Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="p-5 rounded-2xl bg-slate-950/40 border border-slate-800 hover:border-slate-700 transition-all space-y-3">
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400">
              <ArrowLeftRight className="w-5 h-5" />
            </div>
            <h3 className="font-semibold text-white">Funds Transfer</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Instant balance mutation via Pessimistic Row Lock (SELECT FOR UPDATE) with sub-50ms SLA.
            </p>
          </div>

          <div className="p-5 rounded-2xl bg-slate-950/40 border border-slate-800 hover:border-slate-700 transition-all space-y-3">
            <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
              <CreditCard className="w-5 h-5" />
            </div>
            <h3 className="font-semibold text-white">Credit &amp; Collateral</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              2022 Toyota Vios 1.5G appraised at ₱600,000. Approved credit limit: ₱300,000.
            </p>
          </div>

          <div className="p-5 rounded-2xl bg-slate-950/40 border border-slate-800 hover:border-slate-700 transition-all space-y-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <h3 className="font-semibold text-white">Immutable Audit Trail</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Append-only audit writes committed to PostgreSQL 15+ with automatic data drift rollback.
            </p>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-800/80 px-6 py-4 text-center text-xs text-slate-500">
        CAPSTONE FSE: Core Retail Ledger Engine &bull; React + Vite :3000 &bull; Spring Boot :8082
      </footer>
    </div>
  );
}
