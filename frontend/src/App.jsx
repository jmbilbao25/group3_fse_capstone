import React, { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import CustomerPortal from './components/CustomerPortal';
import ManagerPortal from './components/ManagerPortal';
import AdminPortal from './components/AdminPortal';
import Toast from './components/Toast';
import apiClient, { mockState } from './services/api';

function MainApp() {
  const { user } = useAuth();
  const [balance, setBalance] = useState({
    account_id: '1000-2000-3001',
    account_type: 'SAVINGS',
    currency: 'PHP',
    current_balance: 1000000.0000,
    held_balance: 725000.0000,
    available_balance: 275000.0000,
  });
  const [toast, setToast] = useState(null);

  const fetchBalance = async () => {
    try {
      const res = await apiClient.get(`/accounts/${balance.account_id}/balance`);
      setBalance(res.data);
    } catch (_) {
      setBalance({ ...mockState.account });
    }
  };

  useEffect(() => {
    fetchBalance();
  }, []);

  const showToast = (toastObj) => {
    setToast(toastObj);
    setTimeout(() => {
      setToast(null);
    }, 6000);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans selection:bg-indigo-500 selection:text-white">
      <Navbar onRefreshBalance={fetchBalance} />

      <main className="flex-1 max-w-7xl w-full mx-auto p-6 md:p-8 space-y-8">
        {/* Dynamic Context Header Banner */}
        <div className="p-6 rounded-2xl bg-gradient-to-r from-indigo-950/50 via-slate-900/80 to-slate-900 border border-indigo-500/20 shadow-2xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4 backdrop-blur-md">
          <div>
            <div className="flex items-center gap-2">
              <span className="px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                {user?.role === 'ROLE_CUSTOMER' && 'Verified Retail Client'}
                {user?.role === 'ROLE_MANAGER' && 'Operations Manager Console'}
                {user?.role === 'ROLE_ADMIN' && 'Audit & Compliance Console'}
              </span>
              <span className="flex items-center gap-1.5 text-[11px] text-emerald-400 font-mono">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                {user?.role === 'ROLE_CUSTOMER' ? 'Secure Banking Session' : 'Ledger Engine Online'}
              </span>
            </div>
            <h2 className="text-2xl font-bold text-white mt-2 tracking-tight">
              {user?.role === 'ROLE_CUSTOMER' && `Welcome back, ${user?.name}`}
              {user?.role === 'ROLE_MANAGER' && 'Bank Operations Manager Console & Maker-Checker Review'}
              {user?.role === 'ROLE_ADMIN' && 'Audit, Compliance & Immutable SCN Vault Monitoring'}
            </h2>
            {user?.role !== 'ROLE_CUSTOMER' && (
              <p className="text-xs text-slate-400 mt-1 max-w-3xl leading-relaxed">
                {user?.role === 'ROLE_MANAGER' && 'Level 1 Checker workstation: Authorize high-value transfers, enforce segregation of duties, and manage dual-control queue.'}
                {user?.role === 'ROLE_ADMIN' && 'Dual-storage core monitoring: Oracle XE 21c (Master Ledger) and PostgreSQL 15 (Immutable Append-Only Audit Vault).'}
              </p>
            )}
          </div>
        </div>

        {/* Dynamic Role Views */}
        {user?.role === 'ROLE_CUSTOMER' && (
          <CustomerPortal
            balance={balance}
            onTransactionComplete={fetchBalance}
            showToast={showToast}
          />
        )}

        {user?.role === 'ROLE_MANAGER' && (
          <ManagerPortal
            onActionComplete={fetchBalance}
            showToast={showToast}
          />
        )}

        {user?.role === 'ROLE_ADMIN' && (
          <AdminPortal />
        )}
      </main>

      <Toast toast={toast} onClose={() => setToast(null)} />

      {/* Footer */}
      <footer className="border-t border-slate-800/80 px-6 py-4 flex flex-col sm:flex-row items-center justify-between text-xs text-slate-500 max-w-7xl w-full mx-auto">
        <p>CAPSTONE FSE (Group 3) &bull; Core Retail Ledger &amp; Balance Mutation Engine</p>
        <p className="font-mono text-[11px] mt-1 sm:mt-0 text-slate-400">
          React 18 &bull; Vite :3000 &bull; Oracle XE :1521 &bull; PostgreSQL :5432 &bull; Notification :8083
        </p>
      </footer>
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <MainApp />
    </AuthProvider>
  );
}
