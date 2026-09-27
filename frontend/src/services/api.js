import axios from 'axios';
import { generateUUID } from '../utils/currency';

// Strictly volatile in-memory token storage (guard against XSS token exfiltration)
let inMemoryAccessToken = null;

export const setAccessToken = (token) => {
  inMemoryAccessToken = token;
};

export const getAccessToken = () => {
  return inMemoryAccessToken;
};

const apiClient = axios.create({
  baseURL: '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true,
  timeout: 5000,
});

// Request interceptor: attach bearer token and idempotency header
apiClient.interceptors.request.use((config) => {
  if (inMemoryAccessToken) {
    config.headers['Authorization'] = `Bearer ${inMemoryAccessToken}`;
  }
  if (['post', 'patch', 'put'].includes(config.method?.toLowerCase())) {
    if (!config.headers['X-Idempotency-Key']) {
      config.headers['X-Idempotency-Key'] = generateUUID();
    }
  }
  return config;
});

// Regulatory BSP Thresholds
export const THRESHOLDS = {
  STP_MAX: 50000.0000,         // <= ₱50k: Straight-Through Processing (Instant Settlement)
  DUAL_CONTROL_MIN: 50000.0001, // > ₱50k: Requires Maker-Checker Operations Manager sign-off
  AMLA_CTR_MIN: 500000.0000,    // >= ₱500k: AMLA Covered Transaction Report + Dual Control
};

const STORAGE_KEY = 'fse_core_ledger_state_v4';

