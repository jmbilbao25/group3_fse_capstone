import React, { useState } from 'react';
import { 
  Landmark, 
  User, 
  ShieldCheck, 
  FileCheck2, 
  LogOut, 
  Bell, 
  Mail, 
  ChevronDown, 
  Radio, 
  Sparkles,
  CheckCircle2
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Navbar({ onRefreshBalance, isLiveConnected }) {
  const { user, switchRole, logout } = useAuth();
  const [showRoleMenu, setShowRoleMenu] = useState(false);
  const [showNotifMenu, setShowNotifMenu] = useState(false);
  const [showMsgMenu, setShowMsgMenu] = useState(false);

  const demoRoles = [
    {
      role: 'ROLE_CUSTOMER',
      label: 'Juan Dela Cruz',
      subtitle: 'Verified Account Holder (Maker)',
      id: 'U1001',
      badge: 'Private Client',
      badgeColor: 'bg-cyan-50 text-cyan-700 border-cyan-200',
    },
    {
      role: 'ROLE_MANAGER',
      label: 'Beatriz Ocampo',
      subtitle: 'Maker-Checker Supervisor (L1 Reviewer)',
      id: 'U1002',
      badge: 'L1 Checker',
      badgeColor: 'bg-amber-50 text-amber-700 border-amber-200',
    },
    {
      role: 'ROLE_ADMIN',
      label: 'Diana Admin',
      subtitle: 'Chief Compliance & SCN Auditor',
      id: 'U1004',
      badge: 'SCN Vault',
      badgeColor: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    }
  ];

  const handleSelectRole = (r) => {
    switchRole(r);
    setShowRoleMenu(false);
    onRefreshBalance?.();
  };

  return (
    <header className="border-b border-slate-200/80 bg-white/95 backdrop-blur-xl px-4 sm:px-6 py-2.5 sticky top-0 z-40 shadow-sm">
      <div className="max-w-7xl mx-auto flex items-center justify-between">
        {/* Brand & Wordmark */}
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-600 via-cyan-700 to-slate-900 text-white flex items-center justify-center shadow-md shadow-cyan-600/20 ring-1 ring-cyan-500/30">
            <Landmark className="w-5 h-5 text-white" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-extrabold text-lg text-slate-900 tracking-tight flex items-center">
                aura<span className="text-cyan-600">.</span>bank
              </span>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold tracking-wider bg-slate-100 text-slate-700 border border-slate-200">
                PREMIER VAULT
              </span>
            </div>
            <p className="text-[11px] text-slate-500 hidden sm:block">
              {user?.role === 'ROLE_CUSTOMER' 
                ? 'Private Wealth & Corporate Treasury • Oracle XE 21c SCN' 
                : 'Core Ledger Mutation & Dual-Control Engine'}
            </p>
          </div>
        </div>

        {/* Center / Right Header Controls */}
        <div className="flex items-center gap-2 sm:gap-3.5">
          {/* Live Engine Status Pill */}
          <div className="hidden lg:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-50 border border-slate-200 text-[11px] text-slate-600 font-mono">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Ledger :3000</span>
            <span className="text-slate-300">|</span>
            <span className="text-emerald-700 font-medium">SCN 982144</span>
            {isLiveConnected && (
              <span className="text-[10px] font-semibold text-cyan-600 bg-cyan-50 px-1.5 py-0.2 rounded border border-cyan-200">
                SSE LIVE
              </span>
            )}
          </div>

          {/* Quick Notification Badges */}
          <div className="relative">
            <button
              type="button"
              onClick={() => {
                setShowMsgMenu(!showMsgMenu);
                setShowNotifMenu(false);
                setShowRoleMenu(false);
              }}
              title="5 Unread Corporate Notices"
              className="p-2 rounded-xl text-slate-600 hover:text-cyan-700 hover:bg-slate-100 transition-all relative cursor-pointer"
            >
              <Mail className="w-4 h-4" />
              <span className="absolute top-1 right-1 w-4 h-4 rounded-full bg-cyan-600 text-white text-[9px] font-bold flex items-center justify-center ring-2 ring-white">
                5
              </span>
            </button>

            {showMsgMenu && (
              <div className="absolute right-0 mt-2 w-72 bg-white rounded-2xl border border-slate-200 shadow-xl p-3 z-50 animate-in fade-in zoom-in-95">
                <div className="flex items-center justify-between pb-2 border-b border-slate-100">
                  <span className="text-xs font-bold text-slate-900">Corporate Messages</span>
                  <span className="text-[10px] font-semibold text-cyan-600">5 New</span>
                </div>
                <div className="divide-y divide-slate-100 text-xs py-1">
                  <div className="py-2">
                    <p className="font-semibold text-slate-800">Payroll ACH Batch Cleared</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Executive Payroll Deposit of ₱15.0M successfully posted.</p>
                  </div>
                  <div className="py-2">
                    <p className="font-semibold text-slate-800">AMLA Statutory Advisory</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Threshold updates applied pursuant to BSP Cir. 1033.</p>
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="relative">
            <button
              type="button"
              onClick={() => {
                setShowNotifMenu(!showNotifMenu);
                setShowMsgMenu(false);
                setShowRoleMenu(false);
              }}
              title="2 Pending Alerts"
              className="p-2 rounded-xl text-slate-600 hover:text-cyan-700 hover:bg-slate-100 transition-all relative cursor-pointer"
            >
              <Bell className="w-4 h-4" />
              <span className="absolute top-1 right-1 w-4 h-4 rounded-full bg-amber-500 text-white text-[9px] font-bold flex items-center justify-center ring-2 ring-white">
                2
              </span>
            </button>

            {showNotifMenu && (
              <div className="absolute right-0 mt-2 w-72 bg-white rounded-2xl border border-slate-200 shadow-xl p-3 z-50 animate-in fade-in zoom-in-95">
                <div className="flex items-center justify-between pb-2 border-b border-slate-100">
                  <span className="text-xs font-bold text-slate-900">System Notifications</span>
                  <span className="text-[10px] font-semibold text-amber-600">2 Alerts</span>
                </div>
                <div className="divide-y divide-slate-100 text-xs py-1">
                  <div className="py-2">
                    <p className="font-semibold text-slate-800">Maker-Checker Dual Approval</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Transfer TX-551029 (₱650k) pending L2 approval.</p>
                  </div>
                  <div className="py-2">
                    <p className="font-semibold text-slate-800">Credit Facility Statement Ready</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Billing cycle cutoff active. ₱2,000 statement balance due.</p>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* User Profile Pill & Quick Role Switcher */}
          <div className="relative">
            <button
              type="button"
              onClick={() => {
                setShowRoleMenu(!showRoleMenu);
                setShowNotifMenu(false);
                setShowMsgMenu(false);
              }}
              className="flex items-center gap-2 pl-2 pr-2.5 py-1 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 transition-all cursor-pointer"
            >
              <div className="relative">
                <div className="w-7 h-7 rounded-lg bg-gradient-to-tr from-cyan-600 to-slate-800 text-white font-bold text-xs flex items-center justify-center shadow-inner">
                  {user?.first_name ? user.first_name[0] : 'J'}
                </div>
                <span className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full bg-emerald-500 border-2 border-white" />
              </div>
              <div className="text-left hidden md:block">
                <p className="text-xs font-bold text-slate-900 leading-tight">{user?.name || 'Juan Dela Cruz'}</p>
                <p className="text-[10px] text-slate-500 font-medium">
                  {user?.role === 'ROLE_CUSTOMER'
                    ? 'Private Client'
                    : user?.role === 'ROLE_MANAGER'
                    ? 'Checker Manager'
                    : 'Auditor Compliance'}
                </p>
              </div>
              <ChevronDown className="w-3.5 h-3.5 text-slate-400 ml-0.5" />
            </button>

            {/* Role Switcher Dropdown */}
            {showRoleMenu && (
              <div className="absolute right-0 mt-2 w-72 bg-white rounded-2xl border border-slate-200 shadow-xl p-2 z-50 animate-in fade-in zoom-in-95">
                <div className="px-3 py-2 border-b border-slate-100">
                  <div className="flex items-center justify-between">
                    <span className="text-[11px] font-bold text-slate-900 uppercase tracking-wider">Switch Workstation</span>
                    <span className="text-[10px] text-cyan-700 bg-cyan-50 px-2 py-0.5 rounded-full font-mono font-medium">
                      RBAC Gateway
                    </span>
                  </div>
                  <p className="text-[10px] text-slate-400 mt-0.5">Select a designated banking role persona:</p>
                </div>
                <div className="space-y-1 mt-1">
                  {demoRoles.map((dr) => {
                    const isCurrent = user?.role === dr.role;
                    return (
                      <button
                        key={dr.role}
                        type="button"
                        onClick={() => handleSelectRole(dr.role)}
                        className={`w-full p-2.5 rounded-xl text-left transition-all flex items-start gap-2.5 cursor-pointer ${
                          isCurrent
                            ? 'bg-cyan-50/80 border border-cyan-200 text-cyan-950 font-semibold'
                            : 'hover:bg-slate-50 text-slate-700 hover:text-slate-900'
                        }`}
                      >
                        <div className="w-6 h-6 rounded-lg bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-600 mt-0.5 shrink-0">
                          {dr.role === 'ROLE_CUSTOMER' ? (
                            <User className="w-3.5 h-3.5 text-cyan-600" />
                          ) : dr.role === 'ROLE_MANAGER' ? (
                            <ShieldCheck className="w-3.5 h-3.5 text-amber-600" />
                          ) : (
                            <FileCheck2 className="w-3.5 h-3.5 text-emerald-600" />
                          )}
                        </div>
                        <div className="flex-1">
                          <div className="flex items-center justify-between">
                            <span className="text-xs font-bold text-slate-900">{dr.label}</span>
                            <span className={`text-[9px] font-semibold px-1.5 py-0.2 rounded border ${dr.badgeColor}`}>
                              {dr.badge}
                            </span>
                          </div>
                          <p className="text-[10px] text-slate-500 leading-snug">{dr.subtitle}</p>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </div>

          {/* Secure Log Out Button */}
          <button
            onClick={logout}
            className="p-2 sm:px-3 sm:py-1.5 rounded-xl text-xs font-semibold bg-slate-100 hover:bg-rose-50 text-slate-600 hover:text-rose-700 border border-slate-200 hover:border-rose-200 transition-all flex items-center gap-1.5 cursor-pointer"
            title="Log out and return to secure gateway"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Exit</span>
          </button>
        </div>
      </div>
    </header>
  );
}
