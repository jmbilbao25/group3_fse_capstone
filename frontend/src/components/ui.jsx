import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { Loader2, X, AlertTriangle, CheckCircle2 } from 'lucide-react';

export const cn = (...c) => c.filter(Boolean).join(' ');

/** The Aura mark. Same geometry as the app painter and public/mark.svg. */
export function Logo({ size = 32, className }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" className={className} aria-label="Aura">
      <defs>
        <linearGradient id="lg-arch" x1="0" x2="1">
          <stop offset="0" stopColor="#97CFF3" />
          <stop offset="1" stopColor="#A7E8D1" />
        </linearGradient>
      </defs>
      <rect width="64" height="64" rx="18" fill="#10171C" />
      <path d="M18 48C18 29 24.5 15 32 15s14 14 14 33" fill="none" stroke="url(#lg-arch)" strokeWidth="6.4" strokeLinecap="round" />
      <path d="M22.5 37c4-4 7-4 9.5-1.5s5.5 2.5 9.5-1.5" fill="none" stroke="#fff" strokeOpacity=".94" strokeWidth="3.6" strokeLinecap="round" />
    </svg>
  );
}

export const Aurora = ({ className }) => (
  <div className={cn('aurora', className)} aria-hidden>
    <span />
    <span />
    <span />
    <i />
  </div>
);

const BUTTON = {
  primary: 'bg-ink text-white hover:bg-ink-800',
  mint: 'bg-mint text-ink hover:bg-[#95DEC4]',
  ghost: 'bg-transparent text-ink-500 hover:bg-ink-100 hover:text-ink',
  outline: 'bg-white text-ink ring-1 ring-inset ring-ink-100 hover:ring-ink-200',
  danger: 'bg-white text-danger ring-1 ring-inset ring-danger/25 hover:bg-danger-wash',
};

export function Button({ variant = 'primary', size = 'md', loading, icon: Icon, children, className, ...rest }) {
  return (
    <button
      {...rest}
      disabled={loading || rest.disabled}
      className={cn(
        'inline-flex items-center justify-center gap-2 rounded-full font-semibold transition-[transform,background-color,box-shadow] duration-200 ease-out active:scale-[.97] disabled:opacity-50 disabled:pointer-events-none',
        size === 'sm' ? 'h-8 px-3.5 text-[13px]' : 'h-10 px-5 text-sm',
        BUTTON[variant],
        className,
      )}
    >
      {loading ? <Loader2 className="size-4 animate-spin" /> : Icon && <Icon className="size-4" strokeWidth={2.2} />}
      {children}
    </button>
  );
}

const TONE = {
  neutral: 'bg-ink-100 text-ink-500',
  mint: 'bg-mint-wash text-mint-deep',
  sky: 'bg-sky-wash text-sky-deep',
  ember: 'bg-ember-wash text-ember-deep',
  danger: 'bg-danger-wash text-danger',
  ink: 'bg-ink text-white',
};

export const Badge = ({ tone = 'neutral', children, className }) => (
  <span className={cn('inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap', TONE[tone], className)}>{children}</span>
);

export function PageHeader({ title, description, actions }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-4 mb-6 animate-rise">
      <div>
        <h1 className="text-[28px] font-semibold tracking-[-0.03em] leading-tight">{title}</h1>
        {description && <p className="mt-1.5 text-[15px] text-ink-500 max-w-2xl">{description}</p>}
      </div>
      {actions && <div className="flex gap-2">{actions}</div>}
    </div>
  );
}

export const Empty = ({ icon: Icon = CheckCircle2, title, body }) => (
  <div className="py-16 text-center animate-fade">
    <div className="mx-auto mb-4 grid size-12 place-items-center rounded-full bg-mint-wash text-mint-deep">
      <Icon className="size-5" />
    </div>
    <p className="font-semibold">{title}</p>
    {body && <p className="mt-1 text-sm text-ink-400 max-w-sm mx-auto">{body}</p>}
  </div>
);

export const ErrorNote = ({ message, onRetry }) => (
  <div className="flex items-center gap-3 rounded-xl bg-danger-wash px-4 py-3 text-sm text-danger animate-fade">
    <AlertTriangle className="size-4 shrink-0" />
    <span className="flex-1">{message}</span>
    {onRetry && (
      <button onClick={onRetry} className="font-semibold underline underline-offset-4">
        Try again
      </button>
    )}
  </div>
);

