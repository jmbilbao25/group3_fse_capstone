const php = new Intl.NumberFormat('en-PH', { style: 'currency', currency: 'PHP', minimumFractionDigits: 2 });
const compact = new Intl.NumberFormat('en-PH', { notation: 'compact', maximumFractionDigits: 1 });

export const money = (n) => (n == null || Number.isNaN(Number(n)) ? '-' : php.format(Number(n)));
export const moneyCompact = (n) => `₱${compact.format(Number(n) || 0)}`;

export function dateTime(v) {
  if (!v) return '-';
  const d = new Date(v);
  return Number.isNaN(d) ? String(v) : d.toLocaleString('en-PH', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
}

export function ago(v) {
  const s = (Date.now() - new Date(v).getTime()) / 1000;
  if (!Number.isFinite(s)) return '';
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return `${Math.floor(s / 86400)} d ago`;
}

export const fullName = (p) => [p?.first_name, p?.middle_name, p?.last_name].filter(Boolean).join(' ');

export const titleCase = (s) => String(s || '').toLowerCase().replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase());

/** Great-circle distance, km. Same formula the ledger uses. */
export function haversineKm(a, b) {
  const r = (x) => (x * Math.PI) / 180;
  const h = Math.sin(r(b.lat - a.lat) / 2) ** 2 + Math.cos(r(a.lat)) * Math.cos(r(b.lat)) * Math.sin(r(b.lon - a.lon) / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

/** [lat, lon] points along the great circle from a to b. Longitudes are
 *  unwrapped so a Pacific crossing draws as one line, not two. */
export function greatCircle(a, b, n = 64) {
  const r = Math.PI / 180;
  const [p1, l1, p2, l2] = [a.lat * r, a.lon * r, b.lat * r, b.lon * r];
  const d = (haversineKm(a, b) / 6371) || 0;
  if (d < 1e-9) return [[a.lat, a.lon]];
  const pts = [];
  for (let i = 0; i <= n; i += 1) {
    const f = i / n;
    const A = Math.sin((1 - f) * d) / Math.sin(d);
    const B = Math.sin(f * d) / Math.sin(d);
    const x = A * Math.cos(p1) * Math.cos(l1) + B * Math.cos(p2) * Math.cos(l2);
    const y = A * Math.cos(p1) * Math.sin(l1) + B * Math.cos(p2) * Math.sin(l2);
    const z = A * Math.sin(p1) + B * Math.sin(p2);
    let lon = Math.atan2(y, x) / r;
    if (i) lon += 360 * Math.round((pts[i - 1][1] - lon) / 360);
    pts.push([Math.atan2(z, Math.hypot(x, y)) / r, lon]);
  }
  return pts;
}

const ID_TYPES = { PHILID: 'PhilSys National ID', DRIVERS_LICENSE: "Driver's license", PASSPORT: 'Philippine passport', UMID: 'UMID', POSTAL_ID: 'Postal ID', PRC: 'PRC ID' };
export const idTypeLabel = (t) => ID_TYPES[String(t || '').toUpperCase()] || titleCase(t);
