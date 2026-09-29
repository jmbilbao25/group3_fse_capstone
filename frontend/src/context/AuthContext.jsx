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
      
      const targetUserId = user_id || dbUser?.user_id || (email.includes('carlos') ? 'U3003' : email.includes('manager') || email.includes('beatriz') ? 'U3002' : email.includes('admin') ? 'U0001' : 'U1001');
      const rawRole = role || dbUser?.role || (email.includes('carlos') || email.includes('manager') || email.includes('beatriz') ? 'ROLE_MANAGER' : email.includes('admin') ? 'ROLE_ADMIN' : 'ROLE_CUSTOMER');
      const targetRole = rawRole.startsWith('ROLE_') ? rawRole : `ROLE_${rawRole}`;

      const authenticatedUser = {
        // Core DB 16 Columns (Oracle XE USERS table)
        user_id: targetUserId,
        first_name: dbUser?.first_name || (targetUserId === 'U3003' ? 'Carlos' : targetUserId === 'U3002' ? 'Beatriz' : targetUserId === 'U0001' ? 'Diana' : 'Juan'),
        middle_name: dbUser?.middle_name || (targetUserId === 'U3003' ? 'Eduardo' : targetUserId === 'U3002' ? 'Santos' : targetUserId === 'U0001' ? 'Marie' : 'Reyes'),
        last_name: dbUser?.last_name || (targetUserId === 'U3003' ? 'Mendoza' : targetUserId === 'U3002' ? 'Ocampo' : targetUserId === 'U0001' ? 'Vance' : 'Dela Cruz'),
        email: dbUser?.email || email,
        phone_number: dbUser?.phone_number || (targetUserId === 'U3003' ? '09171122334' : targetUserId === 'U3002' ? '09204445566' : targetUserId === 'U0001' ? '09190001122' : '09171234567'),
        dob: dbUser?.dob || (targetUserId === 'U3003' ? '1982-11-05' : targetUserId === 'U3002' ? '1984-07-19' : targetUserId === 'U0001' ? '1985-03-12' : '1990-05-14'),
        government_id: dbUser?.government_id || (targetUserId === 'U3003' ? 'PRC-5544-3322' : targetUserId === 'U3002' ? 'PRC-9988-7711' : targetUserId === 'U0001' ? 'GOV-1122-3344' : 'PSA-1234-5678'),
        role: targetRole,
        password_hash: dbUser?.password_hash || '$2a$10$Yc8Pb5dWtINUdZYHEQ72fOX0g.GqUn1B3BkspBIiuTkmN.1Jwf1PC',
        pin_hash: dbUser?.pin_hash || (targetRole === 'ROLE_CUSTOMER' ? '$2a$12$k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8' : null),
        max_concurrent_sessions: dbUser?.max_concurrent_sessions || 3,
        failed_login_attempts: dbUser?.failed_login_attempts || 0,
        status: dbUser?.status || 'ACTIVE',
        created_at: dbUser?.created_at || '2024-01-10T09:15:00Z',
        updated_at: dbUser?.updated_at || new Date().toISOString(),
        
        // UI Presentation helpers
        name: user_name || `${dbUser?.first_name || (targetUserId === 'U3003' ? 'Carlos' : targetUserId === 'U3002' ? 'Beatriz' : targetUserId === 'U0001' ? 'Diana' : 'Juan')} ${dbUser?.last_name || (targetUserId === 'U3003' ? 'Mendoza' : targetUserId === 'U3002' ? 'Ocampo' : targetUserId === 'U0001' ? 'Vance' : 'Dela Cruz')}`,
        title: user_title || (targetUserId === 'U3003' || targetUserId === 'U3002' ? 'Operations Manager' : targetUserId === 'U0001' ? 'System Auditor & Compliance' : 'Retail Account Holder'),
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
    if (personaKey === 'manager_l1' || personaKey === 'manager_beatriz' || personaKey === 'beatriz') {
      email = 'beatriz.ocampo@bank.com';
    } else if (personaKey === 'manager_l2' || personaKey === 'manager_carlos' || personaKey === 'carlos') {
      email = 'carlos.mendoza@bank.com';
    } else if (personaKey === 'admin') {
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
  const switchRole = async (newRole, managerId = 'U3002') => {
    if (newRole === 'ROLE_CUSTOMER') {
      await login('juan.dc@email.com', 'password123');
    } else if (newRole === 'ROLE_MANAGER') {
      if (managerId === 'U3003') {
        await login('carlos.mendoza@bank.com', 'password123');
      } else {
        await login('beatriz.ocampo@bank.com', 'password123');
      }
    } else if (newRole === 'ROLE_ADMIN') {
      await login('diana.admin@bank.com', 'password123');
    }
  };

  const switchManager = async (managerId) => {
    await switchRole('ROLE_MANAGER', managerId);
  };

  return (
    <AuthContext.Provider value={{ user, token, isLoading, login, loginAs, logout, switchRole, switchManager, updateUserProfile }}>
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
