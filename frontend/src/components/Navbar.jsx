import React from 'react';
import { Landmark, Shield, User, RefreshCw, CheckCircle2 } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Navbar({ onRefreshBalance }) {
  const { user, switchRole } = useAuth();

  return (
    <header className="border-b border-slate-800/80 bg-slate-950/90 backdrop-blur-xl px-6 py-3.5 flex items-center justify-between sticky top-0 z-40 shadow-lg shadow-black/20">
      {/* Brand & System Spec */}
      <div className="flex items-center gap-3.5">
        <div className="p-2.5 bg-gradient-to-br from-indigo-500 via-indigo-600 to-indigo-700 rounded-xl shadow-lg shadow-indigo-500/25 flex items-center justify-center">
          <Landmark className="w-5 h-5 text-white" />
        </div>
        <div>
          <div className="flex items-center gap-2">
            <h1 className="font-bold text-base text-white tracking-tight">EastWest Retail Core Ledger</h1>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-medium bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              v1.0-PROD
            </span>
          </div>
          <p className="text-xs text-slate-400">Balance Mutation &amp; Maker-Checker Engine &bull; Port :3000</p>
        </div>
      </div>

      {/* Role Navigation & Active User */}
      <div className="flex items-center gap-4">
        {/* Role Switcher for Capstone Demonstration */}
        <div className="hidden sm:flex items-center gap-1 bg-slate-900/90 border border-slate-800 p-1 rounded-xl text-xs shadow-inner">
          <button
            onClick={() => switchRole('ROLE_CUSTOMER')}
            className={`px-3.5 py-1.5 rounded-lg font-medium transition-all ${
              user?.role === 'ROLE_CUSTOMER'
                ? 'bg-indigo-600 text-white shadow-sm font-semibold'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            Customer Portal
          </button>
          <button
            onClick={() => switchRole('ROLE_MANAGER')}
            className={`px-3.5 py-1.5 rounded-lg font-medium transition-all ${
              user?.role === 'ROLE_MANAGER'
                ? 'bg-amber-600 text-white shadow-sm font-semibold'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            Manager Console (Maker-Checker)
          </button>
          <button
            onClick={() => switchRole('ROLE_ADMIN')}
            className={`px-3.5 py-1.5 rounded-lg font-medium transition-all ${
              user?.role === 'ROLE_ADMIN'
                ? 'bg-emerald-600 text-white shadow-sm font-semibold'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            Audit &amp; Compliance
          </button>
        </div>

        {/* User Badge */}
        <div className="flex items-center gap-2.5 pl-2 border-l border-slate-800/80">
          <div className="relative">
            <div className="w-8 h-8 rounded-full bg-slate-800 border border-slate-700/80 flex items-center justify-center text-slate-300">
              <User className="w-4 h-4" />
            </div>
            <span className="absolute bottom-0 right-0 w-2.5 h-2.5 rounded-full bg-emerald-400 border-2 border-slate-950" />
          </div>
          <div className="text-left hidden md:block">
            <p className="text-xs font-semibold text-white leading-tight">{user?.name || 'Authorized User'}</p>
            <p className="text-[10px] font-mono text-slate-400">ID: {user?.user_id}</p>
          </div>
        </div>
      </div>
    </header>
  );
}
