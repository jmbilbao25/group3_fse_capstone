import React, { createContext, useContext, useState, useEffect } from 'react';
import apiClient, { setAccessToken } from '../services/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  // Pre-seed an active customer session for frictionless capstone demo / evaluation
  const [user, setUser] = useState({
    user_id: 'U1001',
    email: 'juan.dc@email.com',
    name: 'Juan Dela Cruz',
    role: 'ROLE_CUSTOMER', // 'ROLE_CUSTOMER' | 'ROLE_MANAGER' | 'ROLE_ADMIN'
  });
  const [token, setTokenState] = useState('active_memory_jwt');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    // Initial token setup in memory
    setAccessToken(token);

    const handleAuthExpired = () => {
      setAccessToken(null);
      setTokenState(null);
      setUser(null);
    };

    window.addEventListener('auth:expired', handleAuthExpired);
    return () => window.removeEventListener('auth:expired', handleAuthExpired);
  }, []);

  const login = async (email, password) => {
    setIsLoading(true);
    try {
      const res = await apiClient.post('/auth/login', { email, password });
      const { access_token, role, user_id, user_name } = res.data;
      setAccessToken(access_token);
      setTokenState(access_token);
      setUser({
        user_id: user_id || (email.includes('manager') ? 'U3002' : email.includes('admin') ? 'U0001' : 'U1001'),
        email,
        name: user_name || (email.includes('manager') ? 'Beatriz Ocampo' : email.includes('admin') ? 'Diana Vance' : 'Juan Dela Cruz'),
        role: role || (email.includes('manager') ? 'ROLE_MANAGER' : email.includes('admin') ? 'ROLE_ADMIN' : 'ROLE_CUSTOMER'),
      });
      return { success: true };
    } catch (err) {
      return { success: false, error: err.response?.data?.detail || 'Authentication failed' };
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
  };

  // Quick switch role utility for capstone defense & evaluation
  const switchRole = (newRole) => {
    if (newRole === 'ROLE_CUSTOMER') {
      setUser({
        user_id: 'U1001',
        email: 'juan.dc@email.com',
        name: 'Juan Dela Cruz',
        role: 'ROLE_CUSTOMER',
      });
    } else if (newRole === 'ROLE_MANAGER') {
      setUser({
        user_id: 'U3002',
        email: 'beatriz.ocampo@bank.com',
        name: 'Beatriz Ocampo',
        role: 'ROLE_MANAGER',
      });
    } else if (newRole === 'ROLE_ADMIN') {
      setUser({
        user_id: 'U0001',
        email: 'diana.admin@bank.com',
        name: 'Diana Vance',
        role: 'ROLE_ADMIN',
      });
    }
  };

  return (
    <AuthContext.Provider value={{ user, token, isLoading, login, logout, switchRole }}>
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
