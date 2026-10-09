import axios from 'axios';

/**
 * One client for the console. Every request goes through the gateway at
 * /api/v1 with the staff bearer token. Failures are surfaced, never replaced
 * with simulated data: a back office must not show numbers it did not read.
 */
const TOKEN_KEY = 'aura.console.token';

export const api = axios.create({ baseURL: '/api/v1', timeout: 10000, withCredentials: true });

export const tokenStore = {
  get: () => sessionStorage.getItem(TOKEN_KEY),
  set: (t) => (t ? sessionStorage.setItem(TOKEN_KEY, t) : sessionStorage.removeItem(TOKEN_KEY)),
};

api.interceptors.request.use((config) => {
  const token = tokenStore.get();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  if (['post', 'put', 'patch'].includes(config.method)) {
    config.headers['X-Idempotency-Key'] = crypto.randomUUID();
  }
  return config;
});

api.interceptors.response.use(
  (r) => r,
  (error) => {
    if (error.response?.status === 401) window.dispatchEvent(new Event('aura:session-expired'));
    return Promise.reject(error);
  },
);

/** Human-readable message from an RFC-7807 body, a FastAPI detail, or the transport. */
export function errorMessage(err) {
  const d = err?.response?.data;
  if (d?.detail && typeof d.detail === 'string') return d.detail;
  if (d?.message) return d.message;
  if (d?.error) return d.error;
  if (err?.response?.status === 503 || err?.code === 'ERR_NETWORK') return 'The service is not reachable. Check that the stack is running.';
  if (err?.code === 'ECONNABORTED') return 'The service took too long to respond.';
  return err?.message || 'Something went wrong.';
}
