import React, { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import Login from './components/Login';
import CustomerPortal from './components/CustomerPortal';
import ManagerPortal from './components/ManagerPortal';
import AdminPortal from './components/AdminPortal';
import Toast from './components/Toast';
import apiClient, { mockState } from './services/api';

function MainApp() {
  const { user } = useAuth();
  const [activeAccountId, setActiveAccountId] = useState('1000-2000-3001');
  const [balance, setBalance] = useState({
    account_id: '1000-2000-3001',
    account_type: 'SAVINGS',
    currency: 'PHP',
    current_balance: 15000000.0000,
    held_balance: 725000.0000,
    available_balance: 14275000.0000,
    credit_limit: 0.0000,
  });
  const [toast, setToast] = useState(null);

  const fetchBalance = async (targetId) => {
    const accId = targetId || activeAccountId;
    try {
      const res = await apiClient.get(`/accounts/${accId}/balance`);
      setBalance(res.data);
    } catch (_) {
      const isCredit = accId.includes('3003') || accId === 'A2003';
      setBalance(isCredit ? { ...mockState.creditAccount } : { ...mockState.account });
    }
  };

  const handleSwitchAccount = async (targetId) => {
    setActiveAccountId(targetId);
    await fetchBalance(targetId);
  };

  useEffect(() => {
    if (user) {
      fetchBalance(activeAccountId);
    }
  }, [user?.role]);

  const showToast = (toastObj) => {
    setToast(toastObj);
    setTimeout(() => {
      setToast(null);
    }, 6000);
  };

  // If unauthenticated, present the Secure Banking Login Gateway
  if (!user) {
    return (
      <>
        <Login onLoginSuccess={fetchBalance} />
        <Toast toast={toast} onClose={() => setToast(null)} />
      </>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans selection:bg-indigo-500 selection:text-white">
      <Navbar onRefreshBalance={fetchBalance} />

      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 md:p-8 space-y-6">
        {/* Dynamic Context Header Banner (Dedicated for Operations & Compliance Consoles) */}
        {user?.role !== 'ROLE_CUSTOMER' && (
          <div className="p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-indigo-950/50 via-slate-900/80 to-slate-900 border border-indigo-500/20 shadow-2xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4 backdrop-blur-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                  {user?.role === 'ROLE_MANAGER' && 'Operations Manager Console'}
                  {user?.role === 'ROLE_ADMIN' && 'Audit & Compliance Console'}
                </span>
                <span className="flex items-center gap-1.5 text-[11px] text-emerald-400 font-mono">
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                  Ledger Engine Online
                </span>
              </div>
              <h2 className="text-xl sm:text-2xl font-bold text-white mt-1.5 tracking-tight">
                {user?.role === 'ROLE_MANAGER' && 'Maker-Checker Review Console'}
                {user?.role === 'ROLE_ADMIN' && 'Audit & Compliance Workspace'}
              </h2>
              <p className="text-xs text-slate-400 mt-1 max-w-3xl leading-relaxed">
                {user?.role === 'ROLE_MANAGER' && 'Dual-control review workstation for pending high-value transfers and soft-hold releases.'}
                {user?.role === 'ROLE_ADMIN' && 'Immutable ledger mutation monitoring and statutory AMLA CTR compliance registry.'}
              </p>
            </div>
          </div>
        )}

        {/* Dynamic Role Views: STRICT ISOLATION */}
        {user?.role === 'ROLE_CUSTOMER' && (
          <CustomerPortal
            balance={balance}
            onTransactionComplete={() => fetchBalance(activeAccountId)}
            onSwitchAccount={handleSwitchAccount}
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
          PostgreSQL :5432 &bull; Vite :3000 &bull; Notification :8083 &bull; BSP Cir. 808
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
