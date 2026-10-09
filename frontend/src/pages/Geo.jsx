import { useEffect, useMemo, useState } from 'react';
import { MapPinned, Plane, Navigation } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { haversineKm } from '../lib/format';
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

// Equirectangular projection over the region the demo uses.
const W = 760;
const H = 360;
const project = (lat, lon) => [((lon + 100) / 260) * W, ((62 - lat) / 72) * H];

export default function Geo() {
  const toast = useToast();
  const customers = useLoad(
    () => api.get('/accounts').then((r) => [...new Map(r.data.map((a) => [a.user_id, a])).values()].filter((a) => a.user_id?.includes('cst'))),
    [],
  );
  const [userId, setUserId] = useState(null);
  const [current, setCurrent] = useState(null);
  const [target, setTarget] = useState(PLACES[5]);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [flight, setFlight] = useState(0);

  useEffect(() => {
    if (!userId && customers.data?.length) setUserId(customers.data[0].user_id);
  }, [customers.data, userId]);

  useEffect(() => {
    if (!userId) return;
    setErr('');
    api.get(`/users/${userId}/location`)
      .then(({ data }) => setCurrent({ name: data.location_name, lat: Number(data.latitude), lon: Number(data.longitude), ip: data.ip_address }))
      .catch((e) => setErr(errorMessage(e)));
  }, [userId]);

  const km = current && target ? haversineKm(current, target) : 0;
  const impliedKmh = km / (5 / 60);
  const flagged = km >= 100 && impliedKmh > 800;

  async function move() {
    setBusy(true);
    try {
      await api.patch(`/users/${userId}/location`, { latitude: target.lat, longitude: target.lon, location_name: target.name, ip_address: target.ip });
      setFlight((f) => f + 1);
      setCurrent(target);
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
      <div className="grid gap-6 lg:grid-cols-[320px_1fr]">
        <div className="panel overflow-hidden animate-rise">
          <p className="label px-5 pt-5">Customer</p>
          {customers.loading ? (
            <SkeletonRows rows={4} />
          ) : customers.error ? (
            <div className="p-5"><ErrorNote message={errorMessage(customers.error)} onRetry={customers.reload} /></div>
          ) : (
            <ul className="p-2">
              {customers.data.map((c, i) => (
                <li key={c.user_id} className="row-enter" style={{ '--i': i }}>
                  <button
                    onClick={() => setUserId(c.user_id)}
                    className={cn('w-full rounded-xl px-3 py-2.5 text-left text-sm transition-colors', userId === c.user_id ? 'bg-ink text-white' : 'hover:bg-paper')}
                  >
                    <p className="font-semibold">{c.user_id}</p>
                    <p className={cn('text-xs', userId === c.user_id ? 'text-white/60' : 'text-ink-400')}>{c.account_number}</p>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="space-y-6">
          {err && <ErrorNote message={err} />}
          <RouteMap from={current} to={target} flight={flight} />

          <div className="panel p-5 animate-rise" style={{ animationDelay: '120ms' }}>
            <p className="label mb-3">Move to</p>
            <div className="flex flex-wrap gap-2">
              {PLACES.map((p) => (
                <button
                  key={p.name}
                  onClick={() => setTarget(p)}
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

/** Graticule, both cities and the great-circle hop drawn as an arc. The arc
 *  draws itself and a plane runs along it each time the customer is moved. */
function RouteMap({ from, to, flight }) {
  const arc = useMemo(() => {
    if (!from || !to) return null;
    const [x1, y1] = project(from.lat, from.lon);
    const [x2, y2] = project(to.lat, to.lon);
    const lift = Math.min(140, Math.hypot(x2 - x1, y2 - y1) * 0.35);
    const cx = (x1 + x2) / 2;
    const cy = Math.min(y1, y2) - lift;
    return { x1, y1, x2, y2, d: `M${x1},${y1} Q${cx},${cy} ${x2},${y2}` };
  }, [from, to]);

  return (
    <div className="panel relative overflow-hidden animate-rise" style={{ animationDelay: '60ms' }}>
      <div className="absolute inset-0 bg-ink" />
      <svg viewBox={`0 0 ${W} ${H}`} className="relative block w-full" role="img" aria-label={from && to ? `Route from ${from.name} to ${to.name}` : 'Route map'}>
        <defs>
          <linearGradient id="route" x1="0" x2="1"><stop offset="0" stopColor="#97CFF3" /><stop offset="1" stopColor="#A7E8D1" /></linearGradient>
          <radialGradient id="ping"><stop offset="0" stopColor="#A7E8D1" stopOpacity=".6" /><stop offset="1" stopColor="#A7E8D1" stopOpacity="0" /></radialGradient>
        </defs>
        {Array.from({ length: 9 }, (_, i) => <line key={`v${i}`} x1={(i * W) / 8} x2={(i * W) / 8} y1="0" y2={H} stroke="#fff" strokeOpacity=".05" />)}
        {Array.from({ length: 5 }, (_, i) => <line key={`h${i}`} y1={(i * H) / 4} y2={(i * H) / 4} x1="0" x2={W} stroke="#fff" strokeOpacity=".05" />)}
        {PLACES.map((p) => {
          const [x, y] = project(p.lat, p.lon);
          return <circle key={p.name} cx={x} cy={y} r="2.5" fill="#fff" fillOpacity=".3" />;
        })}
        {arc && (
          <g key={`${from.name}-${to.name}-${flight}`}>
            <path d={arc.d} fill="none" stroke="url(#route)" strokeWidth="2.5" strokeLinecap="round" pathLength="1" strokeDasharray="1" className="route-draw" />
            <circle cx={arc.x2} cy={arc.y2} r="22" fill="url(#ping)" className="route-ping" />
            <circle cx={arc.x1} cy={arc.y1} r="5" fill="#97CFF3" />
            <circle cx={arc.x2} cy={arc.y2} r="5" fill="#A7E8D1" />
            <g className="route-plane" style={{ offsetPath: `path('${arc.d}')` }}>
              <circle r="4" fill="#fff" />
            </g>
            <text x={arc.x1 + 10} y={arc.y1 + 18} fill="#fff" fillOpacity=".75" fontSize="13">{from.name.split(',')[0]}</text>
            <text x={arc.x2 + 10} y={arc.y2 - 10} fill="#fff" fontSize="13" fontWeight="600">{to.name.split(',')[0]}</text>
          </g>
        )}
      </svg>
      <div className="relative flex items-center gap-2 border-t border-white/10 px-5 py-3 text-sm text-white/70">
        <MapPinned className="size-4 text-mint" /> Now in <b className="text-white">{from?.name || '...'}</b>
        <Plane className="ml-3 size-4 text-sky" /> Target <b className="text-white">{to?.name}</b>
      </div>
      <style>{`
        .route-draw { stroke-dashoffset: 1; animation: route-draw 1.2s cubic-bezier(0.16,1,0.3,1) forwards; }
        .route-ping { transform-box: fill-box; transform-origin: center; animation: route-ping 2.4s ease-out 1s infinite; opacity: 0; }
        .route-plane { offset-rotate: auto; offset-distance: 0%; animation: route-fly 1.6s cubic-bezier(0.65,0,0.35,1) .2s forwards; opacity: 0; }
        @keyframes route-draw { to { stroke-dashoffset: 0; } }
        @keyframes route-ping { 0% { opacity: .9; transform: scale(.4); } 100% { opacity: 0; transform: scale(1.6); } }
        @keyframes route-fly { 0% { opacity: 1; offset-distance: 0%; } 90% { opacity: 1; } 100% { opacity: 0; offset-distance: 100%; } }
      `}</style>
    </div>
  );
}
