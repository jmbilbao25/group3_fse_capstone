import React, { useState } from 'react';
import { AlertCircle, ArrowRight, Eye, EyeOff, Lock, Mail, ShieldCheck, Users } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import Brand from './Brand';
import ThemeToggle from './ThemeToggle';
import { Button, Field, Input, Callout, cn } from '../ui';

const ADMIN_PERSONAS = [
  { 
    name: 'Carlos Mendoza', 
    role: 'Senior Operations Lead (Admin 1 / Maker)', 
    email: 'carlos.mendoza@bank.com',
    userId: 'usr-1006-mgr-002',
    badge: 'Operations Lead'
  },
  { 
    name: 'Diana Vance', 
    role: 'Compliance & Audit Lead (Admin 2 / Checker)', 
    email: 'diana.admin@bank.com',
    userId: 'usr-1004-adm-001',
    badge: 'Compliance Lead'
  },
];

const DEMO_PASSWORD = 'password123';

export default function Login({ onLoginSuccess }) {
  const { login, isLoading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const fill = (persona) => {
    setEmail(persona.email);
    setPassword(DEMO_PASSWORD);
    setError('');
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!email.trim()) {
      setError('Enter your administrative email address.');
      return;
    }

    setError('');
    setSubmitting(true);

    try {
      const res = await login(email.trim(), password || DEMO_PASSWORD);
      if (res?.success) {
        onLoginSuccess?.();
      } else {
        setError(res?.error || 'Administrative credentials were not recognized.');
      }
    } catch {
      setError('Could not reach the authentication gateway. Check system status and try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const busy = submitting || isLoading;

  return (
    <div className="flex min-h-screen flex-col bg-canvas text-fg">
      {/* Top Bar */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-line">
        <Brand />
        <div className="flex items-center gap-3">
          <div className="hidden sm:flex items-center gap-1.5 rounded-full border border-emerald-500/30 bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-400">
            <ShieldCheck className="h-3.5 w-3.5" />
            <span>Dedicated Admin Portal</span>
          </div>
          <ThemeToggle />
        </div>
      </div>

      <div className="flex flex-1 items-center justify-center px-4 py-12">
        <div className="w-full max-w-md space-y-6">
          {/* Header */}
          <div className="text-center">
            <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-xl bg-accent/10 text-accent">
              <Users className="h-6 w-6" />
            </div>
            <h1 className="mt-4 text-2xl font-bold tracking-tight text-fg">
              Central Operations Sign In
            </h1>
            <p className="mt-1.5 text-xs text-fg-muted max-w-sm mx-auto">
              Authorized access for CBS transaction surveillance, dual-admin reversal control, and geographic fraud governance.
            </p>
          </div>

          {/* Form */}
          <div className="rounded-2xl border border-line bg-surface p-6 sm:p-8 shadow-sm">
            <form onSubmit={handleSubmit} className="space-y-4" noValidate>
              {error && (
                <Callout tone="voided" icon={AlertCircle} role="alert">
                  {error}
                </Callout>
              )}

              <Field label="Administrative Email" htmlFor="email">
                <Input
                  id="email"
                  name="email"
                  type="email"
                  placeholder="name@bank.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  autoComplete="username"
                  autoFocus
                  icon={Mail}
                  size="lg"
                />
              </Field>

              <Field label="Security Passphrase" htmlFor="password">
                <div className="relative">
                  <Lock
                    className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-fg-subtle"
                    aria-hidden="true"
                  />
                  <input
                    id="password"
                    name="password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    autoComplete="current-password"
                    placeholder="Enter admin password"
                    className={cn(
                      'h-11 w-full border border-line bg-sunken pl-9 pr-11 text-sm text-fg rounded-lg',
                      'transition-[background-color,border-color] duration-150',
                      'placeholder:text-fg-subtle hover:border-line-strong',
                      'focus:border-accent focus:bg-surface focus:outline-none'
                    )}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((v) => !v)}
                    aria-pressed={showPassword}
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                    className="absolute right-0 top-0 flex h-11 w-11 items-center justify-center text-fg-subtle transition-colors hover:text-fg"
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4" aria-hidden="true" />
                    ) : (
                      <Eye className="h-4 w-4" aria-hidden="true" />
                    )}
                  </button>
                </div>
              </Field>

              <Button type="submit" variant="primary" size="lg" fullWidth loading={busy} icon={ArrowRight}>
                {busy ? 'Authenticating Operator...' : 'Sign In to Console'}
              </Button>
            </form>

            {/* Quick-Select Admin Personas */}
            <div className="mt-8 border-t border-line pt-6">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wider text-fg-subtle">
                  Authorized Administrators
                </span>
                <span className="text-[11px] text-fg-subtle font-mono">
                  Default: {DEMO_PASSWORD}
                </span>
              </div>

              <div className="mt-3 space-y-2">
                {ADMIN_PERSONAS.map((admin) => (
                  <button
                    key={admin.email}
                    type="button"
                    onClick={() => fill(admin)}
                    className={cn(
                      "flex w-full items-center justify-between rounded-xl border border-line bg-sunken/40 p-3 text-left transition hover:bg-sunken hover:border-line-strong",
                      email === admin.email && "border-accent/60 bg-accent/5 ring-1 ring-accent/30"
                    )}
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-bold text-fg">{admin.name}</span>
                        <span className="rounded-md bg-accent/10 px-1.5 py-0.5 text-[10px] font-semibold text-accent-text">
                          {admin.badge}
                        </span>
                      </div>
                      <span className="block text-[11px] text-fg-muted mt-0.5">{admin.role}</span>
                      <span className="block text-[10px] text-fg-subtle font-mono mt-0.5">{admin.email}</span>
                    </div>
                    <span className="rounded-lg border border-line bg-surface px-2.5 py-1 text-xs font-medium text-accent hover:border-accent transition">
                      Select
                    </span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
