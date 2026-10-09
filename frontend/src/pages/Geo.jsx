import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { MapPinned, Plane, Navigation } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { greatCircle, haversineKm } from '../lib/format';
import { Badge, Button, ErrorNote, PageHeader, SkeletonRows, cn, useLoad, useToast } from '../components/ui';

/** Demo destinations, with an IP that geolocates to each city. */
const PLACES = [
  { name: 'Manila, Philippines', lat: 14.5995, lon: 120.9842, ip: '112.198.45.10' },
  { name: 'Cebu City, Philippines', lat: 10.3157, lon: 123.8854, ip: '112.198.120.4' },
  { name: 'Davao City, Philippines', lat: 7.1907, lon: 125.4578, ip: '112.198.99.77' },
  { name: 'Singapore', lat: 1.3521, lon: 103.8198, ip: '118.189.0.12' },
  { name: 'Tokyo, Japan', lat: 35.6762, lon: 139.6503, ip: '133.242.0.3' },
  { name: 'London, United Kingdom', lat: 51.5074, lon: -0.1278, ip: '81.2.69.160' },
  { name: 'New York, United States', lat: 40.7128, lon: -74.006, ip: '23.80.5.10' },
];

export default function Geo() {
  const toast = useToast();
  const customers = useLoad(
    () => api.get('/accounts').then((r) => {
      const byOwner = new Map();
      for (const a of r.data) {
        if (a.owner_role !== 'CUSTOMER') continue;
        const c = byOwner.get(a.user_id) || { user_id: a.user_id, name: a.owner_name || a.user_id, accounts: 0 };
        c.accounts += 1;
        byOwner.set(a.user_id, c);
      }
      return [...byOwner.values()].sort((x, y) => x.name.localeCompare(y.name));
    }),
    [],
  );
  const [userId, setUserId] = useState(null);
  const [current, setCurrent] = useState(null);
  const [target, setTarget] = useState(PLACES[5]);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  // The hop just flown, so the map keeps showing it after the customer lands.
  const [hop, setHop] = useState(null);

  useEffect(() => {
    if (!userId && customers.data?.length) setUserId(customers.data[0].user_id);
  }, [customers.data, userId]);

  useEffect(() => {
    if (!userId) return;
    setErr('');
    setHop(null);
    api.get(`/users/${userId}/location`)
      .then(({ data }) => setCurrent({
        name: data.location_name, lat: Number(data.latitude), lon: Number(data.longitude), ip: data.ip_address,
        who: [data.first_name, data.last_name].filter(Boolean).join(' '),
      }))
      .catch((e) => setErr(errorMessage(e)));
  }, [userId]);

  const km = current && target ? haversineKm(current, target) : 0;
  const impliedKmh = km / (5 / 60);
  const flagged = km >= 100 && impliedKmh > 800;

  function pick(p) {
    setTarget(p);
    setHop(null);
  }

  async function move() {
    setBusy(true);
    try {
      await api.patch(`/users/${userId}/location`, { latitude: target.lat, longitude: target.lon, location_name: target.name, ip_address: target.ip });
      setHop({ from: current, to: target });
      setCurrent({ ...target, who: current?.who });
      toast(`Customer now appears in ${target.name}. Their next transfer will be checked against the last one.`);
    } catch (e) {
      toast(errorMessage(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Location simulator"
        description="For demos. Move a customer's reported location, then have them send money. If the jump is faster than a plane, the ledger holds the transfer for review."
        actions={<Badge tone="ember">Demo tool</Badge>}
      />
      <div className="grid items-start gap-6 lg:grid-cols-[320px_1fr]">
        <div className="panel overflow-hidden animate-rise">
          <p className="label px-5 pt-5">Customers{customers.data?.length ? ` · ${customers.data.length}` : ''}</p>
          {customers.loading ? (
            <SkeletonRows rows={4} />
          ) : customers.error ? (
            <div className="p-5"><ErrorNote message={errorMessage(customers.error)} onRetry={customers.reload} /></div>
          ) : !customers.data.length ? (
            <p className="px-5 py-6 text-sm text-ink-400">No customer accounts yet.</p>
          ) : (
            <ul className="p-2">
              {customers.data.map((c, i) => {
                const on = userId === c.user_id;
                const initials = c.name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
                return (
                  <li key={c.user_id} className="row-enter" style={{ '--i': i }}>
                    <button
                      onClick={() => setUserId(c.user_id)}
                      aria-pressed={on}
                      className={cn('flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm transition-colors', on ? 'bg-ink text-white' : 'hover:bg-paper')}
                    >
                      <span aria-hidden className={cn('grid size-9 shrink-0 place-items-center rounded-full text-xs font-semibold', on ? 'bg-white/10 text-mint' : 'bg-mint-wash text-mint-deep')}>
                        {initials}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-semibold">{c.name}</span>
                        <span className={cn('block truncate font-mono text-xs', on ? 'text-white/60' : 'text-ink-400')}>
                          {c.user_id} · {c.accounts} {c.accounts === 1 ? 'account' : 'accounts'}
                        </span>
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        <div className="space-y-6">
          {err && <ErrorNote message={err} />}
          <RouteMap from={hop?.from || current} to={hop?.to || target} who={current?.who} />

          <div className="panel p-5 animate-rise" style={{ animationDelay: '120ms' }}>
            <p className="label mb-3">Move to</p>
            <div className="flex flex-wrap gap-2">
              {PLACES.map((p) => (
                <button
                  key={p.name}
                  onClick={() => pick(p)}
                  className={cn('rounded-full px-3.5 py-1.5 text-sm font-medium ring-1 ring-inset transition-colors',
                    target.name === p.name ? 'bg-ink text-white ring-ink' : 'ring-ink-100 hover:ring-ink-200')}
                >
                  {p.name.split(',')[0]}
                </button>
              ))}
            </div>
            <div className="mt-5 flex flex-wrap items-center justify-between gap-4 border-t border-ink-100 pt-5">
              <div className="text-sm">
                <p><b className="tabular-nums">{Math.round(km).toLocaleString()} km</b> from {current?.name || '...'}</p>
                <p className="text-ink-500">
                  A transfer 5 minutes later would imply <b className="tabular-nums text-ink">{Math.round(impliedKmh).toLocaleString()} km/h</b>.{' '}
                  {flagged ? <span className="text-danger font-semibold">Laya will hold it.</span> : 'Within normal travel.'}
                </p>
              </div>
              <Button icon={Navigation} loading={busy} disabled={!userId || current?.name === target.name} onClick={move}>Move customer</Button>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

const INK = '#10171C';

/** OpenStreetMap with both cities and the great-circle hop between them.
 *  The route draws itself and a marker flies along it whenever it changes. */
function RouteMap({ from, to, who }) {
  const el = useRef(null);
  const map = useRef(null);
  const layer = useRef(null);

  useEffect(() => {
    // maxBounds keeps the view off the grey band past the poles; longitudes stay wide for unwrapped routes.
    const m = L.map(el.current, { scrollWheelZoom: false, worldCopyJump: true, maxBounds: [[-85, -720], [85, 720]], maxBoundsViscosity: 1 })
      .setView([25, 60], 2);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(m);
    layer.current = L.layerGroup().addTo(m);
    map.current = m;
    return () => m.remove();
  }, []);

  useEffect(() => {
    const g = layer.current;
    g.clearLayers();
    if (!from || !to) return undefined;

    const pts = greatCircle(from, to);
    const end = pts[pts.length - 1];
    const label = (direction) => ({ permanent: true, direction, offset: direction === 'top' ? [0, -10] : [0, 10], className: 'route-label' });

    if (pts.length > 1) {
      L.polyline(pts, { color: '#fff', weight: 7, opacity: 0.85, interactive: false }).addTo(g);
      const line = L.polyline(pts, { color: INK, weight: 3, lineCap: 'round', interactive: false, className: 'route-line' }).addTo(g);
      line.getElement()?.setAttribute('pathLength', '1');
      L.circleMarker(pts[0], { radius: 6, color: '#fff', weight: 2, fillColor: '#97CFF3', fillOpacity: 1 })
        .bindTooltip(from.name.split(',')[0], label('bottom')).addTo(g);
    }
    L.marker(end, { icon: L.divIcon({ className: 'route-pin', iconSize: [16, 16] }), keyboard: false })
      .bindTooltip(to.name.split(',')[0], label('top')).addTo(g);

    if (pts.length > 1) map.current.fitBounds(L.latLngBounds(pts), { padding: [56, 56], maxZoom: 6 });
    else map.current.setView(end, 5);

    if (pts.length < 2 || matchMedia('(prefers-reduced-motion: reduce)').matches) return undefined;
    const plane = L.circleMarker(pts[0], { radius: 5, color: INK, weight: 2, fillColor: '#fff', fillOpacity: 1, interactive: false }).addTo(g);
    const t0 = performance.now();
    let raf = 0;
    const step = (t) => {
      const f = Math.min(1, (t - t0) / 1800);
      const e = f < 0.5 ? 2 * f * f : 1 - (-2 * f + 2) ** 2 / 2;
      plane.setLatLng(pts[Math.round(e * (pts.length - 1))]);
      if (f < 1) raf = requestAnimationFrame(step);
      else g.removeLayer(plane);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [from, to]);

  return (
    <div className="panel relative isolate overflow-hidden animate-rise" style={{ animationDelay: '60ms' }}>
      <div ref={el} className="h-[380px] w-full bg-ink-100" role="region" aria-label={from && to ? `Map of the route from ${from.name} to ${to.name}` : 'Route map'} />
      <div className="flex flex-wrap items-center gap-x-2 gap-y-1 bg-ink px-5 py-3 text-sm text-white/70">
        <MapPinned className="size-4 text-mint" /> {who ? <b className="text-white">{who}</b> : 'Now'} in <b className="text-white">{from?.name || '...'}</b>
        <Plane className="ml-3 size-4 text-sky" /> Target <b className="text-white">{to?.name}</b>
      </div>
      <style>{`
        .leaflet-container { font: inherit; }
        .route-label { background: ${INK}; color: #fff; border: 0; border-radius: 999px; padding: 3px 10px; font-size: 12px; font-weight: 600; box-shadow: 0 4px 12px rgb(16 23 28 / .18); }
        .route-label::before { display: none; }
        .route-pin { border-radius: 999px; background: #A7E8D1; box-shadow: 0 0 0 2px ${INK}, 0 0 0 4px #fff; }
        @media (prefers-reduced-motion: no-preference) {
          .route-line { stroke-dasharray: 1; stroke-dashoffset: 1; animation: route-draw 1.4s cubic-bezier(0.16,1,0.3,1) forwards; }
          .route-pin::after { content: ''; position: absolute; inset: -6px; border-radius: 999px; border: 2px solid #A7E8D1; animation: route-ping 2.4s ease-out 1s infinite; opacity: 0; }
        }
        @keyframes route-draw { to { stroke-dashoffset: 0; } }
        @keyframes route-ping { 0% { opacity: .9; transform: scale(.6); } 100% { opacity: 0; transform: scale(2.2); } }
      `}</style>
    </div>
  );
}
