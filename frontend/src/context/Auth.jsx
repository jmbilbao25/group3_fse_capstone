import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, tokenStore } from '../lib/api';

/**
 * Staff session. Login goes to account-service; first sign-in on a device
 * returns MFA_REQUIRED and an emailed code. Only staff roles are let in.
 */
const AuthContext = createContext(null);
const STAFF_KEY = 'aura.console.staff';
const STAFF_ROLES = ['ADMIN', 'TELLER', 'MANAGER'];

/** Zel's Segregation of Duties on the live roles: ADMIN is his compliance and fraud desk, TELLER and MANAGER his branch operations desk. */
export const BRANCH_ROLES = ['TELLER', 'MANAGER'];
export const REVERSAL_CHECKERS = ['ADMIN', 'MANAGER'];
const ACCESS = { '/customers': BRANCH_ROLES, '/sar': ['ADMIN'], '/geo': ['ADMIN'], '/audit': ['ADMIN'] };
export const canOpen = (role, path) => (ACCESS[path] || STAFF_ROLES).includes(role);

/** Display details for seeded staff; unknown staff fall back to their email. */
const DIRECTORY = {
  'usr-1004-adm-001': { name: 'Diana Vance', title: 'Chief Compliance Officer' },
  'usr-1006-mgr-002': { name: 'Carlos Mendoza', title: 'Branch Operations Manager' },
  'usr-1005-boo-001': { name: 'Beatriz Ocampo', title: 'Customer Onboarding Officer' },
  'usr-1007-sec-003': { name: 'Alex Rivera', title: 'Fraud and Security Analyst' },
  'usr-1003-tel-001': { name: 'Crisostomo Ibarra', title: 'Branch Teller' },
  // IDs from infrastructure/oracle/03_seed_sample_data.sql, the seed the docker stack actually loads.
  U0001: { name: 'Diana Vance', title: 'Chief Compliance Officer' },
  U3002: { name: 'Beatriz Ocampo', title: 'Customer Onboarding Officer' },
  U3003: { name: 'Carlos Mendoza', title: 'Branch Operations Manager' },
};
export const staffName = (id) => DIRECTORY[id]?.name || id || 'Unknown';

export function AuthProvider({ children }) {
  const [staff, setStaff] = useState(() => {
    try {
      return tokenStore.get() ? JSON.parse(sessionStorage.getItem(STAFF_KEY)) : null;
    } catch {
      return null;
    }
  });

  const adopt = useCallback((data, email) => {
    const role = String(data.role || '').replace('ROLE_', '');
    if (!STAFF_ROLES.includes(role)) {
      throw new Error('This console is for Aura staff. Customers sign in on the Aura app.');
    }
    const s = { id: data.user_id, email, role, ...(DIRECTORY[data.user_id] || { name: email, title: role }) };
    tokenStore.set(data.access_token);
    sessionStorage.setItem(STAFF_KEY, JSON.stringify(s));
    setStaff(s);
    return { status: 'AUTHENTICATED' };
  }, []);

  const login = useCallback(
    async (email, password) => {
      const { data } = await api.post('/auth/login', { email, password, deviceType: 'WEB', deviceName: 'Aura Console' });
      if (data.status === 'MFA_REQUIRED') return { status: 'MFA_REQUIRED', userId: data.user_id, maskedEmail: data.masked_email };
      return adopt(data, email);
    },
    [adopt],
  );

  const verifyOtp = useCallback(
    async (userId, otp, email) => {
      // VerifyLoginOtpRequest binds snake_case only (no camelCase aliases, unknown keys are dropped).
      const { data } = await api.post('/auth/verify-login-otp', { user_id: userId, otp, device_type: 'WEB', device_name: 'Aura Console' });
      return adopt(data, email);
    },
    [adopt],
  );

  const logout = useCallback(async () => {
    try {
      await api.post('/auth/logout');
    } catch {
      /* the local session ends either way */
    }
    tokenStore.set(null);
    sessionStorage.removeItem(STAFF_KEY);
    setStaff(null);
  }, []);

  useEffect(() => {
    const expire = () => {
      tokenStore.set(null);
      setStaff(null);
    };
    window.addEventListener('aura:session-expired', expire);
    return () => window.removeEventListener('aura:session-expired', expire);
  }, []);

  const value = useMemo(() => ({ staff, login, verifyOtp, logout }), [staff, login, verifyOtp, logout]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
