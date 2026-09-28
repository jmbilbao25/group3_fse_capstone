import React, { createContext, useContext, useState, useEffect } from 'react';
import apiClient, { setAccessToken } from '../services/api';

const AuthContext = createContext(null);
const AUTH_STORAGE_KEY = 'fse_auth_active_user';

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
    return user ? 'active_jwt_token_' + user.user_id : null;
  });
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (token) {
      setAccessToken(token);
    }

    const handleAuthExpired = () => {
      setAccessToken(null);
      setTokenState(null);
      setUser(null);
      localStorage.removeItem(AUTH_STORAGE_KEY);
    };

    window.addEventListener('auth:expired', handleAuthExpired);
    return () => window.removeEventListener('auth:expired', handleAuthExpired);
  }, [token]);

  const login = async (email, password) => {
    setIsLoading(true);
    try {
      const res = await apiClient.post('/auth/login', { email, password });
      const { access_token, role, user_id, user_name, user_title, user: dbUser } = res.data;
      setAccessToken(access_token);
      setTokenState(access_token);
      
      const targetUserId = user_id || dbUser?.user_id || (email.includes('carlos') ? 'U3003' : email.includes('manager') ? 'U3002' : email.includes('admin') ? 'U0001' : 'U1001');
      const targetRole = role || (dbUser?.role === 'MANAGER' ? 'ROLE_MANAGER' : dbUser?.role === 'ADMIN' ? 'ROLE_ADMIN' : 'ROLE_CUSTOMER');

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
        password_hash: dbUser?.password_hash || '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
        pin_hash: dbUser?.pin_hash || (targetRole === 'ROLE_CUSTOMER' ? '$2a$12$k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8' : null),
        max_concurrent_sessions: dbUser?.max_concurrent_sessions || 3,
        failed_login_attempts: dbUser?.failed_login_attempts || 0,
        status: dbUser?.status || 'ACTIVE',
        created_at: dbUser?.created_at || '2024-01-10T09:15:00Z',
        updated_at: dbUser?.updated_at || new Date().toISOString(),
        
        // UI Presentation helpers
        name: user_name || `${dbUser?.first_name || 'Juan'} ${dbUser?.last_name || 'Dela Cruz'}`,
        title: user_title || (targetUserId === 'U3003' ? 'Senior Manager (L2)' : targetUserId === 'U3002' ? 'Operations Manager (L1)' : targetUserId === 'U0001' ? 'Compliance Officer' : 'Retail Account Holder (Maker)'),
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

  const loginAs = (personaKey) => {
    let personaUser = null;
    if (personaKey === 'customer') {
      personaUser = {
        user_id: 'U1001',
        first_name: 'Juan',
        middle_name: 'Reyes',
        last_name: 'Dela Cruz',
        email: 'juan.dc@email.com',
        phone_number: '09171234567',
        dob: '1990-05-14',
        government_id: 'PSA-1234-5678',
        role: 'ROLE_CUSTOMER',
        password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
        pin_hash: '$2a$12$k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8',
        max_concurrent_sessions: 3,
        failed_login_attempts: 0,
        status: 'ACTIVE',
        created_at: '2024-01-10T09:15:00Z',
        updated_at: '2024-01-10T09:15:00Z',
        name: 'Juan Reyes Dela Cruz',
        title: 'Retail Account Holder (Maker)',
      };
    } else if (personaKey === 'manager_l1') {
      personaUser = {
        user_id: 'U3002',
        first_name: 'Beatriz',
        middle_name: 'Santos',
        last_name: 'Ocampo',
        email: 'beatriz.ocampo@bank.com',
        phone_number: '09204445566',
        dob: '1984-07-19',
        government_id: 'PRC-9988-7711',
        role: 'ROLE_MANAGER',
        password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
        pin_hash: null,
        max_concurrent_sessions: 3,
        failed_login_attempts: 0,
        status: 'ACTIVE',
        created_at: '2023-10-01T08:30:00Z',
        updated_at: '2023-10-01T08:30:00Z',
        name: 'Beatriz Santos Ocampo',
        title: 'Operations Manager (Checker L1)',
      };
    } else if (personaKey === 'manager_l2') {
      personaUser = {
        user_id: 'U3003',
        first_name: 'Carlos',
        middle_name: 'Eduardo',
        last_name: 'Mendoza',
        email: 'carlos.mendoza@bank.com',
        phone_number: '09171122334',
        dob: '1982-11-05',
        government_id: 'PRC-5544-3322',
        role: 'ROLE_MANAGER',
        password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
        pin_hash: null,
        max_concurrent_sessions: 3,
        failed_login_attempts: 0,
        status: 'ACTIVE',
        created_at: '2023-09-15T08:30:00Z',
        updated_at: '2023-09-15T08:30:00Z',
        name: 'Carlos Eduardo Mendoza',
        title: 'Senior Manager / Branch Head (Approver L2)',
      };
    } else if (personaKey === 'admin') {
      personaUser = {
        user_id: 'U0001',
        first_name: 'Diana',
        middle_name: 'Marie',
        last_name: 'Vance',
        email: 'diana.admin@bank.com',
        phone_number: '09190001122',
        dob: '1985-03-12',
        government_id: 'GOV-1122-3344',
        role: 'ROLE_ADMIN',
        password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
        pin_hash: null,
        max_concurrent_sessions: 3,
        failed_login_attempts: 0,
        status: 'ACTIVE',
        created_at: '2023-09-01T08:30:00Z',
        updated_at: '2023-09-01T08:30:00Z',
        name: 'Diana Marie Vance',
        title: 'System Auditor & Compliance',
      };
    }

    if (personaUser) {
      const mockToken = 'mock_jwt_' + personaUser.user_id;
      setAccessToken(mockToken);
      setTokenState(mockToken);
      setUser(personaUser);
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(personaUser));
    }
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
  };

  // Switch role utility (updates state & localStorage)
  const switchRole = (newRole, managerId = 'U3002') => {
    let newUser = null;
    if (newRole === 'ROLE_CUSTOMER') {
      newUser = {
        user_id: 'U1001',
        email: 'juan.dc@email.com',
        name: 'Juan Dela Cruz',
        title: 'Retail Account Holder (Maker)',
        role: 'ROLE_CUSTOMER',
      };
    } else if (newRole === 'ROLE_MANAGER') {
      if (managerId === 'U3003') {
        newUser = {
          user_id: 'U3003',
          email: 'carlos.mendoza@bank.com',
          name: 'Carlos Mendoza',
          title: 'Senior Manager / Branch Head (Approver L2)',
          role: 'ROLE_MANAGER',
        };
      } else {
        newUser = {
          user_id: 'U3002',
          email: 'beatriz.ocampo@bank.com',
          name: 'Beatriz Ocampo',
          title: 'Operations Manager (Checker L1)',
          role: 'ROLE_MANAGER',
        };
      }
    } else if (newRole === 'ROLE_ADMIN') {
      newUser = {
        user_id: 'U0001',
        email: 'diana.admin@bank.com',
        name: 'Diana Vance',
        title: 'System Auditor & Compliance',
        role: 'ROLE_ADMIN',
      };
    }
    if (newUser) {
      setUser(newUser);
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(newUser));
    }
  };

  const switchManager = (managerId) => {
    switchRole('ROLE_MANAGER', managerId);
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