// Initial realistic core retail ledger state
const initialMockState = {
  // Oracle XE 21c Master USERS table records
  users: [
    {
      user_id: 'U1001',
      first_name: 'Juan',
      middle_name: 'Reyes',
      last_name: 'Dela Cruz',
      email: 'juan.dc@email.com',
      phone_number: '09171234567',
      dob: '1990-05-14',
      government_id: 'PSA-1234-5678',
      role: 'CUSTOMER',
      password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
      pin_hash: '$2a$12$k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8',
      max_concurrent_sessions: 3,
      failed_login_attempts: 0,
      status: 'ACTIVE',
      created_at: '2024-01-10T09:15:00Z',
      updated_at: '2024-01-10T09:15:00Z',
    },
    {
      user_id: 'U1002',
      first_name: 'Maria',
      middle_name: 'Clara',
      last_name: 'Santos',
      email: 'maria.s@email.com',
      phone_number: '09187654321',
      dob: '1992-08-22',
      government_id: 'PASSPORT-9876-5432',
      role: 'CUSTOMER',
      password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
      pin_hash: '$2a$12$k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8k4L9m1Wq2P8',
      max_concurrent_sessions: 3,
      failed_login_attempts: 0,
      status: 'ACTIVE',
      created_at: '2024-01-12T10:00:00Z',
      updated_at: '2024-01-12T10:00:00Z',
    },
    {
      user_id: 'U3002',
      first_name: 'Beatriz',
      middle_name: 'Santos',
      last_name: 'Ocampo',
      email: 'beatriz.ocampo@bank.com',
      phone_number: '09204445566',
      dob: '1984-07-19',
      government_id: 'PRC-9988-7711',
      role: 'MANAGER',
      password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
      pin_hash: null,
      max_concurrent_sessions: 3,
      failed_login_attempts: 0,
      status: 'ACTIVE',
      created_at: '2023-10-01T08:30:00Z',
      updated_at: '2023-10-01T08:30:00Z',
    },
    {
      user_id: 'U3003',
      first_name: 'Carlos',
      middle_name: 'Eduardo',
      last_name: 'Mendoza',
      email: 'carlos.mendoza@bank.com',
      phone_number: '09171122334',
      dob: '1982-11-05',
      government_id: 'PRC-5544-3322',
      role: 'MANAGER',
      password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
      pin_hash: null,
      max_concurrent_sessions: 3,
      failed_login_attempts: 0,
      status: 'ACTIVE',
      created_at: '2023-09-15T08:30:00Z',
      updated_at: '2023-09-15T08:30:00Z',
    },
    {
      user_id: 'U0001',
      first_name: 'Diana',
      middle_name: 'Marie',
      last_name: 'Vance',
      email: 'diana.admin@bank.com',
      phone_number: '09190001122',
      dob: '1985-03-12',
      government_id: 'GOV-1122-3344',
      role: 'ADMIN',
      password_hash: '$2a$12$e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1e8rQ9vXz7Y1',
      pin_hash: null,
      max_concurrent_sessions: 3,
      failed_login_attempts: 0,
      status: 'ACTIVE',
      created_at: '2023-09-01T08:30:00Z',
      updated_at: '2023-09-01T08:30:00Z',
    }
  ],
  account: {
    account_id: '1000-2000-3001',
    user_id: 'U1001',
    account_name: 'Juan Dela Cruz (Primary Savings)',
    account_type: 'SAVINGS',
    currency: 'PHP',
    current_balance: 15000000.0000,
    held_balance: 725000.0000,
    available_balance: 14275000.0000,
    credit_limit: 0.0000,
    status: 'ACTIVE',
  },
  creditAccount: {
    account_id: '1000-2000-3003',
    user_id: 'U1001',
    account_name: 'Juan Dela Cruz (Revolving Credit)',
    account_type: 'CREDIT',
    currency: 'PHP',
    current_balance: 2000.0000,
    held_balance: 0.0000,
    available_balance: 298000.0000,
    credit_limit: 300000.0000,
    status: 'ACTIVE',
  },
  // Oracle XE 21c Master ACCOUNTS table records
  registeredAccounts: [
    { account_id: 'A2001', account_number: '1000-2000-3001', user_id: 'U1001', account_name: 'Juan Dela Cruz', account_type: 'SAVINGS', credit_limit: 0.0000, status: 'ACTIVE' },
    { account_id: 'A2002', account_number: '1000-2000-3002', user_id: 'U1002', account_name: 'Maria Clara Santos', account_type: 'SAVINGS', credit_limit: 0.0000, status: 'ACTIVE' },
    { account_id: 'A2003', account_number: '1000-2000-3003', user_id: 'U1001', account_name: 'Juan Dela Cruz (Revolving Credit)', account_type: 'CREDIT', credit_limit: 300000.0000, status: 'ACTIVE' },
  ],
  transfers: [
    {
      id: 'TX-5003-AMLA',
      from_account_id: '1000-2000-3001',
      to_account_id: '1000-2000-3003',
      recipient_name: 'Apex Commercial Supplies Ltd.',
      amount: 600000.0000,
      currency: 'PHP',
      status: 'PENDING_APPROVAL',
      regulatory_tier: 'TIER_3_AMLA_CTR',
      tier_label: 'Tier 3: AMLA CTR + Dual Control',
      created_at: new Date(Date.now() - 600000).toISOString(),
      memo: 'Commercial server farm procurement batch #3',
      maker_user_id: 'U1001',
      hold_active: true,
      approval_stage: 1, // Stage 1 of 2: Awaiting L1 (Beatriz Ocampo)
      required_stages: 2,
      l1_approver_id: null,
      l1_approver_name: null,
      l1_approved_at: null,
      l1_notes: null,
      l2_approver_id: null,
      l2_approver_name: null,
      l2_approved_at: null,
      l2_notes: null,
    },
    {
      id: 'TX-5002-MC',
      from_account_id: '1000-2000-3001',
      to_account_id: '1000-2000-3002',
      recipient_name: 'Maria Santos',
      amount: 125000.0000,
      currency: 'PHP',
      status: 'PENDING_APPROVAL',
      regulatory_tier: 'TIER_2_DUAL_CONTROL',
      tier_label: 'Tier 2: Maker-Checker Dual Control',
      created_at: new Date(Date.now() - 1800000).toISOString(),
      memo: 'Branch office refurbishment contractor retainer',
      maker_user_id: 'U1001',
      hold_active: true,
      approval_stage: 1, // Stage 1 of 1: Single Manager Sign-off
      required_stages: 1,
    },
    {
      id: 'TX-5001-STP',
      from_account_id: '1000-2000-3001',
      to_account_id: '1000-2000-3002',
      recipient_name: 'Maria Santos',
      amount: 2000.0000,
      currency: 'PHP',
      status: 'SETTLED',
      regulatory_tier: 'TIER_1_STP',
      tier_label: 'Tier 1: Instant STP Settlement',
      created_at: new Date(Date.now() - 7200000).toISOString(),
      memo: 'Reimbursement for regional branch supplies',
      maker_user_id: 'U1001',
      hold_active: false,
      approval_stage: 0,
      required_stages: 0,
    }
  ],
  auditLogs: [
    {
      scn: 18492041,
      tx_id: 'TX-5001-STP',
      event_type: 'BALANCE_MUTATION_DEBIT',
      actor_id: 'U1001',
      actor_role: 'CUSTOMER',
      account_id: '1000-2000-3001',
      delta_amount: -2000.0000,
      balance_after: 998000.0000,
      digest_hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      timestamp: new Date(Date.now() - 7200000).toISOString(),
      status: 'VERIFIED',
    },
    {
      scn: 18492042,
      tx_id: 'TX-5002-MC',
      event_type: 'SOFT_HOLD_RESERVATION',
      actor_id: 'U1001',
      actor_role: 'CUSTOMER',
      account_id: '1000-2000-3001',
      delta_amount: -125000.0000,
      balance_after: 873000.0000,
      digest_hash: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
      timestamp: new Date(Date.now() - 1800000).toISOString(),
      status: 'VERIFIED',
    },
    {
      scn: 18492043,
      tx_id: 'TX-5003-AMLA',
      event_type: 'AMLA_CTR_HOLD_FLAGGED',
      actor_id: 'U1001',
      actor_role: 'CUSTOMER',
      account_id: '1000-2000-3001',
      delta_amount: -600000.0000,
      balance_after: 273000.0000,
      digest_hash: '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
      timestamp: new Date(Date.now() - 600000).toISOString(),
      status: 'VERIFIED',
    }
  ]
};

