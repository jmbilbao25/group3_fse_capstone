import axios from 'axios';

// Base API client pointing to Gateway Service (:8080) via Vite proxy or cloud URL
export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Demo accounts data
export const INITIAL_ACCOUNTS = [
  {
    accountId: 'A2001',
    accountNumber: '1000-2000-3001',
    accountType: 'CREDIT',
    userId: 'U1001',
    userName: 'Juan Dela Cruz',
    balanceAmount: 298000.0,
    holdAmount: 0.0,
    availableBalance: 298000.0,
    creditLimit: 300000.0,
  },
  {
    accountId: 'A2003',
    accountNumber: '1000-2000-3003',
    accountType: 'SAVINGS',
    userId: 'U1001',
    userName: 'Juan Dela Cruz',
    balanceAmount: 15500.0,
    holdAmount: 0.0,
    availableBalance: 15500.0,
    creditLimit: 0.0,
  },
  {
    accountId: 'A2002',
    accountNumber: '1000-2000-3002',
    accountType: 'SAVINGS',
    userId: 'U1002',
    userName: 'Maria Clara Santos',
    balanceAmount: 52000.0,
    holdAmount: 0.0,
    availableBalance: 52000.0,
    creditLimit: 0.0,
  },
];

// Demo system roles
export const ROLES = {
  CUSTOMER: {
    id: 'U1001',
    name: 'Juan Dela Cruz',
    role: 'CUSTOMER',
    badge: 'Retail Customer',
    description: 'Account Holder & Transaction Initiator',
  },
  ADMIN: {
    id: 'U0001',
    name: 'Diana Vance',
    role: 'ADMIN',
    badge: 'Administrator',
    description: 'PostgreSQL Immutable Audit Trail & Regulatory Discovery',
  },
};

// API Services
export const LedgerService = {
  // Query immutable audit records from PostgreSQL
  getAuditRecords: async () => {
    try {
      const response = await apiClient.get('/v1/ledger/audit');
      return { success: true, data: response.data || [] };
    } catch (error) {
      try {
        const directRes = await axios.get('http://localhost:8082/api/v1/ledger/audit', { timeout: 3000 });
        return { success: true, data: directRes.data || [] };
      } catch (err2) {
        return { success: false, error: error.message, data: [] };
      }
    }
  },

  // Execute balance mutation / transfer
  executeTransfer: async (payload) => {
    try {
      const response = await apiClient.post('/v1/ledger/mutate', payload);
      return { success: true, data: response.data };
    } catch (error) {
      const errorDetail = error.response?.data?.detail || error.response?.data?.message || error.message;
      return { success: false, error: errorDetail };
    }
  },

  // Query pending Maker-Checker transactions
  getPendingTransactions: async () => {
    try {
      const response = await apiClient.get('/v1/ledger/pending');
      return { success: true, data: response.data || [] };
    } catch (error) {
      return { success: false, error: error.message, data: [] };
    }
  },

  // Approve pending transfer
  approveTransfer: async (payload) => {
    try {
      const response = await apiClient.post('/v1/ledger/approve', payload);
      return { success: true, data: response.data };
    } catch (error) {
      const errorDetail = error.response?.data?.detail || error.response?.data?.message || error.message;
      return { success: false, error: errorDetail };
    }
  },

  // Reject pending transfer
  rejectTransfer: async (payload) => {
    try {
      const response = await apiClient.post('/v1/ledger/reject', payload);
      return { success: true, data: response.data };
    } catch (error) {
      const errorDetail = error.response?.data?.detail || error.response?.data?.message || error.message;
      return { success: false, error: errorDetail };
    }
  },
};

export const NotificationService = {
  // Get notification history
  getHistory: async (userId) => {
    try {
      const url = userId ? `/v1/notifications/history?userId=${userId}` : '/v1/notifications/history';
      const response = await apiClient.get(url);
      return { success: true, data: response.data || [] };
    } catch (error) {
      return { success: false, error: error.message, data: [] };
    }
  },

  // Simulate Scenarios
  simulateTier1Transfer: async (payload) => {
    try {
      const response = await apiClient.post('/v1/notifications/simulate-transfer', payload || {});
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  },

  simulateTier2MakerChecker: async () => {
    try {
      const response = await apiClient.post('/v1/notifications/simulate-tier2-maker-checker');
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  },

  simulateTier2Approval: async () => {
    try {
      const response = await apiClient.post('/v1/notifications/simulate-tier2-approval');
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  },

  simulateTier3Amla: async () => {
    try {
      const response = await apiClient.post('/v1/notifications/simulate-tier3-amla');
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  },

  getSpoolStatus: async () => {
    try {
      const response = await apiClient.get('/v1/notifications/spool-status');
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  },

  flushSpool: async () => {
    try {
      const response = await apiClient.post('/v1/notifications/flush-spool');
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  },
};
