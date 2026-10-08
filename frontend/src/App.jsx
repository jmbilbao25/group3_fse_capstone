import React, { useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import Login from './components/Login';
import AdminExecutivePortal from './components/AdminExecutivePortal';
import Toast from './components/Toast';

function MainApp() {
  const { user } = useAuth();
  const [toast, setToast] = useState(null);

  const showToast = (next) => {
    setToast(next);
    setTimeout(() => setToast(null), 6000);
  };

  if (!user) {
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    );
  }

  return (
    <div className="flex min-h-screen flex-col bg-canvas text-fg">
      {/* Skip link */}
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:border focus:border-accent focus:bg-surface focus:px-3 focus:py-2 focus:text-sm focus:font-medium"
      >
        Skip to content
      </a>

      <Navbar />

      <main id="main" className="mx-auto w-full max-w-shell flex-1 px-6 lg:px-10 py-8">
        <Routes>
          <Route path="/admin" element={<AdminExecutivePortal showToast={showToast} />} />
          <Route path="*" element={<Navigate to="/admin" replace />} />
        </Routes>
      </main>

      <Footer />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </div>
  );
}

function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="mt-8 border-t border-line bg-surface">
      <div className="mx-auto flex max-w-shell flex-col gap-2 px-4 py-4 text-xs text-fg-subtle sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <p>&copy; {year} AuraBank Central Retail Operations & Ledger Governance. Dual Control Enabled.</p>
        <p>Regulated by Bangko Sentral ng Pilipinas (BSP Cir. 1033 Compliance).</p>
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