export const SkeletonRows = ({ rows = 5 }) => (
  <div className="space-y-3 p-5">
    {Array.from({ length: rows }, (_, i) => (
      <div key={i} className="skeleton h-12" style={{ opacity: 1 - i * 0.12 }} />
    ))}
  </div>
);

/** Laya confidence as a ring that sweeps to its value once. */
export function ConfidenceRing({ value, size = 72 }) {
  const v = Math.max(0, Math.min(100, Number(value) || 0));
  const r = 30;
  const c = 2 * Math.PI * r;
  const tone = v >= 90 ? '#1C6E5A' : v >= 70 ? '#B7681E' : '#C8423B';
  const [shown, setShown] = useState(0);
  useEffect(() => {
    const id = requestAnimationFrame(() => setShown(v));
    return () => cancelAnimationFrame(id);
  }, [v]);
  return (
    <div className="relative shrink-0" style={{ width: size, height: size }}>
      <svg viewBox="0 0 72 72" className="-rotate-90" width={size} height={size}>
        <circle cx="36" cy="36" r={r} fill="none" stroke="#EAECEE" strokeWidth="6" />
        <circle
          cx="36" cy="36" r={r} fill="none" stroke={tone} strokeWidth="6" strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={c * (1 - shown / 100)}
          style={{ transition: 'stroke-dashoffset 1.1s cubic-bezier(0.16,1,0.3,1)' }}
        />
      </svg>
      <div className="absolute inset-0 grid place-items-center">
        <span className="text-[15px] font-semibold tabular-nums" style={{ color: tone }}>{value == null ? '-' : `${v.toFixed(0)}%`}</span>
      </div>
    </div>
  );
}

/** Right-hand drawer. Escape and the scrim close it; focus moves inside on open. */
export function Drawer({ open, onClose, title, subtitle, children, footer, width = 'max-w-2xl' }) {
  const ref = useRef(null);
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    ref.current?.focus();
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-40 flex justify-end">
      <div className="absolute inset-0 bg-ink/30 backdrop-blur-[2px] animate-fade" onClick={onClose} />
      <section
        ref={ref}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={cn('relative flex h-full w-full flex-col bg-paper shadow-lift outline-none animate-drawer', width)}
      >
        <header className="flex items-start gap-4 border-b border-ink-100 bg-white px-6 py-5">
          <div className="flex-1 min-w-0">
            <h2 className="text-lg font-semibold tracking-[-0.01em] truncate">{title}</h2>
            {subtitle && <p className="text-sm text-ink-400 mt-0.5">{subtitle}</p>}
          </div>
          <button onClick={onClose} aria-label="Close" className="grid size-9 place-items-center rounded-full text-ink-400 hover:bg-ink-100 hover:text-ink">
            <X className="size-5" />
          </button>
        </header>
        <div className="flex-1 overflow-y-auto px-6 py-6">{children}</div>
        {footer && <footer className="border-t border-ink-100 bg-white px-6 py-4">{footer}</footer>}
      </section>
    </div>
  );
}

const ToastContext = createContext(() => {});
export const useToast = () => useContext(ToastContext);

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const push = useCallback((message, tone = 'ok') => {
    const id = crypto.randomUUID();
    setToasts((t) => [...t, { id, message, tone }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 5000);
  }, []);
  return (
    <ToastContext.Provider value={push}>
      {children}
      <div className="fixed bottom-6 left-1/2 z-50 -translate-x-1/2 space-y-2" aria-live="polite">
        {toasts.map((t) => (
          <div key={t.id} className="flex items-center gap-3 rounded-full bg-ink px-5 py-3 text-sm text-white shadow-lift animate-rise">
            {t.tone === 'error' ? <AlertTriangle className="size-4 text-ember" /> : <CheckCircle2 className="size-4 text-mint" />}
            {t.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

/** Loads data from the API; returns { data, error, loading, reload }. */
export function useLoad(fn, deps = []) {
  const [state, setState] = useState({ data: null, error: null, loading: true });
  const run = useCallback(async () => {
    setState((s) => ({ ...s, loading: true, error: null }));
    try {
      setState({ data: await fn(), error: null, loading: false });
    } catch (e) {
      setState({ data: null, error: e, loading: false });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  useEffect(() => {
    run();
  }, [run]);
  return { ...state, reload: run };
}
