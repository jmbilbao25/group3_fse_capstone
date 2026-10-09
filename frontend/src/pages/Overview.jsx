import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowUpRight, ScanFace, ArrowLeftRight, FileWarning, Undo2 } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { ago, money } from '../lib/format';
import { canOpen, useAuth } from '../context/Auth';
import { Aurora, Badge, ErrorNote, SkeletonRows, useLoad } from '../components/ui';
import { holdReason } from './Transfers';

/** Counts up to n over ~0.9s with an ease-out, once per value. */
function Count({ n }) {
  const [v, setV] = useState(0);
  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return setV(n);
    let raf;
    const t0 = performance.now();
    const tick = (t) => {
      const p = Math.min(1, (t - t0) / 900);
      setV(Math.round(n * (1 - (1 - p) ** 3)));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [n]);
  return <span className="tabular-nums">{v}</span>;
}

export default function Overview() {
  const { staff } = useAuth();
  const { data, error, loading, reload } = useLoad(async () => {
    // Each source fails on its own, so one service down does not blank the page.
    const [kyc, held, sar, rev] = await Promise.allSettled([
      api.get('/kyc/reviews').then((r) => r.data),
      api.get('/transfers/pending').then((r) => r.data),
      api.get('/risk/sar').then((r) => r.data),
      api.get('/reversals', { params: { status: 'PENDING' } }).then((r) => r.data),
    ]);
    return { kyc, held, sar, rev };
  }, []);

  const val = (s) => (s?.status === 'fulfilled' ? s.value : null);
  const kyc = val(data?.kyc);
  const held = val(data?.held);
  const sar = val(data?.sar);
  const hour = new Date().getHours();

  const tiles = [
    { to: '/kyc', icon: ScanFace, label: 'Identities to review', n: kyc?.filter((r) => r.status.startsWith('PENDING')).length, src: data?.kyc },
    { to: '/transfers', icon: ArrowLeftRight, label: 'Transfers on hold', n: held?.length, src: data?.held },
    { to: '/reversals', icon: Undo2, label: 'Reversals awaiting sign-off', n: val(data?.rev)?.length, src: data?.rev },
    { to: '/sar', icon: FileWarning, label: 'Reports awaiting sign-off', n: sar?.filter((r) => ['DRAFT', 'PENDING_CHECKER'].includes(r.review?.status)).length, src: data?.sar },
  ].filter((t) => canOpen(staff?.role, t.to));

  return (
    <div className="space-y-8">
      <section className="relative overflow-hidden rounded-3xl animate-rise">
        <Aurora />
        <div className="relative z-10 px-10 py-12 text-white">
          <p className="text-white/60">{hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening'}, {staff?.name?.split(' ')[0]}</p>
          <h1 className="mt-2 max-w-xl text-[40px] font-semibold leading-[1.08] tracking-[-0.035em]">Here is what needs a person today.</h1>
        </div>
      </section>

      {loading ? (
        <SkeletonRows rows={3} />
      ) : error ? (
        <ErrorNote message={errorMessage(error)} onRetry={reload} />
      ) : (
        <>
          <div className="grid gap-4 md:auto-cols-fr md:grid-flow-col">
            {tiles.map(({ to, icon: Icon, label, n, src }, i) => (
              <Link key={to} to={to} className="panel group p-6 transition-[transform,box-shadow] duration-300 ease-out hover:-translate-y-0.5 hover:shadow-lift animate-rise" style={{ animationDelay: `${80 + i * 60}ms` }}>
                <div className="flex items-start justify-between">
                  <div className="grid size-10 place-items-center rounded-xl bg-mint-wash text-mint-deep"><Icon className="size-5" /></div>
                  <ArrowUpRight className="size-5 text-ink-300 transition-transform duration-300 group-hover:-translate-y-0.5 group-hover:translate-x-0.5 group-hover:text-ink" />
                </div>
                <p className="mt-6 text-4xl font-semibold tracking-[-0.03em]">{src?.status === 'fulfilled' ? <Count n={n || 0} /> : '-'}</p>
                <p className="mt-1 text-sm text-ink-500">{src?.status === 'fulfilled' ? label : `${label} (unavailable)`}</p>
              </Link>
            ))}
          </div>

          <section className="panel animate-rise" style={{ animationDelay: '260ms' }}>
            <div className="flex items-center justify-between px-6 pt-5">
              <h2 className="font-semibold">Latest holds</h2>
              <Link to="/transfers" className="text-sm font-medium text-ink-500 hover:text-ink">See all</Link>
            </div>
            <ul className="mt-2">
              {(held || []).slice(0, 5).map((t, i) => {
                const why = holdReason(t);
                return (
                  <li key={t.transactionId} className="row-enter flex items-center gap-4 border-t border-ink-100 px-6 py-3.5 text-sm" style={{ '--i': i }}>
                    <span className="font-semibold tabular-nums">{money(t.amount)}</span>
                    <span className="flex-1 truncate text-ink-500">{t.fromAccountId} to {t.toAccountId}</span>
                    <Badge tone={why.tone}>{why.label}</Badge>
                    <span className="w-20 text-right text-ink-400">{ago(t.createdAt)}</span>
                  </li>
                );
              })}
              {held?.length === 0 && <li className="border-t border-ink-100 px-6 py-6 text-sm text-ink-400">Nothing on hold.</li>}
            </ul>
          </section>
        </>
      )}
    </div>
  );
}
