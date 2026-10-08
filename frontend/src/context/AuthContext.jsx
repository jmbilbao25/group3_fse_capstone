import React, { createContext, useContext, useState, useEffect } from 'react';
import apiClient, { setAccessToken } from '../services/api';

const AuthContext = createContext(null);
const AUTH_STORAGE_KEY = 'fse_auth_active_user';
const TOKEN_STORAGE_KEY = 'fse_auth_access_token';

export function AuthProvider({ children }) {
  // Restore persisted session from storage, or start at null (login required)
  const [user, setUser] = useState(() => {
    try {
      const saved = localStorage.getItem(AUTH_STORAGE_KEY);
      return saved ? JSON.parse(saved) : null;
    } catch (_) {
      return null;
    }
  });

  const [token, setTokenState] = useState(() => {
    try {
      const savedToken = localStorage.getItem(TOKEN_STORAGE_KEY);
      if (savedToken && !savedToken.startsWith('active_jwt_') && !savedToken.startsWith('mock_jwt_')) {
        return savedToken;
      }
      localStorage.removeItem(TOKEN_STORAGE_KEY);
      return null;
    } catch (_) {
      return null;
    }
  });

  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (token) {
      setAccessToken(token);
    } else if (user?.email) {
      // Re-hydrate valid JWT from backend if missing or cleared
      login(user.email, 'password123').catch(() => {
        logout();
      });
    }

    const handleAuthExpired = () => {
      setAccessToken(null);
      setTokenState(null);
      setUser(null);
      localStorage.removeItem(AUTH_STORAGE_KEY);
      localStorage.removeItem(TOKEN_STORAGE_KEY);
    };

    window.addEventListener('auth:expired', handleAuthExpired);
    return () => window.removeEventListener('auth:expired', handleAuthExpired);
  }, [token]);

  const login = async (email, password = 'password123') => {
    setIsLoading(true);
    try {
      const res = await apiClient.post('/auth/login', { email, password });
      const { access_token, role, user_id, user_name, user_title, user: dbUser } = res.data;
      
      setAccessToken(access_token);
      setTokenState(access_token);
      localStorage.setItem(TOKEN_STORAGE_KEY, access_token);
      
      const isAlex = email.toLowerCase().includes('alex');
      const isCarlos = email.toLowerCase().includes('carlos');
      const isDiana = email.toLowerCase().includes('diana') || (!isAlex && !isCarlos);

      const targetUserId = user_id || dbUser?.user_id || (isAlex ? 'usr-1007-sec-003' : isCarlos ? 'usr-1006-mgr-002' : 'usr-1004-adm-001');
      const rawRole = role || dbUser?.role || 'ADMIN';
      const targetRole = rawRole.startsWith('ROLE_') ? rawRole : `ROLE_${rawRole}`;

      const adminName = isAlex ? 'Alex Rivera' : isCarlos ? 'Carlos Mendoza' : 'Diana Vance';
      const adminTitle = isAlex ? 'Fraud Ops Analyst' : isCarlos ? 'Branch Operations Officer' : 'Compliance Lead (Checker)';

      const authenticatedUser = {
        // Core DB 16 Columns (Oracle XE USERS table)
        user_id: targetUserId,
        first_name: dbUser?.first_name || (isAlex ? 'Alex' : isCarlos ? 'Carlos' : 'Diana'),
        middle_name: dbUser?.middle_name || '',
        last_name: dbUser?.last_name || (isAlex ? 'Rivera' : isCarlos ? 'Mendoza' : 'Vance'),
        email: dbUser?.email || email,
        phone_number: dbUser?.phone_number || (isAlex ? '09178889900' : isCarlos ? '09191234567' : '09190001122'),
        dob: dbUser?.dob || (isAlex ? '1988-04-18' : isCarlos ? '1982-08-20' : '1985-03-12'),
        government_id: dbUser?.government_id || (isAlex ? 'GOV-7788-9900' : isCarlos ? 'GOV-5566-7788' : 'GOV-1122-3344'),
        role: targetRole,
        password_hash: dbUser?.password_hash || '$2a$10$Yc8Pb5dWtINUdZYHEQ72fOX0g.GqUn1B3BkspBIiuTkmN.1Jwf1PC',
        pin_hash: null,
        max_concurrent_sessions: dbUser?.max_concurrent_sessions || 3,
        failed_login_attempts: dbUser?.failed_login_attempts || 0,
        status: dbUser?.status || 'ACTIVE',
        created_at: dbUser?.created_at || '2024-01-10T09:15:00Z',
        updated_at: dbUser?.updated_at || new Date().toISOString(),
        
        // UI Presentation helpers
        name: adminName,
        title: adminTitle,
      };
      
      setUser(authenticatedUser);
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(authenticatedUser));
      return { success: true };
    } catch (err) {
      return { success: false, error: err.response?.data?.detail || 'Authentication failed' };
    } finally {
      setIsLoading(false);
    }
  };

  const loginAs = async (personaKey) => {
    let email = 'juan.dc@email.com';
    if (personaKey === 'admin') {
      email = 'diana.admin@bank.com';
    }
    return await login(email, 'password123');
  };

  const updateUserProfile = async (updatedData) => {
    setIsLoading(true);
    try {
      const res = await apiClient.put(`/users/${user?.user_id}`, updatedData);
      const updatedRecord = res.data;
      const computedName = `${updatedRecord.first_name} ${updatedRecord.middle_name ? updatedRecord.middle_name + ' ' : ''}${updatedRecord.last_name}`;
      
      const mergedUser = {
        ...user,
        ...updatedRecord,
        name: computedName,
      };
      setUser(mergedUser);
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(mergedUser));
      return { success: true, user: mergedUser };
    } catch (err) {
      return { 
        success: false, 
        error: err.response?.data?.detail || 'Failed to update user profile in Core Database.' 
      };
    } finally {
      setIsLoading(false);
    }
  };

  const logout = async () => {
    try {
      await apiClient.post('/auth/logout');
    } catch (_) {}
    setAccessToken(null);
    setTokenState(null);
    setUser(null);
    localStorage.removeItem(AUTH_STORAGE_KEY);
    localStorage.removeItem(TOKEN_STORAGE_KEY);
  };

  // Switch role utility with genuine backend token authentication
  const switchRole = async (newRole) => {
    if (newRole === 'ROLE_CUSTOMER' || newRole === 'CUSTOMER') {
      await login('juan.dc@email.com', 'password123');
    } else if (newRole === 'ROLE_ADMIN' || newRole === 'ADMIN') {
      await login('diana.admin@bank.com', 'password123');
    }
  };

  return (
    <AuthContext.Provider value={{ user, token, isLoading, login, loginAs, logout, switchRole, updateUserProfile }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
