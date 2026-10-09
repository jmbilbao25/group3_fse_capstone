import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/Auth';
import { ToastProvider } from './components/ui';
import Shell from './components/Shell';
import Login from './pages/Login';
import Overview from './pages/Overview';
import Kyc from './pages/Kyc';
import Transfers from './pages/Transfers';
import Sar from './pages/Sar';
import Geo from './pages/Geo';
import Audit from './pages/Audit';
import Customers from './pages/Customers';
import Reversals from './pages/Reversals';

function Routed() {
  const { staff } = useAuth();
  if (!staff) return <Login />;
  return (
    <Routes>
      <Route element={<Shell />}>
        <Route index element={<Overview />} />
        <Route path="customers" element={<Customers />} />
        <Route path="kyc" element={<Kyc />} />
        <Route path="transfers" element={<Transfers />} />
        <Route path="reversals" element={<Reversals />} />
        <Route path="sar" element={<Sar />} />
        <Route path="geo" element={<Geo />} />
        <Route path="audit" element={<Audit />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <ToastProvider>
          <Routed />
        </ToastProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}
