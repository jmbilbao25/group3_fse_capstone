import React from 'react';
import { Landmark, User, ShieldCheck, FileCheck2, LogOut } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Navbar() {
  const { user, logout } = useAuth();

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
          <p className="text-xs text-slate-400">
            {user?.role === 'ROLE_CUSTOMER' ? 'Secure Retail Online Banking' : 'Balance Mutation & Maker-Checker Engine • Port :3000'}
          </p>
        </div>
      </div>

      {/* Role Badge, Active Operator Profile & Secure Log Out */}
      <div className="flex items-center gap-3 sm:gap-4">
        {/* Manager & Admin Badges */}
        {user?.role === 'ROLE_MANAGER' && (
          <span className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/25 font-mono shadow-sm">
            <ShieldCheck className="w-3.5 h-3.5 text-amber-400" />
            <span>Maker-Checker Workstation</span>
          </span>
        )}

        {user?.role === 'ROLE_ADMIN' && (
          <span className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-300 border border-emerald-500/25 font-mono shadow-sm">
            <FileCheck2 className="w-3.5 h-3.5 text-emerald-400" />
            <span>Audit &amp; Compliance Vault</span>
          </span>
        )}

        {/* User Identity Profile */}
        <div className="flex items-center gap-2.5 pl-2 border-l border-slate-800/80">
          <div className="relative">
            <div className="w-8 h-8 rounded-full bg-slate-800 border border-slate-700/80 flex items-center justify-center text-slate-300 shadow-inner">
              <User className="w-4 h-4" />
            </div>
            <span className="absolute bottom-0 right-0 w-2.5 h-2.5 rounded-full bg-emerald-400 border-2 border-slate-950" />
          </div>
          <div className="text-left hidden md:block">
            <p className="text-xs font-semibold text-white leading-tight">{user?.name || 'Authorized Operator'}</p>
            <p className="text-[10px] font-mono text-slate-400">
              {user?.role === 'ROLE_CUSTOMER'
                ? 'Verified Account Holder'
                : `ID: ${user?.user_id}${user?.title ? ` • ${user.title}` : ''}`}
            </p>
          </div>
        </div>

        {/* Secure Log Out Button */}
        <button
          onClick={logout}
          className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-900 hover:bg-rose-500/15 text-slate-400 hover:text-rose-300 border border-slate-800 hover:border-rose-500/30 transition-all flex items-center gap-1.5 cursor-pointer ml-1 shadow-sm"
          title="Log out and return to secure gateway"
        >
          <LogOut className="w-3.5 h-3.5" />
          <span className="hidden sm:inline">Log Out</span>
        </button>
      </div>
    </header>
  );
}
