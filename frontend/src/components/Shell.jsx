import { Navigate, NavLink, Outlet, useLocation } from 'react-router-dom';
import { LayoutGrid, ScanFace, ArrowLeftRight, MapPinned, FileWarning, ScrollText, LogOut, Users, Undo2 } from 'lucide-react';
import { canOpen, useAuth } from '../context/Auth';
import { Aurora, Logo, cn } from './ui';

const NAV = [
  { to: '/', label: 'Overview', icon: LayoutGrid, end: true },
  { to: '/customers', label: 'Customers', icon: Users },
  { to: '/kyc', label: 'Identity review', icon: ScanFace },
  { to: '/transfers', label: 'Held transfers', icon: ArrowLeftRight },
  { to: '/reversals', label: 'Reversals', icon: Undo2 },
  { to: '/sar', label: 'SAR / STR', icon: FileWarning },
  { to: '/geo', label: 'Location simulator', icon: MapPinned },
  { to: '/audit', label: 'Audit trail', icon: ScrollText },
];

export default function Shell() {
  const { staff, logout } = useAuth();
  const { pathname } = useLocation();
  return (
    <div className="flex min-h-[100dvh]">
      <aside className="sticky top-0 flex h-[100dvh] w-[264px] shrink-0 flex-col overflow-hidden bg-ink text-white">
        <div className="relative h-40 shrink-0">
          <Aurora />
          <div className="relative z-10 flex items-center gap-3 px-6 pt-6">
            <Logo size={34} />
            <div>
              <p className="font-semibold leading-tight">Aura Console</p>
              <p className="text-xs text-white/55">Back office</p>
            </div>
          </div>
        </div>
        <nav className="-mt-10 relative z-10 flex-1 space-y-1 px-3">
          {NAV.filter((n) => canOpen(staff?.role, n.to)).map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  'group flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-[14px] font-medium transition-colors duration-200',
                  isActive ? 'bg-white/10 text-white' : 'text-white/60 hover:bg-white/5 hover:text-white',
                )
              }
            >
              {({ isActive }) => (
                <>
                  <Icon className={cn('size-[18px] transition-colors', isActive ? 'text-mint' : 'text-white/45 group-hover:text-white/80')} strokeWidth={2} />
                  {label}
                </>
              )}
            </NavLink>
          ))}
        </nav>
        <div className="m-3 flex items-center gap-3 rounded-2xl bg-white/5 p-3">
          <div className="grid size-9 shrink-0 place-items-center rounded-full bg-mint font-semibold text-ink">{staff?.name?.[0]}</div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold">{staff?.name}</p>
            <p className="truncate text-xs text-white/50">{staff?.title}</p>
          </div>
          <button onClick={logout} aria-label="Sign out" className="grid size-8 place-items-center rounded-full text-white/50 hover:bg-white/10 hover:text-white">
            <LogOut className="size-4" />
          </button>
        </div>
      </aside>
      <main className="min-w-0 flex-1">
        {/* Keyed by path so each view gets its own entrance. */}
        <div key={pathname} className="mx-auto max-w-[1280px] px-10 py-10">
          {canOpen(staff?.role, pathname) ? <Outlet /> : <Navigate to="/" replace />}
        </div>
      </main>
    </div>
  );
}
