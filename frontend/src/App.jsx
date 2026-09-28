import React, { useState, useEffect } from 'react';
import { 
  Bell, 
  X, 
  CheckCircle2, 
  AlertTriangle, 
  Info, 
  ShieldAlert, 
  Sparkles 
} from 'lucide-react';
import Header from './components/Header';
import CustomerPortal from './components/CustomerPortal';
import TellerPortal from './components/TellerPortal';
import AdminPortal from './components/AdminPortal';
import { INITIAL_ACCOUNTS } from './api/client';

export default function App() {
  const [activeRole, setActiveRole] = useState('CUSTOMER');
  const [accounts, setAccounts] = useState(INITIAL_ACCOUNTS);
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

  // Connect to SSE notifications stream
  useEffect(() => {
    let eventSource = null;
    let reconnectTimeout = null;

    const connectSSE = () => {
      try {
        eventSource = new EventSource('/api/v1/notifications/stream?userId=U1001');

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
              amount: data.amount,
              type: data.status === 'SUCCESS' ? 'success' : 'info',
              timestamp: new Date().toLocaleTimeString(),
            };
            addToastNotification(newToast);
          } catch (e) {
            // Unparsed message or ping
          }
        };

        eventSource.onerror = () => {
          setIsLiveConnected(false);
          if (eventSource) {
            eventSource.close();
          }
          // Attempt graceful reconnect after 5 seconds
          reconnectTimeout = setTimeout(connectSSE, 5000);
        };
      } catch (err) {
        setIsLiveConnected(false);
      }
    };

    connectSSE();

    return () => {
      if (eventSource) {
        eventSource.close();
      }
      if (reconnectTimeout) {
        clearTimeout(reconnectTimeout);
      }
    };
  }, []);

  const addToastNotification = (toast) => {
    setLiveNotifications((prev) => [toast, ...prev.slice(0, 4)]);
    setTimeout(() => {
      setLiveNotifications((prev) => prev.filter((t) => t.id !== toast.id));
    }, 7000);
  };

  const removeToastNotification = (id) => {
    setLiveNotifications((prev) => prev.filter((t) => t.id !== id));
  };

  // Callback when Customer initiates a transfer
  const handleTransactionComplete = (mutationData) => {
    const isPending = mutationData.status === 'PENDING_APPROVAL';

    if (isPending) {
      const newPendingItem = {
        transactionId: mutationData.transactionId,
        sourceAccountId: mutationData.accountId,
        destinationAccountId: mutationData.targetAccountId,
        amount: mutationData.mutationAmount,
        initiatorUserId: mutationData.initiatorUserId || 'U1001',
        description: mutationData.description || 'Dual-control transfer review required',
        submittedAt: new Date().toISOString(),
        status: 'PENDING_APPROVAL',
        riskTier: mutationData.mutationAmount >= 500000 ? 'TIER_3_AMLA' : 'TIER_2_MAKER_CHECKER',
      };

      setPendingTransactions((prev) => [newPendingItem, ...prev]);

      addToastNotification({
        id: 'TOAST-' + Math.random().toString(36).substring(2, 9),
        title: 'Maker-Checker Hold Applied',
        message: `Transaction ${mutationData.transactionId} queued for dual-control approval.`,
        amount: `₱${mutationData.mutationAmount.toLocaleString('en-US', { minimumFractionDigits: 4 })}`,
        type: 'warning',
        timestamp: new Date().toLocaleTimeString(),
      });
    } else {
      addToastNotification({
        id: 'TOAST-' + Math.random().toString(36).substring(2, 9),
        title: 'Transfer Completed',
        message: `Transaction ${mutationData.transactionId} settled. Available balance updated.`,
        amount: `₱${mutationData.mutationAmount.toLocaleString('en-US', { minimumFractionDigits: 4 })}`,
        type: 'success',
        timestamp: new Date().toLocaleTimeString(),
      });
    }
  };

  // Callback when Teller/Checker approves or rejects
  const handleApprovalComplete = (txData, outcome) => {
    const amount = txData.amount || txData.mutationAmount || 0;

    if (outcome === 'APPROVED') {
      setAccounts((prev) =>
        prev.map((acc) => {
          if (acc.accountId === txData.sourceAccountId || acc.accountId === txData.accountId) {
            return {
              ...acc,
              holdAmount: Math.max(0, (acc.holdAmount || 0) - amount),
              balanceAmount: acc.balanceAmount - amount,
            };
          }
          if (acc.accountId === txData.destinationAccountId || acc.accountId === txData.targetAccountId) {
            return {
              ...acc,
              balanceAmount: acc.balanceAmount + amount,
              availableBalance: acc.availableBalance + amount,
            };
          }
          return acc;
        })
      );

      addToastNotification({
        id: 'TOAST-' + Math.random().toString(36).substring(2, 9),
        title: 'Checker Approved Transaction',
        message: `Transaction ${txData.transactionId} approved. Debit advice dispatched to MailHog.`,
        amount: `₱${amount.toLocaleString('en-US', { minimumFractionDigits: 4 })}`,
        type: 'success',
        timestamp: new Date().toLocaleTimeString(),
      });
    } else {
      // Rejection: Release hold back to available balance
      setAccounts((prev) =>
        prev.map((acc) => {
          if (acc.accountId === txData.sourceAccountId || acc.accountId === txData.accountId) {
            return {
              ...acc,
              holdAmount: Math.max(0, (acc.holdAmount || 0) - amount),
              availableBalance: acc.availableBalance + amount,
            };
          }
          return acc;
        })
      );

      addToastNotification({
        id: 'TOAST-' + Math.random().toString(36).substring(2, 9),
        title: 'Transaction Rejected',
        message: `Transaction ${txData.transactionId} rejected. Soft hold released to available balance.`,
        amount: `₱${amount.toLocaleString('en-US', { minimumFractionDigits: 4 })}`,
        type: 'warning',
        timestamp: new Date().toLocaleTimeString(),
      });
    }
  };

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 flex flex-col font-sans selection:bg-indigo-500 selection:text-white">
      {/* Top Navigation Bar with Role Switcher & Live Indicators */}
      <Header 
        activeRole={activeRole} 
        setActiveRole={setActiveRole} 
        isLiveConnected={isLiveConnected} 
      />

      {/* Main Body View based on Active Role */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 py-8">
        {activeRole === 'CUSTOMER' && (
          <CustomerPortal
            accounts={accounts}
            setAccounts={setAccounts}
            onTransactionComplete={handleTransactionComplete}
          />
        )}

        {activeRole === 'TELLER' && (
          <TellerPortal
            pendingTransactions={pendingTransactions}
            setPendingTransactions={setPendingTransactions}
            onApprovalComplete={handleApprovalComplete}
          />
        )}

        {activeRole === 'ADMIN' && <AdminPortal />}
      </main>

      {/* Toast Notification Container (Bottom Right) */}
      <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-full pointer-events-none">
        {liveNotifications.map((notif) => (
          <div
            key={notif.id}
            className="pointer-events-auto p-4 rounded-xl shadow-2xl border backdrop-blur-md transition-all duration-300 transform translate-y-0 bg-slate-950/95 border-slate-700/80 flex items-start gap-3"
          >
            <div className="mt-0.5">
              {notif.type === 'success' && <CheckCircle2 className="w-5 h-5 text-emerald-400" />}
              {notif.type === 'warning' && <AlertTriangle className="w-5 h-5 text-amber-400" />}
              {notif.type === 'info' && <Bell className="w-5 h-5 text-blue-400" />}
            </div>

            <div className="flex-1">
              <div className="flex items-center justify-between gap-2">
                <p className="text-xs font-semibold text-white">{notif.title}</p>
                <span className="text-[10px] text-slate-400">{notif.timestamp}</span>
              </div>
              <p className="text-xs text-slate-300 mt-1 leading-snug">{notif.message}</p>
              {notif.amount && (
                <p className="text-xs font-mono font-bold text-indigo-300 mt-1">{notif.amount}</p>
              )}
            </div>

            <button
              onClick={() => removeToastNotification(notif.id)}
              className="text-slate-400 hover:text-white transition"
              title="Dismiss"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>

      {/* Footer */}
      <footer className="border-t border-slate-800 bg-slate-950/60 py-4 text-center text-xs text-slate-400">
        <div className="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-2">
          <span>EastWest Retail Core Ledger Platform &bull; FSE Capstone 2026</span>
          <div className="flex items-center gap-4 text-[11px] text-slate-400">
            <span>Gateway :8080</span>
            <span>CME :8082</span>
            <span>Notifications :8083</span>
            <span>PostgreSQL :5432</span>
            <span>Oracle :1521</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
