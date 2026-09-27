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

// Initial realistic core retail ledger state
let mockState = {
  account: {
    account_id: '1000-2000-3001',
    user_id: 'U1001',
    account_name: 'Juan Dela Cruz (Primary Savings)',
    account_type: 'SAVINGS',
    currency: 'PHP',
    current_balance: 1000000.0000,
    held_balance: 725000.0000,
    available_balance: 275000.0000,
    status: 'ACTIVE',
  },
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

// Response interceptor with Mock Simulation Fallback
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    // If backend is unreachable (ECONNREFUSED / Network Error), route to mock ledger engine
    if (!error.response || error.code === 'ERR_NETWORK') {
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
        const email = payload.email || '';
        let role = 'ROLE_CUSTOMER';
        let user_id = 'U1001';
        let user_name = 'Juan Dela Cruz';

        if (email.includes('manager') || email.includes('ocampo')) {
          role = 'ROLE_MANAGER';
          user_id = 'U3002';
          user_name = 'Beatriz Ocampo';
        } else if (email.includes('admin') || email.includes('vance')) {
          role = 'ROLE_ADMIN';
          user_id = 'U0001';
          user_name = 'Diana Vance';
        }

        return resolve({
          data: {
            access_token: token,
            token_type: 'Bearer',
            expires_in_seconds: 900,
            role,
            user_id,
            user_name,
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
        return resolve({
          data: { ...mockState.account, cached: true, last_updated: new Date().toISOString() }
        });
      }

      // 4. Initiating Funds Transfer
      if (url.endsWith('/transfers') && method === 'post') {
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

        if (amount > mockState.account.available_balance) {
          return reject({
            response: {
              status: 422,
              data: {
                type: 'https://api.banking.capstone/errors/insufficient-funds',
                title: 'Unprocessable Entity',
                detail: `Available balance insufficient. Available: ₱${mockState.account.available_balance.toFixed(4)}, Requested: ₱${amount.toFixed(4)}.`,
              }
            }
          });
        }

        // Regulatory Threshold Classification
        let tier = 'TIER_1_STP';
        let tierLabel = 'Tier 1: Instant STP Settlement';
        let status = 'SETTLED';
        let isHeld = false;
        let responseMsg = 'Funds transfer settled instantly via Oracle XE Row-Level Lock.';

        if (amount >= THRESHOLDS.AMLA_CTR_MIN) {
          tier = 'TIER_3_AMLA_CTR';
          tierLabel = 'Tier 3: AMLA CTR + Dual Control';
          status = 'PENDING_APPROVAL';
          isHeld = true;
          responseMsg = 'AMLA Covered Transaction (CTR) threshold reached (≥ ₱500k). Soft hold placed pending Operations Manager authorization.';
        } else if (amount > THRESHOLDS.STP_MAX) {
          tier = 'TIER_2_DUAL_CONTROL';
          tierLabel = 'Tier 2: Maker-Checker Dual Control';
          status = 'PENDING_APPROVAL';
          isHeld = true;
          responseMsg = 'Transfer exceeds STP threshold (> ₱50k). Soft hold placed pending Operations Manager authorization.';
        }

        const newTransfer = {
          id: 'TX-' + Math.floor(5000 + Math.random() * 4999) + (isHeld ? '-MC' : '-STP'),
          from_account_id: mockState.account.account_id,
          to_account_id: payload.to_account_id || '1000-2000-3002',
          recipient_name: payload.recipient_name || 'Beneficiary Account',
          amount: amount,
          currency: 'PHP',
          status: status,
          regulatory_tier: tier,
          tier_label: tierLabel,
          created_at: new Date().toISOString(),
          memo: payload.memo || 'Standard Retail Transfer',
          maker_user_id: payload.maker_user_id || 'U1001',
          hold_active: isHeld,
        };

        if (isHeld) {
          mockState.account.held_balance += amount;
          mockState.account.available_balance -= amount;
        } else {
          mockState.account.current_balance -= amount;
          mockState.account.available_balance -= amount;
        }

        mockState.transfers.unshift(newTransfer);

        // Record Audit Entry
        const nextScn = mockState.auditLogs.length > 0 
          ? mockState.auditLogs[mockState.auditLogs.length - 1].scn + 1 
          : 18492044;
        
        mockState.auditLogs.push({
          scn: nextScn,
          tx_id: newTransfer.id,
          event_type: isHeld ? (tier === 'TIER_3_AMLA_CTR' ? 'AMLA_CTR_HOLD_FLAGGED' : 'SOFT_HOLD_RESERVATION') : 'BALANCE_MUTATION_DEBIT',
          actor_id: newTransfer.maker_user_id,
          actor_role: 'CUSTOMER',
          account_id: mockState.account.account_id,
          delta_amount: -amount,
          balance_after: mockState.account.available_balance,
          digest_hash: Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2),
          timestamp: newTransfer.created_at,
          status: 'VERIFIED',
        });

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

      // 6. Approve Transfer (Manager Action)
      if (url.includes('/transfers/') && url.endsWith('/approve') && method === 'post') {
        const id = url.split('/transfers/')[1].split('/approve')[0];
        const tx = mockState.transfers.find((t) => t.id === id);
        
        if (!tx || tx.status !== 'PENDING_APPROVAL') {
          return reject({ response: { status: 404, data: { detail: 'Transfer not found or already settled.' } } });
        }

        // Segregation of Duties Check
        const checkerId = payload.checker_user_id || 'U3002';
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

        tx.status = 'SETTLED';
        tx.hold_active = false;
        tx.approved_at = new Date().toISOString();
        tx.approver_notes = payload.notes || 'Operations Manager dual-control sign-off.';
        tx.checker_user_id = checkerId;

        // Release hold and settle from ledger current balance
        mockState.account.held_balance -= tx.amount;
        mockState.account.current_balance -= tx.amount;

        // Record Audit Entry
        const nextScn = mockState.auditLogs[mockState.auditLogs.length - 1].scn + 1;
        mockState.auditLogs.push({
          scn: nextScn,
          tx_id: tx.id,
          event_type: 'MANAGER_CHECKER_AUTHORIZATION',
          actor_id: checkerId,
          actor_role: 'MANAGER',
          account_id: tx.from_account_id,
          delta_amount: 0,
          balance_after: mockState.account.current_balance,
          digest_hash: Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2),
          timestamp: tx.approved_at,
          status: 'VERIFIED',
        });

        return resolve({
          data: {
            transfer_id: tx.id,
            status: 'SETTLED',
            message: 'Transfer authorized. Soft hold cleared and Oracle XE master balance permanently debited.'
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
        mockState.account.held_balance -= tx.amount;
        mockState.account.available_balance += tx.amount;

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
          balance_after: mockState.account.available_balance,
          digest_hash: Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2),
          timestamp: tx.rejected_at,
          status: 'VERIFIED',
        });

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

      // Default mock fallback
      return resolve({ data: { message: 'Action executed successfully in simulation mode.' } });
    }, 100);
  });
}

export default apiClient;
export { mockState };