const loadMockState = () => {
  try {
    const raw = typeof window !== 'undefined' ? localStorage.getItem(STORAGE_KEY) : null;
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && parsed.account && Array.isArray(parsed.transfers)) {
        // Migration and compatibility check for multi-level approval
        parsed.transfers.forEach((tx) => {
          if (tx.regulatory_tier === 'TIER_3_AMLA_CTR') {
            tx.required_stages = 2;
            if (!tx.approval_stage) {
              tx.approval_stage = tx.l1_approver_id ? 2 : 1;
            }
          } else if (tx.regulatory_tier === 'TIER_2_DUAL_CONTROL') {
            tx.required_stages = 1;
            tx.approval_stage = 1;
          }
        });
        if (parsed.account.current_balance < 15000000.0000) {
          parsed.account.current_balance = 15000000.0000;
          parsed.account.available_balance = 15000000.0000 - (parsed.account.held_balance || 0);
        }
        if (!parsed.users || !Array.isArray(parsed.users) || parsed.users.length === 0) {
          parsed.users = JSON.parse(JSON.stringify(initialMockState.users));
        }
        if (!parsed.creditAccount) {
          parsed.creditAccount = JSON.parse(JSON.stringify(initialMockState.creditAccount));
        }
        if (!parsed.registeredAccounts || !Array.isArray(parsed.registeredAccounts) || parsed.registeredAccounts.length === 0) {
          parsed.registeredAccounts = JSON.parse(JSON.stringify(initialMockState.registeredAccounts));
        } else {
          parsed.registeredAccounts.forEach((acc) => {
            if (!acc.account_type) {
              acc.account_type = acc.account_id === 'A2003' || acc.account_number === '1000-2000-3003' ? 'CREDIT' : 'SAVINGS';
            }
            if (acc.credit_limit === undefined) {
              acc.credit_limit = acc.account_type === 'CREDIT' ? 300000.0000 : 0.0000;
            }
          });
        }
        // Filter out any bogus transfers that may have been created with non-existent accounts during testing
        const validAccountNums = ['100020003001', '100020003002', '100020003003', 'A2001', 'A2002', 'A2003'];
        parsed.transfers = parsed.transfers.filter((tx) => {
          const cleanTo = (tx.to_account_id || '').replace(/[\s-]/g, '').toUpperCase();
          return validAccountNums.includes(cleanTo);
        });
        return parsed;
      }
    }
  } catch (_) {}
  return JSON.parse(JSON.stringify(initialMockState));
};

let mockState = loadMockState();

export const saveMockState = () => {
  try {
    if (typeof window !== 'undefined') {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(mockState));
    }
  } catch (_) {}
};

export const resetMockState = () => {
  mockState = JSON.parse(JSON.stringify(initialMockState));
  saveMockState();
  return mockState;
};

// Response interceptor with Mock Simulation Fallback
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    // If backend is unreachable (ECONNREFUSED / Network Error / Vite proxy 500/502/504), route to mock ledger engine
    const isBackendUnavailable =
      !error.response ||
      error.code === 'ERR_NETWORK' ||
      ([500, 502, 503, 504].includes(error.response?.status) && (!error.response.data || typeof error.response.data !== 'object' || !error.response.data.title));

    if (isBackendUnavailable) {
      return handleMockFallback(error.config);
    }

    const originalRequest = error.config;
    // Silent token refresh on 401
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      try {
        const refreshRes = await axios.post('/api/v1/auth/refresh', {}, { withCredentials: true });
        const newToken = refreshRes.data.access_token;
        setAccessToken(newToken);
        originalRequest.headers['Authorization'] = `Bearer ${newToken}`;
        return apiClient(originalRequest);
      } catch (refreshErr) {
        setAccessToken(null);
        window.dispatchEvent(new CustomEvent('auth:expired'));
        return Promise.reject(refreshErr);
      }
    }

    return Promise.reject(error);
  }
);

