import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import Login from './components/Login';
import CustomerPortal from './components/CustomerPortal';
import AdminPortal from './components/AdminPortal';
import Toast from './components/Toast';
import LiveNotices from './components/LiveNotices';
import apiClient, { mockState } from './services/api';

/*
 * Application shell.
 *
 * Two things changed structurally here.
 *
 * First, the footer. It used to print "Gateway :8080 / CME :8082 / Kafka :9092 /
 * Redis :6379 / Oracle XE 21c / BSP Cir. 1033" on every screen. Infrastructure
 * ports are build trivia, not product information, and printing them on a
 * customer's banking page is the clearest possible signal that nobody decided
 * who the screen was for. The footer now carries the two things a retail banking
 * customer actually looks for.
 *
 * Second, the role context banner. It was a bordered panel restating the page
 * title with an eyebrow, a pulsing dot, and a sentence of description above
 * every staff view. The portals now own their own headings, so the shell does
 * not narrate them.
 */

const ROLE_HOME = {
  ROLE_ADMIN: '/admin',
  ADMIN: '/admin',
  ROLE_CUSTOMER: '/customer',
  CUSTOMER: '/customer',
};

const INITIAL_BALANCE = {
  account_id: '1000-2000-3001',
  account_type: 'SAVINGS',
  currency: 'PHP',
  current_balance: 15000000.0,
  held_balance: 0.0,
  available_balance: 15000000.0,
  credit_limit: 0.0,
};

function MainApp() {
  const { user } = useAuth();
  const [activeAccountId, setActiveAccountId] = useState('1000-2000-3001');
  const [balance, setBalance] = useState(INITIAL_BALANCE);
  const [toast, setToast] = useState(null);

  const [isLiveConnected, setIsLiveConnected] = useState(false);
  const [liveNotices, setLiveNotices] = useState([]);

  const addNotice = (notice) => {
    setLiveNotices((prev) => [notice, ...prev.slice(0, 4)]);
    setTimeout(() => {
      setLiveNotices((prev) => prev.filter((n) => n.id !== notice.id));
    }, 7000);
  };

  const dismissNotice = (id) => {
    setLiveNotices((prev) => prev.filter((n) => n.id !== id));
  };

  const showToast = (next) => {
    setToast(next);
    setTimeout(() => setToast(null), 6000);
  };

  const fetchBalance = async (targetId) => {
    const accountId = targetId || activeAccountId;
    try {
      const res = await apiClient.get(`/accounts/${accountId}/balance`);
      setBalance(res.data);
    } catch {
      const isCredit = accountId.includes('3003') || accountId === 'A2003';
      setBalance(isCredit ? { ...mockState.creditAccount } : { ...mockState.account });
    }
  };

  const handleSwitchAccount = async (targetId) => {
    setActiveAccountId(targetId);
    await fetchBalance(targetId);
  };

  // Server-sent settlement notices. Reconnects with a fixed 5s backoff, and the
  // header reports the state rather than failing silently.
  useEffect(() => {
    if (!user) return;

    let source = null;
    let retry = null;

    const connect = () => {
      try {
        source = new EventSource(
          `/api/v1/notifications/stream?userId=${user?.user_id || 'U1001'}`
        );

        source.onopen = () => setIsLiveConnected(true);

        source.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            addNotice({
              id: `N-${Math.random().toString(36).slice(2, 9)}`,
              title: data.status === 'SUCCESS' ? 'Transfer settled' : 'Account notice',
              message:
                data.message ||
                `Transaction ${data.transferId || ''} status updated.`.trim(),
              amount: data.amount != null ? parseFloat(data.amount) : null,
              type: data.status === 'SUCCESS' ? 'success' : 'info',
              at: new Date(),
            });
          } catch {
            /* Heartbeat frame. */
          }
        };

        source.onerror = () => {
          setIsLiveConnected(false);
          source?.close();
          retry = setTimeout(connect, 5000);
        };
      } catch {
        setIsLiveConnected(false);
      }
    };

    connect();

    return () => {
      source?.close();
      if (retry) clearTimeout(retry);
    };
  }, [user]);

  useEffect(() => {
    if (user) fetchBalance(activeAccountId);
  }, [user?.role]);

  const home = ROLE_HOME[user?.role] || '/customer';

  if (!user) {
    return (
      <Routes>
        <Route path="/login" element={<Login onLoginSuccess={fetchBalance} />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    );
  }

  return (
    <div className="flex min-h-screen flex-col bg-canvas">
      {/* Skip link. The staff portals put a long filter bar and a wide table
          between the header and the content, so bypassing it matters. */}
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:border focus:border-accent focus:bg-surface focus:px-3 focus:py-2 focus:text-sm focus:font-medium"
      >
        Skip to content
      </a>

      <Navbar onRefreshBalance={fetchBalance} isLiveConnected={isLiveConnected} />

      <main id="main" className="mx-auto w-full max-w-shell flex-1 px-4 py-6 sm:px-6">
        <Routes>
          <Route
            path="/customer"
            element={
              (user.role === 'ROLE_CUSTOMER' || user.role === 'CUSTOMER') ? (
                <CustomerPortal
                  balance={balance}
                  onTransactionComplete={() => fetchBalance(activeAccountId)}
                  onSwitchAccount={handleSwitchAccount}
                  showToast={showToast}
                />
              ) : (
                <Navigate to={home} replace />
              )
            }
          />

          <Route
            path="/admin"
            element={
              (user.role === 'ROLE_ADMIN' || user.role === 'ADMIN') ? <AdminPortal /> : <Navigate to={home} replace />
            }
          />

          <Route path="/manager" element={<Navigate to={home} replace />} />
          <Route path="/teller" element={<Navigate to={home} replace />} />
          <Route path="*" element={<Navigate to={home} replace />} />
        </Routes>
      </main>

      <Footer />

      <LiveNotices notices={liveNotices} onDismiss={dismissNotice} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </div>
  );
}

/*
 * Footer. Two facts a retail customer looks for and can act on: who insures the
 * deposit, and that the session is encrypted. No port numbers, no circular
 * numbers, no container names.
 */
function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="mt-4 border-t border-line bg-surface">
      <div className="mx-auto flex max-w-shell flex-col gap-2 px-4 py-4 text-xs text-fg-subtle sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <p>&copy; {year} AuraBank. Deposits insured by PDIC up to PHP 500,000 per depositor.</p>
        <p>Regulated by the Bangko Sentral ng Pilipinas.</p>
      </div>
    </footer>
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
