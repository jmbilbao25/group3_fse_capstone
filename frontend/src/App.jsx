import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { 
  Bell, 
  X, 
  CheckCircle2, 
  AlertTriangle, 
  Info, 
  ShieldAlert, 
  Sparkles 
} from 'lucide-react';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import Login from './components/Login';
import CustomerPortal from './components/CustomerPortal';
import ManagerPortal from './components/ManagerPortal';
import TellerPortal from './components/TellerPortal';
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

  // SSE Live Notification Streaming State (Integrated from Group 3 Event Stream)
  const [isLiveConnected, setIsLiveConnected] = useState(false);
  const [liveNotifications, setLiveNotifications] = useState([]);
  const [pendingTransactions, setPendingTransactions] = useState([
    {
      transactionId: 'TX-772190',
      sourceAccountId: 'A2001',
      destinationAccountId: 'A2002',
      amount: 75000.0,
      initiatorUserId: 'U1001',
      description: 'Vendor Invoice Settlement (Hardware Supplier)',
      submittedAt: new Date(Date.now() - 1000 * 60 * 14).toISOString(),
      status: 'PENDING_APPROVAL',
      riskTier: 'TIER_2_MAKER_CHECKER',
    },
    {
      transactionId: 'TX-551029',
      sourceAccountId: 'A2001',
      destinationAccountId: 'A2002',
      amount: 650000.0,
      initiatorUserId: 'U1001',
      description: 'Commercial Real Estate Acquisition Escrow',
      submittedAt: new Date(Date.now() - 1000 * 60 * 32).toISOString(),
      status: 'PENDING_APPROVAL',
      riskTier: 'TIER_3_AMLA',
    },
  ]);

  const addToastNotification = (newToast) => {
    setLiveNotifications((prev) => [newToast, ...prev.slice(0, 4)]);
    setTimeout(() => {
      setLiveNotifications((prev) => prev.filter((t) => t.id !== newToast.id));
    }, 7000);
  };

  const removeToastNotification = (id) => {
    setLiveNotifications((prev) => prev.filter((t) => t.id !== id));
  };

  // Connect to SSE notifications stream
  useEffect(() => {
    let eventSource = null;
    let reconnectTimeout = null;

    const connectSSE = () => {
      try {
        const streamUserId = user?.userId || 'U1001';
        eventSource = new EventSource(`/api/v1/notifications/stream?userId=${streamUserId}`);

        eventSource.onopen = () => {
          setIsLiveConnected(true);
        };

        eventSource.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            const newToast = {
              id: 'TOAST-' + Math.random().toString(36).substring(2, 9),
              title: data.status === 'SUCCESS' ? 'Transfer Settled' : 'System Notification',
              message: data.message || `Transaction ${data.transferId || ''} status update received.`,
              amount: data.amount ? `₱${parseFloat(data.amount).toLocaleString('en-US', { minimumFractionDigits: 2 })}` : null,
              type: data.status === 'SUCCESS' ? 'success' : 'info',
              timestamp: new Date().toLocaleTimeString(),
            };
            addToastNotification(newToast);
          } catch (_) {
            // Heartbeat ping or unparsed stream data
          }
        };

        eventSource.onerror = () => {
          setIsLiveConnected(false);
          if (eventSource) {
            eventSource.close();
          }
          reconnectTimeout = setTimeout(connectSSE, 5000);
        };
      } catch (_) {
        setIsLiveConnected(false);
      }
    };

    if (user) {
      connectSSE();
    }

    return () => {
      if (eventSource) {
        eventSource.close();
      }
      if (reconnectTimeout) {
        clearTimeout(reconnectTimeout);
      }
    };
  }, [user]);

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

  // Helper to determine home route based on role
  const getRoleHome = () => {
    if (user?.role === 'ROLE_MANAGER') return '/manager';
    if (user?.role === 'ROLE_ADMIN') return '/admin';
    return '/customer';
  };

  // If unauthenticated, route to Login gateway
  if (!user) {
    return (
      <Routes>
        <Route path="/login" element={<Login onLoginSuccess={fetchBalance} />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    );
  }

  return (
    <div className="min-h-screen bg-slate-100/70 text-slate-900 flex flex-col font-sans selection:bg-cyan-600 selection:text-white">
      <Navbar onRefreshBalance={fetchBalance} isLiveConnected={isLiveConnected} />

      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 space-y-5">
        {/* Dynamic Context Header Banner for Manager and Admin */}
        {user?.role !== 'ROLE_CUSTOMER' && (
          <div className="p-4 sm:p-5 rounded-2xl bg-white border border-slate-200/90 shadow-sm flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-2">
                <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-cyan-50 text-cyan-800 border border-cyan-200">
                  {user?.role === 'ROLE_MANAGER' && 'Operations Manager Console'}
                  {user?.role === 'ROLE_ADMIN' && 'Audit & Compliance Console'}
                </span>
                <span className="flex items-center gap-1.5 text-[11px] text-emerald-700 font-mono font-medium">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                  Ledger Engine Online {isLiveConnected && '(SSE Active)'}
                </span>
              </div>
              <h2 className="text-xl sm:text-2xl font-bold text-slate-900 mt-1.5 tracking-tight">
                {user?.role === 'ROLE_MANAGER' && 'Maker-Checker Review Console'}
                {user?.role === 'ROLE_ADMIN' && 'Audit & Compliance Workspace'}
              </h2>
              <p className="text-xs text-slate-500 mt-1 max-w-3xl leading-relaxed">
                {user?.role === 'ROLE_MANAGER' && 'Dual-control review workstation for pending high-value transfers and soft-hold releases.'}
                {user?.role === 'ROLE_ADMIN' && 'Immutable ledger mutation monitoring and statutory AMLA CTR compliance registry.'}
              </p>
            </div>
          </div>
        )}

        {/* React Router v6 Declarative Route Hierarchy */}
        <Routes>
          <Route
            path="/customer"
            element={
              user?.role === 'ROLE_CUSTOMER' ? (
                <CustomerPortal
                  balance={balance}
                  onTransactionComplete={() => fetchBalance(activeAccountId)}
                  onSwitchAccount={handleSwitchAccount}
                  showToast={showToast}
                />
              ) : (
                <Navigate to={getRoleHome()} replace />
              )
            }
          />

          <Route
            path="/manager"
            element={
              user?.role === 'ROLE_MANAGER' ? (
                <ManagerPortal
                  onActionComplete={fetchBalance}
                  showToast={showToast}
                />
              ) : (
                <Navigate to={getRoleHome()} replace />
              )
            }
          />

          <Route
            path="/teller"
            element={
              user?.role === 'ROLE_MANAGER' ? (
                <TellerPortal
                  pendingTransactions={pendingTransactions}
                  setPendingTransactions={setPendingTransactions}
                  onApprovalComplete={() => fetchBalance(activeAccountId)}
                />
              ) : (
                <Navigate to={getRoleHome()} replace />
              )
            }
          />

          <Route
            path="/admin"
            element={
              user?.role === 'ROLE_ADMIN' ? (
                <AdminPortal />
              ) : (
                <Navigate to={getRoleHome()} replace />
              )
            }
          />

          <Route path="/" element={<Navigate to={getRoleHome()} replace />} />
          <Route path="*" element={<Navigate to={getRoleHome()} replace />} />
        </Routes>
      </main>

      {/* Floating SSE Live Toast Notifications (Bottom Right) */}
      <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-full pointer-events-none">
        {liveNotifications.map((notif) => (
          <div
            key={notif.id}
            className="pointer-events-auto p-4 rounded-2xl shadow-xl border backdrop-blur-md transition-all duration-300 transform translate-y-0 bg-white/95 border-slate-200 flex items-start gap-3"
          >
            <div className="mt-0.5">
              {notif.type === 'success' && <CheckCircle2 className="w-5 h-5 text-emerald-600" />}
              {notif.type === 'warning' && <AlertTriangle className="w-5 h-5 text-amber-600" />}
              {notif.type === 'info' && <Bell className="w-5 h-5 text-cyan-600" />}
            </div>

            <div className="flex-1">
              <div className="flex items-center justify-between gap-2">
                <p className="text-xs font-bold text-slate-900">{notif.title}</p>
                <span className="text-[10px] text-slate-400">{notif.timestamp}</span>
              </div>
              <p className="text-xs text-slate-600 mt-1 leading-snug">{notif.message}</p>
              {notif.amount && (
                <p className="text-xs font-mono font-bold text-cyan-700 mt-1">{notif.amount}</p>
              )}
            </div>

            <button
              onClick={() => removeToastNotification(notif.id)}
              className="text-slate-400 hover:text-slate-700 transition cursor-pointer"
              title="Dismiss"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>

      <Toast toast={toast} onClose={() => setToast(null)} />

      {/* Integrated Enterprise Footer */}
      <footer className="border-t border-slate-200/80 bg-white/80 px-6 py-4 mt-8 flex flex-col sm:flex-row items-center justify-between text-xs text-slate-500 max-w-7xl w-full mx-auto rounded-t-xl">
        <p className="font-medium text-slate-600">AuraBank &bull; Premier Vault Core Retail Banking Ledger &amp; Mutation Engine</p>
        <div className="flex flex-wrap items-center gap-3 font-mono text-[11px] mt-1 sm:mt-0 text-slate-500">
          <span>Gateway :8080</span>
          <span>&bull;</span>
          <span>CME :8082</span>
          <span>&bull;</span>
          <span>Kafka :9092</span>
          <span>&bull;</span>
          <span>Redis :6379</span>
          <span>&bull;</span>
          <span>Oracle XE 21c</span>
          <span>&bull;</span>
          <span>BSP Cir. 1033</span>
        </div>
      </footer>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <MainApp />
      </AuthProvider>
    </BrowserRouter>
  );
}