// High-fidelity client-side mock simulation
function handleMockFallback(config) {
  const { url, method, data } = config;
  const payload = typeof data === 'string' ? JSON.parse(data || '{}') : (data || {});

  return new Promise((resolve, reject) => {
    setTimeout(() => {
      // 1. Auth Login
      if (url.includes('/auth/login') && method === 'post') {
        const token = 'mock_jwt_access_token_' + Math.random().toString(36).substring(2);
        setAccessToken(token);
        const email = (payload.email || '').toLowerCase().trim();
        let role = 'ROLE_CUSTOMER';
        let user_id = 'U1001';
        let user_name = 'Juan Dela Cruz';
        let user_title = 'Retail Account Holder (Maker)';

        let userRecord = mockState.users.find((u) => 
          (payload.user_id && u.user_id === payload.user_id) ||
          u.email.toLowerCase() === email ||
          (email && u.first_name && email.includes(u.first_name.toLowerCase())) ||
          (email && u.last_name && email.includes(u.last_name.toLowerCase()))
        );

        if (!userRecord) {
          if (email.includes('carlos') || email.includes('mendoza')) {
            userRecord = mockState.users.find(u => u.user_id === 'U3003');
          } else if (email.includes('manager') || email.includes('ocampo') || email.includes('beatriz')) {
            userRecord = mockState.users.find(u => u.user_id === 'U3002');
          } else if (email.includes('admin') || email.includes('vance') || email.includes('diana') || email.includes('audit')) {
            userRecord = mockState.users.find(u => u.user_id === 'U0001');
          } else {
            userRecord = mockState.users.find(u => u.user_id === 'U1001') || mockState.users[0];
          }
        }

        user_id = userRecord.user_id;
        user_name = `${userRecord.first_name} ${userRecord.middle_name ? userRecord.middle_name + ' ' : ''}${userRecord.last_name}`;
        if (userRecord.role === 'MANAGER') {
          role = 'ROLE_MANAGER';
          user_title = user_id === 'U3003' ? 'Senior Manager / Branch Head (Approver L2)' : 'Operations Manager (Checker L1)';
        } else if (userRecord.role === 'ADMIN') {
          role = 'ROLE_ADMIN';
          user_title = 'System Auditor & Compliance';
        } else {
          role = 'ROLE_CUSTOMER';
          user_title = 'Retail Account Holder (Maker)';
        }

        return resolve({
          data: {
            access_token: token,
            token_type: 'Bearer',
            expires_in_seconds: 900,
            role,
            user_id,
            user_name,
            user_title,
            user: { ...userRecord }
          }
        });
      }

      // 2. Auth Refresh
      if (url.includes('/auth/refresh') && method === 'post') {
        const token = 'mock_jwt_refreshed_' + Math.random().toString(36).substring(2);
        setAccessToken(token);
        return resolve({
          data: {
            access_token: token,
            token_type: 'Bearer',
            expires_in_seconds: 900,
          }
        });
      }

      // 3. Balance Inquiry
      if (url.includes('/balance') && method === 'get') {
        const isCredit = url.includes('1000-2000-3003') || url.includes('100020003003') || url.includes('A2003');
        const targetAcc = isCredit ? (mockState.creditAccount || initialMockState.creditAccount) : mockState.account;
        return resolve({
          data: { ...targetAcc, cached: true, last_updated: new Date().toISOString() }
        });
      }

      // 4. Initiating Funds Transfer
      if (url.includes('/transfers') && !url.includes('/pending') && !url.includes('/approve') && !url.includes('/reject') && !url.includes('/sign-l1') && method === 'post') {
        const toAccountId = (payload.to_account_id || '').trim();
        const fromAccountId = (payload.from_account_id || mockState.account.account_id || '1000-2000-3001').trim();

        // 1. Beneficiary Account Required
        if (!toAccountId) {
          return reject({
            response: {
              status: 400,
              data: {
                type: 'https://api.banking.capstone/errors/validation-failed',
                title: 'Missing Beneficiary Account',
                detail: 'Recipient account number is required.',
                invalid_params: [{ field: 'to_account_id', rejected_value: toAccountId, reason: 'must not be blank' }]
              }
            }
          });
        }

        // 2. Prevent Self-Transfer (Cannot transfer to own account)
        const cleanFrom = fromAccountId.replace(/[\s-]/g, '').toUpperCase();
        const cleanTo = toAccountId.replace(/[\s-]/g, '').toUpperCase();
        if (cleanFrom === cleanTo) {
          return reject({
            response: {
              status: 400,
              data: {
                type: 'https://api.banking.capstone/errors/invalid-transfer',
                title: 'Invalid Destination Account',
                detail: 'Self-transfer prohibited: Cannot transfer funds to the same originating account.',
                invalid_params: [{ field: 'to_account_id', rejected_value: toAccountId, reason: 'cannot transfer to own account' }]
              }
            }
          });
        }

        // 3. Verify Destination Account Existence in Bank Ledger
        const registeredList = (mockState.registeredAccounts && mockState.registeredAccounts.length > 0)
          ? mockState.registeredAccounts
          : initialMockState.registeredAccounts;

        const matchedAccount = registeredList.find((acc) => {
          const accNumClean = (acc.account_number || '').replace(/[\s-]/g, '').toUpperCase();
          const accIdClean = (acc.account_id || '').replace(/[\s-]/g, '').toUpperCase();
          return accNumClean === cleanTo || accIdClean === cleanTo;
        });

        if (!matchedAccount) {
          return reject({
            response: {
              status: 404,
              data: {
                type: 'https://api.banking.capstone/errors/account-not-found',
                title: 'Account Does Not Exist',
                detail: `Destination account "${toAccountId}" does not exist in the bank ledger. Please verify the account number and try again.`,
                invalid_params: [{ field: 'to_account_id', rejected_value: toAccountId, reason: 'account does not exist' }]
              }
            }
          });
        }

        if (matchedAccount.status !== 'ACTIVE') {
          return reject({
            response: {
              status: 422,
              data: {
                type: 'https://api.banking.capstone/errors/account-inactive',
                title: 'Beneficiary Account Inactive',
                detail: `Destination account "${toAccountId}" is currently not active or restricted.`,
                invalid_params: [{ field: 'to_account_id', rejected_value: toAccountId, reason: 'account status is ' + matchedAccount.status }]
              }
            }
          });
        }

        const amount = parseFloat(payload.amount);
        if (isNaN(amount) || amount <= 0) {
          return reject({
            response: {
              status: 400,
              data: {
                type: 'https://api.banking.capstone/errors/validation-failed',
                title: 'Bad Request (JSR-380)',
                detail: 'The payload failed perimeter validation constraints. Amount must be strictly positive.',
                invalid_params: [{ field: 'amount', rejected_value: amount, reason: 'must be greater than 0.0000' }]
              }
            }
          });
        }

        const isFromCredit = fromAccountId.includes('3003') || fromAccountId === 'A2003';
        const sourceAccount = isFromCredit ? (mockState.creditAccount || initialMockState.creditAccount) : mockState.account;

        if (amount > sourceAccount.available_balance) {
          return reject({
            response: {
              status: 422,
              data: {
                type: 'https://api.banking.capstone/errors/insufficient-funds',
                title: 'Unprocessable Entity',
                detail: `Available balance insufficient. Available: ₱${sourceAccount.available_balance.toFixed(4)}, Requested: ₱${amount.toFixed(4)}.`,
              }
            }
          });
        }

        // Regulatory Threshold Classification
        const isTier3 = amount >= THRESHOLDS.AMLA_CTR_MIN;
        const isTier2 = amount > THRESHOLDS.STP_MAX && !isTier3;
        const isHeld = isTier2 || isTier3;

        let tier = 'TIER_1_STP';
        let tierLabel = 'Tier 1: Instant STP Settlement';
        let status = 'SETTLED';
        let responseMsg = 'Funds transfer settled instantly via Oracle XE Row-Level Lock.';

        if (isTier3) {
          tier = 'TIER_3_AMLA_CTR';
          tierLabel = 'Tier 3: AMLA CTR + Dual Control';
          status = 'PENDING_APPROVAL';
          responseMsg = 'AMLA Covered Transaction (CTR) threshold reached (≥ ₱500k). Soft hold placed. Requires 2-Stage Manager Approval (L1 Operations Checker + L2 Senior Manager).';
        } else if (isTier2) {
          tier = 'TIER_2_DUAL_CONTROL';
          tierLabel = 'Tier 2: Maker-Checker Dual Control';
          status = 'PENDING_APPROVAL';
          responseMsg = 'Transfer exceeds STP threshold (> ₱50k). Soft hold placed pending Operations Manager authorization.';
        }

        const newTransfer = {
          id: 'TX-' + Math.floor(5000 + Math.random() * 4999) + (isTier3 ? '-AMLA' : isTier2 ? '-MC' : '-STP'),
          from_account_id: sourceAccount.account_id,
          to_account_id: matchedAccount.account_number || toAccountId,
          recipient_name: payload.recipient_name || matchedAccount.account_name || 'Beneficiary Account',
          amount: amount,
          currency: 'PHP',
          status: status,
          regulatory_tier: tier,
          tier_label: tierLabel,
          created_at: new Date().toISOString(),
          memo: payload.memo || 'Standard Retail Transfer',
          maker_user_id: payload.maker_user_id || 'U1001',
          hold_active: isHeld,
          approval_stage: isTier3 ? 1 : (isTier2 ? 1 : 0),
          required_stages: isTier3 ? 2 : (isTier2 ? 1 : 0),
          l1_approver_id: null,
          l1_approver_name: null,
          l1_approved_at: null,
          l1_notes: null,
          l2_approver_id: null,
          l2_approver_name: null,
          l2_approved_at: null,
          l2_notes: null,
        };

        if (isHeld) {
          sourceAccount.held_balance += amount;
          sourceAccount.available_balance -= amount;
        } else {
          if (isFromCredit) {
            sourceAccount.current_balance += amount;
          } else {
            sourceAccount.current_balance -= amount;
          }
          sourceAccount.available_balance -= amount;
        }

        mockState.transfers.unshift(newTransfer);

        // Record Audit Entry
        const nextScn = mockState.auditLogs.length > 0 
          ? mockState.auditLogs[mockState.auditLogs.length - 1].scn + 1 
          : 18492044;
        
        mockState.auditLogs.push({
          scn: nextScn,
          tx_id: newTransfer.id,
          event_type: isHeld ? (isTier3 ? 'AMLA_CTR_HOLD_FLAGGED' : 'SOFT_HOLD_RESERVATION') : 'BALANCE_MUTATION_DEBIT',
          actor_id: newTransfer.maker_user_id,
          actor_role: 'CUSTOMER',
          account_id: sourceAccount.account_id,
          delta_amount: -amount,
          balance_after: sourceAccount.available_balance,
          digest_hash: Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2),
          timestamp: newTransfer.created_at,
          status: 'VERIFIED',
        });
        saveMockState();

        // Dispatch real email advice to notification-service (:8083) -> MailHog (:1025 / :8025)
        try {
          const notifPayload = {
            amount: newTransfer.amount,
            transfer_id: newTransfer.id,
            from_account_id: newTransfer.from_account_id,
            to_account_id: newTransfer.to_account_id,
            recipient_name: newTransfer.recipient_name,
            memo: newTransfer.memo,
          };

          if (tier === 'TIER_1_STP') {
            axios.post('http://localhost:8083/api/v1/notifications/simulate-transfer', notifPayload).catch(() => {});
          } else if (tier === 'TIER_2_DUAL_CONTROL') {
            axios.post('http://localhost:8083/api/v1/notifications/simulate-tier2-maker-checker', notifPayload).catch(() => {});
          } else if (tier === 'TIER_3_AMLA_CTR') {
            axios.post('http://localhost:8083/api/v1/notifications/simulate-tier3-amla', notifPayload).catch(() => {});
          }
        } catch (_) {}

        return resolve({
          status: 202,
          data: {
            transfer_id: newTransfer.id,
            status: newTransfer.status,
            regulatory_tier: tier,
            message: responseMsg,
            record: newTransfer,
          }
        });
      }

      // 5. Get Pending Transfers for Manager Queue
      if (url.includes('/transfers/pending') && method === 'get') {
        const pending = mockState.transfers.filter((t) => t.status === 'PENDING_APPROVAL');
        return resolve({ data: pending });
      }

      // 5b. Stage 1 Sign-Off for Tier 3 AMLA Transfers (L1 Operations Manager: Beatriz Ocampo U3002)
      if (url.includes('/transfers/') && url.endsWith('/sign-l1') && method === 'post') {
        const id = url.split('/transfers/')[1].split('/sign-l1')[0];
        const tx = mockState.transfers.find((t) => t.id === id);

        if (!tx || tx.status !== 'PENDING_APPROVAL') {
          return reject({ response: { status: 404, data: { detail: 'Transfer not found or already settled.' } } });
        }

        const checkerId = payload.checker_user_id || 'U3002';
        const checkerName = payload.checker_name || (checkerId === 'U3002' ? 'Beatriz Ocampo' : 'Operations Manager');

        // Segregation of Duties: Maker cannot sign L1
        if (checkerId === tx.maker_user_id) {
          return reject({
            response: {
              status: 403,
              data: {
                title: 'Segregation of Duties Violation',
                detail: 'Rule FSE-204: The initiating customer/maker cannot perform operational sign-off.',
              }
            }
          });
        }

        if (tx.approval_stage !== 1) {
          return reject({
            response: {
              status: 400,
              data: {
                title: 'Invalid Workflow Stage',
                detail: `Transfer is currently in Stage ${tx.approval_stage}. Level 1 sign-off is already completed.`,
              }
            }
          });
        }

        // Advance to Stage 2 (Awaiting Level 2 Senior Manager)
        tx.approval_stage = 2;
        tx.l1_approver_id = checkerId;
        tx.l1_approver_name = checkerName;
        tx.l1_approved_at = new Date().toISOString();
        tx.l1_notes = payload.notes || 'Verified customer identity, KYC profile, and AMLA covered transaction mandate.';

        // Soft hold remains intact in Oracle XE (no balance debit yet)
        saveMockState();

        // Record Audit Entry
        const nextScn = mockState.auditLogs.length > 0 
          ? mockState.auditLogs[mockState.auditLogs.length - 1].scn + 1 
          : 18492044;

        mockState.auditLogs.push({
          scn: nextScn,
          tx_id: tx.id,
          event_type: 'AMLA_TIER3_STAGE1_L1_SIGNOFF',
          actor_id: checkerId,
          actor_role: 'MANAGER',
          account_id: tx.from_account_id,
          delta_amount: 0,
          balance_after: mockState.account.available_balance,
          digest_hash: Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2),
          timestamp: tx.l1_approved_at,
          status: 'VERIFIED',
        });
        saveMockState();

        // Notification dispatched to Carlos Mendoza (Senior Manager / L2 Approver)
        try {
          axios.post('http://localhost:8083/api/v1/notifications/simulate-tier3-amla', {
            transfer_id: tx.id,
            amount: tx.amount,
            from_account_id: tx.from_account_id,
            to_account_id: tx.to_account_id,
            recipient_email: 'carlos.mendoza@retailbank.ph',
            memo: `AMLA L1 Sign-off Complete by ${checkerName}. Awaiting Level 2 Senior Manager final authorization.`
          }).catch(() => {});
        } catch (_) {}

        return resolve({
          data: {
            transfer_id: tx.id,
            status: 'PENDING_APPROVAL',
            approval_stage: 2,
            message: `Stage 1 sign-off recorded by ${checkerName}. Forwarded to Level 2 Senior Manager (Carlos Mendoza) for final settlement release.`
          }
        });
      }

      // 6. Approve Transfer (Manager Action: Tier 2 single approval or Tier 3 Stage 2 final release)
      if (url.includes('/transfers/') && url.endsWith('/approve') && method === 'post') {
        const id = url.split('/transfers/')[1].split('/approve')[0];
        const tx = mockState.transfers.find((t) => t.id === id);
        
        if (!tx || tx.status !== 'PENDING_APPROVAL') {
          return reject({ response: { status: 404, data: { detail: 'Transfer not found or already settled.' } } });
        }

        const checkerId = payload.checker_user_id || 'U3002';
        const checkerName = payload.checker_name || (checkerId === 'U3003' ? 'Carlos Mendoza' : 'Beatriz Ocampo');

        // Segregation of Duties Check: Maker cannot approve
        if (checkerId === tx.maker_user_id) {
          return reject({
            response: {
              status: 403,
              data: {
                title: 'Segregation of Duties Violation',
                detail: 'Rule FSE-204: The initiating maker cannot authorize their own balance mutation.',
              }
            }
          });
        }

        // Dual-Control Multi-Level Enforcement for Tier 3 AMLA
        const isTier3 = tx.regulatory_tier === 'TIER_3_AMLA_CTR' || (tx.amount >= THRESHOLDS.AMLA_CTR_MIN);
        if (isTier3) {
          if (tx.approval_stage === 1) {
            return reject({
              response: {
                status: 400,
                data: {
                  title: 'Multi-Level Approval Required',
                  detail: 'Tier 3 AMLA transfers (≥ ₱500k) require Stage 1 (L1 Operations Manager) sign-off before Stage 2 release.',
                }
              }
            });
          }

          // Segregation of Duties: Level 2 approver cannot be the same individual who signed Level 1!
          if (tx.l1_approver_id && checkerId === tx.l1_approver_id) {
            return reject({
              response: {
                status: 403,
                data: {
                  title: 'Dual-Control Segregation Violation',
                  detail: `Rule AMLA-204: Level 2 final release must be approved by a distinct Senior Manager (Carlos Mendoza U3003). Manager ${checkerName} already executed Level 1 sign-off.`,
                }
              }
            });
          }

          tx.l2_approver_id = checkerId;
          tx.l2_approver_name = checkerName;
          tx.l2_approved_at = new Date().toISOString();
          tx.l2_notes = payload.notes || 'Senior Manager AMLA Covered Transaction CTR clearance verified.';
        }

        tx.status = 'SETTLED';
        tx.hold_active = false;
        tx.approved_at = new Date().toISOString();
        tx.approver_notes = payload.notes || (isTier3 ? 'AMLA CTR dual-manager final clearance.' : 'Operations Manager dual-control sign-off.');
        tx.checker_user_id = checkerId;

        // Release hold and settle from ledger current balance
        const isFromCredit = (tx.from_account_id || '').includes('3003') || tx.from_account_id === 'A2003';
        const sourceAcc = isFromCredit ? (mockState.creditAccount || initialMockState.creditAccount) : mockState.account;

        sourceAcc.held_balance = Math.max(0, (sourceAcc.held_balance || 0) - tx.amount);
        if (isFromCredit) {
          sourceAcc.current_balance += tx.amount;
        } else {
          sourceAcc.current_balance -= tx.amount;
        }
        saveMockState();

        // Record Audit Entry
        const nextScn = mockState.auditLogs.length > 0 
          ? mockState.auditLogs[mockState.auditLogs.length - 1].scn + 1 
          : 18492044;

        mockState.auditLogs.push({
          scn: nextScn,
          tx_id: tx.id,
          event_type: isTier3 ? 'AMLA_TIER3_STAGE2_FINAL_SETTLEMENT' : 'MANAGER_CHECKER_AUTHORIZATION',
          actor_id: checkerId,
          actor_role: 'MANAGER',
          account_id: tx.from_account_id,
          delta_amount: -tx.amount,
          balance_after: sourceAcc.current_balance,
          digest_hash: Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2),
          timestamp: tx.approved_at,
          status: 'VERIFIED',
        });
        saveMockState();

        // Dispatch approval release email to notification-service (:8083) -> MailHog (:1025 / :8025)
        try {
          axios.post('http://localhost:8083/api/v1/notifications/simulate-tier2-approval', {
            transfer_id: tx.id,
            amount: tx.amount,
            from_account_id: tx.from_account_id,
            to_account_id: tx.to_account_id,
            recipient_email: 'juan.delacruz@retailbank.ph',
            memo: `Settlement Advice: Transfer ${tx.id} for PHP ${tx.amount.toLocaleString()} was approved and released by ${checkerName}. Funds debited.`
          }).catch(() => {});
        } catch (_) {}

        return resolve({
          data: {
            transfer_id: tx.id,
            status: 'SETTLED',
            message: isTier3
              ? 'AMLA Tier 3 Transfer Fully Authorized. Dual manager approval completed, soft hold released, and funds settled.'
              : 'Transfer authorized. Soft hold cleared and Oracle XE master balance permanently debited.'
          }
        });
      }

      // 7. Reject Transfer (Manager Action)
      if (url.includes('/transfers/') && url.endsWith('/reject') && method === 'post') {
        const id = url.split('/transfers/')[1].split('/reject')[0];
        const tx = mockState.transfers.find((t) => t.id === id);
        
        if (!tx || tx.status !== 'PENDING_APPROVAL') {
          return reject({ response: { status: 404, data: { detail: 'Transfer not found.' } } });
        }

        tx.status = 'REJECTED';
        tx.hold_active = false;
        tx.rejected_at = new Date().toISOString();
        tx.rejection_reason = payload.reason || 'Flagged during dual-control operations review.';

        // Release hold back to customer's available balance
        const isFromCredit = (tx.from_account_id || '').includes('3003') || tx.from_account_id === 'A2003';
        const sourceAcc = isFromCredit ? (mockState.creditAccount || initialMockState.creditAccount) : mockState.account;

        sourceAcc.held_balance = Math.max(0, (sourceAcc.held_balance || 0) - tx.amount);
        sourceAcc.available_balance = (sourceAcc.available_balance || 0) + tx.amount;
        saveMockState();

        // Record Audit Entry
        const nextScn = mockState.auditLogs[mockState.auditLogs.length - 1].scn + 1;
        mockState.auditLogs.push({
          scn: nextScn,
          tx_id: tx.id,
          event_type: 'MAKER_CHECKER_DISAPPROVAL_VOID',
          actor_id: payload.checker_user_id || 'U3002',
          actor_role: 'MANAGER',
          account_id: tx.from_account_id,
          delta_amount: tx.amount,
          balance_after: sourceAcc.available_balance,
          digest_hash: Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2),
          timestamp: tx.rejected_at,
          status: 'VERIFIED',
        });
        saveMockState();

        // Dispatch disapproval advice to notification-service (:8083) -> MailHog (:1025 / :8025)
        // Explicitly sent to the initiating customer (Juan Dela Cruz) per BSP Circular 1033 & RA 7394
        try {
          axios.post('http://localhost:8083/api/v1/notifications/simulate-transfer', {
            amount: tx.amount,
            transfer_id: tx.id,
            from_account_id: tx.from_account_id,
            to_account_id: tx.to_account_id,
            recipient_email: 'juan.delacruz@retailbank.ph',
            memo: `Disapproval Advice: Transfer ${tx.id} for PHP ${tx.amount.toLocaleString()} was voided by Manager Beatriz Ocampo. Reason: ${payload.reason || 'Dual-control rejection'}. Soft hold released, PHP 0 debited.`
          }).catch(() => {});
        } catch (_) {}

        return resolve({
          data: {
            transfer_id: tx.id,
            status: 'REJECTED',
            message: 'Transfer disapproved. Soft hold released and funds returned to customer available balance.'
          }
        });
      }

      // 8. Audit Logs Inquiry
      if (url.includes('/audit') && method === 'get') {
        return resolve({ data: mockState.auditLogs });
      }

      // 9. User Profile Inquiry (Oracle XE USERS Table)
      if (url.includes('/users') && method === 'get') {
        const parts = url.split('/users');
        const rawParam = parts[1] ? parts[1].replace('/', '').split('?')[0] : '';
        const targetId = rawParam || 'U1001';
        const userRecord = mockState.users.find(u => u.user_id === targetId || u.email.toLowerCase() === targetId.toLowerCase());
        if (!userRecord) {
          return reject({ response: { status: 404, data: { detail: 'User record not found in Oracle XE master table.' } } });
        }
        return resolve({ data: { ...userRecord } });
      }

      // 10. Update User Profile (Oracle XE USERS Table Mutation)
      if (url.includes('/users') && (method === 'put' || method === 'patch')) {
        const parts = url.split('/users');
        const rawParam = parts[1] ? parts[1].replace('/', '').split('?')[0] : '';
        const targetId = rawParam || payload.user_id || 'U1001';
        const userIdx = mockState.users.findIndex(u => u.user_id === targetId);
        
        if (userIdx === -1) {
          return reject({ response: { status: 404, data: { detail: 'User record not found in Oracle XE master table.' } } });
        }

        const existing = mockState.users[userIdx];

        // Strict mapping to DB columns
        if (payload.first_name !== undefined) existing.first_name = payload.first_name.trim();
        if (payload.middle_name !== undefined) existing.middle_name = payload.middle_name ? payload.middle_name.trim() : null;
        if (payload.last_name !== undefined) existing.last_name = payload.last_name.trim();
        if (payload.email !== undefined) existing.email = payload.email.trim();
        if (payload.phone_number !== undefined) existing.phone_number = payload.phone_number.trim();
        if (payload.dob !== undefined) existing.dob = payload.dob;
        if (payload.government_id !== undefined) existing.government_id = payload.government_id.trim();
        if (payload.max_concurrent_sessions !== undefined) existing.max_concurrent_sessions = Number(payload.max_concurrent_sessions);

        // Security hashes updates
        if (payload.new_password) {
          existing.password_hash = '$2a$12$' + Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2);
        }
        if (payload.new_pin) {
          existing.pin_hash = '$2a$12$' + Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2);
        }

        existing.updated_at = new Date().toISOString();
        saveMockState();

        // Record audit entry in append-only PostgreSQL log
        const nextScn = mockState.auditLogs.length > 0 
          ? mockState.auditLogs[mockState.auditLogs.length - 1].scn + 1 
          : 18492044;
        
        mockState.auditLogs.push({
          scn: nextScn,
          tx_id: 'SEC-USER-' + existing.user_id,
          event_type: 'USER_PROFILE_MUTATION',
          actor_id: existing.user_id,
          actor_role: existing.role,
          account_id: '1000-2000-3001',
          delta_amount: 0,
          balance_after: mockState.account.available_balance,
          digest_hash: Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2),
          timestamp: existing.updated_at,
          status: 'VERIFIED',
        });
        saveMockState();

        return resolve({
          status: 200,
          data: { ...existing }
        });
      }

      // Default mock fallback
      return resolve({ data: { message: 'Action executed successfully in simulation mode.' } });
    }, 100);
  });
}

export default apiClient;
export { mockState };
